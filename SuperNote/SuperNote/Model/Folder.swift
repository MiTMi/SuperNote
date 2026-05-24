import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = "Untitled Folder"
    var createdAt: Date = Date.now

    var parent: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var children: [Folder]?

    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    var notes: [Note]?

    init(name: String = "Untitled Folder", parent: Folder? = nil) {
        self.name = name
        self.parent = parent
    }

    var sortedChildren: [Folder] {
        (children ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var optionalSortedChildren: [Folder]? {
        let sorted = sortedChildren
        return sorted.isEmpty ? nil : sorted
    }
}
