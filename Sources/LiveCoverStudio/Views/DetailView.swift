import SwiftUI

struct DetailView: View {
    @ObservedObject var viewModel: LivePhotoViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                PreviewPane(
                    title: "原始 Live Photo",
                    systemImage: "livephoto",
                    footer: originalFooter,
                    livePreviewAction: viewModel.canPreviewLivePhoto ? {
                        viewModel.previewOriginalLivePhoto()
                    } : nil
                ) {
                    LivePhotoPreviewView(resources: viewModel.resources)
                }

                PreviewPane(
                    title: "处理后封面",
                    systemImage: "wand.and.stars",
                    footer: processedFooter,
                    livePreviewAction: viewModel.processedPreviewResources.isComplete ? {
                        viewModel.previewProcessedLivePhoto()
                    } : nil
                ) {
                    ProcessedCoverPreview(
                        image: viewModel.processedCoverImage,
                        livePhotoResources: viewModel.processedPreviewResources
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            EditorBar(viewModel: viewModel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay {
            if viewModel.isBusy {
                ProgressView("正在处理")
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .sheet(item: $viewModel.livePhotoPreviewRequest) { request in
            LivePhotoPlayerSheet(request: request)
        }
    }

    private var originalFooter: String {
        guard viewModel.canPreviewLivePhoto else {
            return "选择图片和 MOV 后可预览"
        }

        return viewModel.resources.displayName
    }

    private var processedFooter: String {
        guard viewModel.processedCoverImage != nil else {
            return "提取第一帧或更换封面后可预览"
        }

        return viewModel.selectedEffect.title
    }
}
