import AppKit

/// 메뉴바 아이콘: GitHub 마크(번들 PNG)를 template image로 로드한다.
/// `isTemplate = true` 라 알파(투명도) 기준으로 다크/라이트 메뉴바 색에 맞춰 자동 틴트된다.
/// (SwiftBar 플러그인이 쓰던 github-mark.png와 동일한 마크)
enum MenuBarIcon {
    static let github: NSImage? = {
        guard let url = Bundle.module.url(forResource: "github-mark", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.isTemplate = true                     // 알파 기준 자동 틴트(메뉴바 색 적응)
        img.size = NSSize(width: 18, height: 18)   // 메뉴바 표준 크기
        return img
    }()
}
