#!/bin/bash
# ReviewBar 로컬 빌드 + .app 번들 생성 스크립트 (배포·서명 없이 본인 맥에서만 사용).
# 전제: Swift 툴체인(CLT면 충분), gh 인증 완료. Xcode 불필요.
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ 빌드 (release)"
swift build -c release

BIN=".build/release/ReviewBar"
APP="ReviewBar.app"

echo "▶ .app 번들 생성: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ReviewBar"

# SwiftPM 리소스 번들(Bundle.module: github-mark.png 등)을 .app 안으로 복사
for b in .build/release/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/" && echo "  리소스 번들: $(basename "$b")"
done

# 앱 아이콘 = 알림 아이콘. github-mark.png를 베이스로 "PR 리뷰" 아이콘(둥근 사각형 + 흰 Octocat + 초록 체크 배지)을
# icon_gen.swift로 1024px 생성 → sips로 iconset → iconutil로 AppIcon.icns.
echo "▶ 앱 아이콘 생성 (github-mark + 리뷰 배지)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
BASE_PNG="$(mktemp -d)/appicon_1024.png"
mkdir -p "$ICONSET"
swift icon_gen.swift "Sources/ReviewBar/Resources/github-mark.png" "$BASE_PNG" 1024 >/dev/null
for s in 16 32 128 256 512; do
  s2=$((s * 2))
  sips -z "$s"  "$s"  "$BASE_PNG" --out "$ICONSET/icon_${s}x${s}.png"    >/dev/null
  sips -z "$s2" "$s2" "$BASE_PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" && echo "  AppIcon.icns 생성"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>ReviewBar</string>
  <key>CFBundleDisplayName</key><string>ReviewBar</string>
  <key>CFBundleIdentifier</key><string>local.reviewbar</string>
  <key>CFBundleExecutable</key><string>ReviewBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>           <!-- Dock 아이콘 없는 메뉴바 전용 앱 -->
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# 로컬 전용이라 서명 불필요하지만, ad-hoc 서명을 해두면 일부 경고를 줄일 수 있다.
echo "▶ ad-hoc 코드 서명(로컬 전용)"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (서명 생략 — 직접 빌드한 바이너리는 quarantine이 없어 그냥 실행됨)"

echo
echo "✅ 완료: $(pwd)/$APP"
echo "   실행:        open ./$APP   (또는 Finder에서 더블클릭)"
echo "   개발 중 실행: swift run     (.app 없이 바로 띄우기)"
echo "   종료:        메뉴 팝오버 하단의 ⏻ 버튼"
