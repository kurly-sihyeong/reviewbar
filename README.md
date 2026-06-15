# SwiftBar — GitHub 리뷰 요청 PR 메뉴바

macOS 메뉴바에서 **"내가 리뷰 요청받았고 아직 리뷰하지 않은 열린 PR"** 을
GitHub 마크 아이콘 + 개수 배지로 보여주고, 클릭하면 목록을 펼치는 [SwiftBar](https://github.com/swiftbar/SwiftBar) 플러그인.

기존 GitHub `gh` CLI 토큰을 그대로 재사용하므로 별도 OAuth 승인 절차가 필요 없다.
기본값은 org `thefarmersfront` / 라벨 prefix `리뷰요청` 이며, 둘 다 [`config.sh`](#설정-configsh)로 바꿀 수 있다.

```
 PR마크 7
 ─────────────────────────────
 리뷰 대기 PR 7건  ·  ⏳5  ✅2
 ─────────────────────────────
 ⏳ 미승인 5건
 [PR아이콘] feature: 상품 검증 입력값 처리…          ← 제목 (클릭=PR 열기)
 🏷 리뷰요청  ·  @octocat · web-front #297         ← 라벨 + 작성자·레포·번호
 ─────────────────────────────
 ✅ 승인됨 2건
 …
```

---

## 빠른 시작

전제: `gh`, `jq` 설치 + `gh auth login` 완료(scope `repo`, `read:org`).

```bash
brew install --cask swiftbar              # SwiftBar 설치 (이미 있으면 생략)
cp config.example.sh config.sh            # (선택) 기본값과 다를 때만 수정
./install.sh                              # 아이콘·플러그인(+config) 배치
open "swiftbar://refreshallplugins"       # 갱신
```

> 이 repo는 원본일 뿐, SwiftBar가 실행하는 건 `~/.config/swiftbar/`의 **복사본**이다.
> 파일을 고쳤으면 **반드시 `./install.sh`** 로 다시 배치해야 메뉴바에 반영된다.

### Claude Code로 셋업 (팀원용)

이 repo를 **Claude Code로 열고 "이 SwiftBar 플러그인 셋업해줘"** 라고 하면, Claude가
의존성/`gh` 인증 확인 → (기본값과 다르면) `config.sh` 작성 → `./install.sh` → SwiftBar 갱신까지
처리한다. 절차는 [`CLAUDE.md`](./CLAUDE.md)의 "팀원 셋업" 섹션에 정의돼 있다.

---

## 설정 (config.sh)

플러그인은 내장 **기본값**을 갖고, `config.example.sh`를 복사한 `config.sh`가 있으면 그 값으로 덮어쓴다.

| 변수 | 기본값 | 설명 |
|---|---|---|
| `ORG` | `thefarmersfront` | review-requested 검색 대상 org |
| `LABEL_PREFIX` | `리뷰요청` | 이 문자열로 **시작**하는 라벨이 붙은 PR만 노출. `""`이면 필터 끔(전부) |
| `PER_PAGE` | `50` | 검색 결과 페이지당 최대 건수 |

- `config.sh`는 `.gitignore` 되어 **커밋되지 않는다**(개인 환경 전용). 안 만들면 기본값을 그대로 쓴다.
- **갱신 주기**는 플러그인 파일명으로 정한다: `org-review-prs.5m.sh`의 `5m` → `2m`/`10m` 등으로 rename.

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| 메뉴바에 `⚠︎` | gh/jq 미발견 또는 조회 실패. 드롭다운 "에러 로그 보기" 또는 `cat ~/.cache/swiftbar/org-review-prs.err`, `gh auth status` 확인. |
| PR이 하나도 안 뜸 | 라벨 컨벤션이 다를 수 있음. `config.sh`에서 `LABEL_PREFIX`를 맞추거나 `""`(필터 끔)로. org가 다르면 `ORG`도 확인. |
| 아이콘이 흰 사각형 / 흐림 | 아이콘 PNG 문제. [DESIGN.md 아이콘 재생성](./DESIGN.md#아이콘-재생성) 참고. |
| 열 때 1~2초 대기 | 정상. 동기 fetch(`refreshOnOpen`) 비용. |

---

## 더 자세히

- **설계·아키텍처·검색식·인증·의사결정 로그**: [`DESIGN.md`](./DESIGN.md)
- **배포 모델·개발 규칙·팀원 셋업 절차**: [`CLAUDE.md`](./CLAUDE.md)
