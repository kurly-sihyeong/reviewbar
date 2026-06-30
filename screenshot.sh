#!/bin/bash
# 스크린샷 모드로 ReviewBar를 띄워 mock 데이터가 채워진 팝오버 UI를 PNG로 저장한다.
# 실제 GitHub 호출/계정과 무관하게 항상 동일한 데모 화면이 나온다(README용).
#
# 전제: ./build.sh 가능. screencapture가 화면 기록 권한을 요구하면 1회 허용 필요
#       (시스템 설정 → 개인정보 보호 및 보안 → 화면 기록).
set -euo pipefail
cd "$(dirname "$0")"

OUT="screenshots/popover.png"
LOG="$(mktemp)"

echo "▶ 빌드"
./build.sh >/dev/null

mkdir -p screenshots
pkill -x ReviewBar 2>/dev/null || true
sleep 0.3

echo "▶ 스크린샷 모드 실행(mock 데이터)"
./ReviewBar.app/Contents/MacOS/ReviewBar --screenshot >"$LOG" 2>&1 &
APP_PID=$!

# 윈도우 번호가 stdout에 찍힐 때까지 대기
WID=""
for _ in $(seq 1 40); do
  WID=$(grep -o 'WINDOW_ID=[0-9]\{1,\}' "$LOG" | head -1 | cut -d= -f2 || true)
  [ -n "$WID" ] && break
  sleep 0.2
done
if [ -z "$WID" ]; then
  echo "✗ 윈도우 ID를 못 찾음. 앱 로그:"; cat "$LOG"
  kill "$APP_PID" 2>/dev/null || true
  exit 1
fi

sleep 4.0   # 레이아웃·렌더 + 아바타(원격 이미지) 로드 안정
echo "▶ 캡처 (window #$WID) → $OUT"
screencapture -l "$WID" -o "$OUT"

kill "$APP_PID" 2>/dev/null || true
echo "✅ 저장: $(pwd)/$OUT"
