import ScreenCaptureKit
import Metal
import AppKit

final class ScreenCaptureProvider: NSObject, SCStreamOutput, @unchecked Sendable {
    private var stream: SCStream?
    private let device: MTLDevice
    private let textureCache: CVMetalTextureCache
    private let lock = NSLock()
    private var _latestTexture: MTLTexture?

    var latestTexture: MTLTexture? {
        lock.lock()
        defer { lock.unlock() }
        return _latestTexture
    }

    init?(device: MTLDevice) {
        self.device = device
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess,
              let cache else { return nil }
        self.textureCache = cache
        super.init()
    }

    func requestPermissionAndStart() {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, error in
            guard let self, error == nil, let display = content?.displays.first else { return }
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let ownWindows = content?.windows.filter { $0.owningApplication?.processID == ownPID } ?? []
            self.startCapture(display: display, excludingWindows: ownWindows)
        }
    }

    private func startCapture(display: SCDisplay, excludingWindows: [SCWindow]) {
        let filter = SCContentFilter(display: display, excludingWindows: excludingWindows)
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = false
        config.capturesAudio = false

        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try? newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        newStream.startCapture { _ in }
        self.stream = newStream
    }

    func stop() {
        stream?.stopCapture { _ in }
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width  = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil, textureCache, imageBuffer, nil,
            .bgra8Unorm, width, height, 0, &cvTexture
        )
        guard result == kCVReturnSuccess,
              let cvTexture,
              let tex = CVMetalTextureGetTexture(cvTexture) else { return }

        lock.lock()
        _latestTexture = tex
        lock.unlock()
    }
}
