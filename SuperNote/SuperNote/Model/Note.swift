import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var body: String = ""
    var backgroundColorHex: String = "#FFDD00"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        body: String = "",
        backgroundColorHex: String = "#FFDD00",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.body = body
        self.backgroundColorHex = backgroundColorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
