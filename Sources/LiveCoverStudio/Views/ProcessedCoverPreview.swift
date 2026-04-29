import SwiftUI

struct ProcessedCoverPreview: View {
    let image: NSImage?
    let livePhotoResources: LivePhotoResources

    var body: some View {
        ZStack {
            if livePhotoResources.isComplete {
                LivePhotoPreviewView(resources: livePhotoResources)
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(24)
            } else {
                ContentUnavailableView(
                    "暂无封面",
                    systemImage: "photo",
                    description: Text("提取第一帧、更换封面或选择效果后会显示在这里")
                )
                .foregroundStyle(.secondary)
            }
        }
    }
}
