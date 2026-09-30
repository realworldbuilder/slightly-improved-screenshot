# Slightly Improved Screenshot

A tiny macOS menu bar utility that extends the built-in screenshot workflow with
fixed-size frames for social media. Press the hotkey, a frame locked to the chosen
preset follows your mouse, click to capture. The result is copied to the clipboard
and saved to `~/Downloads` at the exact pixel size the platform expects.

## Presets

| Preset | Pixels |
|---|---|
| X / Twitter | 1600 × 900 |
| Instagram Square | 1080 × 1080 |
| Instagram Portrait | 1080 × 1350 |
| Instagram Story | 1080 × 1920 |
| LinkedIn | 1200 × 627 |
| Open Graph | 1200 × 630 |

## Using it

- **⌃⌥⌘S** (rebindable in Settings) or the menu bar icon starts a capture with the selected preset.
- Move the mouse to place the frame. **Arrow keys** nudge by 1 px, **Shift + arrows** by 10 px.
- **Click**, **Return** or **Space** captures. **Esc** or right-click cancels.
- Output is an opaque sRGB PNG at 72 DPI with exactly the preset's pixel dimensions.

On a Retina display the frame is drawn at `pixels / scale` points so the capture is
pixel-for-pixel. When a preset does not fit on the display under the cursor (for
example a 1080 × 1920 story on a 1080 px tall 1x monitor) the frame is scaled down
to fit and the capture is upscaled to the exact preset size. The label turns orange
and shows the scale. Settings can switch this to a strict 1:1 mode instead.

## Requirements

- macOS 26 or later (uses the ScreenCaptureKit screenshot API introduced in macOS 26).
- Xcode 26.3, [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- An Apple Development signing identity. The Screen Recording permission is keyed to the
  code signature, so a consistently signed build keeps its grant across rebuilds.

## Build and install

```bash
make run
```

This regenerates the Xcode project, builds Release, installs to `~/Applications`,
and launches the app. Other targets: `make build`, `make test`, `make install`,
`make reset-tcc` (forget the Screen Recording grant to re-test first launch), `make clean`.

The first launch asks for **Screen Recording** access. Grant it in
System Settings › Privacy & Security › Screen & System Audio Recording, then relaunch.

## Layout

```
Sources/
  App/        App entry, delegate, AppState (capture pipeline orchestration)
  Model/      Preset and FitPolicy enums, UserDefaults-backed PresetStore
  Hotkey/     KeyboardShortcuts registration
  Overlay/    FrameGeometry (pure math), OverlayWindow/View/Controller
  Capture/    ScreenCaptureKit capturers (macOS 26 rect API, legacy filter API), permission helpers
  Output/     sRGB normalization, PNG encoding, clipboard and Downloads writing
  Settings/   SwiftUI settings window
Tests/        FrameGeometry unit tests (Swift Testing)
```
