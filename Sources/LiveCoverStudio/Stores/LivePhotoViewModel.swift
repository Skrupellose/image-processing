import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class LivePhotoViewModel: ObservableObject {
    private static let previewDirectoryName = "LiveCoverStudioPreview"
    private static let photosExportDirectoryName = "LiveCoverStudioPhotosExport"
    @Published var resources = LivePhotoResources()
    @Published var extractedFirstFrame: NSImage?
    @Published var processedCoverImage: NSImage?
    @Published var processedPreviewResources = LivePhotoResources()
    @Published var selectedEffect: CoverEffect = .original
    @Published var statusMessage = "选择 Live Photo 的图片和 MOV 文件开始。"
    @Published var isBusy = false
    @Published var lastExportResult: LivePhotoExportResult?
    @Published var alertMessage: String?
    @Published var livePhotoPreviewRequest: LivePhotoPreviewRequest?

    private let frameService = LivePhotoFrameService()
    private let imageProcessor = CoverImageProcessor()
    private let exportService = LivePhotoExportService()
    private let previewResourceService = LivePhotoPreviewResourceService()
    private let demoService = LivePhotoDemoService()
    private let photosSaveService = PhotosLibrarySaveService()
    private let previewDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(previewDirectoryName, isDirectory: true)
    private let photosExportDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(photosExportDirectoryName, isDirectory: true)
    private var previewRevision = 0

    init() {
        cleanupWorkingDirectories()
    }

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

        isBusy = true
        statusMessage = "正在从 MOV 提取第一帧..."

        let frameService = frameService

        Task {
            do {
                let image = try await runOnWorker {
                    try frameService.firstFrame(from: videoURL)
                }

                extractedFirstFrame = image
                selectedEffect = .original
                try await updateProcessedCover(using: image, effect: .original)
                statusMessage = "已从 MOV 提取第一帧。"
            } catch {
                show(error: error)
            }

            isBusy = false
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

        isBusy = true
        statusMessage = "正在处理新的封面图..."

        Task {
            do {
                let currentProcessedCoverImage = processedCoverImage
                let currentExtractedFirstFrame = extractedFirstFrame
                let currentMotionVideoURL = resources.motionVideoURL

                let normalizedImage = await runOnWorker {
                    Self.makeNormalizedReplacementCover(
                        image,
                        targetImage: currentProcessedCoverImage ?? currentExtractedFirstFrame,
                        motionVideoURL: currentMotionVideoURL
                    )
                }

                extractedFirstFrame = normalizedImage
                selectedEffect = .original
                try await updateProcessedCover(using: normalizedImage, effect: .original)
                statusMessage = "已更换封面图并按视频比例裁切：\(url.lastPathComponent)"
            } catch {
                show(error: error)
            }

            isBusy = false
        }
    }

    func selectEffect(_ effect: CoverEffect) {
        guard selectedEffect != effect else {
            return
        }

        selectedEffect = effect
        applySelectedEffect()
    }

    func applySelectedEffect() {
        guard let sourceImage = extractedFirstFrame else {
            return
        }

        let effect = selectedEffect
        isBusy = true
        statusMessage = "正在应用效果：\(effect.title)..."

        Task {
            do {
                try await updateProcessedCover(using: sourceImage, effect: effect)
                statusMessage = "已应用效果：\(effect.title)"
            } catch {
                show(error: error)
            }

            isBusy = false
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

                try? FileManager.default.removeItem(at: exportFolder)

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
        guard let image = processedCoverImage,
              let videoURL = resources.motionVideoURL else {
            previewRevision += 1
            processedPreviewResources = LivePhotoResources()
            return
        }

        refreshProcessedPreview(for: image, videoURL: videoURL)
    }

    private func refreshProcessedPreview(for image: NSImage, videoURL: URL) {
        previewRevision += 1
        let currentRevision = previewRevision

        Task {
            do {
                let previewResources = try await previewResourceService.makePreviewResources(
                    image: image,
                    videoURL: videoURL,
                    in: previewDirectory,
                    revision: currentRevision
                )

                guard currentRevision == previewRevision else {
                    return
                }

                processedPreviewResources = previewResources
            } catch {
                guard currentRevision == previewRevision else {
                    return
                }

                show(error: error)
            }
        }
    }

    nonisolated private static func makeNormalizedReplacementCover(
        _ image: NSImage,
        targetImage: NSImage?,
        motionVideoURL: URL?
    ) -> NSImage {
        let referenceImage = targetImage ?? motionVideoURL.flatMap {
            try? LivePhotoFrameService().firstFrame(from: $0)
        }

        guard let targetCGImage = referenceImage?.normalizedCGImage,
              let normalized = image.scaledToFill(
                pixelWidth: targetCGImage.width,
                pixelHeight: targetCGImage.height
              ) else {
            return image
        }

        return normalized
    }

    private func updateProcessedCover(using sourceImage: NSImage, effect: CoverEffect) async throws {
        let imageProcessor = imageProcessor

        let processedImage = try await runOnWorker {
            try imageProcessor.apply(effect: effect, to: sourceImage)
        }

        processedCoverImage = processedImage
        refreshProcessedPreview(for: processedImage, videoURL: try currentMotionVideoURL())
    }

    private func currentMotionVideoURL() throws -> URL {
        guard let videoURL = resources.motionVideoURL else {
            throw LivePhotoProcessingError.missingResources
        }

        return videoURL
    }

    private func runOnWorker<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: operation).value
    }

    private func runOnWorker<T: Sendable>(
        _ operation: @escaping @Sendable () -> T
    ) async -> T {
        await Task.detached(priority: .userInitiated, operation: operation).value
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

    private func cleanupWorkingDirectories() {
        do {
            try previewResourceService.cleanupDirectory(previewDirectory)
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        do {
            try cleanupPhotoExportDirectory()
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func cleanupPhotoExportDirectory() throws {
        guard FileManager.default.fileExists(atPath: photosExportDirectory.path) else {
            return
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: photosExportDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            try FileManager.default.removeItem(at: url)
        }
    }
}
