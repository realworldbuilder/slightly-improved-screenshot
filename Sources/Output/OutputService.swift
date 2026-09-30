import AppKit
import ImageIO
import UniformTypeIdentifiers

enum OutputService {
    /// PNG bytes with 72 DPI metadata so the pixel size is also the nominal size.
    nonisolated static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw OutputError.encodeFailed
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: 72,
            kCGImagePropertyDPIHeight: 72,
            kCGImagePropertyPixelWidth: image.width,
            kCGImagePropertyPixelHeight: image.height,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw OutputError.encodeFailed }
        return data as Data
    }

    /// Copies PNG and TIFF flavors. No file URL, so paste targets embed the image inline.
    static func copyToPasteboard(png: Data, image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        pasteboard.setData(png, forType: .png)
        let rep = NSBitmapImageRep(cgImage: image)
        if let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    /// `~/Downloads/Screenshot <Token> <W>x<H> yyyy-MM-dd at HH.mm.ss.png`, de-duplicated with ` (n)`.
    nonisolated static func downloadsURL(preset: Preset, date: Date = .now, fileManager: FileManager = .default) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "Screenshot \(preset.fileToken) \(preset.width)x\(preset.height) \(formatter.string(from: date))"
        let directory = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        var url = directory.appendingPathComponent(base).appendingPathExtension("png")
        var n = 2
        while fileManager.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(base) (\(n))").appendingPathExtension("png")
            n += 1
        }
        return url
    }

    nonisolated static func write(png: Data, to url: URL) throws {
        try png.write(to: url, options: .atomic)
    }
}
