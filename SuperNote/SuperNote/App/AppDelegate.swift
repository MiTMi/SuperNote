import AppKit

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
}
