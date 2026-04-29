import AVFoundation
import AppKit
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

final class LivePhotoDemoService {
    private let imageWriter = LivePhotoImageWriter()

    func generateDemoResources() async throws -> LivePhotoResources {
        let assetIdentifier = UUID().uuidString
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveCoverStudioDemo-\(assetIdentifier)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let imageURL = folderURL.appendingPathComponent("demo-cover.jpg")
        let videoURL = folderURL.appendingPathComponent("demo-motion.mov")

        let firstFrame = try makeFrameImage(frame: 0, frameCount: 48, width: 540, height: 720)
        try imageWriter.writeJPEG(firstFrame, to: imageURL, assetIdentifier: assetIdentifier)
        try await writeDemoMovie(to: videoURL, assetIdentifier: assetIdentifier)

        return LivePhotoResources(stillImageURL: imageURL, motionVideoURL: videoURL)
    }

    private func writeDemoMovie(to url: URL, assetIdentifier: String) async throws {
        let width = 540
        let height = 720
        let frameCount = 48
        let frameRate: Int32 = 24

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.metadata = [contentIdentifierMetadataItem(assetIdentifier)]

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        videoInput.expectsMediaDataInRealTime = false

        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw LivePhotoProcessingError.videoExportSessionUnavailable
        }
        writer.add(videoInput)

        let metadataInput = try stillImageTimeMetadataInput()
        let metadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)
        guard writer.canAdd(metadataInput) else {
            throw LivePhotoProcessingError.videoExportSessionUnavailable
        }
        writer.add(metadataInput)

        guard writer.startWriting() else {
            throw LivePhotoProcessingError.videoExportFailed(writer.error?.localizedDescription ?? "无法开始写入视频")
        }

        writer.startSession(atSourceTime: .zero)
        try appendStillImageTimeMetadata(with: metadataAdaptor)
        metadataInput.markAsFinished()

        for frame in 0..<frameCount {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            guard let pixelBuffer = makePixelBuffer(frame: frame, frameCount: frameCount, width: width, height: height) else {
                throw LivePhotoProcessingError.videoExportFailed("无法创建演示视频帧")
            }

            let time = CMTime(value: CMTimeValue(frame), timescale: frameRate)
            if !pixelAdaptor.append(pixelBuffer, withPresentationTime: time) {
                throw LivePhotoProcessingError.videoExportFailed(writer.error?.localizedDescription ?? "无法追加视频帧")
            }
        }

        videoInput.markAsFinished()

        try await finishWriting(writer)
    }

    private func stillImageTimeMetadataInput() throws -> AVAssetWriterInput {
        let specification: [String: Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataBaseDataType_SInt8 as String
        ]

        var formatDescription: CMMetadataFormatDescription?
        let status = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDescription else {
            throw LivePhotoProcessingError.videoExportFailed("无法创建 still-image-time 元数据描述")
        }

        return AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: formatDescription
        )
    }

    private func appendStillImageTimeMetadata(with adaptor: AVAssetWriterInputMetadataAdaptor) throws {
        let item = AVMutableMetadataItem()
        item.keySpace = .quickTimeMetadata
        item.key = "com.apple.quicktime.still-image-time" as NSString
        item.value = 0 as NSNumber
        item.dataType = kCMMetadataBaseDataType_SInt8 as String

        let group = AVTimedMetadataGroup(
            items: [item],
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 1, timescale: 30))
        )

        guard adaptor.append(group) else {
            throw LivePhotoProcessingError.videoExportFailed("无法写入 still-image-time 元数据")
        }
    }

    private func finishWriting(_ writer: AVAssetWriter) async throws {
        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        guard writer.status == .completed else {
            throw LivePhotoProcessingError.videoExportFailed(writer.error?.localizedDescription ?? "视频写入未完成")
        }
    }

    private func contentIdentifierMetadataItem(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataContentIdentifier
        item.value = assetIdentifier as NSString
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    private func makeFrameImage(frame: Int, frameCount: Int, width: Int, height: Int) throws -> NSImage {
        guard let pixelBuffer = makePixelBuffer(frame: frame, frameCount: frameCount, width: width, height: height) else {
            throw LivePhotoProcessingError.imageConversionFailed
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            throw LivePhotoProcessingError.imageConversionFailed
        }

        return NSImage.fromCGImage(cgImage)
    }

    private func makePixelBuffer(frame: Int, frameCount: Int, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let progress = Double(frame) / Double(max(frameCount - 1, 1))
        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            let row = pointer.advanced(by: y * bytesPerRow)
            let yRatio = Double(y) / Double(max(height - 1, 1))

            for x in 0..<width {
                let xRatio = Double(x) / Double(max(width - 1, 1))
                let offset = x * 4

                row[offset] = UInt8(80 + 110 * abs(sin((xRatio + progress) * .pi)))
                row[offset + 1] = UInt8(90 + 120 * yRatio)
                row[offset + 2] = UInt8(120 + 100 * progress)
                row[offset + 3] = 255
            }
        }

        return pixelBuffer
    }
}
