import CoreGraphics
import Foundation

nonisolated enum OutputError: LocalizedError {
    case contextFailed
    case sizeMismatch
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .contextFailed: "Could not create an image buffer."
        case .sizeMismatch: "The output image did not have the expected size."
        case .encodeFailed: "Could not encode the PNG."
        }
    }
}

enum ImageNormalizer {
    /// Draws `source` into an opaque sRGB bitmap of exactly `size` pixels.
    /// Performs the upscale when the frame was auto-fitted, converts Display P3 to sRGB,
    /// and strips alpha so social sites see a plain opaque PNG.
    nonisolated static func normalize(_ source: CGImage, to size: CGSize) throws -> CGImage {
        let w = Int(size.width), h = Int(size.height)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else { throw OutputError.contextFailed }

        let sameSize = source.width == w && source.height == h
        context.interpolationQuality = sameSize ? .none : .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let out = context.makeImage(), out.width == w, out.height == h else {
            throw OutputError.sizeMismatch
        }
        return out
    }
}
