#!/bin/bash
#
# WeatherScreen.app 번들을 만드는 스크립트.
#
# 하는 일:
#   1) swift build -c release 로 실행 파일 컴파일
#   2) 표준 .app 번들 구조(Contents/MacOS, Contents/Resources)로 감싸기
#   3) Info.plist 복사
#   4) ad-hoc 코드사이닝(무료, Apple 계정 불필요) → Gatekeeper 우회는 아래 README 참고
#
# 사용법:  ./build_app.sh
# 결과물:  ./WeatherScreen.app
#
set -euo pipefail

APP_NAME="WeatherScreen"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "▶︎ 1/4  Release 빌드 중… (처음엔 몇 분 걸릴 수 있습니다)"
swift build -c release

echo "▶︎ 2/4  .app 번들 구조 생성…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 실행 파일 복사
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "▶︎ 3/4  Info.plist 복사…"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "▶︎ 4/4  ad-hoc 코드사이닝…"
# "-" 는 ad-hoc 서명(무료). 인증서 없이도 로컬 실행에 충분합니다.
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅ 완료: $SCRIPT_DIR/$APP_BUNDLE"
echo ""
echo "실행:  open $APP_BUNDLE"
echo "설치:  cp -r $APP_BUNDLE /Applications/   (선택)"
