import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: LivePhotoViewModel

    var body: some View {
        List {
            Section("资源") {
                ResourceRow(
                    title: "封面图片",
                    value: viewModel.resources.stillImageURL?.lastPathComponent ?? "未选择",
                    systemImage: "photo",
                    clearAction: viewModel.resources.stillImageURL == nil ? nil : {
                        viewModel.clearStillImage()
                    }
                ) {
                    viewModel.chooseStillImage()
                }

                ResourceRow(
                    title: "动态视频",
                    value: viewModel.resources.motionVideoURL?.lastPathComponent ?? "未选择",
                    systemImage: "video",
                    clearAction: viewModel.resources.motionVideoURL == nil ? nil : {
                        viewModel.clearMotionVideo()
                    }
                ) {
                    viewModel.chooseMotionVideo()
                }

                if viewModel.resources.stillImageURL != nil || viewModel.resources.motionVideoURL != nil {
                    Button(role: .destructive) {
                        viewModel.clearAllResources()
                    } label: {
                        Label("清空资源", systemImage: "trash")
                    }
                }
            }

            if let warning = viewModel.resourceWarning {
                Section("提示") {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }

            Section("流程") {
                Label("预览实况图片", systemImage: viewModel.canPreviewLivePhoto ? "checkmark.circle" : "circle")
                Label("提取第一帧", systemImage: viewModel.extractedFirstFrame == nil ? "circle" : "checkmark.circle")
                Label("处理封面", systemImage: viewModel.processedCoverImage == nil ? "circle" : "checkmark.circle")
                Label("导出文件", systemImage: viewModel.lastExportResult == nil ? "circle" : "checkmark.circle")
            }

            if let result = viewModel.lastExportResult {
                Section("最近导出") {
                    Text(result.imageURL.lastPathComponent)
                        .lineLimit(1)
                    Text(result.videoURL.lastPathComponent)
                        .lineLimit(1)
                    Text(result.assetIdentifier)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct ResourceRow: View {
    let title: String
    let value: String
    let systemImage: String
    let clearAction: (() -> Void)?
    let action: () -> Void

    init(
        title: String,
        value: String,
        systemImage: String,
        clearAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.clearAction = clearAction
        self.action = action
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: action) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("选择\(title)")

            if let clearAction {
                Button(action: clearAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("移除\(title)")
            }
        }
    }
}
