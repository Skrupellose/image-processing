import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class CoverImageProcessor {
    private let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any
    ])

    func apply(effect: CoverEffect, to image: NSImage) throws -> NSImage {
        guard effect != .original else {
            return image
        }

        guard let cgImage = image.normalizedCGImage else {
            throw LivePhotoProcessingError.imageConversionFailed
        }

        let input = CIImage(cgImage: cgImage)
        let output: CIImage

        switch effect {
        case .original:
            output = input
        case .cinematic:
            output = cinematic(input)
        case .vivid:
            output = vivid(input)
        case .noir:
            output = input.applyingFilter("CIPhotoEffectNoir")
        case .comic:
            output = input.applyingFilter("CIComicEffect")
        case .bloom:
            output = bloom(input)
        }

        guard let rendered = context.createCGImage(output, from: output.extent) else {
            throw LivePhotoProcessingError.imageConversionFailed
        }

        return NSImage.fromCGImage(rendered)
    }

    private func cinematic(_ input: CIImage) -> CIImage {
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.contrast = 1.12
        controls.saturation = 0.92
        controls.brightness = -0.015

        let vignette = CIFilter.vignette()
        vignette.inputImage = controls.outputImage ?? input
        vignette.intensity = 0.75
        vignette.radius = Float(max(input.extent.width, input.extent.height) * 0.62)

        return vignette.outputImage ?? input
    }

    private func vivid(_ input: CIImage) -> CIImage {
        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = input
        vibrance.amount = 0.55

        let controls = CIFilter.colorControls()
        controls.inputImage = vibrance.outputImage ?? input
        controls.contrast = 1.08
        controls.saturation = 1.14
        controls.brightness = 0.01

        return controls.outputImage ?? input
    }

    private func bloom(_ input: CIImage) -> CIImage {
        let bloom = CIFilter.bloom()
        bloom.inputImage = input
        bloom.intensity = 0.42
        bloom.radius = 8

        let controls = CIFilter.colorControls()
        controls.inputImage = bloom.outputImage ?? input
        controls.contrast = 1.02
        controls.saturation = 1.05

        return controls.outputImage ?? input
    }
}
