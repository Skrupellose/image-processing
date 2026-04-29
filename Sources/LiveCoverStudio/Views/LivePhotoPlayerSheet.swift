import PhotosUI
import SwiftUI

struct LivePhotoPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: LivePhotoPreviewRequest

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(request.title, systemImage: "livephoto.play")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("关闭", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            TrueLivePhotoPreviewView(resources: request.resources)
                .frame(minWidth: 760, idealWidth: 900, minHeight: 560, idealHeight: 680)
                .background(.black)
        }
    }
}

private struct TrueLivePhotoPreviewView: NSViewRepresentable {
    let resources: LivePhotoResources

    func makeNSView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.isMuted = true
        view.livePhoto = nil
        return view
    }

    func updateNSView(_ nsView: PHLivePhotoView, context: Context) {
        guard let stillImageURL = resources.stillImageURL,
              let motionVideoURL = resources.motionVideoURL else {
            nsView.livePhoto = nil
            context.coordinator.requestKey = nil
            return
        }

        let targetSize = targetSize(for: nsView)
        let key = "\(stillImageURL.path)|\(motionVideoURL.path)|\(Int(targetSize.width))x\(Int(targetSize.height))"
        guard context.coordinator.requestKey != key else {
            return
        }

        context.coordinator.requestKey = key
        nsView.livePhoto = nil

        PHLivePhoto.request(
            withResourceFileURLs: [stillImageURL, motionVideoURL],
            placeholderImage: NSImage(contentsOf: stillImageURL),
            targetSize: targetSize,
            contentMode: .aspectFit
        ) { livePhoto, info in
            DispatchQueue.main.async {
                guard context.coordinator.requestKey == key else {
                    return
                }

                nsView.livePhoto = livePhoto

                if livePhoto != nil {
                    nsView.startPlayback(with: .full)
                } else if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                    NSLog("Live Photo sheet preview failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func targetSize(for view: NSView) -> CGSize {
        let scale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let width = max(view.bounds.width * scale, 900)
        let height = max(view.bounds.height * scale, 700)
        return CGSize(width: width, height: height)
    }

    final class Coordinator {
        var requestKey: String?
    }
}
