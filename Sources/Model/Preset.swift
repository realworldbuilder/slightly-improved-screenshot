import Foundation

/// A social media image size preset. Dimensions are in pixels.
nonisolated enum Preset: String, CaseIterable, Codable, Identifiable, Sendable {
    case x
    case instagramSquare
    case instagramPortrait
    case instagramStory
    case linkedIn
    case openGraph

    var id: String { rawValue }

    var width: Int {
        switch self {
        case .x: 1600
        case .instagramSquare, .instagramPortrait, .instagramStory: 1080
        case .linkedIn, .openGraph: 1200
        }
    }

    var height: Int {
        switch self {
        case .x: 900
        case .instagramSquare: 1080
        case .instagramPortrait: 1350
        case .instagramStory: 1920
        case .linkedIn: 627
        case .openGraph: 630
        }
    }

    var pixelSize: CGSize { CGSize(width: width, height: height) }

    var displayName: String {
        switch self {
        case .x: "X / Twitter"
        case .instagramSquare: "Instagram Square"
        case .instagramPortrait: "Instagram Portrait"
        case .instagramStory: "Instagram Story"
        case .linkedIn: "LinkedIn"
        case .openGraph: "Open Graph"
        }
    }

    /// One-word caption for the capture toolbar.
    var shortName: String {
        switch self {
        case .x: "X"
        case .instagramSquare: "Square"
        case .instagramPortrait: "Portrait"
        case .instagramStory: "Story"
        case .linkedIn: "LinkedIn"
        case .openGraph: "Link"
        }
    }

    /// Short token used in file names.
    var fileToken: String {
        switch self {
        case .x: "X"
        case .instagramSquare: "IG-Square"
        case .instagramPortrait: "IG-Portrait"
        case .instagramStory: "IG-Story"
        case .linkedIn: "LinkedIn"
        case .openGraph: "OpenGraph"
        }
    }

    var dimensionsLabel: String { "\(width) × \(height)" }
}

/// What to do when a preset does not fit 1:1 on the display under the cursor.
nonisolated enum FitPolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Shrink the on-screen frame so it fits, then upscale the capture to the exact preset size.
    case autoFit
    /// Only allow pixel-exact captures; show a hint when the preset does not fit.
    case exactOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autoFit: "Auto-fit (scale down frame, upscale result)"
        case .exactOnly: "1:1 only (exact pixels, may not fit)"
        }
    }
}

/// What the Capture button produces.
nonisolated enum CaptureMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case photo
    case video

    var id: String { rawValue }
}
