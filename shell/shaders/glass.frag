#version 440
// aurora's liquid glass. The optics come from the user's limn library: a
// convex bezel as wide as the corner radius refracts the backdrop, strongest
// at the rim, with a little chromatic dispersion. The middle shows the
// blurred backdrop (frost); toward the rim the lookup moves to the sharp
// scene, so what's behind visibly bends around the edge, as in Apple's
// Liquid Glass (refracting a blur alone is invisible). The result is
// saturated, veiled with the tint and lit along the rim: a soft band of
// light facing the top-left and, fainter, the opposite side, over a bright
// hairline with a faint dark line just inside it (iOS 27's edge).
//
// The outline is a rounded rectangle whose corners are superellipses
// (|x|^p + |y|^p = r^p): p = 2 is a circular arc, p ≈ 4 matches Apple's
// continuous corners. A tooltip adds a pointer to one edge, joined to the
// body with a soft fillet so the rim runs around both as one piece of glass.

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
    vec4 glow;       // press highlight: centre in item uv (xy), strength 0–1 (z); inner edge shade 0–1 (w)
    vec4 lens;       // magnification of the middle (x; 1 = none), rim bezel width in points (y; 0 = corner radius), edge on/off (z), bloom 0–1 (w)
    vec4 tail;       // pointer: apex x in points (x), half its base (y), length (z; 0 = none), on the bottom edge (w > 0) or the top (w < 0)
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D sharp;

const vec2 LIGHT = vec2(-0.5432, -0.8396); // normalized (-0.55, -0.85): top-left

// The body: the item without the room its pointer takes.
vec2 bodySize() {
    return vec2(itemSize.x, itemSize.y - max(tail.z, 0.0));
}

float cornerRadius() {
    vec2 size = bodySize();
    return min(radius, 0.5 * min(size.x, size.y));
}

// Signed distance to an isosceles triangle with its apex at the origin and
// its base (half-width q.x) at y = q.y (Inigo Quilez).
float triangle(vec2 p, vec2 q) {
    p.x = abs(p.x);
    vec2 a = p - q * clamp(dot(p, q) / dot(q, q), 0.0, 1.0);
    vec2 b = p - q * vec2(clamp(p.x / q.x, 0.0, 1.0), 1.0);
    float s = -sign(q.y);
    vec2 d = min(vec2(dot(a, a), s * (p.x * q.y - p.y * q.x)), vec2(dot(b, b), s * (p.y - q.y)));
    return -sqrt(d.x) * sign(d.y);
}

// Signed distance (approximate for p != 2) to the outline, in points.
float outline(vec2 p) {
    float r = cornerRadius();
    vec2 size = bodySize();
    vec2 origin = vec2(0.0, tail.w < 0.0 ? max(tail.z, 0.0) : 0.0);
    vec2 q = abs(p - origin - 0.5 * size) - 0.5 * size + vec2(r);
    vec2 c = max(q, vec2(0.0));
    float k = max(power, 1.0);
    float corner = pow(pow(c.x, k) + pow(c.y, k), 1.0 / k);
    float body = corner + min(max(q.x, q.y), 0.0) - r;
    if (tail.z < 0.5 || tail.y < 0.5)
        return body;
    // The pointer reaches into the body so the two always meet; its apex is
    // rounded a little, and a smooth union fillets the joints.
    float reach = tail.z + 4.0;
    vec2 local = vec2(p.x - tail.x, tail.w > 0.0 ? itemSize.y - p.y : p.y);
    float point = triangle(local - vec2(0.0, 1.0), vec2(tail.y * reach / tail.z, reach)) - 1.0;
    float f = 3.0;
    float h = clamp(0.5 + 0.5 * (point - body) / f, 0.0, 1.0);
    return mix(point, body, h) - f * h * (1.0 - h);
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

    // Bezel profile h(u) = (1 - u^k)^(1/k) across the band. A wide bezel
    // (panels, modules: k → 2, a quarter circle) bends smoothly all the way
    // to the edge, so the band visibly lenses what's behind it — a quartic
    // profile there only bent the outermost points and read as a flat
    // outline. A narrow bezel (a control's knob over its own labels: k → 4)
    // stays flat until the very edge, or the label gets pulled into the rim
    // as ghost text. Its slope tilts the surface normal, and a ray refracted
    // through it (n = 1.5) shifts the lookup inward; the shift fades in from
    // the very edge like a drop.
    // On a capsule the corner radius is half the height, so a bezel that
    // wide would bend the whole surface; lens.y keeps the bend to a rim and
    // leaves a flat middle, as Apple's lifted knobs do.
    float bezel = max(lens.y > 0.0 ? min(lens.y, cornerRadius()) : cornerRadius(), 4.0);
    float depth = clamp(-d / bezel, 0.0, 1.0);
    float u = 1.0 - depth;
    float k = clamp(24.0 / bezel, 2.0, 4.0);
    float slope = min(pow(u, k - 1.0) / pow(max(1.0 - pow(u, k), 1e-4), (k - 1.0) / k), 40.0);
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

    // Toward the rim, the sharp scene: the bent content stays legible there.
    float rimView = edgeOn * pow(1.0 - depth, 1.6) * 0.9;
    if (rimView > 0.002) {
        vec4 crisp = vec4(0.0);
        for (int i = 0; i < 3; i++) {
            vec2 at = uv + shift * (0.88 + 0.08 * float(i));
            vec4 tap = texture(sharp, at);
            if (material.y > 0.001) {
                tap.r = texture(sharp, at + spread).r;
                tap.b = texture(sharp, at - spread).b;
            }
            crisp += tap / 3.0;
        }
        scene = mix(scene, crisp, rimView);
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
    float shade = smoothstep(0.0, line, inset) * (1.0 - smoothstep(line, line + max(2.5, 0.25 * bezel), inset));
    // A solid knob drops it (glow.w = 0): Apple's reads as clean white with a lit rim.
    rgb *= 1.0 - 0.14 * shade * edgeOn * glow.w;
    // Lit from the top-left: the hairline is bright where the rim faces the
    // light, faint along the sides and a dim reflection on the far side —
    // never a uniform outline (Apple's dark pill, measured: the top edge
    // ~2.5x the sides, the bottom barely there).
    float facing = dot(normal, LIGHT);
    float toward = pow(max(facing, 0.0), 1.5);
    float away = pow(max(-facing, 0.0), 2.0);
    float glint = (1.0 - smoothstep(0.0, line, inset)) * (0.10 + 0.45 * toward + 0.08 * away) * edgeOn;
    rgb = mix(rgb, vec3(1.0), glint);
    // The specular band: light caught by the curved rim, lit the same way,
    // falling off exponentially over about a third of the bezel (Apple's
    // fades over ~4% of the shape, a soft gradient rather than a line).
    float caught = exp(-inset / max(0.3 * bezel, 1.5)) * edgeOn;
    float lit = 0.03 + 0.09 * toward + 0.02 * away;
    rgb = mix(rgb, vec3(1.0), caught * lit);
    // The rim is the glass's own light: over a clear source (a lens past
    // its control's edge) it still shows as an outline.
    alpha = mix(alpha, 1.0, max(glint, caught * lit));

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
