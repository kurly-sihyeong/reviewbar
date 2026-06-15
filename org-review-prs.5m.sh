#!/bin/bash
# <bitbar.title>GitHub Review Requests</bitbar.title>
# <bitbar.version>3.3</bitbar.version>
# <bitbar.author>thefarmersfront</bitbar.author>
# <bitbar.desc>리뷰 요청받은 열린 PR을 ⏳미승인 / ✅승인됨 으로 나눠서 표시</bitbar.desc>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
#
# 동작:
#   - 메뉴 열 때: refreshOnOpen=true + 동기 gh 호출 → fetch가 렌더 "전"에 끝나므로
#     메뉴는 이미 최신으로 뜨고, 그 뒤 재렌더가 없어 저절로 닫히지 않음(열 때 ~1s 대기).
#   - 메뉴 닫혀 있을 때: 파일명 주기(5m)로 백그라운드 실행해 배지만 최신 유지.
#   - 비동기 백그라운드 fetch / refreshallplugins 미사용 → "fetch 완료가 열린 메뉴를 닫는" 문제 없음.
# 검색식: org:$ORG is:pr is:open review-requested:@me  (+ jq에서 LABEL_PREFIX 필터)
#         org/라벨은 아래 설정 블록 기본값이며 config 파일로 override 가능
#
# [reviewed-by 제거 이유] GitHub의 "Comment" 리뷰는 review 요청을 해제하지 않고(Approve/Request
#   changes만 해제), 따라서 코멘트만 남긴 PR도 여전히 review-requested:@me 로 남는다. 기존 쿼리의
#   -reviewed-by:@me 는 그런 코멘트 PR까지 걸러내 "approve 안 했는데 사라지는" 문제가 있었다.
#   → -reviewed-by:@me 를 빼서, review-requested:@me = "요청받았고 아직 approve(또는 request
#     changes) 안 한" PR을 그대로 노출한다. approve하면 GitHub가 요청에서 빼주므로 자동으로 사라진다.
#
# [라벨 필터] GitHub의 label:은 전체 문자열 정확 일치라 "리뷰요청-프론트" 같은 변형을 못 잡는다.
#   → 서버 쿼리에서는 label을 빼고(전체 review-requested 수집), jq에서 "리뷰요청"으로 시작하는
#     라벨(prefix)을 가진 PR만 노출한다. 향후 "리뷰요청-*" 변형도 자동 포함, 리뷰완료·무라벨은 제외.
#
# [승인 상태 분리] REST search/issues 응답엔 리뷰 상태 필드가 없다. GraphQL search로 reviewDecision
#   을 받아올 수는 있지만 search 리졸버가 느려 ~2.5s(REST의 2배)가 걸린다. 대신 GitHub 검색의
#   review:approved 한정자를 써서 "승인" / "미승인(-review:approved)" 두 쿼리를 **병렬 REST**로
#   날린다 → 둘 다 ~1.2s, 동시에 끝나므로 전체 ~1.2s로 GraphQL 대비 절반. 결과(승인/미승인 분류)는
#   reviewDecision 기준과 동일함을 검증함. review:approved = "리뷰어 중 누군가 approve 한 PR".
#   두 쿼리는 같은 베이스의 정확한 여집합이라 합쳐서 빠짐/중복 없음(approved ∪ -approved = 전체).
#   화면엔 ⏳미승인을 위, ✅승인됨을 아래로 모두 top-level(서브메뉴 아님)로 펼쳐서 보여준다.

# GUI 앱은 PATH가 비어 있으므로 명시
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# ── 설정(기본값) ──────────────────────────────────────────────────────────────
# 팀 공통 기본값. 개인 override는 아래 config 파일에서 한다(없으면 이 값을 그대로 사용).
ORG='thefarmersfront'        # review-requested 검색 대상 org
# "리뷰 대기"로 인정할 라벨 prefix (이 문자열로 시작하는 라벨이 하나라도 있으면 노출).
# 빈 문자열("")이면 라벨 필터 없이 review-requested 전부 표시.
LABEL_PREFIX='리뷰요청'
PER_PAGE=50                  # 검색 결과 페이지당 최대 건수

# 선택적 로컬 override (install.sh가 배치, .gitignore라 커밋 안 됨). 있으면 위 값 덮어씀.
CFG="$HOME/.config/swiftbar/org-review-prs.config.sh"
[ -f "$CFG" ] && . "$CFG"

# reviewed-by 미사용(코멘트 리뷰 살리려고), label도 서버 쿼리에서 제외 → 아래 jq에서 LABEL_PREFIX 필터
Q="org:$ORG is:pr is:open review-requested:@me"
ERR="$HOME/.cache/swiftbar/org-review-prs.err"
mkdir -p "$HOME/.cache/swiftbar"

# 메뉴바 아이콘: GitHub 마크(base64 PNG)를 templateImage로. 없으면 SF Symbol 폴백.
ICON="$(cat "$HOME/.cache/swiftbar/github-icon.b64" 2>/dev/null)"
if [ -n "$ICON" ]; then ICON_PARAM="templateImage=$ICON"; else ICON_PARAM="sfimage=arrow.triangle.branch"; fi

