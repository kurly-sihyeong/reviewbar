import Foundation

/// 검색 대상·필터 설정. 로컬 전용이라 상수로 둔다(추후 설정창/UserDefaults로 확장 가능).
/// SwiftBar 플러그인의 ORG / LABEL_PREFIX / PER_PAGE 와 의미가 동일하다.
enum Config {
    static let org = "thefarmersfront"
    /// 이 prefix로 "시작"하는 라벨이 붙은 PR만 "리뷰할 PR"에 노출. ""이면 필터 끔(전부).
    static let labelPrefix = "리뷰요청"
    static let perPage = 50
    /// 주기 갱신 간격(초)
    static let refreshInterval: TimeInterval = 300

    /// gh 실행 경로 (GUI 앱은 PATH가 비어 있어 명시)
    static let ghPath = "/opt/homebrew/bin/gh"

    /// 리뷰할 PR(다른 사람) 베이스 검색식
    static let reviewBase = "org:\(org) is:pr is:open review-requested:@me"
    /// 내 PR(내가 작성) 베이스 검색식 — org 한정 없음
    static let mineBase = "is:pr is:open author:@me"

    /// 리뷰할 PR에만 적용하는 라벨 prefix 필터 (내 PR엔 적용 안 함)
    static func labelMatches(_ pr: PullRequest) -> Bool {
        guard !labelPrefix.isEmpty else { return true }
        return pr.labelList.contains { $0.name.hasPrefix(labelPrefix) }
    }

    /// 검색식을 GitHub 웹 검색 URL로 변환
    static func webSearchURL(_ query: String) -> URL {
        var c = URLComponents(string: "https://github.com/search")!
        c.queryItems = [
            .init(name: "q", value: query),
            .init(name: "type", value: "pullrequests"),
        ]
        return c.url!
    }
}
