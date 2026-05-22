import AppKit
import SwiftUI

extension Color {
    init?(hex: String) {
        guard let nsColor = NSColor(hex: hex) else { return nil }
        self.init(nsColor: nsColor)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }

        guard trimmed.count == 6 || trimmed.count == 8,
              let value = UInt64(trimmed, radix: 16) else {
            return nil
        }

        let r, g, b, a: CGFloat
        if trimmed.count == 8 {
            a = CGFloat((value & 0xFF00_0000) >> 24) / 255
            r = CGFloat((value & 0x00FF_0000) >> 16) / 255
            g = CGFloat((value & 0x0000_FF00) >> 8)  / 255
            b = CGFloat( value & 0x0000_00FF)        / 255
        } else {
            a = 1
            r = CGFloat((value & 0xFF_0000) >> 16) / 255
            g = CGFloat((value & 0x00_FF00) >> 8)  / 255
            b = CGFloat( value & 0x00_00FF)        / 255
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        guard let srgb = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var isPerceptuallyLight: Bool {
        guard let srgb = usingColorSpace(.sRGB) else { return true }
        let luma = 0.2126 * srgb.redComponent
                 + 0.7152 * srgb.greenComponent
                 + 0.0722 * srgb.blueComponent
        return luma > 0.55
    }
}
