import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

@MainActor
final class ImageService: ObservableObject {
    static let shared = ImageService()

    private let context = CIContext()

    private init() {}

    // MARK: - Preprocessing for LLM

    func preprocessForLLM(_ image: UIImage, maxDimension: CGFloat = 1280) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Filters

    func applySepia(_ image: UIImage, intensity: Double = 0.8) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.sepiaTone()
        filter.inputImage = ciImage
        filter.intensity = Float(intensity)
        return renderFilter(filter)
    }

    func applyMonochrome(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = ciImage
        filter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        filter.intensity = 1.0
        return renderFilter(filter)
    }

    func applyVivid(_ image: UIImage, amount: Double = 1.5) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.vibrance()
        filter.inputImage = ciImage
        filter.amount = Float(amount)
        return renderFilter(filter)
    }

    func adjustBrightnessContrast(_ image: UIImage, brightness: Double = 0, contrast: Double = 1.0) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = Float(brightness)
        filter.contrast = Float(contrast)
        return renderFilter(filter)
    }

    func applyBlur(_ image: UIImage, radius: Double = 10) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = Float(radius)
        return renderFilter(filter)
    }

    func autoEnhance(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filters = ciImage.autoAdjustmentFilters()
        var result = ciImage
        for filter in filters {
            filter.setValue(result, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                result = output
            }
        }
        guard let cgImage = context.createCGImage(result, from: result.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Background Removal

    func removeBackground(_ image: UIImage) async throws -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else { return nil }
        let maskBuffer = result.pixelBuffer

        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        let originalImage = CIImage(cgImage: cgImage)

        let scaledMask = maskImage.transformed(by: CGAffineTransform(
            scaleX: originalImage.extent.width / maskImage.extent.width,
            y: originalImage.extent.height / maskImage.extent.height
        ))

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = originalImage
        blendFilter.backgroundImage = CIImage(color: .clear).cropped(to: originalImage.extent)
        blendFilter.maskImage = scaledMask

        guard let output = blendFilter.outputImage,
              let cgResult = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgResult)
    }

    // MARK: - Rotate

    func rotate(_ image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        let rotatedBounds = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
        let newSize = CGSize(width: abs(rotatedBounds.width), height: abs(rotatedBounds.height))

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.cgContext.rotate(by: radians)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                   width: image.size.width, height: image.size.height))
        }
    }

    // MARK: - Helpers

    private func renderFilter(_ filter: CIFilter) -> UIImage? {
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