# 각 PR 행 앞 아이콘: git-pull-request 마크. 없으면 SF Symbol 폴백.
PR_ICON="$(cat "$HOME/.cache/swiftbar/pr-icon.b64" 2>/dev/null)"
if [ -n "$PR_ICON" ]; then PR_ICON_PARAM="templateImage=$PR_ICON"; else PR_ICON_PARAM="sfimage=arrow.triangle.pull"; fi

fail() {
  echo "⚠︎ | sfimage=exclamationmark.triangle sfcolor=orange"
  echo "---"
  echo "$1 | color=red"
  [ -s "$ERR" ] && echo "에러 로그 보기 | bash=/bin/cat param1=$ERR terminal=true"
  echo "새로고침 | refresh=true sfimage=arrow.clockwise"
  exit 0
}

command -v gh >/dev/null 2>&1 || fail "gh CLI를 찾을 수 없음"
command -v jq >/dev/null 2>&1 || fail "jq를 찾을 수 없음 (brew install jq)"

# 승인/미승인을 review:approved 한정자로 서버에서 나눠, 두 검색을 병렬 REST로 호출(각 ~1.2s, 동시 완료).
A_JSON=$(mktemp); P_JSON=$(mktemp)
trap 'rm -f "$A_JSON" "$P_JSON"' EXIT
gh api -X GET search/issues --raw-field q="$Q review:approved"  --raw-field per_page="$PER_PAGE" >"$A_JSON" 2>"$ERR"  & pidA=$!
gh api -X GET search/issues --raw-field q="$Q -review:approved" --raw-field per_page="$PER_PAGE" >"$P_JSON" 2>>"$ERR" & pidP=$!
wait "$pidA"; rcA=$?
wait "$pidP"; rcP=$?
[ "$rcA" -eq 0 ] && [ "$rcP" -eq 0 ] && [ -s "$A_JSON" ] && [ -s "$P_JSON" ] || fail "GitHub 조회 실패 (gh auth status 확인)"

# 라벨 prefix 필터 후 항목 수 (LABEL_PREFIX="" 이면 필터 없이 전부)
count_file() { jq --arg pfx "$LABEL_PREFIX" '[.items[] | select($pfx == "" or any(.labels[].name; startswith($pfx)))] | length' "$1"; }

# 한 검색 결과 파일을 SwiftBar 행으로 출력 (라벨 prefix 필터; 빈 prefix면 전부)
emit_file() {
  jq -r --arg pricon "$PR_ICON_PARAM" --arg pfx "$LABEL_PREFIX" '
    .items[]
    | select($pfx == "" or any(.labels[].name; startswith($pfx)))   # prefix로 시작하는 라벨이 있는 PR만(빈 prefix면 전부)
    | ( .repository_url | sub("https://api.github.com/repos/"; "") ) as $repo
    | ( .title | gsub("\\|"; "｜") ) as $t
    | ( .html_url ) as $url
    | ( [ .labels[].name ] | map(gsub("\\|"; "｜")) ) as $labels
    | ( if ($labels | length) > 0 then "🏷 " + ($labels | join(", ")) + "  ·  " else "" end ) as $lp
    | "---",
      "\($t) | href=\($url) length=70 \($pricon)",
      "\($lp)@\(.user.login) · \($repo) #\(.number) | size=11 color=gray href=\($url)"
  ' "$1"
}

NP=$(count_file "$P_JSON")   # ⏳ 미승인 (-review:approved)
NA=$(count_file "$A_JSON")   # ✅ 승인됨 (review:approved)
N=$((NP + NA))

# ── 메뉴바 타이틀: 배지는 "미승인(⏳)" 건수만 표시(승인된 건 액션이 끝났으므로 제외) ──
echo "${NP} | $ICON_PARAM"
echo "---"
if [ "$N" -eq 0 ]; then
  echo "리뷰 대기 PR 없음 🎉 | size=12 color=gray"
else
  echo "리뷰 대기 PR ${N}건  ·  ⏳${NP}  ✅${NA} | size=12 color=gray"

  echo "---"
  echo "⏳ 미승인 ${NP}건 | size=12 color=gray"
  if [ "$NP" -gt 0 ]; then emit_file "$P_JSON"; else echo "없음 | size=11 color=gray"; fi

  echo "---"
  echo "✅ 승인됨 ${NA}건 | size=12 color=gray"
  if [ "$NA" -gt 0 ]; then emit_file "$A_JSON"; else echo "없음 | size=11 color=gray"; fi
fi
echo "---"
# 현재 검색식($Q)을 그대로 여는 GitHub 검색 URL을 동적 생성(jq로 URL 인코딩)
VIEW_URL="https://github.com/search?q=$(jq -rn --arg q "$Q" '$q|@uri')&type=pullrequests"
echo "검색 결과 열기 | href=$VIEW_URL sfimage=safari"
echo "GitHub 리뷰요청 검색 | href=https://github.com/pulls/review-requested sfimage=magnifyingglass"
echo "새로고침 | refresh=true sfimage=arrow.clockwise"
