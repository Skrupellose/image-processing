import AppKit
import CoreGraphics

extension NSImage {
    var normalizedCGImage: CGImage? {
        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.cgImage
    }

    static func fromCGImage(_ cgImage: CGImage) -> NSImage {
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    func scaledToFill(pixelWidth: Int, pixelHeight: Int) -> NSImage? {
        guard let source = normalizedCGImage,
              pixelWidth > 0,
              pixelHeight > 0 else {
            return nil
        }

        let targetSize = CGSize(width: pixelWidth, height: pixelHeight)
        let sourceSize = CGSize(width: source.width, height: source.height)
        let scale = max(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2
        )

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(
            source,
            in: CGRect(origin: origin, size: scaledSize)
        )

        guard let output = context.makeImage() else {
            return nil
        }

        return NSImage.fromCGImage(output)
    }
}
