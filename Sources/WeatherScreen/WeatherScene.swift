import SpriteKit

/// 비/눈 파티클을 그리는 SpriteKit 씬.
///
/// clear 상태가 되면 파티클을 소멸시킨 뒤 `isPaused = true` 로 렌더를 멈춰
/// GPU/CPU 사용을 0 으로 만듭니다. 비주얼은 깊이감을 위해 층을 3개 쌓습니다.
final class WeatherScene: SKScene {

    /// 현재 올라와 있는 층별 방출기. 상태 전환 시 한꺼번에 교체·제거합니다.
    private var emitters: [SKEmitterNode] = []

    /// 방출량 배수(0~1). 배터리 모드에서 낮춥니다.
    private var intensity: CGFloat = 1.0

    /// 이 씬이 그려지는 화면의 backingScale(Retina=2.0). WindowController 가 설정.
    /// 실제 렌더 픽셀 수 = (논리 크기 × backingScale)^2 이므로 부하 계산에 필요합니다.
    var backingScale: CGFloat = 2.0

    /// 고해상도 화면 보정. 렌더 부하는 실제 픽셀 "면적"에 비례하므로, 기준 면적
    /// (1920×1080 @1x)을 넘는 만큼 방출량을 줄여 총 부하를 억제합니다.
    /// 예) 5K(5120×2880 픽셀)는 ~0.3 까지 낮아짐. 0.3~1.0 사이로 클램프.
    private var resolutionScale: CGFloat {
        let pixelArea = (size.width * backingScale) * (size.height * backingScale)
        let referenceArea: CGFloat = 1920 * 1080
        guard pixelArea > referenceArea else { return 1.0 }
        return max(0.3, referenceArea / pixelArea)
    }

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 미사용") }

    func apply(condition: WeatherCondition, intensity: CGFloat) {
        self.intensity = max(0, min(1, intensity))
        switch condition {
        case .clear:
            stopEffects()
        case .rain:
            startEffects(makeRainLayers())
        case .snow:
            startEffects(makeSnowLayers())
        }
    }

    // MARK: - 렌더 on/off

    private func startEffects(_ nodes: [SKEmitterNode]) {
        fadeOutTimer?.invalidate()   // 진행 중이던 fade-out 정리 예약 취소.
        fadeOutTimer = nil
        removeEmitters()
        let birthScale = intensity * resolutionScale
        for node in nodes {
            node.particleBirthRate *= birthScale
            addChild(node)
            emitters.append(node)
        }
        isPaused = false
        view?.isPaused = false
    }

    /// 렌더 정지를 예약한 타이머. pause 상태와 무관하게(실시간) 정리를 보장합니다.
    private var fadeOutTimer: Timer?

    /// 맑음 전환: 생성을 멈추고 남은 파티클을 fadeOutDuration 동안 서서히 투명하게
    /// 만든 뒤 정지합니다. 곧바로 isPaused=true 하면 떨어지던 비/눈이 화면에
    /// 얼어붙으므로 페이드로 부드럽게 걷어냅니다.
    ///
    /// 최종 정리는 SKAction 이 아니라 Timer 로 겁니다. SKAction 은 씬/뷰가 pause
    /// 상태(디스플레이 절전 등)면 진행되지 않아, 비가 얼어붙은 채 남는 버그가
    /// 있었습니다. Timer 는 pause 와 무관하게 실시간으로 도므로 확실히 걷어냅니다.
    private func stopEffects() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil

        guard !emitters.isEmpty else {
            isPaused = true
            view?.isPaused = true
            return
        }

        // 렌더가 멈춰 있으면 페이드가 보이지도 않으므로, 걷어내는 동안은 렌더를 켭니다.
        isPaused = false
        view?.isPaused = false

