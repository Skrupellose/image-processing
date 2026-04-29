import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class LivePhotoViewModel: ObservableObject {
    @Published var resources = LivePhotoResources()
    @Published var extractedFirstFrame: NSImage?
    @Published var processedCoverImage: NSImage?
    @Published var processedPreviewResources = LivePhotoResources()
    @Published var selectedEffect: CoverEffect = .original {
        didSet {
            applySelectedEffect()
        }
    }
    @Published var statusMessage = "选择 Live Photo 的图片和 MOV 文件开始。"
    @Published var isBusy = false
    @Published var lastExportResult: LivePhotoExportResult?
    @Published var alertMessage: String?
    @Published var livePhotoPreviewRequest: LivePhotoPreviewRequest?

    private let frameService = LivePhotoFrameService()
    private let imageProcessor = CoverImageProcessor()
    private let exportService = LivePhotoExportService()
    private let imageWriter = LivePhotoImageWriter()
    private let metadataService = LivePhotoMetadataService()
    private let demoService = LivePhotoDemoService()
    private let photosSaveService = PhotosLibrarySaveService()
    private let previewDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LiveCoverStudioPreview", isDirectory: true)
    private let photosExportDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LiveCoverStudioPhotosExport", isDirectory: true)
    private var previewRevision = 0

    var canPreviewLivePhoto: Bool {
        resources.isComplete
    }

    var canExport: Bool {
        resources.motionVideoURL != nil && processedCoverImage != nil
    }

    var resourceWarning: String? {
        if resources.stillImageURL != nil && resources.motionVideoURL == nil {
            return "只有 JPEG/图片文件不能恢复实况效果，还需要同一组 Live Photo 的 MOV。"
        }

        if resources.stillImageURL == nil && resources.motionVideoURL != nil {
            return "只有 MOV 还不能预览原始 Live Photo，请补充同一组封面图片。"
        }

        return nil
    }

    func chooseResources() {
        let panel = NSOpenPanel()
        panel.title = "选择 Live Photo 资源"
        panel.message = "请选择原始静态图和对应的 MOV 文件。"
        panel.allowedContentTypes = [
            .jpeg,
            .png,
            .heic,
            .quickTimeMovie,
            .movie
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else {
            return
        }

        setResources(from: panel.urls)
    }

    func loadDemoResources() {
        isBusy = true
        statusMessage = "正在生成演示 Live Photo 资源..."

        Task {
            do {
                let demoResources = try await demoService.generateDemoResources()
                resources = demoResources
                extractedFirstFrame = nil
                processedCoverImage = nil
                processedPreviewResources = LivePhotoResources()
                lastExportResult = nil
                statusMessage = "已载入演示资源，可以预览并提取第一帧。"
            } catch {
                show(error: error)
            }

            isBusy = false
        }
    }

    func chooseStillImage() {
        let panel = NSOpenPanel()
        panel.title = "选择原始封面图片"
        panel.allowedContentTypes = [.jpeg, .png, .heic, .image]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        resources.stillImageURL = url
        resetProcessedState()
        statusMessage = resources.motionVideoURL == nil
            ? "已选择图片：\(url.lastPathComponent)。如果这是从 iCloud 单独保存的 JPEG，它本身不包含实况视频。"
            : "已选择封面图：\(url.lastPathComponent)"
    }

    func chooseMotionVideo() {
        let panel = NSOpenPanel()
        panel.title = "选择实况视频 MOV"
        panel.allowedContentTypes = [.quickTimeMovie, .movie]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        resources.motionVideoURL = url
        resetProcessedState()
        statusMessage = "已选择视频：\(url.lastPathComponent)"
    }

    func clearStillImage() {
        resources.stillImageURL = nil
        resetProcessedState()
        statusMessage = "已移除封面图片。"
    }

    func clearMotionVideo() {
        resources.motionVideoURL = nil
        resetProcessedState()
        statusMessage = "已移除动态视频。"
    }

    func clearAllResources() {
        resources = LivePhotoResources()
        resetProcessedState()
        statusMessage = "已清空资源。"
    }

    func extractFirstFrame() {
        guard let videoURL = resources.motionVideoURL else {
            show(error: LivePhotoProcessingError.missingResources)
            return
        }

        do {
            let image = try frameService.firstFrame(from: videoURL)
            extractedFirstFrame = image
            processedCoverImage = image
            selectedEffect = .original
            refreshProcessedPreview()
            statusMessage = "已从 MOV 提取第一帧。"
        } catch {
            show(error: error)
        }
    }

    func chooseReplacementCover() {
        let panel = NSOpenPanel()
        panel.title = "选择新的封面图"
        panel.allowedContentTypes = [.jpeg, .png, .heic, .image]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let image = NSImage(contentsOf: url) else {
            show(error: LivePhotoProcessingError.imageConversionFailed)
            return
        }

        let normalizedImage = normalizedReplacementCover(image)
        extractedFirstFrame = normalizedImage
        processedCoverImage = normalizedImage
        selectedEffect = .original
        refreshProcessedPreview()
        statusMessage = "已更换封面图并按视频比例裁切：\(url.lastPathComponent)"
    }

    func applySelectedEffect() {
        guard let sourceImage = extractedFirstFrame else {
            return
        }

        do {
            processedCoverImage = try imageProcessor.apply(effect: selectedEffect, to: sourceImage)
            refreshProcessedPreview()
            statusMessage = "已应用效果：\(selectedEffect.title)"
        } catch {
            show(error: error)
        }
    }

    func exportProcessedLivePhoto() {
        guard let coverImage = processedCoverImage else {
            show(error: LivePhotoProcessingError.missingCoverImage)
            return
        }

        guard resources.motionVideoURL != nil else {
            show(error: LivePhotoProcessingError.missingResources)
            return
        }

        let panel = NSOpenPanel()
        panel.title = "选择导出文件夹"
        panel.message = "会导出一张带 Live Photo 资源标识的 JPG 和一段匹配的 MOV。"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        isBusy = true
        statusMessage = "正在导出..."

        Task {
            do {
                let result = try await exportService.export(
                    resources: resources,
                    coverImage: coverImage,
                    to: folderURL,
                    baseName: resources.displayName
                )
                lastExportResult = result
                statusMessage = "资源对导出完成：\(result.imageURL.lastPathComponent) / \(result.videoURL.lastPathComponent)。要成为照片 App 里的实况照片，请使用「保存到照片」。"
            } catch {
                show(error: error)
            }

            isBusy = false
        }
    }

    func previewOriginalLivePhoto() {
        guard resources.isComplete else {
            show(error: LivePhotoProcessingError.missingResources)
            return
        }

        livePhotoPreviewRequest = LivePhotoPreviewRequest(
            title: "原始 Live Photo",
            resources: resources
        )
    }

    func previewProcessedLivePhoto() {
        guard processedPreviewResources.isComplete else {
            show(error: LivePhotoProcessingError.missingCoverImage)
            return
        }

        livePhotoPreviewRequest = LivePhotoPreviewRequest(
            title: "处理后 Live Photo",
            resources: processedPreviewResources
        )
    }

    func saveProcessedLivePhotoToPhotos() {
        guard let coverImage = processedCoverImage else {
            show(error: LivePhotoProcessingError.missingCoverImage)
            return
        }

        guard resources.motionVideoURL != nil else {
            show(error: LivePhotoProcessingError.missingResources)
            return
        }

        isBusy = true
        statusMessage = "正在创建 Live Photo 并保存到照片..."

        Task {
            do {
                try FileManager.default.createDirectory(
                    at: photosExportDirectory,
                    withIntermediateDirectories: true
                )

                let exportFolder = photosExportDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(
                    at: exportFolder,
                    withIntermediateDirectories: true
                )

                let result = try await exportService.export(
                    resources: resources,
                    coverImage: coverImage,
                    to: exportFolder,
                    baseName: resources.displayName
                )

                try await photosSaveService.saveLivePhoto(
                    imageURL: result.imageURL,
                    videoURL: result.videoURL
                )

                lastExportResult = result
                statusMessage = "已保存到照片 App。打开「照片」后应显示为一张 Live Photo。"
            } catch {
                show(error: error)
            }

            isBusy = false
        }
    }

    private func setResources(from urls: [URL]) {
        var next = resources

        for url in urls {
            let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType

            if type?.conforms(to: .movie) == true || type?.conforms(to: .quickTimeMovie) == true {
                next.motionVideoURL = url
            } else if type?.conforms(to: .image) == true {
                next.stillImageURL = url
            }
        }

        resources = next
        resetProcessedState()

        if resources.isComplete {
            statusMessage = "资源已就绪，可以预览 Live Photo 并提取第一帧。"
        } else {
            statusMessage = "已选择部分资源，请补齐图片和 MOV 文件。"
        }
    }

    private func refreshProcessedPreview() {
        previewRevision += 1
        let currentRevision = previewRevision

        guard let image = processedCoverImage,
              let videoURL = resources.motionVideoURL else {
            processedPreviewResources = LivePhotoResources()
            return
        }

        Task {
            let assetIdentifier = await metadataService.assetIdentifier(from: videoURL) ?? UUID().uuidString
            let previewURL = previewDirectory
                .appendingPathComponent("processed-\(currentRevision).jpg")

            do {
                try FileManager.default.createDirectory(
                    at: previewDirectory,
                    withIntermediateDirectories: true
                )
                try imageWriter.writeJPEG(image, to: previewURL, assetIdentifier: assetIdentifier)

                guard currentRevision == previewRevision else {
                    return
                }

                processedPreviewResources = LivePhotoResources(
                    stillImageURL: previewURL,
                    motionVideoURL: videoURL
                )
            } catch {
                guard currentRevision == previewRevision else {
                    return
                }

                show(error: error)
            }
        }
    }

    private func normalizedReplacementCover(_ image: NSImage) -> NSImage {
        let targetImage = processedCoverImage ?? extractedFirstFrame ?? resources.motionVideoURL.flatMap {
            try? frameService.firstFrame(from: $0)
        }

        guard let targetCGImage = targetImage?.normalizedCGImage,
              let normalized = image.scaledToFill(
                pixelWidth: targetCGImage.width,
                pixelHeight: targetCGImage.height
              ) else {
            return image
        }

        return normalized
    }

    private func resetProcessedState() {
        extractedFirstFrame = nil
        processedCoverImage = nil
        processedPreviewResources = LivePhotoResources()
        lastExportResult = nil
        previewRevision += 1
    }

    private func show(error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alertMessage = message
        statusMessage = message
    }
}
