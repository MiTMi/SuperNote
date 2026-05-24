import AppKit
import Foundation

@MainActor
final class EditorFormatController {
    weak var textView: NSTextView?

    // MARK: Inline

    func toggleBold() { toggleInlineWrap(marker: "**") }
    func toggleItalic() { toggleInlineWrap(marker: "*") }
    func toggleCode() { toggleInlineWrap(marker: "`") }

    private func toggleInlineWrap(marker: String) {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        var range = tv.selectedRange()
        guard range.location != NSNotFound, range.location + range.length <= nsText.length else { return }

        if range.length == 0 {
            let wordRange = tv.selectionRange(forProposedRange: range, granularity: .selectByWord)
            if wordRange.length > 0,
               wordRange.location + wordRange.length <= nsText.length {
                let candidate = nsText.substring(with: wordRange)
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    range = wordRange
                }
            }
        }

        let markerLen = (marker as NSString).length
        let isItalic = marker == "*"
        let selected = nsText.substring(with: range)
        let nsSelected = selected as NSString

        if nsSelected.length >= markerLen * 2,
           selected.hasPrefix(marker),
           selected.hasSuffix(marker),
           !(isItalic && (nsSelected.hasPrefix("**") || nsSelected.hasSuffix("**"))) {
            let inner = nsSelected.substring(
                with: NSRange(location: markerLen, length: nsSelected.length - markerLen * 2)
            )
            replaceText(
                in: range,
                with: inner,
                newSelection: NSRange(location: range.location, length: (inner as NSString).length)
            )
            return
        }

        let outerStart = range.location - markerLen
        let suffixStart = range.location + range.length
        if outerStart >= 0, suffixStart + markerLen <= nsText.length {
            let prefix = nsText.substring(with: NSRange(location: outerStart, length: markerLen))
            let suffix = nsText.substring(with: NSRange(location: suffixStart, length: markerLen))
            if prefix == marker, suffix == marker {
                let leadingIsPartOfBold = isItalic
                    && outerStart > 0
                    && nsText.substring(with: NSRange(location: outerStart - 1, length: 1)) == "*"
                let trailingIsPartOfBold = isItalic
                    && suffixStart + markerLen < nsText.length
                    && nsText.substring(with: NSRange(location: suffixStart + markerLen, length: 1)) == "*"
                if !leadingIsPartOfBold, !trailingIsPartOfBold {
                    let fullRange = NSRange(location: outerStart, length: markerLen * 2 + range.length)
                    replaceText(
                        in: fullRange,
                        with: selected,
                        newSelection: NSRange(location: outerStart, length: range.length)
                    )
                    return
                }
            }
        }

        let wrapped = marker + selected + marker
        let newLocation = range.location + markerLen
        let newSelection = NSRange(location: newLocation, length: range.length)
        replaceText(in: range, with: wrapped, newSelection: newSelection)
    }

    // MARK: Line-level

    func setHeading(level: Int) {
        applyLineTransform { line in
            var stripped = line
            if stripped.hasPrefix("### ") { stripped.removeFirst(4) }
            else if stripped.hasPrefix("## ") { stripped.removeFirst(3) }
            else if stripped.hasPrefix("# ") { stripped.removeFirst(2) }

            guard level >= 1, level <= 3 else { return stripped }
            return String(repeating: "#", count: level) + " " + stripped
        }
    }

    func toggleBullet() {
        applyLineTransform { line in
            if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
            if line.isEmpty { return "- " }
            return "- " + line
        }
    }

    func toggleQuote() {
        applyLineTransform { line in
            if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
            if line.isEmpty { return "> " }
            return "> " + line
        }
    }

    private func applyLineTransform(_ transform: (String) -> String) {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        let selRange = tv.selectedRange()
        guard selRange.location != NSNotFound else { return }

        let lineRange = nsText.lineRange(for: selRange)
        let original = nsText.substring(with: lineRange)
        let endsWithNewline = original.hasSuffix("\n")
        let trimmed = endsWithNewline ? String(original.dropLast()) : original
        let lines = trimmed.components(separatedBy: "\n")
        let transformed = lines.map(transform).joined(separator: "\n")
        let final = endsWithNewline ? transformed + "\n" : transformed

        let newSelection = NSRange(location: lineRange.location, length: (final as NSString).length - (endsWithNewline ? 1 : 0))
        replaceText(in: lineRange, with: final, newSelection: newSelection)
    }

    // MARK: Link

    func insertLink() {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        let range = tv.selectedRange()
        guard range.location != NSNotFound else { return }
        let selected = nsText.substring(with: range)

        if selected.isEmpty {
            let insertion = "[](url)"
            let caret = NSRange(location: range.location + 1, length: 0)
            replaceText(in: range, with: insertion, newSelection: caret)
        } else {
            let insertion = "[\(selected)](url)"
            let urlStart = range.location + (selected as NSString).length + 3
            let urlRange = NSRange(location: urlStart, length: 3)
            replaceText(in: range, with: insertion, newSelection: urlRange)
        }
    }

    // MARK: Helpers

    private func replaceText(in range: NSRange, with text: String, newSelection: NSRange) {
        guard let tv = textView else { return }
        if tv.shouldChangeText(in: range, replacementString: text) {
            tv.replaceCharacters(in: range, with: text)
            tv.didChangeText()
            tv.selectedRange = newSelection
            tv.window?.makeFirstResponder(tv)
        }
    }
}
