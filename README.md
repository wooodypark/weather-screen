# WeatherScreen 🌦️

macOS 메뉴바에 상주하는 **실시간 날씨 연동 바탕화면 오버레이 앱**.
비가 오면 화면 위로 빗줄기가, 눈이 오면 눈송이가 내립니다. 배경화면은
그대로 두고, 클릭이 통과되는 투명 창 위에 SpriteKit 파티클만 얹어
**배터리와 CPU 소모를 최소화**했습니다.

| 상태 | 효과 |
|------|------|
| ☀️ 맑음 | 효과 없음 (렌더링 완전 정지, 소모 0) |
| 🌧️ 비 | 빗줄기(3겹 깊이감 + 바람) + 화면이 서서히 살짝 어두워짐 |
| ❄️ 눈 | 눈송이(3겹 + 좌우 나부낌·회전) + 화면이 서서히 살짝 어두워짐 |

- 메뉴바 아이콘이 현재 날씨를 이모지로 표시합니다.
- **자동 모드**: 지정한 도시의 실제 날씨를 30분마다 가져와 반영.
- **수동 모드**: 실제 날씨와 무관하게 비/눈/맑음을 직접 골라 고정 (이때는 네트워크 호출 없음).

---

## 요구 환경

- macOS 13 (Ventura) 이상
- 무료 [OpenWeatherMap API Key](https://home.openweathermap.org/api_keys) — [발급 방법](#api-key-발급-무료)
- **직접 빌드하는 경우에만** Xcode 또는 Command Line Tools 필요 (아래 설명)

## 설치 & 실행

### 방법 A. 다운로드해서 바로 실행 (일반 사용자)

> 🚧 **준비 중** — GitHub Releases에 빌드된 `WeatherScreen.app` 배포 예정입니다.
> 준비되면 여기에 다운로드 링크와 실행 방법이 올라갑니다. 그 전까지는 방법 B로 직접 빌드하세요.

### 방법 B. 소스에서 직접 빌드 (개발자 / 직접 빌드파)

Xcode 전체(수십 GB)까지는 필요 없고, **Command Line Tools**만 있으면 됩니다:

```bash
xcode-select --install     # 이미 있으면 건너뜀 (컴파일러만 설치, 수백 MB)
```

그다음:

```bash
git clone <이 저장소 URL>
cd weather_screen
./build_app.sh             # WeatherScreen.app 생성 (release 빌드 + 번들 + 서명)
open WeatherScreen.app      # 실행
```

`/Applications` 에 두고 쓰려면:

```bash
cp -r WeatherScreen.app /Applications/
```

> Xcode를 이미 쓰신다면 `Package.swift` 를 Xcode로 열어 그대로 빌드/실행해도 됩니다.

## 첫 실행 — API Key 설정

앱을 처음 실행하면 설정창이 자동으로 열립니다:

1. **API Key** 입력 (OpenWeatherMap 무료 키)
2. **도시 이름** 입력 (예: `Seoul`, `London`, `Tokyo`)
3. **저장 후 새로고침** 클릭

나중에 다시 열려면 메뉴바 아이콘 → **설정…**.

> 💡 발급 직후 API Key는 서버 활성화까지 최대 1~2시간 걸릴 수 있습니다.
> 바로 넣었는데 `401` 오류가 뜨면 잠시 후 **지금 새로고침**을 눌러보세요.

### API Key 발급 (무료)

1. [OpenWeatherMap 회원가입](https://home.openweathermap.org/users/sign_up) (이메일 인증)
2. [API keys 페이지](https://home.openweathermap.org/api_keys) 에서 자동 생성된 키 복사
3. 설정창에 붙여넣기

무료 플랜 한도는 **분당 60회 / 월 100만 회**입니다. 이 앱은 30분에 1회(월 ~1,500회)만
호출하므로 요금 걱정이 없습니다.

## 메뉴 사용법

메뉴바 아이콘을 클릭하면:

- **상태 / 마지막 업데이트** — 현재 인식된 날씨와 마지막 갱신 시각
- **자동 (실제 날씨)** — 실제 날씨 연동 모드로 전환 (30분 폴링)
- **지금 새로고침** — 자동 모드에서 즉시 1회 갱신 (`⌘R`)
- **수동으로 효과 고정** — ☀️ 맑음 / 🌧️ 비 / ❄️ 눈 중 하나를 골라 화면에 고정
- **설정…** — API Key·도시·옵션 (`⌘,`)
- **종료** (`⌘Q`)

수동으로 효과를 고르면 자동으로 수동 모드가 되고 폴링이 멈춥니다.
다시 실제 날씨를 보려면 **자동 (실제 날씨)** 를 누르세요.

## "확인되지 않은 개발자" 경고가 뜬다면

이 앱은 무료 ad-hoc 서명만 되어 있어(Apple Developer Program 미가입),
Gatekeeper가 처음 실행을 막을 수 있습니다. 아래 중 하나로 허용하세요:

- **우클릭 → 열기** → 대화상자에서 **열기**, 또는
- 시스템 설정 → 개인정보 보호 및 보안 → 하단의 **그래도 열기**, 또는
```bash
xattr -dr com.apple.quarantine WeatherScreen.app
```

## 프로젝트 구조

```
weather_screen/
├── Package.swift                 # SwiftPM 실행 타깃 정의
├── build_app.sh                  # .app 번들 생성 + ad-hoc 서명
├── Resources/
│   └── Info.plist                # LSUIElement=true 등 번들 메타데이터
└── Sources/WeatherScreen/
    ├── main.swift                # 진입점 (accessory 정책 설정)
    ├── AppDelegate.swift         # 중심 오케스트레이터 + 메뉴바 + 모드 전환
    ├── WeatherManager.swift      # OpenWeatherMap 호출 / 30분 폴링 / 자동·수동 모드
    ├── WeatherCondition.swift    # 날씨 상태 enum (clear/rain/snow)
    ├── Settings.swift            # UserDefaults 설정 저장소 (키·도시·모드·옵션)
    ├── SettingsView.swift        # SwiftUI 설정 화면
    ├── SettingsWindowController.swift  # 설정창(NSWindow)
    ├── OverlayManager.swift      # 멀티모니터/절전/전원 상태 총괄
    ├── WeatherWindowController.swift  # 투명 클릭통과 창 + dimming 애니메이션
    └── WeatherScene.swift        # SpriteKit 비/눈 파티클 (3레이어·바람·나부낌)
```

## 배터리 최적화 설계

| 기법 | 설명 |
|------|------|
| 렌더 완전 정지 | 맑음이 되면 파티클 소멸 후 `SKView.isPaused=true` → GPU/CPU 사용 0 |
| 상태 변화 감지 | 날씨가 직전과 같으면 씬을 재구성하지 않음 |
| 수동 모드 폴링 중단 | 수동 모드에서는 타이머를 멈춰 네트워크 호출 자체가 없음 |
| 30분 폴링 | 자동 모드도 네트워크는 30분에 1회, 타이머 tolerance로 wake 코얼레싱 |
| 절전 연동 | 시스템 sleep/wake 시 렌더 자동 정지·재개 |
| 배터리 감지 | 어댑터 없이 구동 중이면 파티클 방출량 절반으로 (옵션) |
| 배경화면 미변경 | 시스템 배경화면 파일을 건드리지 않고 투명 레이어 opacity로 어둡기 구현 |

## 라이선스

MIT
