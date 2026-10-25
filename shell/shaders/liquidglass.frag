#version 440
// Foxtail "Liquid Glass" material.
//
// The panel is modelled as a slab of glass whose footprint is a rounded
// rectangle. Inside a bevel band near the edge the surface curves down like
// a quarter-circle (a dome edge); the flat middle is clear.
//
// From that height field we get a 3D surface normal per pixel and use it for:
//  - refraction: the curved rim bends light, so it shows the backdrop from
//    just *outside* the panel, compressed inward - Apple's signature look -
//    with a per-channel split for chromatic dispersion;
//  - Fresnel: grazing angles near the rim reflect more of a bright "sky";
//  - specular: a Blinn-Phong highlight from a movable light (it follows the
//    pointer on the Dock), which naturally forms an arc along the lit edge;
//  - a thin dark contact line just inside the edge on the shadowed side for
//    definition on light backdrops.
//
// The flat center only carries the tint: the compositor's live blur shows
// through, so windows behind the panel stay visible (the wallpaper texture is
// only ever sampled in the bevel).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // px
    vec4 screenRect;    // item rect on the backdrop, normalized (x, y, w, h)
    float radius;       // corner radius, px
    float bezel;        // width of the curved rim, px
    float refraction;   // how far the rim reaches outward for its image, px
    float dispersion;   // chromatic split, 0..1
    float frost;        // backdrop blur radius in the rim, px
    vec4 tint;          // rgb + amount (non-premultiplied)
    float rimLight;     // specular / Fresnel strength
    float dark;         // 0 light, 1 dark
    vec2 light;         // light position in item coords (0..1, may exceed)
    float rimOpacity;   // max opacity of the refracted rim (lower over windows)
    float exposure;     // brightness of what sits behind (e.g. 0.75 under a 25% dim)
};

layout(binding = 1) uniform sampler2D backdrop;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 sdNormal(vec2 p, vec2 halfSize, float r) {
    const float e = 0.75;
    float dx = sdRoundBox(p + vec2(e, 0.0), halfSize, r) - sdRoundBox(p - vec2(e, 0.0), halfSize, r);
    float dy = sdRoundBox(p + vec2(0.0, e), halfSize, r) - sdRoundBox(p - vec2(0.0, e), halfSize, r);
    vec2 n = vec2(dx, dy);
    float l = length(n);
    return l > 0.0001 ? n / l : vec2(0.0);
}

