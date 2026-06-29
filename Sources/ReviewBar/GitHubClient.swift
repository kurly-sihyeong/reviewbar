import Foundation

/// GitHub GraphQL 클라이언트. `gh auth token`으로 토큰을 1회 받아 재사용하고,
/// 리뷰할 PR + 내 PR을 **단일 GraphQL 요청**으로 가져온다(REST 4회 → 1회).
actor GitHubClient {
    private var cachedToken: String?

    enum ClientError: LocalizedError {
        case ghFailed(String)
        case http(Int, String)
        case graphql(String)

        var errorDescription: String? {
            switch self {
            case .ghFailed(let m): return "gh 토큰 획득 실패: \(m)"
            case .http(let code, let body): return "GitHub API 오류(\(code)): \(body.prefix(200))"
            case .graphql(let m): return "GraphQL 오류: \(m.prefix(200))"
            }
        }
    }

    /// 단일 요청으로 (리뷰할 PR, 내 PR) 노드 배열을 반환. 승인/미승인 분류는 호출부에서 reviewDecision으로.
    func fetchAll() async throws -> (reviewRequested: [PullRequest], authored: [PullRequest]) {
        let token = try token()
        var req = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": Self.query])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.http(-1, "응답 없음") }
        guard http.statusCode == 200 else {
            throw ClientError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(GraphQLResponse.self, from: data)
        if let errs = result.errors, !errs.isEmpty {
            throw ClientError.graphql(errs.map(\.message).joined(separator: "; "))
        }
        guard let payload = result.data else { throw ClientError.graphql("data 없음") }
        return (payload.reviewRequested.nodes, payload.authored.nodes)
    }

    /// is:pr 쿼리라 모든 노드가 PullRequest. inline fragment로 PR 필드만 선택.
    private static let prFields = """
    ... on PullRequest {
      number title url reviewDecision createdAt
      author { login avatarUrl }
      repository { nameWithOwner }
      labels(first: 10) { nodes { name color } }
    }
    """

    private static var query: String {
        """
        query {
          reviewRequested: search(query: "\(Config.reviewBase)", type: ISSUE, first: \(Config.perPage)) {
            nodes { \(prFields) }
          }
          authored: search(query: "\(Config.mineBase)", type: ISSUE, first: \(Config.perPage)) {
            nodes { \(prFields) }
          }
        }
        """
    }

    // MARK: - 토큰 (gh CLI 재사용)

    private func token() throws -> String {
        if let t = cachedToken { return t }
        let out = try Self.runGH(["auth", "token"])
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ClientError.ghFailed("빈 토큰") }
        cachedToken = trimmed
        return trimmed
    }

    func resetToken() { cachedToken = nil }

    private nonisolated static func runGH(_ args: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: Config.ghPath)
        proc.arguments = args
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            throw ClientError.ghFailed("\(Config.ghPath) 실행 실패: \(error.localizedDescription)")
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw ClientError.ghFailed("종료코드 \(proc.terminationStatus) (gh auth status 확인)")
        }
        return String(decoding: data, as: UTF8.self)
    }
}
