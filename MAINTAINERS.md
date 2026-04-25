# MacShader — Maintainer Notes

## What it is

Menu-bar app that overlays a system-wide CRT shader effect on top of all screen content. No Dock icon. Two modes:

- **Procedural** — phosphor triad mask + scanlines + vignette, rendered as a transparent overlay. No permissions required.
- **Screen Capture** — live screen capture via ScreenCaptureKit, processed through CRT color grading + bloom + scanlines. Requires Screen Recording permission.

## Architecture

```
AppDelegate              menu bar status item + popover lifecycle
OverlayWindowController  NSWindow (borderless, ignoresMouseEvents, level=screenSaverWindow-1)
                         owns MTKView + CRTRenderer + ScreenCaptureProvider
CRTRenderer              MTKViewDelegate — builds pipeline, drives draw loop, uploads uniforms
CRTShaderSource          MSL source as a Swift string (runtime compiled via makeLibrary(source:))
ScreenCaptureProvider    SCStream → CVMetalTextureCache → MTLTexture, thread-safe with NSLock
ControlPanel             SwiftUI popover (enable toggle, mode picker, sliders)
```

## Key decisions

**Runtime shader compilation.** Xcode 26.x beta is missing the offline Metal toolchain (`metal` compiler). Shaders are compiled at launch via `device.makeLibrary(source:options:)`. If the Metal toolchain ships in a stable Xcode release, `.metal` files can replace `CRTShaderSource.swift`.

**`bgra8Unorm` pixel format.** `rgba16Float` layers are treated as opaque by the macOS compositor — transparent compositing requires `bgra8Unorm`.

**Fragment function inlining.** MSL does not allow calling one `fragment`-qualified function from another. Both render modes are inlined as branches inside the single `crt_fragment` entry point.

**Overlay window level.** `CGWindowLevelForKey(.screenSaverWindow) - 1` puts the overlay above all normal app windows and below the system screen saver. `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` keeps it visible across Spaces and fullscreen apps.

**Feedback loop fix.** In Screen Capture mode the SCStream filter explicitly excludes all windows owned by MacShader's PID, preventing the overlay from being captured and re-processed.

**Sandbox disabled.** `com.apple.security.app-sandbox = false` in entitlements — required for the overlay window level to work. `LSUIElement = true` in Info.plist suppresses the Dock icon.

**`ScreenCaptureProvider` concurrency.** The `SCStreamOutput` delegate callback is `nonisolated` and arrives on a background queue. The provider is `@unchecked Sendable` and guards `_latestTexture` with an `NSLock`.

## Building

Requires Xcode 15+ on macOS 13+. Open `MacShader/MacShader.xcodeproj` and run.

```
xcodebuild -scheme MacShader -configuration Debug build
```

No external dependencies.

## Sliders and uniforms

| Slider | Uniform | Range | Effect |
|---|---|---|---|
| Scanlines | `scanlineIntensity` | 0–1 | Depth of horizontal scanline darkening |
| Glow | `glowIntensity` | 0–1 | Center bloom brightness / capture bloom threshold |
| Saturation | `colorSaturation` | 1–3 | Color saturation multiplier fed into phosphor gamut matrix |
