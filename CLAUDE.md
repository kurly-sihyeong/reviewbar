# CLAUDE.md — ReviewBar

GitHub 리뷰 PR을 보여주는 **로컬 전용 SwiftUI 메뉴바 앱**. SwiftBar 플러그인에서 네이티브 앱으로 전환했다
(SwiftBar 잔재는 모두 제거됨). 배포·서명·공증 없이 본인 맥에서 빌드해 쓴다.

## 🔧 수정 → 반영 절차

이 앱은 빌드 산출물(`ReviewBar.app`)을 SwiftBar처럼 별도 위치로 복사하지 않는다. **여기서 빌드하고 여기서 실행**한다.

```bash
# 1) Sources/ReviewBar/*.swift, Config.swift, build.sh, icon_gen.swift 수정
# 2) 빌드 + 번들 생성(아이콘·ad-hoc 서명 포함)
./build.sh
# 3) 재실행 (기존 인스턴스 종료 후)
pkill -x ReviewBar; open ./ReviewBar.app
```

- 개발 중 빠른 확인은 `swift run`(.app 없이). 단 **알림은 .app으로 실행해야** 정상 동작한다(아래 참고).
- 권위 있는 검증은 항상 `swift build` / `./build.sh`. 편집기(SourceKit)의 "Cannot find type …" 류 cross-file 진단은
  단일 파일 분석 노이즈라 무시한다(빌드가 통과하면 문제없음).

## 📁 구조

| 파일 | 역할 |
|---|---|
| `ReviewBarApp.swift` | `@main`. `MenuBarExtra(.window)` + 메뉴바 배지. **`App.init`에서 `model.start()` 호출**. `--screenshot`이면 mock 주입 |
| `ContentView.swift` | 팝오버 UI — 글래스 카드 2개·SF Symbol 헤더·PR 행·동적 높이. 아바타 `AvatarView`(.task), 스크린샷용 `PopoverBackdrop` 포함 |
| `AppModel.swift` | `@Observable @MainActor` 상태 + 백그라운드 폴링 + 새 PR diff·알림 트리거. `reviewDecision`으로 4분류 |
| `Notifier.swift` | `UserNotifications` 래퍼(권한·배너·클릭 시 URL 열기) + osascript fallback |
| `GitHubClient.swift` | `actor`. `gh auth token` + `URLSession`로 **GraphQL 단일 요청**(리뷰할+내 PR) |
| `Models.swift` | GraphQL 응답 모델(`PullRequest` 등) |
| `Config.swift` | org / 라벨 prefix / 페이지 수 / 폴링 주기 / gh 경로 / 검색식 |
| `Color+Hex.swift` | 라벨 hex 색 → `Color` |
| `View+Glass.swift` | 카드 Liquid Glass 헬퍼(`glassEffect`) |
| `WindowAccessor.swift` | 팝오버 NSWindow 접근(열 때 새로고침 관찰 등록) |
| `MenuBarIcon.swift` | 메뉴바 GitHub 마크(template) 로더 |
| `build.sh` | release 빌드 → `.app` 번들 + `icon_gen.swift`로 아이콘 생성 + ad-hoc 서명 |
| `icon_gen.swift` | `github-mark.png` 기반 앱/알림 아이콘 드로잉(다크 그라데이션 + 흰 Octocat + 초록 체크 배지) |
| `AppDelegate.swift` | **스크린샷 모드 전용** — mock UI를 별도 윈도우로 띄워 캡처(평소엔 미동작) |
| `MockData.swift` | 스크린샷용 가짜 PR 데이터(4분류) |
| `screenshot.sh` | `--screenshot` 실행 → `screencapture` → `screenshots/popover.png` |

## ⚙️ 핵심 동작 (반드시 알아둘 것)

- **데이터: GraphQL 단일 요청.** `reviewRequested`(review-requested:@me) + `authored`(author:@me) alias 한 번에.
  `reviewDecision == "APPROVED"` → 승인/완료, 그 외 → 미승인/리뷰 전. 라벨 prefix 필터(`Config.labelMatches`)는
  **리뷰할 PR에만** 적용(내 PR엔 안 함). 검색식은 `Config.reviewBase`/`mineBase` 재사용.
