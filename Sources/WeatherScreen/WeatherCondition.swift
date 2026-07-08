import Foundation

/// 화면 오버레이가 표현할 "날씨 상태"의 단순화된 분류.
///
/// OpenWeatherMap 은 수십 개의 상세 weather condition code 를 주지만,
/// 이 앱은 화면에 뿌릴 효과가 3가지(비/눈/없음)뿐이므로 그 수준으로만 좁힙니다.
/// 이렇게 좁혀두면 WindowController·Scene 쪽이 코드값을 몰라도 되어 결합도가 낮아집니다.
enum WeatherCondition: String, Equatable {
    case clear   // 효과 없음 (맑음 등)
    case rain    // 비 파티클
    case snow    // 눈 파티클

    /// OpenWeatherMap 의 weather[0].id (condition code)를 앱 상태로 변환.
    ///
    /// 분류 규칙(요구사항 그대로):
    ///  - 2xx(뇌우), 3xx(이슬비), 5xx(비)  → rain
    ///  - 6xx(눈)                          → snow
    ///  - 800(맑음) 및 그 외(7xx 안개, 80x 구름 등) → clear
    static func from(openWeatherCode code: Int) -> WeatherCondition {
        switch code {
        case 200..<600:
            return .rain
        case 600..<700:
            return .snow
        default:
            return .clear
        }
    }

    /// 메뉴바에 띄울 대표 이모지.
    var emoji: String {
        switch self {
        case .clear: return "☀️"
        case .rain:  return "🌧️"
        case .snow:  return "❄️"
        }
    }

    /// 사람이 읽을 라벨 (메뉴 항목 표시용).
    var label: String {
        switch self {
        case .clear: return "맑음 / 효과 없음"
        case .rain:  return "비"
        case .snow:  return "눈"
        }
    }
}
