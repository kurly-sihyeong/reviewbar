import SwiftUI
import Observation
import AppKit

/// 앱 상태. 단일 GraphQL 요청 결과를 reviewDecision 기준으로 4분류한다.
/// 백그라운드 비동기 폴링이라 팝오버가 열려 있어도 닫히지 않는다(자동 닫힘 근본 해결).
@MainActor
@Observable
final class AppModel {
    var reviewPending: [PullRequest] = []    // 리뷰할 · 미승인
    var reviewApproved: [PullRequest] = []   // 리뷰할 · 승인됨
    var minePending: [PullRequest] = []      // 내 PR · 리뷰 전
    var mineApproved: [PullRequest] = []     // 내 PR · 리뷰 완료

    var isLoading = false
    var lastUpdated: Date?
    var errorMessage: String?

    /// 메뉴바 배지 = 리뷰할 PR 중 미승인 건수(내가 리뷰할 차례)
    var badgeCount: Int { reviewPending.count }

    private let client = GitHubClient()
    private let notifier = Notifier()
    private var started = false
    private weak var observedWindow: NSWindow?

    /// 직전 폴링까지 알고 있던 "리뷰할·미승인" PR id (새로 들어온 건을 가려내는 기준선)
    private var knownReviewIDs: Set<String> = []
    /// 첫 refresh로 기준선을 잡았는지. 잡기 전엔 알림하지 않는다(앱 시작 시 폭탄 방지).
    private var hasBaseline = false

    /// 스크린샷 모드(`--screenshot`): 폴링·새로고침을 막아 주입된 mock 데이터를 그대로 유지한다.
    var isScreenshotMode = false

    func start() {
        guard !isScreenshotMode, !started else { return }
        started = true
        Task {
            await notifier.requestAuthorization()
            while !Task.isCancelled {
                await refresh(notify: true)   // 백그라운드 폴링에서만 새 PR 알림
                try? await Task.sleep(for: .seconds(Config.refreshInterval))
            }
        }
    }

    /// 팝오버 윈도우가 키가 될 때(= 메뉴를 새로 열 때)마다 새로고침하도록 관찰 등록(윈도우당 1회).
    /// 메뉴를 직접 여는 경우라 알림은 띄우지 않는다(이미 화면으로 보는 중).
    func attachWindow(_ window: NSWindow) {
        guard observedWindow !== window else { return }
        observedWindow = window
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh(notify: false) }
        }
    }

    /// - Parameter notify: 직전 기준선 대비 새로 들어온 리뷰 요청 PR을 데스크톱 알림으로 띄울지.
    ///   백그라운드 폴링은 `true`, 사용자가 메뉴를 직접 열거나 새로고침을 누른 경우는 `false`.
    func refresh(notify: Bool = false) async {
        guard !isScreenshotMode else { return }   // mock 데이터 유지(네트워크 호출 안 함)
        guard !isLoading else { return }   // 동시/중복 호출 방지(열 때마다 1회만)
        isLoading = true
        defer { isLoading = false }
        do {
            let (reviewRequested, authored) = try await client.fetchAll()
            // 라벨 prefix 필터는 "리뷰할 PR"에만 (내 PR엔 적용 안 함)
            let rr = reviewRequested.filter(Config.labelMatches)
            reviewPending = rr.filter { !$0.isApproved }
            reviewApproved = rr.filter { $0.isApproved }
            minePending = authored.filter { !$0.isApproved }
            mineApproved = authored.filter { $0.isApproved }
            lastUpdated = Date()
            errorMessage = nil

            // 새 리뷰 요청 알림: 기준선 대비 새로 들어온 미승인 PR만. 기준선은 모든 경로에서 갱신.
            if hasBaseline && notify {
                let newPRs = reviewPending.filter { !knownReviewIDs.contains($0.id) }
                if !newPRs.isEmpty { notifier.notifyNewReviews(newPRs) }
            }
            knownReviewIDs = Set(reviewPending.map(\.id))
            hasBaseline = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
