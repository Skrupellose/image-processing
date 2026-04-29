import Foundation
import Photos

final class PhotosLibrarySaveService {
    func saveLivePhoto(imageURL: URL, videoURL: URL) async throws {
        let status = await requestAuthorization()

        guard status == .authorized || status == .limited else {
            throw LivePhotoProcessingError.photosAccessDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()

                let photoOptions = PHAssetResourceCreationOptions()
                photoOptions.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: imageURL, options: photoOptions)

                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.shouldMoveFile = false
                request.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: LivePhotoProcessingError.photosSaveFailed(
                            error?.localizedDescription ?? "未知错误"
                        )
                    )
                }
            }
        }
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
