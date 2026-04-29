import Foundation

struct LivePhotoPreviewRequest: Identifiable {
    let id = UUID()
    let title: String
    let resources: LivePhotoResources
}
