import SwiftUI
import AppKit

/// `--screenshot` 모드에서만 동작한다: mock 데이터로 팝오버 콘텐츠(`ContentView`)를 일반 윈도우에 띄우고,
/// 그 윈도우 번호를 stdout으로 출력한다. `screenshot.sh`가 이 번호로 `screencapture -l` 해서 PNG로 저장한다.
/// (App body의 `MenuBarExtra`는 `SceneBuilder`가 if/else를 못 받아 분기할 수 없어, 별도 윈도우는 여기서 만든다.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var backgroundWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard CommandLine.arguments.contains("--screenshot") else { return }

        // behindWindow 글래스는 윈도우 "뒤"를 블러하므로, 배경이 비면 글래스가 밋밋해진다(캡처마다 달라짐).
        // 화면을 덮는 그라데이션 배경을 깔아 글래스가 항상 동일하고 풍부하게 나오게 한다.
        // (screencapture는 mock 윈도우만 찍으므로 이 배경 자체는 결과에 안 들어가고 글래스 블러로만 반영된다.)
        if let screen = NSScreen.main {
            let bg = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            bg.isOpaque = true
            let view = NSView(frame: screen.frame)
            view.wantsLayer = true
            let gradient = CAGradientLayer()
            gradient.frame = screen.frame
            gradient.colors = [NSColor(srgbRed: 0.30, green: 0.40, blue: 0.82, alpha: 1).cgColor,
                               NSColor(srgbRed: 0.58, green: 0.38, blue: 0.80, alpha: 1).cgColor]
            gradient.startPoint = CGPoint(x: 0, y: 1)
            gradient.endPoint = CGPoint(x: 1, y: 0)
            view.layer?.addSublayer(gradient)
            bg.contentView = view
            bg.orderFrontRegardless()
            backgroundWindow = bg
        }

        let model = AppModel()
        model.isScreenshotMode = true
        MockData.install(into: model)

        let host = NSHostingController(rootView: ContentView(model: model).frame(width: 400))
        host.sizingOptions = [.preferredContentSize]   // 윈도우가 콘텐츠 높이에 맞춰짐

        let window = ScreenshotWindow(contentViewController: host)
        // 메뉴바 팝오버처럼: 타이틀바·신호등 없는 borderless + 실제 팝오버 수준 모서리(~11pt).
        window.styleMask = [.borderless, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 11
            contentView.layer?.masksToBounds = true
            // 배경색은 칠하지 않는다 — ContentView의 PopoverBackdrop(글래스)가 배경을 담당.
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        print("WINDOW_ID=\(window.windowNumber)")
        fflush(stdout)
    }
}

/// borderless 윈도우는 기본적으로 key가 될 수 없어 내부 컨트롤이 비활성(흐림) 외형으로 렌더된다.
/// 스크린샷에선 버튼이 활성 상태로 보여야 하므로 key/main이 될 수 있게 한다.
final class ScreenshotWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
