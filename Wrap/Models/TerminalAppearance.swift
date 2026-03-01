import SwiftUI

@Observable
final class TerminalAppearance {
    static let shared = TerminalAppearance()

    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "terminal.fontSize") }
    }
    var backgroundColorHex: String {
        didSet { UserDefaults.standard.set(backgroundColorHex, forKey: "terminal.bgColor") }
    }
    var foregroundColorHex: String {
        didSet { UserDefaults.standard.set(foregroundColorHex, forKey: "terminal.fgColor") }
    }

    init() {
        let size = UserDefaults.standard.double(forKey: "terminal.fontSize")
        fontSize = size > 0 ? size : 14
        backgroundColorHex = UserDefaults.standard.string(forKey: "terminal.bgColor") ?? "#000000"
        foregroundColorHex = UserDefaults.standard.string(forKey: "terminal.fgColor") ?? "#FFFFFF"
    }

    var backgroundColor: Color { Color(hex: backgroundColorHex) }
    var foregroundColor: Color { Color(hex: foregroundColorHex) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(r * 255), gi = Int(g * 255), bi = Int(b * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}
