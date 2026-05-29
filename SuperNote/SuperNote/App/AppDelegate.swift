import AppKit
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var panelController: PanelController?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelController = PanelController()
        self.panelController = panelController

        let statusItemController = StatusItemController(
            onLeftClick: { button in
                panelController.toggle(relativeTo: button)
            },
            onQuit: { NSApp.terminate(nil) }
        )
        self.statusItemController = statusItemController

        hotkeyManager = HotkeyManager { [weak self] in
            guard let button = self?.statusItemController?.button else { return }
            self?.panelController?.toggle(relativeTo: button)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - URL scheme (supernote://new?body=...&color=...&pin=...)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }

    /// Creates a note from a `supernote://new` URL. Inserting through the shared
    /// ModelContainer's main context means the note shows up in the UI and is
    /// mirrored to iCloud by the same CloudKit-backed store the app already uses.
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "supernote" else { return }

        // Accept supernote://new and supernote:///new (host vs first path segment).
        let isNew = url.host?.lowercased() == "new"
            || url.path.lowercased().hasPrefix("/new")
        guard isNew else { return }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        let body = value("body") ?? ""
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let note = Note(body: body)
        if let pin = value("pin"), pin == "1" || pin.lowercased() == "true" {
            note.isPinned = true
        }
        if let color = value("color"), !color.isEmpty {
            note.backgroundColorHex = color.hasPrefix("#") ? color : "#\(color)"
        }

        let context = AppContainer.shared.mainContext
        context.insert(note)
        try? context.save()
    }
}
