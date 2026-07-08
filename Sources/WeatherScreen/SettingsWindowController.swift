import AppKit
import SwiftUI

/// SwiftUI SettingsView 를 담는 일반 NSWindow 를 관리.
///
/// LSUIElement 앱은 기본 메뉴/도크가 없으므로 설정창을 직접 띄워야 합니다.
/// 창을 열 때 잠깐 앱을 일반 앱처럼 활성화해 포커스를 주고, 닫히면 다시
/// 액세서리(메뉴바 전용) 모드로 돌아갑니다.
@MainActor
final class SettingsWindowController {

    private var window: NSWindow?
    private let onSaveAndRefresh: () -> Void

    init(onSaveAndRefresh: @escaping () -> Void) {
        self.onSaveAndRefresh = onSaveAndRefresh
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(onSaveAndRefresh: { [weak self] in
            self?.onSaveAndRefresh()
        })
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "WeatherScreen 설정"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        // SwiftUI 뷰의 .frame 과 동일한 콘텐츠 크기를 창에도 명시.
        window.setContentSize(NSSize(width: 380, height: 460))
        window.center()
        window.delegate = windowDelegate

        self.window = window

        // 설정창 동안만 포커스 가능한 앱처럼 승격.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // 창이 닫힐 때 참조 정리를 위한 delegate.
    private lazy var windowDelegate = WindowDelegate { [weak self] in
        self?.window = nil
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
