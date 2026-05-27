import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID = UUID()
    var ext: String = "png"
    @Attribute(.externalStorage) var data: Data = Data()
    var createdAt: Date = Date.now

    init(id: UUID = UUID(), ext: String = "png", data: Data = Data(), createdAt: Date = .now) {
        self.id = id
        self.ext = ext
        self.data = data
        self.createdAt = createdAt
    }

    var reference: String { "\(Attachment.scheme)\(id.uuidString).\(ext)" }

    static let scheme = "attachment://"

    /// Extracts the attachment UUID from an `attachment://<uuid>.<ext>` reference.
    static func parseID(from reference: String) -> UUID? {
        guard reference.hasPrefix(scheme) else { return nil }
        let tail = String(reference.dropFirst(scheme.count))
        let stem = (tail as NSString).deletingPathExtension
        return UUID(uuidString: stem)
    }
}