- **자동 닫힘 해결.** macOS `NSMenu`는 열린 채 내용 교체 불가(재렌더=닫힘)였다. `MenuBarExtra(.window)` +
  `@Observable` + 백그라운드 async 폴링이라 팝오버가 열려 있어도 닫히지 않는다.
- **백그라운드 폴링은 `App.init`에서 시작.** `MenuBarExtra(.window)`의 `ContentView`는 팝오버를 **처음 열 때만**
  생성되므로, `start()`를 `.task`에 두면 메뉴를 안 열면 폴링·알림이 영영 안 돈다 → `App.init`에서 호출한다.
- **새 리뷰 요청 알림.** `AppModel.refresh(notify:)`가 직전 기준선(`knownReviewIDs`, 리뷰할·미승인 id 집합) 대비
  새로 들어온 PR만 알림. **백그라운드 폴링만 `notify:true`**, 메뉴 직접 열기·수동 새로고침은 `notify:false`(이미 보는 중이라 중복 방지).
  **첫 폴링은 기준선만 잡고 알림 안 함**(앱 시작 시 폭탄 방지).

## 🔔 알림 디버깅 함정 (겪은 것)

- **ad-hoc 서명 + LSUIElement 앱에서도 `UserNotifications`는 정상 동작**한다(권한·배너·클릭). 번들 ID(`local.reviewbar`)만 있으면 됨.
  osascript fallback은 번들 ID 없는 `swift run` 직접 실행 때만 탄다.
- **알림 좌측 아이콘 = 앱 아이콘**(`CFBundleIconFile`, `build.sh`가 `AppIcon.icns` 생성). 별도 지정 API 없음.
- **아이콘을 바꿔도 알림에 바로 반영 안 됨.** 앱 목록 아이콘은 금방 바뀌지만, 알림 아이콘은 알림 데몬이 따로 캐싱한다.
  `killall usernoted NotificationCenter`(sudo 불필요)로 갱신, 그래도 안 되면 **재로그인/재부팅**이 확실.
- **알림 검증은 `open ./ReviewBar.app`(LaunchServices 경유)으로 실행.** 바이너리 직접 실행은 발신 번들 연결이 약하다.
  `open`은 환경변수를 못 넘기므로 플래그 주입이 필요하면 `launchctl setenv KEY 1` 후 `open`(끝나면 `launchctl unsetenv`).

## 📸 스크린샷 모드 (README 이미지 생성)

`./screenshot.sh` → mock 데이터로 팝오버를 캡처해 `screenshots/popover.png` 생성(실제 계정·네트워크 무관, 항상 동일).

- `--screenshot` 시 `AppModel.isScreenshotMode=true`(폴링·네트워크 차단) + `MockData` 주입. App body의 `MenuBarExtra`는
  `SceneBuilder`가 if/else를 못 받아, 별도 윈도우는 `AppDelegate`가 띄운다(borderless·11pt 모서리·key 윈도우라 버튼 활성).
- `AppDelegate`가 윈도우 뒤에 고정 그라데이션 배경을 깔아, `PopoverBackdrop`(behindWindow 글래스)이 캡처마다 일관되게 풍부하다(없으면 데스크톱에 의존해 밋밋).
- 스크린샷 연출(글래스 백드롭·전체 펼침·카드 그림자)은 **`model.isScreenshotMode` 분기로 스크린샷 때만** 적용한다.
  **실제 앱엔 안 넣는다** — MenuBarExtra 시스템 백드롭과 중첩돼 더 불투명해짐(검증함).
- **`AvatarView`(.task)**: `AsyncImage`가 NSHostingController 컨텍스트에서 로드 task를 안 걸어 아바타가 회색으로 남던 문제를
  `.task` 직접 로드로 해결. 스크린샷뿐 아니라 **실제 앱 아바타에도 적용**된다.

## 의존성 / 인증

- `gh`(scope: `repo`, `read:org`) 필요. GUI 앱은 PATH가 비어 있어 `Config.ghPath`(`/opt/homebrew/bin/gh`)를 명시한다.
- 인증 확인: `gh auth status`. 토큰은 `gh auth token`으로 1회 받아 `GitHubClient`가 캐시·재사용한다.
