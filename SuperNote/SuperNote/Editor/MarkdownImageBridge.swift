import AppKit
import SwiftData

/// Converts between the markdown source stored in `Note.body` and the
/// attributed string shown in the editor. Images written as
/// `![alt](attachment://uuid.ext)` are swapped for `ImageTextAttachment`s
/// on the way in, and reconstituted back to markdown on the way out.
enum MarkdownImageBridge {
    /// Matches `![alt](attachment://filename.ext)`.
    private static let imageRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"!\[([^\]\n]*)\]\((attachment://[^)\s]+)\)"#,
            options: []
        )
    }()

    @MainActor
    static func attributedString(from markdown: String, context: ModelContext?) -> NSAttributedString {
        let result = NSMutableAttributedString()
        guard let regex = imageRegex else {
            result.append(NSAttributedString(string: markdown, attributes: MarkdownStyler.bodyAttributes))
            return result
        }

        let ns = markdown as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var cursor = 0

        regex.enumerateMatches(in: markdown, options: [], range: fullRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let range = match.range
            if range.location > cursor {
                let plain = ns.substring(with: NSRange(location: cursor, length: range.location - cursor))
                result.append(NSAttributedString(string: plain, attributes: MarkdownStyler.bodyAttributes))
            }

            let alt = ns.substring(with: match.range(at: 1))
            let reference = ns.substring(with: match.range(at: 2))

            if let context, let image = AttachmentService.image(forReference: reference, in: context) {
                let attachment = ImageTextAttachment(reference: reference, alt: alt, image: image)
                result.append(NSAttributedString(attachment: attachment))
            } else {
                // Attachment missing — keep the markdown so the user can see/repair it.
                let original = ns.substring(with: range)
                result.append(NSAttributedString(string: original, attributes: MarkdownStyler.bodyAttributes))
            }
            cursor = range.location + range.length
        }

        if cursor < ns.length {
            let tail = ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
            result.append(NSAttributedString(string: tail, attributes: MarkdownStyler.bodyAttributes))
        }

        return result
    }

    static func markdown(from attributed: NSAttributedString) -> String {
        let ns = attributed.string as NSString
        var output = ""
        output.reserveCapacity(ns.length)

        var index = 0
        let length = ns.length
        while index < length {
            var effective = NSRange()
            let attachment = attributed.attribute(.attachment, at: index, effectiveRange: &effective) as? ImageTextAttachment
            if let attachment {
                output.append("![\(attachment.alt)](\(attachment.reference))")
                index = effective.location + effective.length
            } else {
                output.append(ns.substring(with: NSRange(location: index, length: 1)))
                index += 1
            }
        }
        return output
    }
}
