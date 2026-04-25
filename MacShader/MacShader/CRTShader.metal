#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut crt_vertex(uint vid [[vertex_id]]) {
    const float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    VertexOut out;
    out.position = float4(positions[vid], 0.0, 1.0);
    out.uv = positions[vid] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;
    return out;
}

struct CRTUniforms {
    float scanlineIntensity;
    float glowIntensity;
    float time;
    float screenHeight;
};

fragment float4 crt_fragment(VertexOut in [[stage_in]],
                              constant CRTUniforms &u [[buffer(0)]])
{
    float2 uv = in.uv;

    float scanlineFreq = u.screenHeight * 0.5;
    float scanline = sin(uv.y * scanlineFreq * 3.14159265) * 0.5 + 0.5;
    scanline = pow(scanline, 1.5);
    float scanlineDark = mix(1.0 - u.scanlineIntensity, 1.0, scanline);

    float2 center = uv - 0.5;
    float dist = length(center);
    float vignette = 1.0 - smoothstep(0.3, 0.75, dist);

    float glow = exp(-dist * dist * 6.0) * u.glowIntensity;
    float3 glowColor = float3(0.15, 0.55, 0.15) * glow;

    float flicker = 1.0 + sin(u.time * 47.3) * 0.005;

    float3 rgb = glowColor * scanlineDark * vignette * flicker;

    float alpha = (glow * vignette + u.scanlineIntensity * (1.0 - scanline) * 0.35) * flicker;
    alpha = clamp(alpha, 0.0, 0.92);

    float3 premult = rgb * alpha;

    return float4(premult, alpha);
}
