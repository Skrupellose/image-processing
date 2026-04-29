import SwiftUI

struct PreviewPane<Content: View>: View {
    let title: String
    let systemImage: String
    let footer: String
    let infoTooltip: String?
    var livePreviewAction: (() -> Void)?
    @ViewBuilder var content: Content

    @State private var isShowingInfoTooltip = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 12)
                if let infoTooltip {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .onHover { isHovering in
                                isShowingInfoTooltip = isHovering
                            }

                        if isShowingInfoTooltip {
                            Text(infoTooltip)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: .black.opacity(0.14), radius: 10, y: 6)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: 220, alignment: .leading)
                                .offset(x: 14, y: 20)
                                .zIndex(1)
                        }
                    }
                }
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.82))
            .zIndex(2)

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.94))

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)

                    content
                        .frame(width: proxy.size.width - 32, height: proxy.size.height - 32)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if let livePreviewAction {
                        Button(action: livePreviewAction) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 68, height: 68)
                                .background(.regularMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                        }
                        .buttonStyle(.plain)
                        .help("在弹窗中播放实况")
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .shadow(color: .black.opacity(0.12), radius: 20, y: 12)
    }
}
