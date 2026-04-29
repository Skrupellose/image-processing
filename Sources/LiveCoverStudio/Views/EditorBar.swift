import SwiftUI

struct EditorBar: View {
    @ObservedObject var viewModel: LivePhotoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    viewModel.extractFirstFrame()
                } label: {
                    Label("提取第一帧", systemImage: "film.stack")
                }
                .disabled(viewModel.resources.motionVideoURL == nil)

                Button {
                    viewModel.chooseReplacementCover()
                } label: {
                    Label("更换封面", systemImage: "photo.on.rectangle.angled")
                }

                Picker(
                    "效果",
                    selection: Binding(
                        get: { viewModel.selectedEffect },
                        set: { viewModel.selectEffect($0) }
                    )
                ) {
                    ForEach(CoverEffect.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 460)
                .disabled(viewModel.extractedFirstFrame == nil)

                Spacer()

                Button {
                    viewModel.exportProcessedLivePhoto()
                } label: {
                    Label("导出资源对", systemImage: "square.and.arrow.down")
                }
                .disabled(!viewModel.canExport || viewModel.isBusy)

                Button {
                    viewModel.saveProcessedLivePhotoToPhotos()
                } label: {
                    Label("保存到照片", systemImage: "photo.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canExport || viewModel.isBusy)
            }

            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .background(.bar)
    }
}
