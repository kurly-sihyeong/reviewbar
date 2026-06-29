import SwiftUI
import AppKit

/// SwiftUI 뷰가 올라간 NSWindow에 접근하기 위한 헬퍼.
/// MenuBarExtra(.window) 팝오버 윈도우를 잡아 "열 때 새로고침" 관찰(attachWindow)을 등록하는 데 쓴다.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            configure(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            configure(window)
        }
    }
}
