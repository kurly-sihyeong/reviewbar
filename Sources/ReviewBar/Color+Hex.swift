import SwiftUI

extension Color {
    /// GitHub 라벨 색("ededed" 또는 "#ededed") → Color. 파싱 실패 시 회색.
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else {
            self = .gray
            return
        }
        self.init(
            red: Double((v >> 16) & 0xff) / 255,
            green: Double((v >> 8) & 0xff) / 255,
            blue: Double(v & 0xff) / 255
        )
    }
}
