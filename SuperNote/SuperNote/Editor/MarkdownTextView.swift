import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var backgroundHex: String
    var formatController: EditorFormatController?
    var modelContext: ModelContext?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, modelContext: modelContext)
    }

    private var appearanceForBackground: NSAppearance? {
        let bg = NSColor(hex: backgroundHex) ?? .windowBackgroundColor
        return NSAppearance(named: bg.isPerceptuallyLight ? .aqua : .darkAqua)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PasteHandlingTextView(frame: .zero)
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        scrollView.appearance = appearanceForBackground
        textView.appearance = appearanceForBackground
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsImageEditing = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.font = MarkdownStyler.bodyFont
        textView.typingAttributes = MarkdownStyler.bodyAttributes
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textStorage?.delegate = context.coordinator
        textView.onPasteImage = { [weak textView] image, ext in
            guard let textView else { return false }
            return context.coordinator.insertPastedImage(image, preferredExtension: ext, in: textView)
        }

        context.coordinator.load(markdown: text, into: textView)

        context.coordinator.textView = textView
        formatController?.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if formatController?.textView !== textView {
            formatController?.textView = textView
        }
        context.coordinator.modelContext = modelContext
        let newAppearance = appearanceForBackground
        if textView.appearance !== newAppearance {
            nsView.appearance = newAppearance
            textView.appearance = newAppearance
        }
        let current = context.coordinator.currentMarkdown(from: textView)
        if current != text {
            let selected = textView.selectedRanges
            context.coordinator.load(markdown: text, into: textView)
            // Clamp the previous selection to the new storage length — the
            // replacement may have shortened the text and AppKit will crash
            // during layout/font-panel updates if `selectedRange` overshoots.
            let newLength = (textView.string as NSString).length
            let clamped = selected.map { value -> NSValue in
                let r = value.rangeValue
                let loc = min(r.location, newLength)
                let len = min(r.length, newLength - loc)
                return NSValue(range: NSRange(location: loc, length: len))
            }
            textView.selectedRanges = clamped.isEmpty
                ? [NSValue(range: NSRange(location: 0, length: 0))]
                : clamped
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        var modelContext: ModelContext?
        private var isApplyingStyles = false
        private var isLoading = false

        init(text: Binding<String>, modelContext: ModelContext?) {
            self._text = text
            self.modelContext = modelContext
        }

        func load(markdown: String, into textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            isLoading = true
            let attributed = MarkdownImageBridge.attributedString(from: markdown, context: modelContext)
            storage.beginEditing()
            storage.setAttributedString(attributed)
            storage.endEditing()
            MarkdownStyler.apply(to: storage, editedRange: NSRange(location: 0, length: storage.length))
            textView.typingAttributes = MarkdownStyler.bodyAttributes
            isLoading = false
        }

        func currentMarkdown(from textView: NSTextView) -> String {
            guard let storage = textView.textStorage else { return textView.string }
            return MarkdownImageBridge.markdown(from: storage)
        }

        @discardableResult
        func insertPastedImage(_ image: NSImage, preferredExtension ext: String?, in textView: NSTextView) -> Bool {
            guard let context = modelContext,
                  let attachment = AttachmentService.save(image: image, preferredExtension: ext, in: context) else {
                return false
            }
            let attachmentNode = ImageTextAttachment(reference: attachment.reference, alt: "", image: image)
            let attachmentString = NSMutableAttributedString(attachment: attachmentNode)
            // Surround with a newline so attachments sit on their own line — easier
            // to delete and avoids odd line metrics around tall images.
            let needsLeadingNewline = needsNewlineBefore(textView: textView)
            if needsLeadingNewline {
                attachmentString.insert(NSAttributedString(string: "\n", attributes: MarkdownStyler.bodyAttributes), at: 0)
            }
            attachmentString.append(NSAttributedString(string: "\n", attributes: MarkdownStyler.bodyAttributes))

            let range = textView.selectedRange()
            guard textView.shouldChangeText(in: range, replacementString: attachmentString.string) else {
                return false
            }
            textView.textStorage?.replaceCharacters(in: range, with: attachmentString)
            textView.didChangeText()
            let newLocation = range.location + attachmentString.length
            textView.selectedRange = NSRange(location: newLocation, length: 0)
            textView.typingAttributes = MarkdownStyler.bodyAttributes
            return true
        }

        private func needsNewlineBefore(textView: NSTextView) -> Bool {
            let location = textView.selectedRange().location
            guard location > 0, let storage = textView.textStorage else { return false }
            let prev = (storage.string as NSString).substring(with: NSRange(location: location - 1, length: 1))
            return prev != "\n"
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Safe to touch typingAttributes here: by the time textDidChange
            // fires, the text view has reconciled its selection with the new
            // storage. Doing this in `didProcessEditing` triggered an out-of-
            // bounds crash inside `updateFontPanel` -> `fallbackFontInfoForSelectedRange:`.
            textView.typingAttributes = MarkdownStyler.bodyAttributes
            text = currentMarkdown(from: textView)
        }

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            guard !isApplyingStyles, !isLoading else { return }
            isApplyingStyles = true
            MarkdownStyler.apply(to: textStorage, editedRange: editedRange)
            isApplyingStyles = false
        }
    }
}

/// NSTextView subclass that intercepts paste so pasted images are saved as
/// attachments instead of falling through to AppKit's default rich-text paste.
final class PasteHandlingTextView: NSTextView {
    /// Returns `true` if the paste was consumed.
    var onPasteImage: ((NSImage, String?) -> Bool)?

    override func paste(_ sender: Any?) {
        if handleImagePaste() { return }
        pasteAsPlainText(sender)
    }

    @discardableResult
    private func handleImagePaste() -> Bool {
        let pasteboard = NSPasteboard.general
        guard let handler = onPasteImage else { return false }

        // 1) File URLs that point to image files (Finder copy).
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let ext = imageExtension(forURL: url), let image = NSImage(contentsOf: url) {
                    if handler(image, ext) { return true }
                }
            }
        }

        // 2) Raw image data on the pasteboard (screenshots, browser copies).
        if let image = NSImage(pasteboard: pasteboard) {
            let ext = preferredExtension(from: pasteboard)
            if handler(image, ext) { return true }
        }

        return false
    }

    private func imageExtension(forURL url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        if let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
            return ext
        }
        return nil
    }

    private func preferredExtension(from pasteboard: NSPasteboard) -> String? {
        let types = pasteboard.types ?? []
        if types.contains(.png) { return "png" }
        if types.contains(.tiff) { return "png" }
        for type in types {
            if let utType = UTType(type.rawValue), utType.conforms(to: .image) {
                return utType.preferredFilenameExtension
            }
        }
        return nil
    }
}
