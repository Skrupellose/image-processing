import AppKit
import Foundation

final class LivePhotoPreviewResourceService {
    private let fileManager: FileManager
    private let imageWriter: LivePhotoImageWriter
    private let metadataService: LivePhotoMetadataService

    init(
        fileManager: FileManager = .default,
        imageWriter: LivePhotoImageWriter = LivePhotoImageWriter(),
        metadataService: LivePhotoMetadataService = LivePhotoMetadataService()
    ) {
        self.fileManager = fileManager
        self.imageWriter = imageWriter
        self.metadataService = metadataService
    }

    func makePreviewResources(
        image: NSImage,
        videoURL: URL,
        in directory: URL,
        revision: Int
    ) async throws -> LivePhotoResources {
        let assetIdentifier = await metadataService.assetIdentifier(from: videoURL) ?? UUID().uuidString
        let previewURL = directory.appendingPathComponent("processed-\(revision).jpg")

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try removeObsoletePreviewFiles(in: directory, keeping: previewURL)
        try imageWriter.writeJPEG(image, to: previewURL, assetIdentifier: assetIdentifier)

        return LivePhotoResources(
            stillImageURL: previewURL,
            motionVideoURL: videoURL
        )
    }

    func cleanupDirectory(_ directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }

    private func removeObsoletePreviewFiles(in directory: URL, keeping currentFileURL: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents where url != currentFileURL {
            try fileManager.removeItem(at: url)
        }
    }
}
