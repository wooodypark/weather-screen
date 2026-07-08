import AppKit
import SpriteKit

/// 클릭이 통과되는 투명 풀스크린 오버레이 창 하나(디스플레이당 하나).
final class WeatherWindowController {

    private let window: OverlayWindow
    private let skView: SKView
    private let scene: WeatherScene
    private let screen: NSScreen

    /// 검정 dimming 레이어. NSWindow.backgroundColor 는 애니메이터블이 아니라서
    /// 서서히 어두워지지 않으므로, 별도 CALayer 의 opacity 를 애니메이션합니다.
    private let dimView = NSView()
    private let maxDimOpacity: Float = 0.3

    init(screen: NSScreen) {
        self.screen = screen

        let frame = screen.frame
        let window = OverlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.window = window

        let skView = SKView(frame: CGRect(origin: .zero, size: frame.size))
        skView.allowsTransparency = true
        skView.autoresizingMask = [.width, .height]
        skView.ignoresSiblingOrder = true
        // 배경 효과라 24fps 면 충분. 5K 등 고해상도 서브 모니터에서 60fps 로
        // 그리면 GPU 부담이 커 렉이 생기므로 크게 제한합니다.
        skView.preferredFramesPerSecond = 24
        self.skView = skView

        let scene = WeatherScene(size: frame.size)
        scene.backgroundColor = .clear
        scene.backingScale = screen.backingScaleFactor
        self.scene = scene
        skView.presentScene(scene)

        configureWindow()
    }

    private func configureWindow() {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false

        // 데스크톱 아이콘 위, 일반 앱 창 아래. 아이콘 아래(.desktopWindow)에 두면
        // 파티클이 아이콘에 가려 안 보입니다. 클릭은 ignoresMouseEvents 로 통과.
        window.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
        )
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        // dimView(뒤) 위에 skView(파티클, 투명 배경)를 겹쳐 담습니다.
        let container = NSView(frame: CGRect(origin: .zero, size: window.frame.size))
        container.autoresizingMask = [.width, .height]

        dimView.frame = container.bounds
        dimView.autoresizingMask = [.width, .height]
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.cgColor
        dimView.layer?.opacity = 0.0

        container.addSubview(dimView)
        container.addSubview(skView)

        window.contentView = container
    }

    func apply(condition: WeatherCondition, dimmingEnabled: Bool, intensity: CGFloat) {
        scene.apply(condition: condition, intensity: intensity)

        let targetOpacity: Float = (dimmingEnabled && condition != .clear) ? maxDimOpacity : 0.0
        setDimming(opacity: targetOpacity, duration: 2.5)

        if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    /// presentation() 값을 못 읽을 때 애니메이션 시작값으로 쓰는 fallback.
    private var currentDimOpacity: Float = 0.0

    private func setDimming(opacity: Float, duration: TimeInterval) {
        guard let layer = dimView.layer else { return }
        let from = layer.presentation()?.opacity ?? currentDimOpacity
        currentDimOpacity = opacity

        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = from
        anim.toValue = opacity
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.isRemovedOnCompletion = true
        layer.opacity = opacity          // 애니메이션 종료 후 최종값.
        layer.add(anim, forKey: "dimOpacity")
    }

    func show() {
        window.orderFrontRegardless()
    }

    func pauseRendering() {
        skView.isPaused = true
    }
    func resumeRendering() {
        skView.isPaused = false
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}

/// 키/포커스를 절대 가져가지 않는 오버레이 전용 창.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
