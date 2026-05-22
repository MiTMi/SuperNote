import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var backgroundHex: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private var appearanceForBackground: NSAppearance? {
        let bg = NSColor(hex: backgroundHex) ?? .windowBackgroundColor
        return NSAppearance(named: bg.isPerceptuallyLight ? .aqua : .darkAqua)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        scrollView.appearance = appearanceForBackground
        textView.appearance = appearanceForBackground
        textView.delegate = context.coordinator
        textView.isRichText = false
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

        textView.string = text
        if let storage = textView.textStorage {
            MarkdownStyler.apply(to: storage, editedRange: NSRange(location: 0, length: storage.length))
        }

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let newAppearance = appearanceForBackground
        if textView.appearance !== newAppearance {
            nsView.appearance = newAppearance
            textView.appearance = newAppearance
        }
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            if let storage = textView.textStorage {
                MarkdownStyler.apply(to: storage, editedRange: NSRange(location: 0, length: storage.length))
            }
            textView.selectedRanges = selected
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        private var isApplyingStyles = false

        init(text: Binding<String>) {
            self._text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            guard !isApplyingStyles else { return }
            isApplyingStyles = true
            MarkdownStyler.apply(to: textStorage, editedRange: editedRange)
            isApplyingStyles = false
            textView?.typingAttributes = MarkdownStyler.bodyAttributes
        }
    }
}
