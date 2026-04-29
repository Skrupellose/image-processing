import SwiftUI

struct PreviewPane<Content: View>: View {
    let title: String
    let systemImage: String
    let footer: String
    var livePreviewAction: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            GeometryReader { proxy in
                ZStack {
                    content
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .background(.black.opacity(0.88))
                        .clipped()

                    if let livePreviewAction {
                        Button(action: livePreviewAction) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 64, height: 64)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("在弹窗中播放实况")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.88))
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
