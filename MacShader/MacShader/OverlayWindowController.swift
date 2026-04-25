import AppKit
import MetalKit
import Combine

final class OverlayWindowController: ObservableObject {
    private var window: NSWindow?
    private var renderer: CRTRenderer?
    private var captureProvider: ScreenCaptureProvider?

    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled { window?.orderFrontRegardless() }
            else { window?.orderOut(nil) }
        }
    }
    @Published var mode: UInt32 = 0 {
        didSet {
            renderer?.mode = mode
            if mode == 1 { ensureCaptureRunning() }
            else { captureProvider?.stop(); captureProvider = nil }
        }
    }
    @Published var scanlineIntensity: Float = 0.6 {
        didSet { renderer?.scanlineIntensity = scanlineIntensity }
    }
    @Published var glowIntensity: Float = 0.4 {
        didSet { renderer?.glowIntensity = glowIntensity }
    }
    @Published var colorSaturation: Float = 1.8 {
        didSet { renderer?.colorSaturation = colorSaturation }
    }

    func showOverlay() {
        guard let screen = NSScreen.main else { return }

        let overlayWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.hasShadow = false
        overlayWindow.isReleasedWhenClosed = false
        overlayWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let mtkView = MTKView(frame: screen.frame)
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60

        if let device = mtkView.device {
            renderer = CRTRenderer(device: device, view: mtkView)
            renderer?.scanlineIntensity = scanlineIntensity
            renderer?.glowIntensity = glowIntensity
            renderer?.colorSaturation = colorSaturation
            renderer?.mode = mode
            mtkView.delegate = renderer
        }

        overlayWindow.contentView = mtkView
        window = overlayWindow
        overlayWindow.orderFrontRegardless()

        if let metalLayer = mtkView.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
        }
    }

    private func ensureCaptureRunning() {
        guard captureProvider == nil, let device = renderer.flatMap({ _ in MTLCreateSystemDefaultDevice() }) else { return }
        let provider = ScreenCaptureProvider(device: device)
        provider?.requestPermissionAndStart()
        captureProvider = provider
        renderer?.captureProvider = provider
    }

    func close() {
        captureProvider?.stop()
        window?.close()
    }
}
