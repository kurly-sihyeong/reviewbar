# 설계 노트 / 상세 문서

ReviewBar의 아키텍처·근거·의사결정을 모았다. 일상 사용은 [README](./README.md), 개발 규칙·디버깅 함정은
[CLAUDE.md](./CLAUDE.md) 참고.

---

## 아키텍처

**메뉴바 팝오버(`MenuBarExtra(.window)`) + 백그라운드 비동기 폴링.**

- `ReviewBarApp`(`@main`)이 `MenuBarExtra { ContentView } label: { GitHub 마크 + 배지 }`를 `.menuBarExtraStyle(.window)`로 띄운다.
- `AppModel`(`@MainActor @Observable`)이 상태(4분류 PR 배열·로딩·에러·마지막 갱신)를 들고, `start()`가
  `while` 루프로 `Config.refreshInterval`(기본 300초)마다 `refresh()`를 돈다.
- `start()`는 **`App.init`에서** 호출한다. `MenuBarExtra(.window)`의 `ContentView`는 팝오버를 처음 열 때만
  생성되므로, `.task`에 두면 메뉴를 한 번도 안 열면 폴링·알림이 시작되지 않는다.
- 팝오버를 새로 열 때도 즉시 갱신한다: `WindowAccessor`가 팝오버 `NSWindow`를 잡아
  `NSWindow.didBecomeKeyNotification`을 관찰 → `refresh(notify: false)`.

### 왜 네이티브 앱인가 (자동 닫힘 버그)

SwiftBar 플러그인 시절의 근본 문제는 **macOS `NSMenu`가 열린 채로 내용 교체가 불가**하다는 것이었다
(백그라운드 fetch 후 갱신하면 재렌더 = 메뉴 닫힘). SwiftBar에선 동기 fetch로 우회했지만 열 때마다 1.5~2초 대기가 따랐다.

`MenuBarExtra(.window)`는 `NSMenu`가 아니라 팝오버(NSPopover류)에 임의 SwiftUI 뷰를 띄운다. 상태 변경 시
SwiftUI가 부분 갱신할 뿐 닫히지 않는다 → **백그라운드 폴링 중에도 팝오버가 열린 채 유지**된다. 동기 대기도 사라졌다.

---

## 데이터: GraphQL 단일 요청

`gh auth token`으로 받은 토큰을 `URLSession` POST(`https://api.github.com/graphql`)에 실어, alias 2개를 **한 요청**으로 가져온다:

```graphql
query {
  reviewRequested: search(query: "org:… is:pr is:open review-requested:@me", type: ISSUE, first: N) {
    nodes { ... on PullRequest { number title url reviewDecision createdAt
                                 author{login avatarUrl} repository{nameWithOwner} labels(first:10){nodes{name color}} } }
  }
  authored: search(query: "is:pr is:open author:@me", type: ISSUE, first: N) { nodes { …동일… } }
}
```

- **분류는 `reviewDecision` 기준**: `APPROVED` → 승인/리뷰 완료, 그 외(`REVIEW_REQUIRED`/`CHANGES_REQUESTED`/null) → 미승인/리뷰 전.
- 검색식은 `Config.reviewBase`(org 한정) / `Config.mineBase`(org 한정 없음)를 재사용한다.
- **하단 "검색 결과 열기" 버튼**은 같은 검색식을 `https://github.com/search?q=…&type=pullrequests` URL로 런타임 생성해 연다(저장된 View ID 같은 식별자 없음).

> **SwiftBar(REST 4회) → 앱(GraphQL 1회)로 바꾼 이유**: REST `search/issues` 응답엔 리뷰 상태 필드가 없어
> `review:approved`/`-review:approved`로 쿼리를 4개로 쪼개야 했다. GraphQL은 `reviewDecision`을 직접 주므로 1요청으로
> 분류까지 끝난다(실측 ~1.8s). 백그라운드 폴링이라 약간의 지연은 UX에 영향 없다.

### 라벨 prefix 필터는 클라이언트에서

GitHub `label:`은 전체 문자열 정확 일치라 `리뷰요청-프론트` 같은 변형을 못 잡는다. 그래서 서버 쿼리엔 label을 넣지 않고,
받은 뒤 `Config.labelMatches`가 `labelPrefix`로 **시작하는** 라벨만 통과시킨다(`리뷰요청-*` 포함, `리뷰완료`·무라벨 제외).
`labelPrefix == ""`이면 필터 끔. **리뷰할 PR에만 적용**하고 내 PR엔 적용하지 않는다(작성자가 항상 나라서).

### `-reviewed-by:@me` 를 쓰지 않는 이유

GitHub의 "Comment" 리뷰는 review 요청을 해제하지 않는다(Approve/Request changes만 해제). `-reviewed-by:@me`를 쓰면
코멘트만 남긴 PR까지 걸러져 "approve 안 했는데 사라지는" 문제가 생긴다 → 빼고, approve(또는 request changes) 전까지 그대로 노출한다.

---

## 새 리뷰 요청 알림

