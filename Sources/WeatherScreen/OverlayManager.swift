import AppKit
import IOKit.ps

/// 모든 디스플레이의 오버레이 창을 총괄하는 관리자.
///
/// 책임:
///  - 화면(모니터) 개수만큼 WeatherWindowController 생성/해제.
///  - 디스플레이 구성 변경(모니터 연결/해제) 시 창 재구성.
///  - 절전/화면잠금/화면깨어남 시 렌더 일시정지·재개(배터리 절약).
///  - 전원 상태(배터리 vs 어댑터)에 따른 파티클 강도 결정.
@MainActor
final class OverlayManager {

    private var controllers: [WeatherWindowController] = []
    private let settings: Settings

    /// 마지막으로 적용한 상태(화면 재구성 시 그대로 다시 반영하기 위해 보관).
    private var lastCondition: WeatherCondition = .clear

    init(settings: Settings = .shared) {
        self.settings = settings
        rebuildForCurrentScreens()
        registerNotifications()
    }

    // MARK: - 화면 구성

    private func rebuildForCurrentScreens() {
        controllers.forEach { $0.close() }
        controllers = NSScreen.screens.map { WeatherWindowController(screen: $0) }
        controllers.forEach { $0.show() }
        apply(condition: lastCondition)   // 새 창에 현재 상태 반영.
    }

    func show() {
        controllers.forEach { $0.show() }
    }

    // MARK: - 상태 반영 (AppDelegate 가 호출)

    func apply(condition: WeatherCondition) {
        lastCondition = condition
        let intensity = currentIntensity()
        for c in controllers {
            c.apply(condition: condition,
                    dimmingEnabled: settings.dimmingEnabled,
                    intensity: intensity)
        }
    }

    /// 설정이 바뀌었을 때(dimming/배터리 옵션 토글) 현재 상태로 재적용.
    func reapply() {
        apply(condition: lastCondition)
    }

    /// 전원 상태에 따른 파티클 강도.
    /// 배터리 절약 옵션이 켜져 있고 지금 배터리로 구동 중이면 방출량을 절반으로.
    private func currentIntensity() -> CGFloat {
        guard settings.reduceOnBattery, isRunningOnBattery() else { return 1.0 }
        return 0.5
    }

    /// IOKit 으로 현재 전원 소스가 배터리인지 판별.
    private func isRunningOnBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any],
                  let state = desc[kIOPSPowerSourceStateKey] as? String
            else { continue }
            if state == kIOPSBatteryPowerValue { return true }
        }
        return false
    }

    // MARK: - 시스템 이벤트 구독

    private func registerNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(screensChanged),
                       name: NSApplication.didChangeScreenParametersNotification,
                       object: nil)

        let wnc = NSWorkspace.shared.notificationCenter
        wnc.addObserver(self, selector: #selector(willSleep),
                        name: NSWorkspace.willSleepNotification, object: nil)
        wnc.addObserver(self, selector: #selector(didWake),
                        name: NSWorkspace.didWakeNotification, object: nil)

        // 전원 소스 변경(배터리↔어댑터)은 별도 구독 없이 sleep/wake·화면변경 시점에
        // 재평가합니다. 배터리 전환은 드물어 이 정도로 충분합니다.
    }

    @objc private func screensChanged() {
        rebuildForCurrentScreens()
    }

    @objc private func willSleep() {
        controllers.forEach { $0.pauseRendering() }
    }

    @objc private func didWake() {
        controllers.forEach { $0.resumeRendering() }
        reapply()   // 깨어난 김에 전원 상태 반영해 강도 재조정.
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
