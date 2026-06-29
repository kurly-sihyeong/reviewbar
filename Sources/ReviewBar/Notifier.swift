import Foundation
import AppKit
import UserNotifications

/// 새 리뷰 요청 PR을 macOS 데스크톱 알림으로 띄운다.
///
/// 로컬 ad-hoc 서명 + LSUIElement 앱이라 `UserNotifications`(UNUserNotificationCenter)가
/// 환경에 따라 동작하지 않을 수 있어(번들 ID 없음·권한 거부·등록 실패) **두 경로**를 둔다:
///  1순위 UserNotifications(클릭 시 PR 열기 가능) → 안 되면 osascript `display notification`(표시만).
/// 어느 경로를 쓸지는 `useUN`으로 런타임에 자동 판단하고, 호출부는 `notifyNewReviews`만 부른다.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    /// 번들 ID가 없으면(예: `swift run`) UNUserNotificationCenter.current()가 못 쓰이므로 처음부터 osascript.
    private var useUN = Bundle.main.bundleIdentifier != nil

    /// 앱 시작 시 1회. 권한을 요청하고, 거부/실패면 osascript 경로로 전환한다(에러 아님).
    func requestAuthorization() async {
        guard useUN else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            if !granted { useUN = false }
        } catch {
            useUN = false
        }
    }

    /// 새로 들어온 "리뷰할·미승인" PR들을 알림으로 표시. 1건이면 그 PR로, 여러 건이면 묶음으로.
    func notifyNewReviews(_ prs: [PullRequest]) {
        guard !prs.isEmpty else { return }

        let title: String
        let body: String
        let urlString: String
        if prs.count == 1 {
            let pr = prs[0]
            title = "새 리뷰 요청"
            body = "\(pr.title) · \(pr.repoName) #\(pr.number) · @\(pr.author?.login ?? "?")"
            urlString = pr.url
        } else {
            title = "새 리뷰 요청 \(prs.count)건"
            body = "\(prs[0].title) 외 \(prs.count - 1)건"
            urlString = Config.webSearchURL(Config.reviewBase).absoluteString
        }

        if useUN {
            sendViaUN(title: title, body: body, urlString: urlString,
                      identifier: prs.count == 1 ? prs[0].id : "review-batch-\(prs[0].id)")
        } else {
            sendViaOsascript(title: title, body: body)
        }
    }

    // MARK: - UserNotifications 경로

    private func sendViaUN(title: String, body: String, urlString: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": urlString]
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// 앱이 떠 있는 동안에도 배너를 표시(LSUIElement라 항상 백그라운드지만 명시).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// 알림 클릭 → userInfo의 URL을 기본 브라우저로 연다.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: urlString) {
            Task { @MainActor in NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }

    // MARK: - osascript fallback (표시만, 클릭 액션 없음)

    private func sendViaOsascript(title: String, body: String) {
        let script = "display notification \"\(Self.escape(body))\" with title \"\(Self.escape(title))\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
    }

    /// AppleScript 문자열 리터럴 이스케이프(역슬래시 먼저, 그다음 따옴표).
    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
