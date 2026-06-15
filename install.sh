#!/bin/bash
# SwiftBar GitHub 리뷰요청 PR 플러그인 배치 스크립트.
# 이 폴더의 플러그인/아이콘을 실제 동작 위치로 복사한다.
# 전제: SwiftBar 설치됨, gh auth 완료(scope repo, read:org), jq 설치됨.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$HOME/.config/swiftbar"
CACHE_DIR="$HOME/.cache/swiftbar"

echo "▶ 폴더 생성"
mkdir -p "$PLUGIN_DIR" "$CACHE_DIR"

echo "▶ SwiftBar 플러그인 폴더 지정"
defaults write com.ameba.SwiftBar PluginDirectory -string "$PLUGIN_DIR" || true

echo "▶ 아이콘 배치"
cp "$SRC_DIR/assets/github-icon.b64" "$CACHE_DIR/github-icon.b64"
cp "$SRC_DIR/assets/pr-icon.b64"     "$CACHE_DIR/pr-icon.b64"

echo "▶ 로컬 설정 배치"
if [ -f "$SRC_DIR/config.sh" ]; then
  cp "$SRC_DIR/config.sh" "$PLUGIN_DIR/org-review-prs.config.sh"
  echo "  config.sh → 배치됨 (개인 override 적용)"
else
  echo "  config.sh 없음 → 플러그인 기본값(org:thefarmersfront / 라벨:리뷰요청) 사용"
  echo "  (바꾸려면: cp config.example.sh config.sh → 수정 → 다시 ./install.sh)"
fi

echo "▶ 플러그인 배치"
cp "$SRC_DIR/org-review-prs.5m.sh" "$PLUGIN_DIR/org-review-prs.5m.sh"
chmod +x "$PLUGIN_DIR/org-review-prs.5m.sh"

echo "▶ 의존성 점검"
command -v gh >/dev/null 2>&1 && echo "  gh: $(command -v gh)" || echo "  ⚠︎ gh 없음 (brew install gh)"
command -v jq >/dev/null 2>&1 && echo "  jq: $(command -v jq)" || echo "  ⚠︎ jq 없음 (brew install jq)"
gh auth status >/dev/null 2>&1 && echo "  gh auth: OK" || echo "  ⚠︎ gh 미인증 (gh auth login)"

echo "▶ 동작 확인 (플러그인 직접 실행, 첫 줄)"
"$PLUGIN_DIR/org-review-prs.5m.sh" | head -1 || true

echo
echo "✅ 배치 완료. SwiftBar가 실행 중이면 갱신:"
echo "   open \"swiftbar://refreshallplugins\""
echo "   (미설치면: brew install --cask swiftbar && xattr -dr com.apple.quarantine /Applications/SwiftBar.app && open -a SwiftBar)"
