import SwiftUI

struct FormattingToolbar: View {
    let controller: EditorFormatController

    var body: some View {
        HStack(spacing: 2) {
            iconButton("bold", help: "Bold (⌘B)") { controller.toggleBold() }
                .keyboardShortcut("b", modifiers: .command)
            iconButton("italic", help: "Italic (⌘I)") { controller.toggleItalic() }
                .keyboardShortcut("i", modifiers: .command)

            separator

            headingMenu

            separator

            iconButton("list.bullet", help: "Bullet list") { controller.toggleBullet() }
            iconButton("text.quote", help: "Quote") { controller.toggleQuote() }
            iconButton("chevron.left.forwardslash.chevron.right", help: "Inline code (⌘E)") {
                controller.toggleCode()
            }
            .keyboardShortcut("e", modifiers: .command)
            iconButton("link", help: "Link (⌘K)") { controller.insertLink() }
                .keyboardShortcut("k", modifiers: .command)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 14)
            .padding(.horizontal, 4)
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { controller.setHeading(level: 1) }
            Button("Heading 2") { controller.setHeading(level: 2) }
            Button("Heading 3") { controller.setHeading(level: 3) }
            Divider()
            Button("Plain Text") { controller.setHeading(level: 0) }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 22)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Heading")
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
