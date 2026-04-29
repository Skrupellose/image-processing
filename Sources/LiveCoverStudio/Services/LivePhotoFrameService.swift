import AVFoundation
import AppKit

final class LivePhotoFrameService {
    func firstFrame(from videoURL: URL) throws -> NSImage {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
        return NSImage.fromCGImage(cgImage)
    }
}
