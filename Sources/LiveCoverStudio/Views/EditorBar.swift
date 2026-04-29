import SwiftUI

struct EditorBar: View {
    @ObservedObject var viewModel: LivePhotoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("封面处理")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

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
                        .disabled(!viewModel.canPreviewLivePhoto)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("效果")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

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
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("导出与保存")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
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
                }
                .padding(.top, 24)
            }

            Divider()
                .overlay(Color.black.opacity(0.06))

            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 18, y: 10)
    }
}
