// The rim's GLSL: aurora's glass (shell/shaders/glass.frag) on a ring around
// the window instead of a filled shape. Same optics — a convex bezel that
// bends the lookup inward, five taps along the bend, a little dispersion,
// saturation, a tint veil, the hairline lit from the top-left with a faint
// shade inside it and the specular band — but in framebuffer pixels, with the
// bezel as wide as the rim and the scene read from a copy of what lies under
// the window. Uniform names are Hyprland's, so CShader resolves them.
#pragma once

namespace Aurora::Shaders {

    inline constexpr const char* VERT = R"glsl(#version 300 es
uniform mat3 proj;
in vec2 pos;
out vec2 v_pos;

void main() {
    gl_Position = vec4(proj * vec3(pos, 1.0), 1.0);
    v_pos       = pos;
}
)glsl";

    inline constexpr const char* FRAG = R"glsl(#version 300 es
precision highp float;
in vec2 v_pos;
layout(location = 0) out vec4 fragColor;

uniform mat3      proj;          // unit quad -> the rim's box in the target
uniform sampler2D tex;           // copy of the target: what is under the window
uniform vec2      fullSize;      // the rim's outer box, px
uniform float     radius;        // window corner radius, px
uniform float     radiusOuter;   // rim's outer corner radius, px
uniform float     roundingPower; // corner superellipse exponent (decoration:rounding_power)
uniform float     thick;         // rim width, px
uniform vec4      tint;          // straight rgba veil
uniform float     alpha;         // window fade
uniform vec4      optics;        // refraction px, dispersion px, px per point, focus 0-1
uniform vec4      light;         // saturation, edge light when focused, when not, unused

const vec2 LIGHT = vec2(-0.5432, -0.8396); // normalized (-0.55, -0.85): top-left

// Signed distance (approximate for p != 2) to a rounded box centred at 0.
float roundedBox(vec2 p, vec2 halfSize, float r) {
    r        = min(r, min(halfSize.x, halfSize.y));
    vec2 q   = abs(p) - halfSize + vec2(r);
    vec2 c   = max(q, vec2(0.0));
    float k  = max(roundingPower, 1.0);
    float cr = pow(pow(c.x, k) + pow(c.y, k), 1.0 / k);
    return cr + min(max(q.x, q.y), 0.0) - r;
}

float outline(vec2 p) {
    return roundedBox(p - 0.5 * fullSize, 0.5 * fullSize, radiusOuter);
}

// What lies under box point p: through the same projection the quad uses,
// so monitor transforms and the target's orientation come for free.
vec4 scene(vec2 p) {
    vec3 c = proj * vec3(p / fullSize, 1.0);
    return texture(tex, c.xy * 0.5 + 0.5);
}

void main() {
    vec2  p      = v_pos * fullSize;
    float px     = max(optics.z, 0.1);
    float d      = outline(p);
    float window = roundedBox(p - 0.5 * fullSize, 0.5 * fullSize - vec2(thick), radius);

    // Outer edge antialiased inward; the inner edge reaches a pixel under the
    // window, whose own antialiased corners then blend over glass, not a gap.
    float coverage = (1.0 - smoothstep(-1.0, 0.0, d)) * smoothstep(-1.5, -0.5, window);
    if (coverage <= 0.0)
        discard;

    const vec2 e      = vec2(0.5, 0.0);
    vec2       g      = vec2(outline(p + e.xy) - outline(p - e.xy), outline(p + e.yx) - outline(p - e.yx));
    vec2       normal = dot(g, g) > 1e-8 ? normalize(g) : vec2(0.0, -1.0);

    // Bezel h(u) = (1 - u^4)^(1/4) across the rim: steep at the outer edge,
    // flat where it meets the window. A ray refracted through it (n = 1.5)
    // lands further in, under the window.
    float depth = clamp(-d / max(thick, 1.0), 0.0, 1.0);
    float u     = 1.0 - depth;
    float slope = min(u * u * u / pow(max(1.0 - u * u * u * u, 1e-4), 0.75), 40.0);
    vec3  n     = normalize(vec3(normal * slope, 1.0));
    vec3  ray   = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / 1.5);
    vec2  bend  = ray.xy / max(-ray.z, 0.25) * smoothstep(0.0, 0.12, depth) / 0.4;

    vec2 shift  = bend * optics.x;
    vec2 spread = bend * optics.y;
    vec4 s      = vec4(0.0);
    for (int i = 0; i < 5; i++) {
        vec2 at  = p + shift * (0.84 + 0.08 * float(i));
        vec4 tap = scene(at);
        if (optics.y > 0.001) {
            tap.r = scene(at + spread).r;
            tap.b = scene(at - spread).b;
        }
        s += 0.2 * tap;
    }

    // Saturation on gamma RGB (the CSS saturate() weights), then the veil.
    float luma = dot(s.rgb, vec3(0.213, 0.715, 0.072));
    s.rgb      = clamp(mix(vec3(luma), s.rgb, light.x), vec3(0.0), vec3(s.a));
    float a    = s.a + tint.a * (1.0 - s.a);
    vec3  rgb  = mix(s.rgb, tint.rgb, tint.a) / max(a, 1e-5);

    // The edge: a bright hairline lit from the top-left and its opposite
    // side, a faint shade just inside it, and the light caught by the curve.
    float glintK = mix(light.z, light.y, optics.w);
    float line   = max(1.0, 0.75 * px);
    float inset  = -d;
    float shade  = smoothstep(0.0, line, inset) * (1.0 - smoothstep(line, line + 2.5 * px, inset));
    rgb *= 1.0 - 0.14 * shade;
    float facing = dot(normal, LIGHT);
    float glint  = (1.0 - smoothstep(0.0, line, inset)) * (0.25 + 0.65 * facing * facing) * glintK;
    rgb          = mix(rgb, vec3(1.0), glint);
    // A rim this thin is all bezel: the light it catches spans its width,
    // strongest at the outer edge, so it reads as a lit tube, not a line.
    float caught = pow(1.0 - smoothstep(0.0, thick, inset), 1.5);
    float lit    = (0.38 * pow(max(facing, 0.0), 2.0) + 0.16 * pow(max(-facing, 0.0), 2.0)) * glintK;
    rgb          = mix(rgb, vec3(1.0), caught * lit);
    a            = mix(a, 1.0, max(glint, caught * lit));

    // Where the glass meets the window, a soft dark line seats the window in it.
    rgb *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 1.5 * px, window));

    a *= coverage * alpha;
    fragColor = vec4(rgb * a, a); // premultiplied
}
)glsl";

}
