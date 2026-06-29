# ReviewBar — GitHub 리뷰 PR 메뉴바 앱

macOS 메뉴바에서 **내가 리뷰 요청받은 열린 PR**(다른 사람이 올린 것)과 **내가 작성한 열린 PR**을
한곳에 모아 보여주는 네이티브 SwiftUI 메뉴바 앱. GitHub 마크 아이콘 + 미승인 개수 배지로 표시하고,
클릭하면 글래스 카드로 목록을 펼친다. **새 리뷰 요청이 들어오면 데스크톱 알림**으로 알려준다.

기존 GitHub `gh` CLI 토큰을 그대로 재사용하므로 별도 OAuth 승인 절차가 필요 없다.

> **로컬 전용 앱**: 배포·코드 서명·공증을 하지 않는다. 본인 맥에서 빌드해 쓰는 전제다.
> 직접 컴파일한 바이너리는 quarantine 속성이 없어 Gatekeeper 경고 없이 그냥 실행된다. Xcode도 필요 없다.

```
 [GitHub마크] 5                         ← 메뉴바: 미승인(내가 리뷰할 차례) 배지
 ┌─────────────────────────────┐
 │ 👀 리뷰할 PR · 다른 사람   (7) │      ← 카드① review-requested:@me (라벨 prefix 필터)
 │   ⏳ 미승인 5                  │
 │   ● feature: 상품 검증 입력값…  │      ← 아바타 + 제목 + 라벨 칩 + @작성자·레포 #번호·상대시간
 │   ✅ 승인됨 2                   │
 ├─────────────────────────────┤
 │ 🙋 내 PR · 내가 작성       (4) │      ← 카드② author:@me (org 한정·라벨 필터 없음)
 │   📝 리뷰 전 1                  │
 │   ● fix: 날짜 파싱 경계값…       │
 │   🚀 리뷰 완료 3               │
 └─────────────────────────────┘
 ↻  3초 전        🔍  👤  ⏻       ← 새로고침·검색·종료 (Liquid Glass 버튼)
```

- **리뷰할 PR**: `review-requested:@me`(내가 리뷰어). `⏳ 미승인` / `✅ 승인됨`으로 나눔. 라벨 prefix 필터 적용.
- **내 PR**: `author:@me`(내가 작성자, org 한정 없음). `📝 리뷰 전` / `🚀 리뷰 완료`로 나눔. 라벨 필터·작성자 표시 없음.
- 분류 기준은 GitHub `reviewDecision`(브랜치 보호 규칙 기반). `APPROVED` → 승인/완료, 그 외 → 미승인/리뷰 전.

---

## 전제

- **macOS 26+** (Liquid Glass·`onGeometryChange` 사용) / **Swift 6.2+** 툴체인
- **Command Line Tools면 충분** (Xcode 불필요)
- **`gh` 인증 완료** (scope `repo`, `read:org`) — 토큰을 `gh auth token`으로 재사용한다

```bash
brew install gh           # 이미 있으면 생략
gh auth login             # scope: repo, read:org
gh auth status            # 인증 확인
```

## 빌드 & 실행

```bash
./build.sh                # release 빌드 + ReviewBar.app 번들 생성(아이콘·ad-hoc 서명 포함)
open ./ReviewBar.app      # 실행 → 메뉴바에 GitHub 마크 + 미승인 배지

# 개발 중 빠른 실행 (.app 없이)
swift run
```

첫 실행 시 **알림 권한 다이얼로그**가 뜬다(허용해야 새 리뷰 요청 알림이 온다). 종료는 팝오버 하단 ⏻ 버튼.
(Dock 아이콘은 없다 — `LSUIElement`.)

## 설정

검색 대상 org·라벨 필터·갱신 주기 등은 [`Sources/ReviewBar/Config.swift`](./Sources/ReviewBar/Config.swift)의
상수로 둔다. 값을 고친 뒤 다시 `./build.sh` 하면 반영된다.

| 상수 | 설명 |
|---|---|
| `org` | **리뷰할 PR**(review-requested) 검색 대상 GitHub org. **내 PR**(author:@me)은 org 한정 없이 전체에서 가져온다 |
| `labelPrefix` | 이 문자열로 **시작**하는 라벨이 붙은 PR만 노출(`리뷰요청-프론트` 같은 변형 포함). `""`이면 필터 끔. **리뷰할 PR에만** 적용 |
| `perPage` | GraphQL 검색 결과 최대 건수 |
| `refreshInterval` | 백그라운드 폴링 주기(초). 새 리뷰 요청 알림도 이 주기로 감지(기본 300초) |

## 자동 시작 (선택)

로그인 시 자동 실행하려면 **시스템 설정 → 일반 → 로그인 항목**에 `ReviewBar.app`을 추가하거나,
`~/Library/LaunchAgents/`에 LaunchAgent plist를 둔다.

---

## 더 자세히

- **설계·아키텍처·의사결정 로그**(GraphQL 단일 요청·자동 닫힘 해결·알림·Liquid Glass·아이콘): [`DESIGN.md`](./DESIGN.md)
- **개발 규칙·빌드 반영 절차·디버깅 함정**: [`CLAUDE.md`](./CLAUDE.md)
