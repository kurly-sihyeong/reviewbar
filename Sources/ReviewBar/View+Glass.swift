import SwiftUI

extension View {
    /// 카드/패널에 Liquid Glass(`glassEffect`)를 적용한다. `GlassEffectContainer` 안에서 쓰면
    /// 인접한 글래스 요소들이 자연스럽게 합성된다. (버튼은 별도로 `.buttonStyle(.glass)` 사용)
    func cardGlass(cornerRadius: CGFloat) -> some View {
        self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
