import AppKit

// 최상위 코드는 nonisolated 라, MainActor 격리된 AppDelegate 생성을 위해
// assumeIsolated 로 감쌉니다(진입점은 항상 메인 스레드라 안전).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate

    // 도크에 안 뜨는 메뉴바 상주 앱(Info.plist 의 LSUIElement 와 동일 효과).
    app.setActivationPolicy(.accessory)

    app.run()
}
