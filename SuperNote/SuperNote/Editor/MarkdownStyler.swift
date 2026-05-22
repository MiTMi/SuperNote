import AppKit

enum MarkdownStyler {
    static let bodyFont = NSFont.systemFont(ofSize: 14)
    static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    private static let headingFonts: [Int: NSFont] = [
        1: .systemFont(ofSize: 24, weight: .bold),
        2: .systemFont(ofSize: 20, weight: .semibold),
        3: .systemFont(ofSize: 17, weight: .semibold)
    ]

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor
        ]
    }

    static func apply(to storage: NSTextStorage, editedRange: NSRange) {
        let nsString = storage.string as NSString
        let safeRange = NSRange(location: 0, length: nsString.length)
        let clamped = NSIntersectionRange(editedRange, safeRange)
        let paragraphRange = nsString.paragraphRange(for: clamped)
        guard paragraphRange.length >= 0 else { return }

        storage.setAttributes(bodyAttributes, range: paragraphRange)

        applyHeadings(storage: storage, in: paragraphRange)
        applyInline(pattern: #"\*\*([^*\n]+)\*\*"#, weightBold: true, storage: storage, range: paragraphRange)
        applyInline(pattern: #"(?<!\*)\*(?!\*)([^*\n]+?)(?<!\*)\*(?!\*)"#, italic: true, storage: storage, range: paragraphRange)
        applyInline(pattern: "`([^`\n]+)`", mono: true, storage: storage, range: paragraphRange)
        applyLinks(storage: storage, in: paragraphRange)
        applyListAndQuote(storage: storage, in: paragraphRange)
    }

    private static func applyHeadings(storage: NSTextStorage, in range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: #"^(#{1,3})\s+.*$"#, options: [.anchorsMatchLines]) else { return }
        regex.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2 else { return }
            let hashesRange = match.range(at: 1)
            guard hashesRange.location != NSNotFound,
                  let hashesNSRange = Range(hashesRange, in: storage.string) else { return }
            let level = storage.string[hashesNSRange].count
            guard let font = headingFonts[level] else { return }
            storage.addAttributes([.font: font], range: match.range)
            storage.addAttributes([.foregroundColor: NSColor.labelColor], range: match.range)
            let hashesAttrRange = match.range(at: 1)
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: hashesAttrRange)
        }
    }

    private static func applyInline(
        pattern: String,
        weightBold: Bool = false,
        italic: Bool = false,
        mono: Bool = false,
        storage: NSTextStorage,
        range: NSRange
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        regex.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
            guard let match else { return }
            let fullRange = match.range
            let existingFont = storage.attribute(.font, at: fullRange.location, effectiveRange: nil) as? NSFont ?? bodyFont
            var descriptor = existingFont.fontDescriptor
            var traits = descriptor.symbolicTraits
            if weightBold { traits.insert(.bold) }
            if italic { traits.insert(.italic) }
            descriptor = descriptor.withSymbolicTraits(traits)
            var font = NSFont(descriptor: descriptor, size: existingFont.pointSize) ?? existingFont
            if mono { font = monoFont }
            storage.addAttribute(.font, value: font, range: fullRange)
            if mono {
                storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: fullRange)
            }
        }
    }

    private static func applyLinks(storage: NSTextStorage, in range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#, options: []) else { return }
        regex.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: match.range)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
        }
    }

    private static func applyListAndQuote(storage: NSTextStorage, in range: NSRange) {
        if let bullet = try? NSRegularExpression(pattern: #"^\s*[-*+]\s"#, options: [.anchorsMatchLines]) {
            bullet.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
                guard let match else { return }
                storage.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: match.range)
            }
        }
        if let quote = try? NSRegularExpression(pattern: #"^>\s.*$"#, options: [.anchorsMatchLines]) {
            quote.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
                guard let match else { return }
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: match.range)
                let italicDescriptor = bodyFont.fontDescriptor.withSymbolicTraits(.italic)
                let italicFont = NSFont(descriptor: italicDescriptor, size: bodyFont.pointSize) ?? bodyFont
                storage.addAttribute(.font, value: italicFont, range: match.range)
            }
        }
    }
}
