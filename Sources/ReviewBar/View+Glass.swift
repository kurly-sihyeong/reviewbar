import SwiftUI

extension View {
    /// 카드/패널에 Liquid Glass(`glassEffect`)를 적용한다. `GlassEffectContainer` 안에서 쓰면
    /// 인접한 글래스 요소들이 자연스럽게 합성된다. (버튼은 별도로 `.buttonStyle(.glass)` 사용)
    /// - Parameter emphasized: 스크린샷(불투명 배경)에선 `.clear` 글래스만으론 카드가 배경과
    ///   구분되지 않아, 그림자로 패널을 띄운다. 실제 앱(글래스 백드롭)에선 `false`라 그대로 둔다.
    func cardGlass(cornerRadius: CGFloat, emphasized: Bool = false) -> some View {
        self
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(emphasized ? 0.12 : 0),
                    radius: emphasized ? 6 : 0, y: emphasized ? 2 : 0)
    }
}
