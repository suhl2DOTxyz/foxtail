#version 440
// Foxtail "Liquid Glass" material.
//
// Modelled on Apple's description of Liquid Glass (WWDC25 "Meet Liquid
// Glass"): a frosted slab that *lenses* what is behind it at its edges, with a
// thin specular sheen that defines its silhouette, and a tint that adapts to
// the content underneath so text on it stays legible.
//
// Shape. The footprint is a rounded rectangle. Across a bezel band at the
// edge the surface rises like a squircle, h(t) = (1 - (1-t)^k)^(1/k), which
// meets the flat middle with zero slope - no visible seam where the curve
// ends (a quarter circle has a curvature jump there).
//
// Lensing. Each pixel's surface normal refracts a straight-down view ray
// (Snell's law, glass IOR 1.5). The ray travels *inward* under a convex rim,
// so the rim shows the backdrop from slightly further in: content under the
// edge is magnified and bends as it passes beneath, as with a real lens.
// Blue bends a little more than red (dispersion), visible only at the lip.
//
// Compositing. The compositor blurs whatever is behind this layer live (see
// hypr/foxtail.lua); the shader only paints the lensed band, the tint and
// the highlights on top. The band samples a screen snapshot (or the
// wallpaper): nearly sharp at the lip, where the lens is clearest and
// content visibly bends, frosting toward the middle to `blurred` - blurred
// like the compositor's blur - and handing over to the live blur there.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // px
    vec4 screenRect;    // item rect on the backdrop, normalized (x, y, w, h)
    float radius;       // corner radius, px
    float bezel;        // width of the curved rim, px
    float thickness;    // dome height relative to the bezel width
    float refraction;   // largest inward displacement (at the lip), px
    float dispersion;   // chromatic split, 0..1
    vec4 tint;          // rgb + base amount (non-premultiplied)
    float rimLight;     // strength of the specular sheen
    float dark;         // 0 light, 1 dark
    vec2 light;         // light position in item coords (0..1, may lie outside)
    float rimOpacity;   // how strongly the lensed band covers the live blur
    float exposure;     // brightness of what sits behind (e.g. 0.75 under a 25% dim)
    float adapt;        // 0..1: raise the tint where the backdrop fights the text
    float contrast;     // 0 "Clear" .. 1 "Tinted" (macOS 26.1 Liquid Glass setting)
    float materialize;  // 0..1: lensing and sheen ramp in as the glass appears
    float clarity;      // 0..1: how clear (unfrosted) the lens is at the lip
    vec3 press;         // xy: where it is pressed (item coords), z: glow 0..1
};

layout(binding = 1) uniform sampler2D backdrop;   // sharp(ish) snapshot
layout(binding = 2) uniform sampler2D blurred;    // the same, frosted

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

vec2 toUv(vec2 px) {
    return clamp(screenRect.xy + (px / itemSize) * screenRect.zw, vec2(0.001), vec2(0.999));
}

