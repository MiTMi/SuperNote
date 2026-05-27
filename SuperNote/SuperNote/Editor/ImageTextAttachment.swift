import AppKit

final class ImageTextAttachment: NSTextAttachment {
    static let maxDisplayWidth: CGFloat = 480

    let reference: String
    let alt: String

    init(reference: String, alt: String, image: NSImage) {
        self.reference = reference
        self.alt = alt
        super.init(data: nil, ofType: nil)
        self.image = image
    }

    required init?(coder: NSCoder) {
        self.reference = ""
        self.alt = ""
        super.init(coder: coder)
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        let imageSize = image?.size ?? .zero
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: imageSize)
        }
        let containerWidth = textContainer?.size.width ?? lineFrag.width
        let maxWidth = min(Self.maxDisplayWidth, max(containerWidth - 4, 100))
        let scale = min(1.0, maxWidth / imageSize.width)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: 0, y: -4, width: width, height: height)
    }
}
