import Foundation

struct PaletteColor: Identifiable, Hashable {
    let name: String
    let hex: String

    var id: String { hex.uppercased() }
}

enum Palette {
    static let all: [PaletteColor] = [
        PaletteColor(name: "Bright Gold", hex: "#FFDD00"),
        PaletteColor(name: "",            hex: "#FFD8A8"),
        PaletteColor(name: "",            hex: "#FFB8B8"),
        PaletteColor(name: "",            hex: "#E0C8FF"),
        PaletteColor(name: "",            hex: "#B8D8FF"),
        PaletteColor(name: "",            hex: "#B8F0E0"),
        PaletteColor(name: "",            hex: "#D8F0B8"),
        PaletteColor(name: "Icy Blue",     hex: "#A2D6F9"),
        PaletteColor(name: "Dodger Blue",  hex: "#1E96FC"),
        PaletteColor(name: "Yellow Green", hex: "#AACC00"),
        PaletteColor(name: "Strong Cyan",  hex: "#02CECB"),
        PaletteColor(name: "Emerald Green", hex: "#59CD90"),
        PaletteColor(name: "Orange Glow",  hex: "#FFA630"),
        PaletteColor(name: "Sky Blue",     hex: "#3FA7D6"),
        PaletteColor(name: "",            hex: "#FFFFFF"),
        PaletteColor(name: "",            hex: "#2A2A2A")
    ]

    static func name(forHex hex: String) -> String? {
        let upper = hex.uppercased()
        return all.first(where: { $0.hex.uppercased() == upper })?.name.nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
