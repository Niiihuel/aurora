#version 440
// One pass of a separable Gaussian blur. Run it twice (horizontal, then
// vertical) for a full 2D blur. Weights are computed from `sigma` on the fly
// and normalized, so any sigma up to ~6.6 texels (3σ ≤ 20 taps) is exact.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texelStep; // one texel along the blur direction, in uv
    float sigma;    // standard deviation, in texels
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float s = max(sigma, 0.001);
    float reach = min(ceil(3.0 * s), 20.0);
    float twoSigmaSq = 2.0 * s * s;

    vec4 sum = vec4(0.0);
    float total = 0.0;
    for (int i = -20; i <= 20; i++) {
        float x = float(i);
        if (abs(x) > reach)
            continue;
        float w = exp(-(x * x) / twoSigmaSq);
        sum += texture(source, qt_TexCoord0 + texelStep * x) * w;
        total += w;
    }
    fragColor = (sum / total) * qt_Opacity;
}
