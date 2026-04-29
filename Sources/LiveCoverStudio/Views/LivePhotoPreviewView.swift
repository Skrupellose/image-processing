import SwiftUI

struct LivePhotoPreviewView: NSViewRepresentable {
    let resources: LivePhotoResources

    func makeNSView(context: Context) -> StillPreviewNSView {
        StillPreviewNSView()
    }

    func updateNSView(_ nsView: StillPreviewNSView, context: Context) {
        nsView.configure(imageURL: resources.stillImageURL)
    }
}

final class StillPreviewNSView: NSView {
    private let imageView = NSImageView()
    private var representedPath: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    func configure(imageURL: URL?) {
        guard let imageURL else {
            representedPath = nil
            imageView.image = nil
            return
        }

        guard representedPath != imageURL.path else {
            return
        }

        representedPath = imageURL.path
        imageView.image = NSImage(contentsOf: imageURL)
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
