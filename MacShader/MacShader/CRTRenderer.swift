import Metal
import MetalKit

struct CRTUniforms {
    var scanlineIntensity: Float
    var glowIntensity: Float
    var colorSaturation: Float
    var time: Float
    var screenWidth: Float
    var screenHeight: Float
    var mode: UInt32
}

final class CRTRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var sampler: MTLSamplerState?
    private var startTime: CFTimeInterval = CACurrentMediaTime()

    var scanlineIntensity: Float = 0.6
    var glowIntensity: Float = 0.4
    var colorSaturation: Float = 1.8
    var mode: UInt32 = 0

    weak var captureProvider: ScreenCaptureProvider?

    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        buildPipeline(view: view)
        buildSampler()
    }

    private func buildPipeline(view: MTKView) {
        do {
            let library    = try device.makeLibrary(source: CRTShaderSource.source, options: nil)
            guard let vertexFn   = library.makeFunction(name: "crt_vertex"),
                  let fragmentFn = library.makeFunction(name: "crt_fragment") else {
                NSLog("CRTRenderer: failed to find shader functions")
                return
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction   = vertexFn
            descriptor.fragmentFunction = fragmentFn
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled             = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor          = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor     = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor        = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor   = .oneMinusSourceAlpha
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            NSLog("CRTRenderer: pipeline built OK")
        } catch {
            NSLog("CRTRenderer: pipeline error: \(error)")
        }
    }

    private func buildSampler() {
        let desc = MTLSamplerDescriptor()
        desc.minFilter    = .linear
        desc.magFilter    = .linear
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: desc)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipelineState,
              let drawable       = view.currentDrawable,
              let descriptor     = view.currentRenderPassDescriptor,
              let commandBuffer  = commandQueue.makeCommandBuffer() else { return }

        descriptor.colorAttachments[0].loadAction  = .clear
        descriptor.colorAttachments[0].clearColor  = MTLClearColorMake(0, 0, 0, 0)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        let elapsed = Float(CACurrentMediaTime() - startTime)
        var uniforms = CRTUniforms(
            scanlineIntensity: scanlineIntensity,
            glowIntensity:     glowIntensity,
            colorSaturation:   colorSaturation,
            time:              elapsed,
            screenWidth:       Float(view.drawableSize.width),
            screenHeight:      Float(view.drawableSize.height),
            mode:              mode
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CRTUniforms>.stride, index: 0)

        if let tex = captureProvider?.latestTexture, let sampler {
            encoder.setFragmentTexture(tex, index: 0)
            encoder.setFragmentSamplerState(sampler, index: 0)
        }

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
