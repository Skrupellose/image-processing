import AVFoundation

final class LivePhotoMetadataService {
    func assetIdentifier(from videoURL: URL) async -> String? {
        let asset = AVURLAsset(url: videoURL)

        guard let metadata = try? await asset.load(.metadata) else {
            return nil
        }

        guard let item = metadata.first(where: { $0.identifier == .quickTimeMetadataContentIdentifier }) else {
            return nil
        }

        if let stringValue = try? await item.load(.stringValue) {
            return stringValue
        }

        if let value = try? await item.load(.value), let stringValue = value as? String {
            return stringValue
        }

        return nil
    }
}
