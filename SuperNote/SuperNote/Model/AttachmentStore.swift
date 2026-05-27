import AppKit
import Foundation
import SwiftData
import os

/// Stores pasted images as `Attachment` SwiftData entities. The blob data is
/// kept in external storage so CloudKit can sync it via CKAssets.
@MainActor
enum AttachmentService {
    private static let log = Logger(subsystem: "com.michaeltouboul.SuperNote", category: "AttachmentService")

    static func save(image: NSImage, preferredExtension: String?, in context: ModelContext) -> Attachment? {
        let ext = (preferredExtension ?? "png").lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let normalized = ext.isEmpty ? "png" : ext
        guard let data = encode(image: image, ext: normalized) else {
            log.error("Failed to encode pasted image")
            return nil
        }
        let attachment = Attachment(ext: normalized, data: data)
        context.insert(attachment)
        do {
            try context.save()
            return attachment
        } catch {
            log.error("Failed to save attachment: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func attachment(forReference ref: String, in context: ModelContext) -> Attachment? {
        guard let id = Attachment.parseID(from: ref) else { return nil }
        var fd = FetchDescriptor<Attachment>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }

    static func image(forReference ref: String, in context: ModelContext) -> NSImage? {
        guard let att = attachment(forReference: ref, in: context) else { return nil }
        return NSImage(data: att.data)
    }

    private static func encode(image: NSImage, ext: String) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        switch ext {
        case "jpg", "jpeg":
            return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
        case "gif":
            return rep.representation(using: .gif, properties: [:])
        default:
            return rep.representation(using: .png, properties: [:])
        }
    }
}