// The backdrop at `px`, frosted by `f` (0 = as captured, 1 = fully blurred).
vec3 sampleBackdrop(vec2 px, float f) {
    vec2 uv = toUv(px);
    vec3 sharp = f < 0.999 ? texture(backdrop, uv).rgb : vec3(0.0);
    vec3 soft = f > 0.001 ? texture(blurred, uv).rgb : vec3(0.0);
    return mix(sharp, soft, f);
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// Sideways shift per unit depth of a vertical ray refracted by a surface
// tilted by angle a (sin a given), for refractive index `ior`.
float lensShift(float sinA, float ior) {
    float a = asin(sinA);
    float b = asin(sinA / ior);
    return tan(a - b);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    vec2 p = px - halfSize;
    float r = min(radius, min(halfSize.x, halfSize.y));

    float d = sdRoundBox(p, halfSize, r);
    float coverage = clamp(0.5 - d, 0.0, 1.0);          // antialiased edge
    if (coverage <= 0.0) { fragColor = vec4(0.0); return; }

    float inset = max(-d, 0.0);                          // px in from the edge
    vec2 outward = sdNormal(p, halfSize, r);
    float grow = clamp(materialize, 0.0, 1.0);

    // ---- surface ------------------------------------------------------------
    const float k = 3.0;
    float b = max(bezel, 1.0);
    float t = clamp(inset / b, 0.0, 1.0);               // 0 at the edge, 1 on the plateau
    float u = 1.0 - t;
    float slope = pow(u, k - 1.0) * pow(max(1.0 - pow(u, k), 1e-4), 1.0 / k - 1.0);
    slope = min(slope * thickness, 14.0);               // dh/d(inset), clamped at the lip
    float sinA = slope / sqrt(1.0 + slope * slope);     // tilt of the surface normal

    // ---- lensing ------------------------------------------------------------
    const float ior = 1.5;
    float maxShift = lensShift(0.9999, ior);            // a ray grazing the lip
    float reach = refraction * grow / maxShift;
    vec2 inward = -outward;
    float split = 0.035 * dispersion;
    // Clearest right at the lip, frosting over toward the middle.
    float frost = 1.0 - clarity * pow(1.0 - t, 1.5);
    vec3 lens;
    lens.r = sampleBackdrop(px + inward * reach * lensShift(sinA, ior - split), frost).r;
    lens.g = sampleBackdrop(px + inward * reach * lensShift(sinA, ior), frost).g;
    lens.b = sampleBackdrop(px + inward * reach * lensShift(sinA, ior + split), frost).b;
    // A lens gathers light: the curved band reads a touch brighter, and glass
    // gives what it shows a slight lift in saturation (macOS "vibrancy").
    lens = mix(vec3(luma(lens)), lens, 1.22) * exposure * (1.0 + 0.06 * (1.0 - t));

    // The lensed band covers the live blur near the edge and hands over to it
    // across the inner part of the bezel.
    float band = (1.0 - smoothstep(0.2, 1.0, t)) * rimOpacity * grow;

    // ---- adaptive tint --------------------------------------------------------
    // Raise the tint just enough that the glass under text keeps the contrast
    // the text needs: dark text in light mode, light text in dark mode.
    float lb = luma(texture(blurred, toUv(px)).rgb) * exposure;
    float tintLuma = luma(tint.rgb);
    float need;
    if (dark < 0.5) {
        float target = mix(0.60, 0.74, contrast);
        need = lb < target ? (target - lb) / max(tintLuma - lb, 0.05) : 0.0;
    } else {
        float target = mix(0.40, 0.28, contrast);
        need = lb > target ? (lb - target) / max(lb - tintLuma, 0.05) : 0.0;
    }
    float baseTint = tint.a + contrast * 0.12;
    float tintA = clamp(max(baseTint, mix(baseTint, need, adapt)), 0.0, 0.92);

    // Premultiplied result over the compositor's live blur C:
    //   screen = tint over mix(C, lens, band)
    vec3 rgb = tintA * tint.rgb + (1.0 - tintA) * band * lens;
    float alpha = tintA + band - tintA * band;

    // ---- bevel shading -------------------------------------------------------
    // Like Apple's controls, the slab reads as a pillow: just inside the
    // bright lip, the curved band turned away from the light falls into a
    // soft shade (strongest along the bottom), and the top of the slab is a
    // touch lighter than its bottom.
    vec2 toKey = light * itemSize - px;
    float away = max(-dot(outward, toKey / max(length(toKey), 1e-3)), 0.0);
    float bandIn = smoothstep(0.8, 2.5, inset) * (1.0 - smoothstep(3.0, max(b * 0.55, 6.0), inset));
    float shade = bandIn * (0.25 + 0.75 * away) * mix(0.13, 0.20, dark) * grow;
    rgb *= 1.0 - shade;
    alpha += shade * (1.0 - alpha);

    // ---- specular sheen -----------------------------------------------------
    // Light from `light` grazes the rim: brightest where the edge faces it,
    // with a fainter return on the opposite side (light that crossed the slab).
    vec2 toLight = light * itemSize - px;
    vec2 ldir = toLight / max(length(toLight), 1e-3);
    float facing = dot(outward, ldir);
    float lit = pow(max(facing, 0.0), 1.5) + 0.55 * pow(max(-facing, 0.0), 1.8);
    float lip = 1.0 - smoothstep(0.6, 2.2, inset);                     // crisp ~2px line
    float glow = pow(1.0 - smoothstep(0.0, b * 0.7, inset), 2.0);      // soft inner falloff
    // Light also enters the top of the slab: a faint sky gradient.
    float sky = (1.0 - qt_TexCoord0.y) * mix(0.06, 0.03, dark);
    // The lip catches light all the way round (Apple's glass has a clear
    // bright rim), brightest where the edge faces the light and on the
    // opposite corner, where light that crossed the slab comes back out.
    float sheen = lip * (0.30 + 0.70 * lit) + glow * 0.26 * lit + sky;
    sheen *= rimLight * grow * mix(1.0, 0.75, dark);

    // Pressed glass lights up from within, starting under the pointer and
    // spreading through the whole piece as the glow grows.
    if (press.z > 0.001) {
        vec2 dp = (qt_TexCoord0 - press.xy) * itemSize / max(itemSize.x, itemSize.y);
        float reachG = 0.25 + 0.9 * press.z;
        sheen += press.z * 0.22 * exp(-dot(dp, dp) / (reachG * reachG * 0.5));
    }

    rgb += vec3(sheen);
    alpha = clamp(alpha + sheen, 0.0, 1.0);

    float a = coverage * qt_Opacity;
    fragColor = vec4(rgb * a, alpha * a);
}
