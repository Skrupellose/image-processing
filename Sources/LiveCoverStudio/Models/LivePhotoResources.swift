import Foundation

struct LivePhotoResources: Equatable {
    var stillImageURL: URL?
    var motionVideoURL: URL?

    var isComplete: Bool {
        stillImageURL != nil && motionVideoURL != nil
    }

    var displayName: String {
        if let stillImageURL {
            return stillImageURL.deletingPathExtension().lastPathComponent
        }

        if let motionVideoURL {
            return motionVideoURL.deletingPathExtension().lastPathComponent
        }

        return "未选择资源"
    }
}
