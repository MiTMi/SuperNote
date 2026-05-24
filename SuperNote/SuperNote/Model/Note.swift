import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var body: String = ""
    var backgroundColorHex: String = "#FFDD00"
    var isPinned: Bool = false
    var isTrashed: Bool = false
    var trashedAt: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var folder: Folder?

    init(
        id: UUID = UUID(),
        body: String = "",
        backgroundColorHex: String = "#FFDD00",
        isPinned: Bool = false,
        isTrashed: Bool = false,
        trashedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        folder: Folder? = nil
    ) {
        self.id = id
        self.body = body
        self.backgroundColorHex = backgroundColorHex
        self.isPinned = isPinned
        self.isTrashed = isTrashed
        self.trashedAt = trashedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.folder = folder
    }

    var displayTitle: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New Note" }
        let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        let stripped = firstLine
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? "New Note" : stripped
    }
}
