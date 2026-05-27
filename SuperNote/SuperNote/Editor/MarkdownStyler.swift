import AppKit

enum MarkdownStyler {
    static let bodyFont = NSFont.systemFont(ofSize: 14)
    static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let hiddenFont = NSFont.systemFont(ofSize: 0.01)

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

        resetAttributes(in: storage, range: paragraphRange)

        applyHeadings(storage: storage, in: paragraphRange)
        applyInline(pattern: #"\*\*([^*\n]+)\*\*"#, weightBold: true, markerLength: 2, storage: storage, range: paragraphRange)
        applyInline(pattern: #"(?<!\*)\*(?!\*)([^*\n]+?)(?<!\*)\*(?!\*)"#, italic: true, markerLength: 1, storage: storage, range: paragraphRange)
        applyInline(pattern: "`([^`\n]+)`", mono: true, markerLength: 1, storage: storage, range: paragraphRange)
        applyLinks(storage: storage, in: paragraphRange)
        applyListAndQuote(storage: storage, in: paragraphRange)
    }

    private static func applyHeadings(storage: NSTextStorage, in range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: #"^(#{1,3}\s+)(.*)$"#, options: [.anchorsMatchLines]) else { return }
        regex.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let prefixRange = match.range(at: 1)
            guard prefixRange.location != NSNotFound else { return }
            let prefixString = (storage.string as NSString).substring(with: prefixRange)
            let level = prefixString.prefix(while: { $0 == "#" }).count
            guard let font = headingFonts[level] else { return }
            storage.addAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: match.range)
            hide(storage: storage, range: prefixRange)
        }
    }

    private static func applyInline(
        pattern: String,
        weightBold: Bool = false,
        italic: Bool = false,
        mono: Bool = false,
        markerLength: Int = 0,
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
            if markerLength > 0, fullRange.length >= markerLength * 2 {
                let leading = NSRange(location: fullRange.location, length: markerLength)
                let trailing = NSRange(
                    location: fullRange.location + fullRange.length - markerLength,
                    length: markerLength
                )
                hide(storage: storage, range: leading)
                hide(storage: storage, range: trailing)
            }
        }
    }

    private static func applyLinks(storage: NSTextStorage, in range: NSRange) {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#, options: []) else { return }
        regex.enumerateMatches(in: storage.string, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let fullRange = match.range
            let textRange = match.range(at: 1)
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: textRange)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            let openBracket = NSRange(location: fullRange.location, length: 1)
            let closeStart = textRange.location + textRange.length
            let trailingLength = fullRange.location + fullRange.length - closeStart
            if trailingLength > 0 {
                let trailing = NSRange(location: closeStart, length: trailingLength)
                hide(storage: storage, range: trailing)
            }
            hide(storage: storage, range: openBracket)
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

    private static func hide(storage: NSTextStorage, range: NSRange) {
        storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
        storage.addAttribute(.font, value: hiddenFont, range: range)
    }

    /// Resets attributes to `bodyAttributes` while preserving `NSTextAttachment`
    /// runs — `setAttributes` would otherwise wipe out inline images.
    private static func resetAttributes(in storage: NSTextStorage, range: NSRange) {
        storage.enumerateAttribute(.attachment, in: range, options: []) { value, subrange, _ in
            if value == nil {
                storage.setAttributes(bodyAttributes, range: subrange)
            }
        }
    }
}
