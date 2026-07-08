import Foundation
import Combine

/// 사용자 설정을 UserDefaults 에 보관하는 단일 저장소.
///
/// - API Key 와 도시명은 사용자가 직접 입력합니다(CoreLocation 미사용 → 위치 권한 불필요).
/// - @Published 로 노출해 SwiftUI 설정창이 바인딩할 수 있게 합니다.
/// - ObservableObject 이므로 값이 바뀌면 관찰자(설정창)가 자동 갱신됩니다.
final class Settings: ObservableObject {

    /// 앱 전역에서 공유하는 단일 인스턴스.
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    // UserDefaults 키를 오타 없이 재사용하기 위한 상수 모음.
    private enum Key {
        static let apiKey = "owm.apiKey"
        static let city = "owm.city"
        static let dimmingEnabled = "overlay.dimmingEnabled"
        static let reduceOnBattery = "overlay.reduceOnBattery"
        static let autoMode = "mode.auto"
        static let manualCondition = "mode.manualCondition"
        static let useLocation = "owm.useLocation"
    }

    /// true = 현재 위치(CoreLocation)로 날씨 조회. false = 아래 city 로 조회.
    @Published var useLocation: Bool {
        didSet { defaults.set(useLocation, forKey: Key.useLocation) }
    }

    /// true = 자동(실제 날씨 연동, 30분 폴링). false = 수동(사용자가 효과 고정, 폴링 없음).
    @Published var autoMode: Bool {
        didSet { defaults.set(autoMode, forKey: Key.autoMode) }
    }

    /// 수동 모드일 때 화면에 고정할 효과. autoMode=false 일 때만 의미 있음.
    @Published var manualCondition: WeatherCondition {
        didSet { defaults.set(manualCondition.rawValue, forKey: Key.manualCondition) }
    }

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Key.apiKey) }
    }

    @Published var city: String {
        didSet { defaults.set(city, forKey: Key.city) }
    }

    /// 비/눈일 때 화면을 살짝 어둡게 할지 여부(요구사항의 alpha dimming).
    @Published var dimmingEnabled: Bool {
        didSet { defaults.set(dimmingEnabled, forKey: Key.dimmingEnabled) }
    }

    /// 노트북이 배터리 모드일 때 파티클 방출량을 줄일지 여부(배터리 최적화 옵션).
    @Published var reduceOnBattery: Bool {
        didSet { defaults.set(reduceOnBattery, forKey: Key.reduceOnBattery) }
    }

    private init() {
        self.apiKey = defaults.string(forKey: Key.apiKey) ?? ""
        self.city = defaults.string(forKey: Key.city) ?? "Seoul"
        // 최초 실행 시 기본값: dimming ON, 배터리 절약 ON.
        self.dimmingEnabled = defaults.object(forKey: Key.dimmingEnabled) as? Bool ?? true
        self.reduceOnBattery = defaults.object(forKey: Key.reduceOnBattery) as? Bool ?? true
        // 기본은 자동 모드. 수동 효과 기본값은 맑음.
        self.autoMode = defaults.object(forKey: Key.autoMode) as? Bool ?? true
        let savedManual = defaults.string(forKey: Key.manualCondition) ?? WeatherCondition.clear.rawValue
        self.manualCondition = WeatherCondition(rawValue: savedManual) ?? .clear
        // 기본은 위치 미사용(도시명 입력). 사용자가 켜면 CoreLocation 사용.
        self.useLocation = defaults.object(forKey: Key.useLocation) as? Bool ?? false
    }

    /// 날씨를 조회할 준비가 되었는지.
    /// API Key 는 항상 필요하고, 위치 모드가 아니면 도시명도 있어야 합니다.
    var isConfigured: Bool {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if useLocation { return true }
        return !city.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
