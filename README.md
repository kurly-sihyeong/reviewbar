# SwiftBar — GitHub 리뷰 요청 PR 메뉴바

macOS 메뉴바에서 **"내가 리뷰 요청받았고 아직 리뷰하지 않은 열린 PR"** 을
GitHub 마크 아이콘 + 개수 배지로 보여주고, 클릭하면 목록을 펼치는 [SwiftBar](https://github.com/swiftbar/SwiftBar) 플러그인.

기존 GitHub `gh` CLI 토큰을 그대로 재사용하므로 별도 OAuth 승인 절차가 필요 없다.

> 기본값은 org `thefarmersfront` / 라벨 prefix `리뷰요청` 이며, 둘 다 `config.sh`로 바꿀 수 있다([설정](#설정-configsh) 참고).

---

## 빠른 시작

전제: `gh`, `jq` 설치 + `gh auth login` 완료(scope `repo`, `read:org`).

```bash
# 1) SwiftBar 설치 (이미 있으면 생략)
brew install --cask swiftbar

# 2) (선택) 개인 설정 — 기본값(thefarmersfront / 리뷰요청)과 다를 때만
cp config.example.sh config.sh && $EDITOR config.sh

# 3) 배치 + 갱신
./install.sh
open "swiftbar://refreshallplugins"
```

### Claude Code로 셋업하기 (팀원용)

이 repo를 **Claude Code로 열고 "이 SwiftBar 플러그인 셋업해줘"** 라고 하면, Claude가
의존성/`gh` 인증 확인 → (기본값과 다르면) `config.sh` 작성 → `./install.sh` → SwiftBar 갱신까지
순서대로 처리한다. 절차는 [`CLAUDE.md`](./CLAUDE.md)의 "팀원 셋업" 섹션에 정의돼 있다.
(`gh auth login`만 대화형이라 직접 실행이 필요할 수 있다.)

---

## 표시 모습

메뉴바:

```
 PR마크 7        ← 리뷰 대기 PR 개수 (숫자는 기본색, 아이콘은 메뉴바 색에 맞춰 틴트)
```

드롭다운(클릭 시):

```
 PR마크 7
 ─────────────────────────────
 리뷰 대기 PR 7건  ·  ⏳5  ✅2
 ─────────────────────────────
 ⏳ 미승인 5건
 [PR아이콘] feature: 상품 검증 입력값 처리…                ← 제목 (클릭=PR 열기)
 🏷 리뷰요청  ·  @octocat · web-front #297               ← 라벨 + 작성자·레포·번호 (회색)
 ─────────────────────────────
 [PR아이콘] fix: 결제 콜백 재시도 …
 🏷 리뷰요청  ·  @hubot · api-server #1358
 ─────────────────────────────
 ✅ 승인됨 2건
 …
 ─────────────────────────────
 검색 결과 열기
 GitHub 리뷰요청 검색
 새로고침
```

- PR마다 **보이는 2줄**(제목 줄 + 라벨/메타 줄), 사이 구분선으로 묶음 구분
- 라벨 있는 PR만 `🏷` 표시, 없으면 작성자·레포·번호만
- 두 줄 모두 클릭 시 해당 PR 열림
- ⏳미승인을 위, ✅승인됨을 아래로 모두 top-level(서브메뉴 아님)로 펼침

---

## 설정 (config.sh)

플러그인은 내장 **기본값**을 갖고, `~/.config/swiftbar/org-review-prs.config.sh`가 있으면 그 값으로 덮어쓴다.
개인 override는 repo 루트에서 `config.example.sh`를 복사해 만든다.

```bash
cp config.example.sh config.sh   # 수정 후 ./install.sh
```

| 변수 | 기본값 | 설명 |
|---|---|---|
| `ORG` | `thefarmersfront` | review-requested 검색 대상 org |
| `LABEL_PREFIX` | `리뷰요청` | 이 문자열로 **시작**하는 라벨이 붙은 PR만 노출. `""`이면 필터 끔(전부 표시) |
| `PER_PAGE` | `50` | 검색 결과 페이지당 최대 건수 |

- `config.sh`는 `.gitignore` 되어 **커밋되지 않는다**(개인 환경 전용). 커밋되는 건 템플릿 `config.example.sh`뿐.
- 만들지 않으면 위 기본값을 그대로 쓴다.
- **갱신 주기**는 config가 아니라 **플러그인 파일명**으로 정한다: `org-review-prs.5m.sh`의 `5m` → `2m`/`10m` 등으로 rename. (gh 토큰 5000 req/h라 여유)

---

## 대상 검색식

플러그인이 `gh api search/issues` 에 raw `q` 로 넘기는 검색식:

```
org:$ORG is:pr is:open review-requested:@me        # (+ jq에서 LABEL_PREFIX prefix 필터)
```

- 드롭다운의 **"검색 결과 열기"** 항목은 이 검색식을 그대로 인코딩한
  `https://github.com/search?q=…&type=pullrequests` URL을 **런타임에 생성**해 연다(개인 저장 View ID 같은 식별자 없음).
- `gh search prs` 에 검색식을 통째로 위치인자로 넘기면 gh가 전체를 한 토큰으로 quoting해 깨진다.
  그래서 `gh api … --raw-field q=…` 를 쓴다. 이 방식은 `-review:approved` 같은 **부정 qualifier까지 정상 동작**한다.

---

## 파일 구성

이 폴더는 **원본(source of truth)** 이다. 실제로 동작하는 파일 위치는 따로 있다(아래 표 참고).

| 이 폴더 | 실제 동작 위치 | 설명 |
|---|---|---|
| `org-review-prs.5m.sh` | `~/.config/swiftbar/org-review-prs.5m.sh` | SwiftBar 플러그인 본체 (파일명 `.5m.` = 5분 주기) |
| `config.example.sh` | — | 개인 설정 템플릿 (커밋됨) |
| `config.sh` (선택) | `~/.config/swiftbar/org-review-prs.config.sh` | 개인 override (`.gitignore`, 비커밋) |
| `assets/github-icon.b64` | `~/.cache/swiftbar/github-icon.b64` | 메뉴바 GitHub 마크 (base64 PNG, 36px@2x) |
| `assets/pr-icon.b64` | `~/.cache/swiftbar/pr-icon.b64` | 각 PR 행 앞 PR 마크 (base64 PNG, 32px@2x) |
| `assets/github-mark.png` | — | 메뉴바 아이콘 원본 (240×240 투명 PNG) |
| `assets/git-pull-request.png` | — | PR 행 아이콘 원본 (240×240 투명 PNG) |
| `pngprep.swift` | — | PNG → (투명 유지) 리사이즈 @2x 변환 헬퍼 |
| `install.sh` | — | 위 위치들로 배치하는 재현 스크립트 |
| `.gitignore` | — | `config.sh`·런타임 부산물 비커밋 |

런타임 부수 파일: `~/.cache/swiftbar/org-review-prs.err` (마지막 gh 에러 로그).

> 아이콘 원본은 GitHub Octicons / GitHub 마크 등 공개 아이콘이다. 자체 로고로 교체하려면 [아이콘 재생성](#아이콘-재생성) 참고.

---

## 동작 방식 (아키텍처)

**동기(synchronous) 방식.** 핵심은 "메뉴를 여는 동안 fetch가 렌더보다 먼저 끝난다"는 것.

- **메뉴 열 때**: `swiftbar.refreshOnOpen=true` → SwiftBar가 스크립트를 실행 → 스크립트는 `gh` 를 **동기 호출**(약 1.5~2초)하고 최신 결과를 출력 → SwiftBar가 그 출력으로 메뉴를 띄움.
  fetch가 **렌더 전에** 끝나므로 메뉴는 이미 최신 상태로 뜨고, 이후 재렌더가 없어 **저절로 닫히지 않는다**. (대가: 열 때 ~1.5~2초 대기)
- **메뉴 닫혀 있을 때**: 파일명 주기(`5m`)로 SwiftBar가 백그라운드 실행 → 배지(개수)만 최신 유지.
- **비동기 백그라운드 fetch / `refreshallplugins` 미사용.**

### 승인/미승인 분리

REST `search/issues` 응답엔 리뷰 상태 필드가 없다. GraphQL `search`로 `reviewDecision`을 받을 수 있지만
리졸버가 느려 ~2.5s(REST의 2배). 대신 검색의 `review:approved` 한정자로 두 쿼리를 **병렬 REST**로 날린다:

- ✅ 승인됨: 베이스 + `review:approved`
- ⏳ 미승인: 베이스 + `-review:approved`

둘은 같은 베이스의 정확한 여집합이라 합집합 = 전체(빠짐/중복 없음). 각 ~1.2s가 동시에 끝나 전체 ~1.2s.
배지 숫자는 **prefix 필터링된 ⏳미승인 건수만**(승인된 건 액션이 끝나 제외), 부제엔 `⏳N ✅M` 둘 다.

### `-reviewed-by:@me` 를 쓰지 않는 이유

GitHub의 "Comment" 리뷰는 review 요청을 해제하지 않는다(Approve/Request changes만 해제).
따라서 코멘트만 남긴 PR도 여전히 `review-requested:@me` 로 남는다. `-reviewed-by:@me` 를 쓰면 그런 코멘트
PR까지 걸러내 "approve 안 했는데 사라지는" 문제가 있어서 **빼고**, approve(또는 request changes) 전까지 그대로 노출한다.
approve하면 GitHub가 요청에서 빼주므로 자동으로 사라진다.

### 라벨은 서버 쿼리가 아니라 jq에서 필터

GitHub `label:`은 전체 문자열 정확 일치라 `리뷰요청-프론트` 같은 변형을 못 잡는다.
→ 서버 쿼리에선 label을 빼고(전체 review-requested 수집), `jq`에서 `LABEL_PREFIX`로 **시작하는** 라벨만 노출.
`리뷰요청-*` 변형 자동 포함, `리뷰완료`·무라벨은 제외. `LABEL_PREFIX=""`면 필터 없이 전부.

### 왜 비동기를 안 쓰나 (자동 닫힘 버그)

초기엔 "캐시 즉시 표시 + 백그라운드 fetch 후 `refreshallplugins`로 갱신" 구조였는데,
**fetch 완료 시점의 `refreshallplugins`가 열려 있던 드롭다운을 재렌더하면서 메뉴를 닫아버렸다.**
(macOS `NSMenu`는 열린 채로 내용 교체가 불가 → 재렌더 = 닫힘.)
→ 동기 방식으로 회귀해 근본 제거.

### 남는 한계

- 열 때 ~1.5~2초 대기(동기 호출 비용).
- 주기 갱신(5분)이 **메뉴 열린 순간과 겹치면** SwiftBar 자체 재렌더로 닫힐 수 있음(강제 `refreshallplugins`는 제거해 빈도·공격성은 크게 낮음). macOS엔 "메뉴 열린 동안 갱신 보류" 훅이 없어 100% 회피는 구조적으로 불가.

---

## 인증 / 권한 (왜 SwiftBar + gh 인가)

- org에 **OAuth App access 제한**이 켜져 있으면, OAuth 앱은 org owner 승인분만 org 데이터에 접근할 수 있다.
  - **Raycast** 등 GitHub OAuth 확장은 org 미승인이면 **org PR이 안 보임**.
  - **gh CLI** 토큰은 org에 이미 승인돼 있으면 org private repo/PR이 보인다. (scope: `repo`, `read:org`)
  - PAT 기반 도구는 OAuth 제한과 무관.
- 결론: **SwiftBar + gh** 조합 — 이미 승인된 gh 토큰 재사용 + 임의 검색식 자유.
- (SAML SSO org면 토큰에 SSO authorize 1회 필요.)

---

## 설치 / 재현

전제: `gh auth login` 완료(scope `repo`, `read:org`), `jq` 설치(macOS 기본 `/usr/bin/jq` 존재).

```bash
# 1) SwiftBar 설치
brew install --cask swiftbar

# 2) 플러그인 폴더 지정
mkdir -p ~/.config/swiftbar
defaults write com.ameba.SwiftBar PluginDirectory -string "$HOME/.config/swiftbar"

# 3) (선택) 개인 설정 — 기본값과 다를 때만
cp config.example.sh config.sh && $EDITOR config.sh

# 4) 아이콘 + 플러그인(+config) 배치
./install.sh

# 5) Gatekeeper quarantine 제거 후 실행
xattr -dr com.apple.quarantine /Applications/SwiftBar.app 2>/dev/null
open -a SwiftBar
```

배포 검증:

```bash
diff -q org-review-prs.5m.sh ~/.config/swiftbar/org-review-prs.5m.sh && echo OK
```

> ⚠️ 이 repo는 원본일 뿐이고 SwiftBar가 실행하는 건 **별도 위치의 복사본**이다.
> 파일을 수정했으면 반드시 `./install.sh`로 다시 배치해야 메뉴바에 반영된다. (자세한 배포 모델은 [`CLAUDE.md`](./CLAUDE.md))

---

## 아이콘 재생성

SF Symbols에는 GitHub/PR 로고가 없어 **base64 PNG를 `templateImage`로** 쓴다.
`templateImage`는 **알파(투명도)만** 보고 모양을 만들어 메뉴바/메뉴 색(다크=흰색, 라이트=검정)에 맞춰 틴트된다.

주의(겪은 함정):
- 배경이 **불투명**한 PNG면 다크 메뉴바에서 **흰 사각형**으로 꽉 찬다 → 반드시 **투명 배경**.
- 18px를 1x로 넣으면 Retina에서 2배 확대돼 **흐릿** → **2배 해상도 + 144dpi(@2x)** 로 넣어야 선명.

`pngprep.swift` 가 위 둘을 처리한다 (AppKit으로 투명 유지 리사이즈 + dpi 메타데이터 기록):

```bash
# 사용법: swift pngprep.swift <src.png> <dst.png> <pointSize> <scale>

# 메뉴바 GitHub 마크 (18pt @2x = 36px, 144dpi)
swift pngprep.swift assets/github-mark.png /tmp/gh.png 18 2
base64 -i /tmp/gh.png | tr -d '\n' > ~/.cache/swiftbar/github-icon.b64

# PR 행 마크 (16pt @2x = 32px, 144dpi)
swift pngprep.swift assets/git-pull-request.png /tmp/pr.png 16 2
base64 -i /tmp/pr.png | tr -d '\n' > ~/.cache/swiftbar/pr-icon.b64

open "swiftbar://refreshallplugins"
```

다른 아이콘으로 바꾸려면 투명 배경 PNG(정사각, 64px+)를 위 명령의 src에 넣으면 된다.

---

## 커스터마이징

- **org / 라벨 / 페이지 수**: `config.sh` (위 [설정](#설정-configsh)). 스크립트 본체를 직접 고치지 않는다.
- **갱신 주기**: 플러그인 파일명 `org-review-prs.5m.sh` 의 `5m` → `2m`, `10m` 등.
- **PR 행 아이콘 제거**: 스크립트의 `PR_ICON_PARAM=""` 로 두면 아이콘 없이 표시.
- **라벨 레이아웃**: 현재는 "보이는 둘째 줄(회색 단색)"에 `🏷 라벨 · 작성자 · 레포 #번호`.
  - 라벨별 **색**을 살리려면 한 줄=한 색 제약상 호버 서브메뉴(`--🏷 라벨 | color=#hex`) 방식이어야 함.
  - 작성자·레포를 빼려면 둘째 줄의 `@\(.user.login) · \($repo) #\(.number)` 부분 제거.

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| 메뉴바에 `⚠︎` | gh/jq 미발견 또는 gh 조회 실패. 드롭다운 "에러 로그 보기" 또는 `cat ~/.cache/swiftbar/org-review-prs.err`. `gh auth status` 확인. |
| PR이 하나도 안 뜸 | 라벨 컨벤션이 다를 수 있음. `config.sh`에서 `LABEL_PREFIX`를 팀 컨벤션에 맞추거나 `""`(필터 끔)로. org가 다르면 `ORG`도 확인. |
| 아이콘이 흰 사각형 | 아이콘 PNG 배경이 불투명. 투명 배경으로 재생성(위 참고). |
| 아이콘이 흐림 | 1x로 들어감. `pngprep.swift ... 18 2` (@2x, 144dpi)로 재생성. |
| 열면 1~2초 뒤 저절로 닫힘 | (구버전) 비동기 fetch + `refreshallplugins`. 현재 동기 방식에선 해당 없음. |
| 열 때 잠깐 대기 | 정상. 동기 fetch(`refreshOnOpen`) 비용. |
| `gh`/`jq` not found in 메뉴바 실행 | GUI 앱은 PATH가 비어 스크립트 상단 `export PATH=...`로 명시(이미 처리됨). |

---

## 의사결정 로그 (요약)

1. **메뉴바에서 org PR 보기** → OAuth 확장(Raycast 등)은 org 미승인으로 막힐 수 있음. gh 토큰은 org 승인돼 있음 → **SwiftBar + gh** 채택.
2. **검색식 전달** → `gh api search/issues` raw `q` (부정 qualifier OK). "검색 결과 열기"는 쿼리 기반 URL을 런타임 생성.
3. **자동 닫힘 버그** → 비동기 fetch+`refreshallplugins` 제거, **동기 방식**으로 회귀.
4. **아이콘** → SF Symbol 없음 → `templateImage`(base64). 투명 배경 필수, @2x로 선명화. `pngprep.swift` 도입.
5. **라벨 표시** → 보이는 2줄 레이아웃(제목 / 라벨·메타), 구분선으로 PR 묶음 구분.
6. **공유** → org/라벨은 기본값으로 두고 개인값은 `config.sh`(비커밋)로 분리, Claude 온보딩 절차를 `CLAUDE.md`에 정의.
