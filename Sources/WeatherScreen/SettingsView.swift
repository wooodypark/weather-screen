import SwiftUI

/// OpenWeatherMap API Key / 도시명 / 옵션을 입력하는 SwiftUI 설정 화면.
///
/// 요구사항상 "설정창만 SwiftUI"라서, AppKit 의 NSWindow(아래 SettingsWindowController)
/// 안에 NSHostingView 로 얹어 표시합니다.
struct SettingsView: View {
    // 전역 설정 저장소를 관찰. 값 변경 시 즉시 UserDefaults 에 반영됩니다.
    @ObservedObject var settings = Settings.shared

    /// [저장 후 새로고침] 눌렀을 때 호출할 클로저(AppDelegate 가 주입).
    var onSaveAndRefresh: () -> Void

    var body: some View {
        // SwiftPM 번들 환경에서 Form/.formStyle(.grouped) 가 세로로 눌려
        // 입력칸이 안 보이는 문제가 있어, 명시적 VStack 레이아웃으로 구성합니다.
        VStack(alignment: .leading, spacing: 14) {
            Text("WeatherScreen 설정")
                .font(.headline)

            Text("OpenWeatherMap")
                .font(.subheadline).bold()
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key").font(.caption).foregroundColor(.secondary)
                TextField("예: ca3b70ad...", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("내 위치 자동 사용", isOn: $settings.useLocation)

            VStack(alignment: .leading, spacing: 4) {
                Text("도시 이름").font(.caption).foregroundColor(.secondary)
                TextField("예: Seoul, London, Tokyo", text: $settings.city)
                    .textFieldStyle(.roundedBorder)
                    .disabled(settings.useLocation)   // 위치 모드면 도시 입력 비활성.
            }
            .opacity(settings.useLocation ? 0.4 : 1.0)

            Link("무료 API Key 발급받기 →",
                 destination: URL(string: "https://home.openweathermap.org/api_keys")!)
                .font(.caption)

            Divider().padding(.vertical, 4)

            Text("오버레이")
                .font(.subheadline).bold()
                .foregroundColor(.secondary)
            Toggle("비/눈일 때 화면 살짝 어둡게", isOn: $settings.dimmingEnabled)
            Toggle("배터리 사용 중일 때 파티클 줄이기", isOn: $settings.reduceOnBattery)

            Divider().padding(.vertical, 4)

            HStack {
                if !settings.isConfigured {
                    Text("API Key와 도시를 입력하세요")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("저장 후 새로고침") {
                    onSaveAndRefresh()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!settings.isConfigured)
            }
        }
        .padding(20)
        .frame(width: 380, height: 460)
    }
}
