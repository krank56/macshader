enum CRTShaderSource {
    static let source = """
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
    float colorSaturation;
    float time;
    float screenWidth;
    float screenHeight;
    uint  mode;
};

float3 dither(float2 pos, float3 color, float alpha) {
    float3 noise = float3(
        fract(sin(dot(pos, float2(127.1, 311.7))) * 43758.5453),
        fract(sin(dot(pos, float2(269.5, 183.3))) * 43758.5453),
        fract(sin(dot(pos, float2(419.2, 371.9))) * 43758.5453)
    );
    return color + (noise - 0.5) / 255.0 * alpha;
}

float3 saturate_crt(float3 color, float amount) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return mix(float3(luma), color, amount);
}

float3 phosphor_gamut(float3 c, float strength) {
    float3x3 mat = float3x3(
        float3(1.0 + 0.08 * strength, -0.02 * strength,  0.0),
        float3(-0.02 * strength, 1.0 + 0.04 * strength,  -0.06 * strength),
        float3(0.0,              -0.02 * strength,  1.0 - 0.04 * strength)
    );
    return clamp(mat * c, 0.0, 1.0);
}

float scanline_mask(float y, float screenHeight, float intensity) {
    float s = sin(y * screenHeight * 0.5 * 3.14159265) * 0.5 + 0.5;
    s = pow(s, 1.5);
    return mix(1.0 - intensity, 1.0, s);
}

float vignette_factor(float2 uv) {
    return 1.0 - smoothstep(0.3, 0.75, length(uv - 0.5));
}

float flicker(float time) {
    return 1.0 + sin(time * 47.3) * 0.005;
}

float3 bloom_sample(texture2d<float> tex, sampler s, float2 uv, float2 texelSize, float radius) {
    float3 acc = float3(0.0);
    float total = 0.0;
    const int TAPS = 9;
    const float offsets[9] = { -4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0 };
    const float weights[9] = { 0.04, 0.08, 0.12, 0.16, 0.20, 0.16, 0.12, 0.08, 0.04 };
    for (int i = 0; i < TAPS; i++) {
        for (int j = 0; j < TAPS; j++) {
            float2 offset = float2(offsets[i], offsets[j]) * texelSize * radius;
            float  w      = weights[i] * weights[j];
            float3 samp   = tex.sample(s, uv + offset).rgb;
            float  luma   = dot(samp, float3(0.2126, 0.7152, 0.0722));
            float  bw     = w * smoothstep(0.4, 1.0, luma);
            acc += samp * bw;
            total += bw;
        }
    }
    return total > 0.0 ? acc / total : float3(0.0);
}

fragment float4 crt_fragment(VertexOut in [[stage_in]],
                              constant CRTUniforms &u [[buffer(0)]],
                              texture2d<float> screenTex [[texture(0)]],
                              sampler screenSampler [[sampler(0)]])
{
    float2 uv  = in.uv;
    float2 pos = in.position.xy;
    float  sl  = scanline_mask(uv.y, u.screenHeight, u.scanlineIntensity);
    float  vig = vignette_factor(uv);
    float  flk = flicker(u.time);

    if (u.mode == 0u) {
        float col = fmod(pos.x, 3.0);
        float3 triad;
        triad.r = exp(-pow(col - 0.0, 2.0) * 0.8) + exp(-pow(col - 3.0, 2.0) * 0.8);
        triad.g = exp(-pow(col - 1.0, 2.0) * 0.8);
        triad.b = exp(-pow(col - 2.0, 2.0) * 0.8);
        triad = clamp(triad, 0.0, 1.0);

        float3 color = triad.r * float3(1.00, 0.10, 0.05)
                     + triad.g * float3(0.05, 1.00, 0.10)
                     + triad.b * float3(0.05, 0.10, 1.00);

        float centerGlow = mix(1.0, 1.0 + u.glowIntensity * 0.5,
                               exp(-dot(uv - 0.5, uv - 0.5) * 3.0));
        color = color * centerGlow * sl * vig * flk;
        color = saturate_crt(color, u.colorSaturation);
        color = phosphor_gamut(color, u.colorSaturation - 1.0);

        float triadLuma = dot(triad, float3(0.333));
        float alpha     = clamp(mix(0.15, 0.55, u.scanlineIntensity) * vig * flk
                                * (0.4 + 0.6 * triadLuma) * sl, 0.0, 0.88);
        return float4(dither(pos, color * alpha, alpha), alpha);
    } else {
        float2 texelSize = float2(1.0 / u.screenWidth, 1.0 / u.screenHeight);
        float3 base      = screenTex.sample(screenSampler, uv).rgb;
        float  luma      = dot(base, float3(0.2126, 0.7152, 0.0722));
        float3 color     = mix(base,
                               base + bloom_sample(screenTex, screenSampler, uv, texelSize, 2.5),
                               smoothstep(0.3, 0.9, luma) * u.glowIntensity);
        color = saturate_crt(color, u.colorSaturation);
        color = phosphor_gamut(color, u.colorSaturation - 1.0);
        color = clamp(color * sl * vig * flk, 0.0, 1.0);

        float alpha = clamp(vig * flk, 0.0, 1.0);
        return float4(dither(pos, color * alpha, alpha), alpha);
    }
}
"""
}
