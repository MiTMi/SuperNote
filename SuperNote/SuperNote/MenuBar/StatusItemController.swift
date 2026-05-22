import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onLeftClick: (NSStatusBarButton) -> Void
    private let onQuit: () -> Void
    private let contextMenu: NSMenu

    var button: NSStatusBarButton? { statusItem.button }

    init(
        onLeftClick: @escaping (NSStatusBarButton) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onLeftClick = onLeftClick
        self.onQuit = onQuit
        self.contextMenu = NSMenu()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "note.text",
                accessibilityDescription: "SuperNote"
            )
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let quitItem = NSMenuItem(
            title: "Quit SuperNote",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            onLeftClick(sender)
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem.menu = contextMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            onLeftClick(sender)
        }
    }

    @objc private func handleQuit() {
        onQuit()
    }
}
