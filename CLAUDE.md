# CLAUDE.md — swiftbar-github-review-prs

## 🚀 팀원 셋업 (사용자가 "셋업해줘" 라고 하면)

처음 이 repo를 받은 팀원이 셋업을 요청하면 아래 순서대로 진행한다.

1. **의존성/인증 확인**
   - `command -v gh`, `command -v jq` — 없으면 `brew install gh jq` 안내.
   - `gh auth status` — 미인증/스코프 부족이면 **`gh auth login`은 대화형**이라 직접 못 돌린다.
     사용자에게 프롬프트에 `! gh auth login` 을 입력하라고 안내(scope `repo`, `read:org` 필요).
2. **개인 override가 필요한지 확인** — org/라벨이 기본값(`thefarmersfront` / `리뷰요청`)과 같으면 **건너뛴다**.
   다르면 사용자에게 org/라벨 prefix를 물어 `config.example.sh`를 복사한 `config.sh`를 만들고 값을 채운다.
   (라벨 필터를 끄려면 `LABEL_PREFIX=""`. `config.sh`는 `.gitignore`라 커밋되지 않는다.)
3. **배치 + 갱신**: `./install.sh` → `open "swiftbar://refreshallplugins"`.
   - SwiftBar 미설치면: `brew install --cask swiftbar && xattr -dr com.apple.quarantine /Applications/SwiftBar.app && open -a SwiftBar`.
4. **검증**: `diff -q org-review-prs.5m.sh ~/.config/swiftbar/org-review-prs.5m.sh && echo OK`,
   이어서 `~/.config/swiftbar/org-review-prs.5m.sh | head -1` 로 배지 숫자가 나오는지 확인.

## ⚙️ 설정 (config 메커니즘)

플러그인은 내장 **기본값**(`ORG=thefarmersfront`, `LABEL_PREFIX=리뷰요청`, `PER_PAGE=50`)을 갖고,
`~/.config/swiftbar/org-review-prs.config.sh`가 있으면 그걸 source해 덮어쓴다.

- 원본 override는 repo 루트 `config.sh`(= `.gitignore`)에 두고, `install.sh`가 위 위치로 복사한다.
- 커밋되는 건 `config.example.sh`(템플릿)뿐. 실제 개인값은 절대 커밋되지 않는다.
- 주기(`.5m.`)는 config가 아니라 **플러그인 파일명**으로 정해진다 → 바꾸려면 파일 rename.

## ⚠️ 배포 모델 (가장 중요)

이 repo는 **원본(source of truth)** 일 뿐이고, SwiftBar가 실제로 실행하는 파일은 **별도 위치의 복사본**이다.

- 원본: 이 폴더의 `org-review-prs.5m.sh`, `assets/*.b64`, (선택) `config.sh`
- 실행 위치(활성 PluginDirectory): `~/.config/swiftbar/org-review-prs.5m.sh` (+ 있으면 `org-review-prs.config.sh`)
- 캐시/아이콘: `~/.cache/swiftbar/` (`github-icon.b64`, `pr-icon.b64`, 에러 로그 `org-review-prs.err`)

**`install.sh`는 심볼릭 링크가 아니라 `cp`(복사)로 배포한다.** 따라서:

> 🔴 이 폴더의 파일을 수정했으면 **반드시 `./install.sh` 를 실행**해서 배포해야 한다.
> repo만 고치고 끝내면 SwiftBar 메뉴바에는 **전혀 반영되지 않는다** (구버전 복사본이 계속 돈다).

심볼릭 링크 방식은 쓰지 않는다 — SwiftBar가 `~/Library/.../SwiftBar/Plugins/`, `~/Library/Caches/com.ameba.SwiftBar/Plugins/` 아래에 **플러그인 파일명 기준으로 per-plugin 캐시/임시 디렉토리**를 만들어 혼동을 주기 때문이다(이 디렉토리들은 SwiftBar 내부용이라 건드리지 않는다).

## 수정 → 반영 절차

```bash
# 1) 이 폴더에서 org-review-prs.5m.sh / config.sh / assets / install.sh 수정
# 2) 배포 (repo → ~/.config/swiftbar 로 복사. config.sh 있으면 같이 복사됨)
./install.sh
# 3) SwiftBar 갱신 (둘 중 하나)
open "swiftbar://refreshallplugins"          # 가벼운 갱신
osascript -e 'quit app "SwiftBar"'; open -a SwiftBar   # 완전 재실행
```

배포가 됐는지 검증:
```bash
diff -q org-review-prs.5m.sh ~/.config/swiftbar/org-review-prs.5m.sh && echo OK
```

## 플러그인 동작 요약

- 매 실행마다 `gh api search/issues`를 **라이브 호출**한다(자체 캐싱 없음). 멈춘 것처럼 보이면 캐싱이 아니라 **쿼리/필터**를 의심할 것.
- 승인/미승인을 분리하려고 **두 검색을 병렬 REST로** 호출한다(베이스 쿼리 `org:$ORG is:pr is:open review-requested:@me`):
  - ✅ 승인됨: 베이스 + `review:approved`
  - ⏳ 미승인: 베이스 + `-review:approved`
  - 둘은 같은 베이스의 정확한 여집합이라 합집합 = 전체(빠짐/중복 없음). 각 ~1.2s가 동시에 끝나므로 전체 ~1.2s.
  - **GraphQL을 쓰지 않는 이유**: `reviewDecision`을 GraphQL `search`로 받을 수 있지만 리졸버가 느려 ~2.5s(REST의 2배). `review:approved` 한정자로 분류 결과는 `reviewDecision` 기준과 동일함을 검증함.
  - 화면 배치: ⏳미승인이 위, ✅승인됨이 아래. 둘 다 top-level(서브메뉴 아님).
  - `-reviewed-by:@me`를 **쓰지 않는다**: GitHub의 "Comment" 리뷰는 review 요청을 해제하지 않으므로(Approve/Request changes만 해제), 코멘트만 남긴 PR도 계속 노출하기 위함. approve하면 GitHub가 요청에서 빼주어 자동으로 사라진다.
  - `label:`을 서버 쿼리에 **넣지 않는다**: GitHub `label:`은 전체 문자열 정확 일치라 `리뷰요청-프론트` 같은 변형을 못 잡는다. 대신 `jq`에서 `LABEL_PREFIX`(기본 `리뷰요청`)로 **prefix 필터**한다 → `리뷰요청-*` 변형 자동 포함, `리뷰완료`·무라벨은 제외. `LABEL_PREFIX=""`면 필터 없이 전부.
- 배지 숫자는 `total_count`가 아니라 **prefix 필터링된 ⏳미승인 건수(`NP`)만**이다(승인된 건 액션이 끝나 제외). 메뉴 부제엔 `⏳N ✅M`로 둘 다 표시.

## 의존성 / 인증

- `gh`(scope: `repo`, `read:org`), `jq` 필요. GUI 앱은 PATH가 비어 있어 스크립트에서 `PATH`를 명시한다.
- 인증 확인: `gh auth status`
