import Foundation

/// 스크린샷 모드(`--screenshot`) 전용 가짜 데이터.
/// 실제 GitHub 호출 없이 항상 동일한 데모 화면을 만들기 위해 4분류를 채운다.
enum MockData {
    @MainActor
    static func install(into model: AppModel) {
        model.reviewPending = [
            pr(297, "feat: 상품 상세 페이지 입력값 검증 개선", "thefarmersfront/web-front", "kim-dev",
               hoursAgo: 2, approved: false, labels: [("리뷰요청", "0E8A16"), ("frontend", "1D76DB")]),
            pr(1432, "fix: 장바구니 수량 동기화 레이스 컨디션 해결", "thefarmersfront/order-api", "lee-backend",
               hoursAgo: 5, approved: false, labels: [("리뷰요청-백엔드", "0E8A16"), ("bug", "D73A4A")]),
            pr(301, "refactor: 결제 모듈 의존성 정리", "thefarmersfront/web-front", "park-fe",
               hoursAgo: 26, approved: false, labels: [("리뷰요청", "0E8A16")]),
        ]
        model.reviewApproved = [
            pr(88, "chore: CI 캐시 키 정리로 빌드 시간 단축", "thefarmersfront/infra", "choi-devops",
               hoursAgo: 30, approved: true, labels: [("리뷰요청", "0E8A16"), ("ci", "FBCA04")]),
        ]
        model.minePending = [
            pr(312, "feat: 알림 설정 화면 추가", "thefarmersfront/web-front", "me",
               hoursAgo: 3, approved: false, labels: []),
        ]
        model.mineApproved = [
            pr(305, "fix: 날짜 파싱 경계값 처리", "thefarmersfront/web-front", "me",
               hoursAgo: 28, approved: true, labels: []),
            pr(12, "docs: README를 ReviewBar 기준으로 재작성", "kurly-sihyeong/reviewbar", "me",
               hoursAgo: 50, approved: true, labels: [("documentation", "0075CA")]),
        ]
        model.lastUpdated = Date()
        model.isLoading = false
        model.errorMessage = nil
    }

    private static func pr(_ number: Int, _ title: String, _ repo: String, _ login: String,
                           hoursAgo: Double, approved: Bool,
                           labels: [(String, String)]) -> PullRequest {
        PullRequest(
            number: number,
            title: title,
            url: "https://github.com/\(repo)/pull/\(number)",
            reviewDecision: approved ? "APPROVED" : "REVIEW_REQUIRED",
            createdAt: Date().addingTimeInterval(-hoursAgo * 3600),
            author: .init(login: login, avatarUrl: "https://i.pravatar.cc/80?u=\(login)"),
            repository: .init(nameWithOwner: repo),
            labels: .init(nodes: labels.map { .init(name: $0.0, color: $0.1) })
        )
    }
}
