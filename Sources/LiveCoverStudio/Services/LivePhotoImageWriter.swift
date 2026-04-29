import AppKit
import ImageIO
import UniformTypeIdentifiers

final class LivePhotoImageWriter {
    func writeJPEG(_ image: NSImage, to url: URL, assetIdentifier: String) throws {
        guard let cgImage = image.normalizedCGImage else {
            throw LivePhotoProcessingError.imageConversionFailed
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw LivePhotoProcessingError.imageWriteFailed
        }

        let makerApple: [String: Any] = [
            "17": assetIdentifier
        ]

        let metadata: [CFString: Any] = [
            kCGImagePropertyMakerAppleDictionary: makerApple,
            kCGImagePropertyOrientation: 1
        ]

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw LivePhotoProcessingError.imageWriteFailed
        }
    }
}
