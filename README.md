# MacShader

A macOS menu-bar app that applies a CRT shader effect over your entire screen in real time.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![Metal](https://img.shields.io/badge/Metal-runtime-silver)

## Modes

**Procedural** — phosphor triad mask, scanlines, vignette and flicker rendered as a transparent overlay. Works instantly, no permissions needed.

**Screen Capture** — captures your live screen via ScreenCaptureKit and processes it through CRT color grading, bloom and scanlines. Requires Screen Recording permission (prompted on first use).

## Install

Clone and build in Xcode, or:

```
xcodebuild -scheme MacShader -configuration Release build
```

Then launch `MacShader.app`. A 📺 icon appears in your menu bar — no Dock icon.

## Controls

Click the menu bar icon to open the control panel.

| Control | Effect |
|---|---|
| Enable toggle | Show / hide the overlay |
| Procedural / Screen Capture | Switch render mode |
| Scanlines | Intensity of horizontal scanline darkening |
| Glow | Bloom brightness |
| Saturation | Color saturation (1× – 3×) |

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (no external dependencies)
- Screen Recording permission for Screen Capture mode
