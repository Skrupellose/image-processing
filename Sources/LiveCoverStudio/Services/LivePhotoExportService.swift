import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct LivePhotoExportResult {
    let imageURL: URL
    let videoURL: URL
    let assetIdentifier: String
}

final class LivePhotoExportService {
    private let imageWriter = LivePhotoImageWriter()

    func export(
        resources: LivePhotoResources,
        coverImage: NSImage,
        to folderURL: URL,
        baseName: String
    ) async throws -> LivePhotoExportResult {
        guard let videoURL = resources.motionVideoURL else {
            throw LivePhotoProcessingError.missingResources
        }

        let assetIdentifier = UUID().uuidString
        let sanitizedBaseName = baseName.sanitizedFileName(defaultName: "LivePhoto")
        let imageURL = folderURL.appendingPathComponent("\(sanitizedBaseName)_cover.jpg")
        let exportedVideoURL = folderURL.appendingPathComponent("\(sanitizedBaseName)_motion.mov")

        try imageWriter.writeJPEG(coverImage, to: imageURL, assetIdentifier: assetIdentifier)
        try removeExistingFileIfNeeded(at: exportedVideoURL)
        try await exportVideo(from: videoURL, to: exportedVideoURL, assetIdentifier: assetIdentifier)

        return LivePhotoExportResult(
            imageURL: imageURL,
            videoURL: exportedVideoURL,
            assetIdentifier: assetIdentifier
        )
    }

    private func exportVideo(from sourceURL: URL, to outputURL: URL, assetIdentifier: String) async throws {
        let asset = AVURLAsset(url: sourceURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw LivePhotoProcessingError.videoExportSessionUnavailable
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true

        var metadata = try await asset.load(.metadata)
        metadata.removeAll { item in
            item.identifier == .quickTimeMetadataContentIdentifier
        }
        metadata.append(contentIdentifierMetadataItem(assetIdentifier))
        exportSession.metadata = metadata

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return
        case .cancelled:
            throw LivePhotoProcessingError.cancelled
        default:
            throw LivePhotoProcessingError.videoExportFailed(
                exportSession.error?.localizedDescription ?? "未知错误"
            )
        }
    }

    private func removeExistingFileIfNeeded(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw LivePhotoProcessingError.videoExportFailed(error.localizedDescription)
        }
    }

    private func contentIdentifierMetadataItem(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataContentIdentifier
        item.value = assetIdentifier as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.extendedLanguageTag = "und"
        return item
    }
}
