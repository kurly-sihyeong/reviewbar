import Foundation

/// GitHub GraphQL 응답: reviewRequested(리뷰할 PR) + authored(내 PR)을 한 요청으로 받는다.
struct GraphQLResponse: Decodable {
    let data: Payload?
    let errors: [GraphQLError]?

    struct Payload: Decodable {
        let reviewRequested: Connection
        let authored: Connection
    }
    struct Connection: Decodable {
        let nodes: [PullRequest]
    }
}

struct GraphQLError: Decodable { let message: String }

/// PR 한 건 (GraphQL `... on PullRequest` 선택 필드)
struct PullRequest: Decodable, Identifiable, Sendable {
    let number: Int
    let title: String
    let url: String
    let reviewDecision: String?   // APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / null
    let createdAt: Date
    let author: Author?
    let repository: Repository
    let labels: LabelConnection

    /// repo가 다르면 같은 번호가 있을 수 있어 repo+번호로 식별
    var id: String { "\(repository.nameWithOwner)#\(number)" }
    /// 리뷰 완료/승인 여부 — reviewDecision 기준(브랜치 보호 규칙 기반)
    var isApproved: Bool { reviewDecision == "APPROVED" }
    var repoName: String { repository.nameWithOwner }
    var labelList: [Label] { labels.nodes }

    struct Author: Decodable, Sendable {
        let login: String
        let avatarUrl: String
    }
    struct Repository: Decodable, Sendable {
        let nameWithOwner: String
    }
    struct LabelConnection: Decodable, Sendable {
        let nodes: [Label]
    }
    struct Label: Decodable, Identifiable, Sendable {
        let name: String
        let color: String   // hex (예: "FBCA04")
        var id: String { name }
    }
}
