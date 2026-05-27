import CloudKit
import CoreData
import Foundation
import Observation
import os

/// Observes CloudKit sync state for the SwiftData store.
/// SwiftData uses `NSPersistentCloudKitContainer` internally and forwards
/// `eventChangedNotification` with the standard event payload, which we
/// translate into a coarse-grained `State` for the UI.
@MainActor
@Observable
final class CloudSyncMonitor {
    enum State: Equatable {
        case disabled            // CloudKit isn't compiled into this build
        case unavailable(String) // iCloud account not signed in / restricted
        case syncing
        case idle                // last event finished cleanly
        case error(String)
    }

    private(set) var state: State
    private(set) var lastSyncDate: Date?

    private let containerID: String
    private let log = Logger(subsystem: "com.michaeltouboul.SuperNote", category: "CloudSync")
    private var eventObserver: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?

    init(enabled: Bool, containerID: String) {
        self.containerID = containerID
        self.state = enabled ? .idle : .disabled
        guard enabled else { return }
        startObservingEvents()
        startObservingAccountChanges()
        Task { await refreshAccountStatus() }
    }

    // No deinit: this monitor is owned by `RootView` via `@State` and lives
    // the full app lifetime, so manual observer removal is unnecessary and
    // would require crossing the MainActor boundary from a nonisolated context.

    // MARK: Observers

    private func startObservingEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleEvent(note: note) }
        }
    }

    private func startObservingAccountChanges() {
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAccountStatus()
            }
        }
    }

    private func handleEvent(note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        if event.endDate == nil {
            state = .syncing
        } else if let error = event.error {
            log.error("CloudKit \(String(describing: event.type), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            state = .error(error.localizedDescription)
        } else {
            lastSyncDate = event.endDate
            state = .idle
        }
    }

    // MARK: Account

    func refreshAccountStatus() async {
        let container = CKContainer(identifier: containerID)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                if case .unavailable = state { state = .idle }
            case .noAccount:
                state = .unavailable("Sign in to iCloud to enable sync")
            case .restricted:
                state = .unavailable("iCloud access is restricted")
            case .temporarilyUnavailable:
                state = .unavailable("iCloud temporarily unavailable")
            case .couldNotDetermine:
                state = .unavailable("Unable to reach iCloud")
            @unknown default:
                state = .unavailable("iCloud unavailable")
            }
        } catch {
            log.error("accountStatus failed: \(error.localizedDescription, privacy: .public)")
            state = .unavailable("Unable to reach iCloud")
        }
    }
}