vec3 sampleBackdrop(vec2 px) {
    vec2 uv = screenRect.xy + (px / itemSize) * screenRect.zw;
    return texture(backdrop, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

// 9-tap frosted sample.
vec3 frosted(vec2 px, float r) {
    if (r < 0.5) return sampleBackdrop(px);
    vec3 c = sampleBackdrop(px) * 0.2;
    c += sampleBackdrop(px + vec2( r, 0.0)) * 0.1;
    c += sampleBackdrop(px + vec2(-r, 0.0)) * 0.1;
    c += sampleBackdrop(px + vec2(0.0,  r)) * 0.1;
    c += sampleBackdrop(px + vec2(0.0, -r)) * 0.1;
    c += sampleBackdrop(px + vec2( r,  r) * 0.7071) * 0.1;
    c += sampleBackdrop(px + vec2(-r,  r) * 0.7071) * 0.1;
    c += sampleBackdrop(px + vec2( r, -r) * 0.7071) * 0.1;
    c += sampleBackdrop(px + vec2(-r, -r) * 0.7071) * 0.1;
    return c;
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    vec2 p = px - halfSize;
    float r = min(radius, min(halfSize.x, halfSize.y));

    float d = sdRoundBox(p, halfSize, r);
    float coverage = clamp(0.5 - d, 0.0, 1.0);          // antialiased edge
    if (coverage <= 0.0) { fragColor = vec4(0.0); return; }

    float inset = max(-d, 0.0);                          // px from the edge
    vec2 outward = sdNormal(p, halfSize, r);

    // ---- surface: quarter-circle bevel -------------------------------------
    float b = max(bezel, 1.0);
    float x = clamp(inset / b, 0.0, 1.0);               // 0 at edge, 1 at plateau
    float u = 1.0 - x;
    // h(x) = sqrt(1 - u^2); slope dh/dx = u / sqrt(1 - u^2), clamped at the lip.
    float slope = u / sqrt(max(1.0 - u * u, 0.04));
    vec3 n = normalize(vec3(outward * slope * 0.9, 1.0)); // tilts outward at the rim
    float edgeness = 1.0 - n.z;                          // 0 flat .. ~1 at the lip

    // ---- refraction ----------------------------------------------------------
    // Look outward through the curved rim: the surroundings get pulled in.
    float bend = smoothstep(0.0, 1.0, edgeness * 1.6);
    vec2 offs = outward * refraction * bend;
    float split = dispersion * bend;
    vec3 refr;
    refr.r = frosted(px + offs * (1.0 + 0.18 * split), frost).r;
    refr.g = frosted(px + offs, frost).g;
    refr.b = frosted(px + offs * (1.0 - 0.18 * split), frost).b;
    // Lenses concentrate light: lift the rim a touch, more in dark mode.
    refr *= exposure * (1.0 + mix(0.06, 0.12, dark) * bend);
    refr = mix(refr, tint.rgb, tint.a * 0.35);

    // Rim coverage: the refracted image fades in across the bevel.
    float m = smoothstep(0.0, 0.85, bend);
    vec3 col = mix(tint.rgb, refr, m);
    float alpha = mix(tint.a, max(rimOpacity, tint.a), m);

    // ---- light ---------------------------------------------------------------
    // Light position -> 3D direction from this pixel (slightly above the panel).
    vec2 lp = (light - qt_TexCoord0) * itemSize / max(itemSize.x, itemSize.y);
    vec3 L = normalize(vec3(lp * 1.4, 0.55));
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 H = normalize(L + V);

    float spec = pow(max(dot(n, H), 0.0), 22.0) * smoothstep(0.02, 0.45, edgeness);
    // Secondary, softer reflection on the far side (light bouncing inside the slab).
    vec3 L2 = normalize(vec3(-lp * 1.4, 0.55));
    float spec2 = pow(max(dot(n, normalize(L2 + V)), 0.0), 18.0) * smoothstep(0.02, 0.45, edgeness);

    // Fresnel: grazing angles mirror a bright sky.
    float fres = pow(edgeness, 2.2);
    vec3 sky = mix(vec3(1.0), vec3(0.85, 0.88, 0.95), dark);

    // Crisp 1px lip highlight around the whole edge, brighter toward the light.
    float lit = clamp(dot(outward, normalize(lp + vec2(1e-4))) * 0.5 + 0.5, 0.0, 1.0);
    float lip = smoothstep(1.2, 0.0, inset) * mix(0.08, 1.0, lit * lit);

    // Contact line: a whisper of darkness just inside the edge, on the side
    // away from the light - gives the slab a visible thickness on light backdrops.
    float contact = smoothstep(0.0, 2.0, inset) * (1.0 - smoothstep(2.0, 5.0, inset)) * (1.0 - lit);
    col *= 1.0 - contact * mix(0.10, 0.04, dark);

    // Inner sheen: a soft vertical gradient on the plateau, brightest at the top.
    float sheen = (1.0 - qt_TexCoord0.y) * 0.06 * (1.0 - m) * (1.0 - dark * 0.6);

    // Dark glass reflects less: keep highlights crisp but small.
    float hot = mix(1.0, 0.55, dark);
    vec3 glow = sky * (fres * 0.22 + lip * 0.6) * mix(1.0, 0.8, dark) + vec3((spec * 1.2 + spec2 * 0.3) * hot + sheen);
    col += glow * rimLight;
    alpha = clamp(alpha + (fres * 0.2 + lip * 0.5 + spec * 0.8) * rimLight, 0.0, 1.0);

    float a = alpha * coverage * qt_Opacity;
    fragColor = vec4(col * a, a);
}