백그라운드 폴링이 기존 데이터 대비 **새로 들어온 "리뷰할·미승인" PR**(`reviewPending`, 배지와 동일 집합)을 감지하면 데스크톱 알림을 띄운다.

- **diff 기준선**: `AppModel`이 직전 폴링의 `reviewPending` id 집합(`knownReviewIDs`)을 기억하고, 새 결과와의 차집합을 알림 대상으로 본다. 기준선은 모든 갱신 경로에서 갱신한다.
- **백그라운드 폴링에서만 알림**: `refresh(notify:)`의 `notify`가 폴링은 `true`, 메뉴 직접 열기·수동 새로고침은 `false`(이미 보는 중이라 중복 방지).
- **첫 폴링은 기준선만 잡고 알림 안 함**(`hasBaseline`) → 앱 시작 시 기존 PR이 전부 "새것"으로 잡혀 폭탄 알림 나는 것 방지.
- **표시**: `Notifier`가 `UserNotifications`로 배너 게시. 1건이면 제목·레포·작성자, 여러 건이면 묶음. 클릭 시 PR URL(여러 건은 검색 페이지)을 `NSWorkspace`로 연다.
- **fallback**: 번들 ID가 없는 등으로 UN을 못 쓰면 `osascript display notification`으로 표시만 한다(클릭 액션 없음). ad-hoc 서명 + LSUIElement 앱에서도 UN이 정상 동작하므로 실제로는 거의 안 탄다.

> 알림 아이콘은 앱 아이콘을 따르고, 알림 데몬이 별도 캐싱한다. 아이콘 변경 후 반영 함정은 [CLAUDE.md](./CLAUDE.md#-알림-디버깅-함정-겪은-것) 참고.

---

## UI

- **Liquid Glass(macOS 26)**: 대분류 카드 2개(`👀 리뷰할 PR` / `🙋 내 PR`)는 `glassEffect` + `GlassEffectContainer`로 합성.
  footer 버튼도 `.buttonStyle(.glass)`/`.glassProminent`.
- **카드 구성**: 카드 헤더(SF Symbol + 제목 + 카운트 pill) 아래 하위 섹션(미승인/승인 · 리뷰 전/완료). PR 행은
  아바타 + 제목(2줄) + 색 라벨 칩 + 메타(`@작성자 · 레포 #번호 · 상대시간`). 행 hover 하이라이트 + 손가락 커서(`.pointerStyle(.link)`).
- **동적 높이**: 카드 스택 높이를 `onGeometryChange`로 측정해, 컨텐츠가 작으면 팝오버가 줄고 최대 600pt에서 스크롤한다.

## 아이콘

앱 아이콘 = 메뉴바 알림 아이콘. `icon_gen.swift`가 `Sources/ReviewBar/Resources/github-mark.png`를 베이스로
AppKit 드로잉(둥근 사각형 다크 그라데이션 + 흰 Octocat + 우하단 초록 체크 배지)해 1024px PNG를 만들고,
`build.sh`가 `sips`로 iconset → `iconutil`로 `AppIcon.icns`를 생성해 번들에 넣는다(Info.plist `CFBundleIconFile=AppIcon`).
메뉴바 마크는 `github-mark.png`를 template 이미지로 써서 다크/라이트에 맞춰 틴트된다.

---

## 인증 / 권한 (왜 gh 토큰 재사용인가)

- org에 **OAuth App access 제한**이 켜져 있으면 OAuth 앱(Raycast 등)은 org 미승인 시 org PR이 안 보인다.
- `gh` CLI 토큰은 org에 이미 승인돼 있으면 org private repo/PR을 볼 수 있다(scope `repo`, `read:org`).
- → `gh auth token`을 재사용하면 별도 OAuth 승인 없이 org 데이터 + 임의 검색식 자유를 얻는다.
- GUI 앱은 PATH가 비어 있어 `Config.ghPath`로 `gh` 경로를 명시한다. (SAML SSO org면 토큰에 SSO authorize 1회 필요.)

---

## 의사결정 로그 (요약)

1. **메뉴바에서 org PR 보기** → OAuth 확장은 org 미승인으로 막힐 수 있음 → 이미 승인된 **gh 토큰 재사용**.
2. **자동 닫힘 버그** → `NSMenu` 한계. SwiftBar(동기 fetch 우회)에서 **`MenuBarExtra(.window)` + 백그라운드 async 폴링** 네이티브 앱으로 전환해 근본 제거.
3. **요청 수 축소** → REST 4회(리뷰 상태 필드 없음)에서 **GraphQL 단일 요청 + `reviewDecision` 분류**로.
4. **새 리뷰 요청 알림** → 기준선 diff + 백그라운드 폴링에서만 + 첫 폴링 baseline(폭탄 방지) + `UserNotifications`(osascript fallback).
5. **UI** → Liquid Glass 카드 2개·동적 높이·아바타/라벨 칩/상대시간. 텍스트 줄 나열(SwiftBar)에서 탈피.
6. **아이콘** → `github-mark.png` 기반 창의적 앱 아이콘(`icon_gen.swift`)을 빌드 시 생성.
