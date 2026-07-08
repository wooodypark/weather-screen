import Foundation

/// OpenWeatherMap "Current Weather" API 를 호출하고 결과를 WeatherCondition 으로
/// 정규화해 콜백으로 전달하는 담당자.
///
/// 두 가지 모드가 있습니다(Settings.autoMode):
///  - 자동: 실제 날씨를 30분마다 폴링해 반영.
///  - 수동: 사용자가 고른 효과(비/눈/맑음)를 고정. 폴링하지 않음(네트워크 0).
///
/// 배터리 관점의 핵심:
///  - 자동 모드에서도 30분에 한 번만 네트워크를 칩니다(Timer). 무시 가능한 비용.
///  - 결과가 "직전과 같으면" 콜백을 다시 부르지 않습니다 → 불필요한 씬 재구성 방지.
///  - 수동 모드에서는 타이머 자체를 멈춰 아무 네트워크도 발생하지 않습니다.
///  - URLSession 기본 세션만 사용(백그라운드 세션·상시 소켓 없음).
@MainActor
final class WeatherManager {

    /// 상태가 "바뀌었을 때만" 호출되는 콜백. AppDelegate 가 여기에 UI 갱신을 겁니다.
    var onConditionChange: ((WeatherCondition) -> Void)?
    /// 매 조회 시(변화 여부 무관) 호출 — 메뉴의 "마지막 업데이트 시각" 등에 사용.
    var onUpdate: ((Result<WeatherCondition, Error>) -> Void)?

    /// 현재까지 파악된 상태. 초기값은 clear(효과 없음).
    private(set) var currentCondition: WeatherCondition = .clear

    /// 마지막으로 조회된 위치의 도시명(응답의 name). 메뉴 표시용.
    private(set) var lastLocationName: String?

    private let settings: Settings
    private let location = LocationManager()
    private var timer: Timer?

    /// 폴링 주기 30분(요구사항). 초 단위.
    private let interval: TimeInterval = 30 * 60

    init(settings: Settings = .shared) {
        self.settings = settings
    }

    /// 현재 모드(자동/수동)에 맞게 폴링을 시작하거나 멈춥니다.
    /// 앱 시작 시, 그리고 모드가 바뀔 때마다 호출합니다.
    func applyMode() {
        if settings.autoMode {
            startPolling()
        } else {
            stop()
            let manual = settings.manualCondition
            currentCondition = manual
            onUpdate?(.success(manual))
            onConditionChange?(manual)
        }
    }

    private func startPolling() {
        stop()
        refreshNow()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        t.tolerance = 60   // wake 코얼레싱 허용 → 배터리 유리.
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 지금 즉시 1회 조회. 수동 모드에서는 API 대신 고정 효과를 유지합니다.
    func refreshNow() {
        guard settings.autoMode else {
            applyMode()
            return
        }
        guard settings.isConfigured else {
            onUpdate?(.failure(WeatherError.notConfigured))
            return
        }
        Task { await fetch() }
    }

    // MARK: - 모드 전환 (메뉴에서 호출)

    /// 수동 모드로 전환하며 특정 효과를 고정. 폴링은 멈춥니다.
    func selectManual(_ condition: WeatherCondition) {
        settings.autoMode = false
        settings.manualCondition = condition
        applyMode()
    }

    /// 자동 모드로 복귀. 실제 날씨 폴링을 재개하고 즉시 1회 조회합니다.
    func enableAuto() {
        settings.autoMode = true
        applyMode()
    }

    // MARK: - Networking

    private func fetch() async {
        do {
            let condition = try await requestCurrentWeather()
            onUpdate?(.success(condition))
            // 상태가 바뀌었을 때만 씬을 재구성(불필요한 갱신 방지).
            if condition != currentCondition {
                currentCondition = condition
                onConditionChange?(condition)
            }
        } catch {
            onUpdate?(.failure(error))
        }
    }

    private func requestCurrentWeather() async throws -> WeatherCondition {
        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        var items = [
            URLQueryItem(name: "appid", value: settings.apiKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        // 위치 모드면 현재 좌표(lat/lon)로, 아니면 도시명(q)으로 조회.
        if settings.useLocation {
            let coord = try await location.requestCurrentCoordinate()
            items.append(URLQueryItem(name: "lat", value: String(coord.latitude)))
            items.append(URLQueryItem(name: "lon", value: String(coord.longitude)))
        } else {
            items.append(URLQueryItem(name: "q", value: settings.city))
        }
        components.queryItems = items
        guard let url = components.url else { throw WeatherError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WeatherError.network
        }
        guard http.statusCode == 200 else {
            // 401(잘못된 키), 404(없는 도시) 등을 사용자에게 구분해 알려줍니다.
            throw WeatherError.http(status: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OWMResponse.self, from: data)
        guard let first = decoded.weather.first else {
            throw WeatherError.emptyPayload
        }
        // 응답의 도시명을 저장(위/경도 조회여도 API 가 지역명을 돌려줍니다).
        lastLocationName = decoded.name.isEmpty ? nil : decoded.name
        return WeatherCondition.from(openWeatherCode: first.id)
    }
}

// MARK: - API 응답 모델 (필요한 필드만 최소로 디코딩)

private struct OWMResponse: Decodable {
    struct Weather: Decodable {
        let id: Int          // condition code (2xx/3xx/5xx/6xx/8xx...)
        let main: String     // "Rain", "Snow", "Clear" ...
        let description: String
    }
    let weather: [Weather]
    let name: String         // 도시명(응답 확인용)
}

// MARK: - 에러 타입

enum WeatherError: LocalizedError {
    case notConfigured
    case badURL
    case network
    case http(status: Int)
    case emptyPayload

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "API Key 와 도시 이름을 먼저 설정하세요."
        case .badURL:
            return "요청 URL 을 만들 수 없습니다."
        case .network:
            return "네트워크 오류가 발생했습니다."
        case .http(let status):
            switch status {
            case 401: return "API Key 가 올바르지 않습니다 (401)."
            case 404: return "도시를 찾을 수 없습니다 (404)."
            case 429: return "API 호출 한도를 초과했습니다 (429)."
            default:  return "서버 오류 (\(status))."
            }
        case .emptyPayload:
            return "날씨 데이터가 비어 있습니다."
        }
    }
}
