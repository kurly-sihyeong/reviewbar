import SwiftUI

@main
struct ReviewBarApp: App {
    // 스크린샷 모드(`--screenshot`)에서 별도 윈도우를 띄우는 처리는 AppDelegate가 담당한다.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let isScreenshot = CommandLine.arguments.contains("--screenshot")
        let model = AppModel()
        if isScreenshot {
            model.isScreenshotMode = true   // 폴링·네트워크 차단, mock 유지
            MockData.install(into: model)
        } else {
            // 팝오버를 한 번도 열지 않아도 백그라운드 폴링·알림이 돌도록 앱 시작 시 가동한다.
            // (ContentView의 .task는 팝오버를 처음 열 때만 실행돼 알림 목적엔 부적합. start는 멱등.)
            model.start()
        }
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            // 메뉴바: GitHub 마크(template) + 미승인 배지 숫자. PNG 로드 실패 시 SF Symbol 폴백.
            if let icon = MenuBarIcon.github {
                Image(nsImage: icon)
            } else {
                Image(systemName: "arrow.triangle.branch")
            }
            Text("\(model.badgeCount)")
        }
        // 핵심: .window 스타일이라야 NSMenu가 아닌 팝오버에 임의 SwiftUI 뷰를 띄우고,
        // 백그라운드 갱신 중에도 닫히지 않는다.
        .menuBarExtraStyle(.window)
    }
}
