import Foundation
import SwiftData
import os

enum AppContainer {
    private static let log = Logger(subsystem: "com.michaeltouboul.SuperNote", category: "AppContainer")

    // Flip to `true` after enabling the iCloud capability in Xcode
    // (Target → Signing & Capabilities → + Capability → iCloud → CloudKit →
    //  add container "iCloud.com.michaeltouboul.SuperNote").
    private static let useCloudKit = false

    static let shared: ModelContainer = {
        let schema = Schema([Note.self])

        let primaryConfig: ModelConfiguration
        if useCloudKit {
            primaryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.michaeltouboul.SuperNote")
            )
        } else {
            primaryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        do {
            return try ModelContainer(for: schema, configurations: [primaryConfig])
        } catch {
            log.error("Persistent store failed (\(error.localizedDescription, privacy: .public)); falling back to in-memory.")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Unable to create in-memory ModelContainer: \(error)")
            }
        }
    }()
}
