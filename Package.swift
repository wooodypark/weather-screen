// swift-tools-version:5.9
import PackageDescription

// WeatherScreen: macOS 메뉴바 상주형 실시간 날씨 오버레이 앱.
//
// SwiftPM 실행 타깃으로 구성했습니다. 이렇게 하면 .xcodeproj 파일을 git에 커밋할
// 필요 없이 GitHub에 올릴 수 있고, 사용자는 `swift build` 또는 동봉된 build_app.sh
// 스크립트 한 번으로 .app 번들을 만들 수 있습니다. Xcode에서 열고 싶으면 이 폴더의
// Package.swift 를 그냥 Xcode로 열면 됩니다.
let package = Package(
    name: "WeatherScreen",
    platforms: [
        // macOS 13(Ventura) 이상. MenuBarExtra 등 최신 API를 쓰진 않지만
        // SwiftUI 설정창과 async/await 를 넉넉히 쓰기 위해 13으로 잡았습니다.
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "WeatherScreen",
            path: "Sources/WeatherScreen"
            // 리소스(Info.plist)는 SwiftPM 번들이 아니라 build_app.sh 가
            // .app 번들의 Contents/Info.plist 로 직접 복사합니다.
        )
    ]
)
