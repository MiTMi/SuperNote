import AppKit
import SwiftData
import SwiftUI

@MainActor
final class PanelController {
    private let panel: NotePanel
    private var globalMonitor: Any?
    private weak var anchorButton: NSStatusBarButton?

    private static let panelSize = NSSize(width: 520, height: 420)

    init() {
        let frame = NSRect(origin: .zero, size: Self.panelSize)
        self.panel = NotePanel(contentRect: frame)

        let host = NSHostingView(
            rootView: RootView()
                .modelContainer(AppContainer.shared)
        )
        host.frame = frame
        host.autoresizingMask = [.width, .height]
        host.wantsLayer = true
        host.layer?.cornerRadius = 12
        host.layer?.masksToBounds = true
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible {
            hide()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        anchorButton = button
        positionPanel(under: button)
        panel.orderFront(nil)
        panel.makeKey()
        installDismissMonitors()
    }

    func hide() {
        removeDismissMonitors()
        panel.orderOut(nil)
    }

    private func positionPanel(under button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonRectOnScreen = buttonWindow.convertToScreen(button.frame)
        let size = panel.frame.size
        let originX = buttonRectOnScreen.midX - size.width / 2
        let originY = buttonRectOnScreen.minY - size.height - 6
        var frame = NSRect(x: originX, y: originY, width: size.width, height: size.height)

        if let screen = NSScreen.screens.first(where: { $0.frame.contains(buttonRectOnScreen) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
            frame.origin.y = max(frame.origin.y, visible.minY + 8)
        }

        panel.setFrame(frame, display: false)
    }

    private func installDismissMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    private func removeDismissMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
    }
}
