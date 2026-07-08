import AppKit

/// 앱의 중심. 메뉴바 상태 아이템을 만들고, WeatherManager 의 결과를
/// OverlayManager 로 흘려보내는 오케스트레이터.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let settings = Settings.shared
    private let weather = WeatherManager()
    private lazy var overlay = OverlayManager()
    private lazy var settingsWC = SettingsWindowController(onSaveAndRefresh: { [weak self] in
        self?.weather.refreshNow()
    })

    // 메뉴에서 상태 텍스트를 갱신하기 위해 항목을 보관.
    private var statusMenuItem: NSMenuItem!
    private var locationMenuItem: NSMenuItem!
    private var lastUpdatedItem: NSMenuItem!

    // 모드 표시용 메뉴 항목(체크마크를 갱신하기 위해 보관).
    private var autoItem: NSMenuItem!
    private var manualClearItem: NSMenuItem!
    private var manualRainItem: NSMenuItem!
    private var manualSnowItem: NSMenuItem!
    private var refreshItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        wireWeatherCallbacks()

        overlay.show()
        weather.applyMode()
        updateModeChecks()

        // 설정이 비어 있으면(최초 실행) 설정창을 자동으로 띄웁니다.
        if !settings.isConfigured {
            settingsWC.show()
        }
    }

    // MARK: - 메뉴바 구성

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = WeatherCondition.clear.emoji

        let menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "상태: 확인 중…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        locationMenuItem = NSMenuItem(title: "위치: -", action: nil, keyEquivalent: "")
        locationMenuItem.isEnabled = false
        menu.addItem(locationMenuItem)

        lastUpdatedItem = NSMenuItem(title: "마지막 업데이트: -", action: nil, keyEquivalent: "")
        lastUpdatedItem.isEnabled = false
        menu.addItem(lastUpdatedItem)

        menu.addItem(.separator())

        autoItem = NSMenuItem(title: "자동 (실제 날씨)",
                              action: #selector(autoTapped), keyEquivalent: "")
        menu.addItem(autoItem)

        refreshItem = NSMenuItem(title: "지금 새로고침",
                                 action: #selector(refreshTapped), keyEquivalent: "r")
        menu.addItem(refreshItem)

        menu.addItem(.separator())

        let manualHeader = NSMenuItem(title: "수동으로 효과 고정", action: nil, keyEquivalent: "")
        manualHeader.isEnabled = false
        menu.addItem(manualHeader)

        manualClearItem = NSMenuItem(title: "  ☀️ 맑음 (효과 없음)",
                                     action: #selector(manualClearTapped), keyEquivalent: "")
        manualRainItem = NSMenuItem(title: "  🌧️ 비",
                                    action: #selector(manualRainTapped), keyEquivalent: "")
        manualSnowItem = NSMenuItem(title: "  ❄️ 눈",
                                    action: #selector(manualSnowTapped), keyEquivalent: "")
        menu.addItem(manualClearItem)
        menu.addItem(manualRainItem)
        menu.addItem(manualSnowItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "설정…",
                                action: #selector(settingsTapped),
                                keyEquivalent: ","))

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "종료",
                                action: #selector(quitTapped),
                                keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    // MARK: - WeatherManager 연결

    private func wireWeatherCallbacks() {
        weather.onConditionChange = { [weak self] condition in
            self?.overlay.apply(condition: condition)
        }
        weather.onUpdate = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let condition):
                self.statusItem.button?.title = condition.emoji
                self.statusMenuItem.title = "상태: \(condition.label)"
                self.locationMenuItem.title = "위치: \(self.weather.lastLocationName ?? "-")"
                self.lastUpdatedItem.title = "마지막 업데이트: \(Self.timeString())"
            case .failure(let error):
                self.statusItem.button?.title = "⚠️"
                self.statusMenuItem.title = "오류: \(error.localizedDescription)"
            }
        }
    }

    private static func timeString() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    // MARK: - 모드 체크마크/활성화 갱신

    /// 현재 모드에 맞춰 메뉴 체크마크와 [지금 새로고침] 활성화를 갱신.
    private func updateModeChecks() {
        let auto = settings.autoMode
        autoItem.state = auto ? .on : .off
        manualClearItem.state = (!auto && settings.manualCondition == .clear) ? .on : .off
        manualRainItem.state  = (!auto && settings.manualCondition == .rain)  ? .on : .off
        manualSnowItem.state  = (!auto && settings.manualCondition == .snow)  ? .on : .off
        refreshItem.isEnabled = auto
    }

    // MARK: - 메뉴 액션

    @objc private func refreshTapped() {
        guard settings.autoMode else { return }
        statusMenuItem.title = "상태: 확인 중…"
        weather.refreshNow()
    }

    @objc private func autoTapped() {
        weather.enableAuto()
        statusMenuItem.title = "상태: 확인 중…"
        updateModeChecks()
    }

    @objc private func manualClearTapped() { selectManual(.clear) }
    @objc private func manualRainTapped()  { selectManual(.rain) }
    @objc private func manualSnowTapped()  { selectManual(.snow) }

    private func selectManual(_ condition: WeatherCondition) {
        weather.selectManual(condition)
        updateModeChecks()
    }

    @objc private func settingsTapped() {
        settingsWC.show()
    }

    @objc private func quitTapped() {
        NSApp.terminate(nil)
    }
}
