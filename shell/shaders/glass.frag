#version 440
// aurora's liquid glass. The optics come from the user's limn library: a
// convex bezel as wide as the corner radius refracts the (already blurred)
// backdrop, strongest at the rim, with a little chromatic dispersion; the
// result is saturated, veiled with the tint and lit by a one-pixel hairline
// facing the light, with a faint dark line just inside it (iOS 27's edge).
//
// The outline is a rounded rectangle whose corners are superellipses
// (|x|^p + |y|^p = r^p): p = 2 is a circular arc, p ≈ 4 matches Apple's
// continuous corners.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // item size, points
    vec4 mapping;    // backdrop uv of the item's top-left (xy) and its extent (zw)
    vec4 tint;       // straight rgba veil
    vec4 material;   // refraction pt, dispersion pt, saturation, dim
    float radius;    // corner radius, points
    float power;     // corner superellipse exponent
    float dpr;       // device pixels per point
    vec4 glow;       // press highlight: centre in item uv (xy), strength 0–1 (z)
    vec4 lens;       // magnification of the middle (x; 1 = none), rim bezel width in points (y; 0 = corner radius), edge on/off (z), bloom 0–1 (w)
};

layout(binding = 1) uniform sampler2D source;

const vec2 LIGHT = vec2(-0.5432, -0.8396); // normalized (-0.55, -0.85): top-left

float cornerRadius() {
    return min(radius, 0.5 * min(itemSize.x, itemSize.y));
}

// Signed distance (approximate for p != 2) to the outline, in points.
float outline(vec2 p) {
    float r = cornerRadius();
    vec2 q = abs(p - 0.5 * itemSize) - 0.5 * itemSize + vec2(r);
    vec2 c = max(q, vec2(0.0));
    float k = max(power, 1.0);
    float corner = pow(pow(c.x, k) + pow(c.y, k), 1.0 / k);
    return corner + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d = outline(p);
    float pixel = 1.0 / max(dpr, 0.1);
    float coverage = 1.0 - smoothstep(-0.8 * pixel, 0.8 * pixel, d);
    if (coverage <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Outward normal from the field's gradient.
    const vec2 e = vec2(0.5, 0.0);
    vec2 g = vec2(outline(p + e.xy) - outline(p - e.xy), outline(p + e.yx) - outline(p - e.yx));
    vec2 normal = dot(g, g) > 1e-8 ? normalize(g) : vec2(0.0, -1.0);

    // Bezel profile h(u) = (1 - u^4)^(1/4) across a band as wide as the
    // corner: steep at the edge, flat in the middle. Its slope tilts the
    // surface normal, and a ray refracted through it (n = 1.5) shifts the
    // lookup inward; the shift fades in from the very edge like a drop.
    // On a capsule the corner radius is half the height, so a bezel that
    // wide would bend the whole surface; lens.y keeps the bend to a rim and
    // leaves a flat middle, as Apple's lifted knobs do.
    float bezel = max(lens.y > 0.0 ? min(lens.y, cornerRadius()) : cornerRadius(), 4.0);
    float depth = clamp(-d / bezel, 0.0, 1.0);
    float u = 1.0 - depth;
    float slope = min(u * u * u / pow(max(1.0 - u * u * u * u, 1e-4), 0.75), 40.0);
    vec3 n = normalize(vec3(normal * slope, 1.0));
    vec3 ray = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / 1.5);
    vec2 bend = ray.xy / max(-ray.z, 0.25) * smoothstep(0.0, 0.12, depth) / 0.4;

    vec2 uvPerPoint = mapping.zw / itemSize;
    // Without an edge (lens.z = 0) the glass is flat: no rim bend, no
    // dispersion, no hairline — what a full-width bar wants.
    float edgeOn = lens.z;
    vec2 shift = bend * min(material.x, 0.88 * bezel) * uvPerPoint * edgeOn;
    vec2 spread = bend * material.y * uvPerPoint * edgeOn;
    // A lifted lens magnifies what's under its middle; the rim refraction
    // above still squeezes and mirrors the edges.
    vec2 local = (qt_TexCoord0 - vec2(0.5)) / max(lens.x, 0.01) + vec2(0.5);
    vec2 uv = mapping.xy + local * mapping.zw;

    // Several taps along the bend keep the squeezed rim smooth.
    vec4 scene = vec4(0.0);
    for (int i = 0; i < 5; i++) {
        vec2 at = uv + shift * (0.84 + 0.08 * float(i));
        vec4 tap = texture(source, at);
        if (material.y > 0.001) {
            tap.r = texture(source, at + spread).r;
            tap.b = texture(source, at - spread).b;
        }
        scene += 0.2 * tap;
    }

    // Saturation on gamma RGB (the CSS saturate() matrix weights), then the
    // optional dimming layer for clear glass over bright content.
    float luma = dot(scene.rgb, vec3(0.213, 0.715, 0.072));
    scene.rgb = clamp(mix(vec3(luma), scene.rgb, material.z), vec3(0.0), vec3(scene.a));
    scene.rgb *= 1.0 - material.w;

    float alpha = scene.a + tint.a * (1.0 - scene.a);
    vec3 rgb = mix(scene.rgb, tint.rgb, tint.a) / max(alpha, 1e-5);

    // The edge: a bright hairline lit from the top-left and its opposite
    // side, and a faint shade just inside it that separates glass from
    // whatever it sits on.
    float line = max(pixel, 0.75);
    float inset = -d;
    float shade = smoothstep(0.0, line, inset) * (1.0 - smoothstep(line, line + 2.5, inset));
    rgb *= 1.0 - 0.14 * shade * edgeOn;
    float facing = dot(normal, LIGHT);
    float glint = (1.0 - smoothstep(0.0, line, inset)) * (0.25 + 0.65 * facing * facing) * edgeOn;
    rgb = mix(rgb, vec3(1.0), glint);

    // Interactive glass brightens under the pointer while pressed: a wide,
    // soft lift centred on the press point (about +8% luminance at full
    // strength, as measured in Apple's interactive glass examples).
    if (glow.z > 0.001) {
        vec2 off = (qt_TexCoord0 - glow.xy) * itemSize;
        float reach = 0.75 * max(itemSize.x, itemSize.y);
        float lift = glow.z * (0.55 + 0.45 * exp(-dot(off, off) / (reach * reach)));
        rgb = mix(rgb, vec3(1.0), 0.14 * lift);
    }

    // Materializing: the glass blooms into a milky, near-opaque white while a
    // menu pops out, then clears to the material as it takes its shape.
    rgb = mix(rgb, vec3(1.0), lens.w);
    alpha = mix(alpha, 1.0, 0.7 * lens.w);

    float a = alpha * coverage * qt_Opacity;
    fragColor = vec4(rgb * a, a);
}