        let fadeOutDuration: TimeInterval = 1.2
        for e in emitters {
            e.particleBirthRate = 0
            e.run(SKAction.fadeOut(withDuration: fadeOutDuration))
        }

        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.removeEmitters()
                self.isPaused = true
                self.view?.isPaused = true
                self.fadeOutTimer = nil
            }
        }
    }

    private func removeEmitters() {
        emitters.forEach { $0.removeFromParent() }
        emitters.removeAll()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        for e in emitters {
            e.position = CGPoint(x: size.width / 2, y: size.height + 20)
            e.particlePositionRange = CGVector(dx: size.width * 1.2, dy: 0)
        }
    }

    // MARK: - 비

    /// far(작고 느리고 흐림) → near(크고 빠르고 진함) 3개 층으로 깊이감.
    private func makeRainLayers() -> [SKEmitterNode] {
        [
            makeRainLayer(scale: 0.6, speed: 700,  birth: 120, alpha: 0.25, length: 10, tilt: 0.06, z: 1),
            makeRainLayer(scale: 0.9, speed: 950,  birth: 180, alpha: 0.40, length: 16, tilt: 0.09, z: 2),
            makeRainLayer(scale: 1.3, speed: 1250, birth: 90,  alpha: 0.55, length: 24, tilt: 0.12, z: 3)
        ]
    }

    private func makeRainLayer(scale: CGFloat, speed: CGFloat, birth: CGFloat,
                               alpha: CGFloat, length: CGFloat, tilt: CGFloat, z: CGFloat) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Self.rainStreakTexture(width: 3, height: length)
        e.particleColor = NSColor(calibratedWhite: 0.85, alpha: 1)
        e.particleColorBlendFactor = 1.0

        e.position = CGPoint(x: size.width / 2, y: size.height + 20)
        e.particlePositionRange = CGVector(dx: max(size.width * 1.2, 1), dy: 0)

        e.particleBirthRate = birth
        e.particleLifetime = 1.4
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.15

        // 바람: 수직(-90도)에서 tilt 만큼 기울여 비스듬히, 줄기도 같이 눕히고 가속.
        e.emissionAngle = .pi * 3 / 2 - tilt
        e.emissionAngleRange = 0.02
        e.particleRotation = tilt
        e.xAcceleration = -tilt * 900

        e.particleAlpha = alpha
        e.particleAlphaRange = 0.15
        e.particleScale = scale
        e.particleScaleRange = scale * 0.3
        e.zPosition = z
        return e
    }

    // MARK: - 눈

    private func makeSnowLayers() -> [SKEmitterNode] {
        [
            makeSnowLayer(scale: 0.25, speed: 55,  birth: 40, alpha: 0.5, sway: 12, z: 1),
            makeSnowLayer(scale: 0.45, speed: 85,  birth: 30, alpha: 0.8, sway: 20, z: 2),
            makeSnowLayer(scale: 0.7,  speed: 120, birth: 16, alpha: 1.0, sway: 30, z: 3)
        ]
    }

    private func makeSnowLayer(scale: CGFloat, speed: CGFloat, birth: CGFloat,
                               alpha: CGFloat, sway: CGFloat, z: CGFloat) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Self.softDotTexture(diameter: 16)
        e.particleColor = .white
        e.particleColorBlendFactor = 1.0

        e.position = CGPoint(x: size.width / 2, y: size.height + 20)
        e.particlePositionRange = CGVector(dx: max(size.width * 1.2, 1), dy: 0)

        e.particleBirthRate = birth
        e.particleLifetime = 12
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.4
        e.emissionAngle = .pi * 3 / 2
        e.emissionAngleRange = .pi / 10

        e.particleAlpha = alpha
        e.particleAlphaRange = 0.3
        e.particleScale = scale
        e.particleScaleRange = scale * 0.5

        // 나부낌: 좌우로 흔들리는 액션을 무한 반복. 층마다 폭·주기를 달리해 흩어지게.
        let period = 2.0 + Double(sway) / 20.0
        let swayRight = SKAction.moveBy(x: sway, y: 0, duration: period / 2)
        swayRight.timingMode = .easeInEaseOut
        let swayLeft = SKAction.moveBy(x: -sway, y: 0, duration: period / 2)
        swayLeft.timingMode = .easeInEaseOut
        e.particleAction = SKAction.repeatForever(SKAction.sequence([swayRight, swayLeft]))

        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = 0.6
        e.zPosition = z
        return e
    }

    // MARK: - 텍스처 (에셋 없이 Core Graphics 그라데이션으로 생성)

    /// 위·아래로 페이드되는 빗줄기(세로 그라데이션).
    private static func rainStreakTexture(width: CGFloat, height: CGFloat) -> SKTexture {
        let size = CGSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colors = [
                NSColor(white: 1, alpha: 0.0).cgColor,
                NSColor(white: 1, alpha: 1.0).cgColor,
                NSColor(white: 1, alpha: 0.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors,
                                     locations: [0.0, 0.5, 1.0]) {
                ctx.drawLinearGradient(grad,
                                       start: CGPoint(x: width/2, y: 0),
                                       end: CGPoint(x: width/2, y: height),
                                       options: [])
            }
        }
        image.unlockFocus()
        return SKTexture(image: image)
    }

    /// 중심이 밝고 가장자리로 투명해지는 눈송이(방사형 그라데이션).
    private static func softDotTexture(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colors = [
                NSColor(white: 1, alpha: 1.0).cgColor,
                NSColor(white: 1, alpha: 0.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors,
                                     locations: [0.0, 1.0]) {
                let c = CGPoint(x: diameter/2, y: diameter/2)
                ctx.drawRadialGradient(grad,
                                       startCenter: c, startRadius: 0,
                                       endCenter: c, endRadius: diameter/2,
                                       options: [])
            }
        }
        image.unlockFocus()
        return SKTexture(image: image)
    }
}
