// VELVET · assets/shaders/dotface.frag — Velly's face (modules/island/VellyFace.qml): a
// round dot-matrix display. Every dot of the grid asks the face what it shows there —
// two eyes that blink, look about, go wide, smile or cross; cheeks; a mouth that idles,
// smiles and speaks; a comet of dots round the rim while she thinks; a ripple when she
// wakes — and round the display a halo of dot rays riding her voice and yours.
// The face works in dot units (one dot = 1, the middle dot at 0, y down).
// Rebuild: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o dotface.frag.qsb dotface.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float px;       // one screen pixel, in face units (the item spans -1 … 1)
    float time;     // seconds, for the idle motion
    float grid;     // dots across the display (odd)
    vec4 ink;       // a lit dot (premultiplied, like every colour here)
    vec4 off;       // an unlit dot
    vec4 hot;       // the accent dots: cheeks, the comet's head
    vec4 glass;     // the display's ground
    vec4 eye;       // x open (0 shut … 1), y smile, z cross (error), w wide (listening)
    vec4 look;      // xy where the eyes look (dots), z cheeks, w mouth open (speaking)
    vec4 mouthA;    // the mouth's eight bars while she speaks, 0 … 1
    vec4 mouthB;
    vec4 haloA;     // the halo's sixteen bands, 0 … 1 (top … bottom, both sides alike)
    vec4 haloB;
    vec4 haloC;
    vec4 haloD;
    vec4 mode;      // x think, y halo strength, z energy, w wake ripple (0 … 1, once)
};

const float PI = 3.14159265;
const float R = 0.74;        // the display's radius; the halo lives outside it

float band16(int i) {
    vec4 v = i < 4 ? haloA : (i < 8 ? haloB : (i < 12 ? haloC : haloD));
    int j = i - (i / 4) * 4;
    return j == 0 ? v.x : (j == 1 ? v.y : (j == 2 ? v.z : v.w));
}

float bar8(int i) {
    vec4 v = i < 4 ? mouthA : mouthB;
    int j = i - (i / 4) * 4;
    return j == 0 ? v.x : (j == 1 ? v.y : (j == 2 ? v.z : v.w));
}

float roundRect(vec2 q, vec2 hs, float r) {
    vec2 a = abs(q) - (hs - r);
    return length(max(a, 0.0)) + min(max(a.x, a.y), 0.0) - r;
}

// one eye, centred at c: the tall rounded block, the smile's arch or the cross
float eyeAt(vec2 q, vec2 c) {
    vec2 e = q - c;
    float open = clamp(eye.x, 0.0, 1.0);
    float hw = 2.0 + 0.4 * eye.w;
    float hh = max(0.5, (3.2 + 0.8 * eye.w) * open);
    float block = clamp(0.62 - roundRect(e, vec2(hw, hh), 1.1), 0.0, 1.0);
    // the smile: the top half of a ring, an upturned arch
    float ring = abs(length(e - vec2(0.0, 1.6)) - 2.5) - 0.55;
    float arch = clamp(0.62 - ring, 0.0, 1.0) * step(e.y, 1.0);
    float b = mix(block, arch, clamp(eye.y, 0.0, 1.0));
    // an error crosses them out
    float x = abs(abs(e.x) - abs(e.y)) - 0.45;
    float cross = clamp(0.62 - x, 0.0, 1.0) * step(max(abs(e.x), abs(e.y)), 2.2);
    return mix(b, cross, clamp(eye.z, 0.0, 1.0));
}

// what the face shows at dot q: (lit, accent)
vec2 face(vec2 q, float rim) {
    float gaze = 1.0 - 0.25 * mode.x;
    vec2 at = vec2(clamp(look.x, -2.2, 2.2), clamp(look.y, -2.0, 1.6));
    float eyeY = -1.5 + at.y;
    float lit = max(eyeAt(q, vec2(-4.0 + at.x, eyeY)), eyeAt(q, vec2(4.0 + at.x, eyeY))) * gaze;

    // the mouth: idling as three soft dots, curving up in a smile, a row of bars as she speaks
    float my = 5.0 + at.y * 0.4;
    float mx = q.x - at.x * 0.5;
    float idle = (1.0 - step(1.5, abs(mx))) * (1.0 - step(0.5, abs(q.y - my))) * 0.55;
    float curve = (1.0 - step(2.5, abs(mx))) * (1.0 - step(0.55, abs(q.y - (my - 0.25 * mx * mx + 0.5))));
    float shape = mix(idle, curve, clamp(eye.y, 0.0, 1.0));
    int col = int(clamp(floor(mx + 4.0), 0.0, 7.0));
    float hb = 0.5 + bar8(col) * 2.6;
    float talk = (1.0 - step(4.0, abs(mx + 0.5))) * (1.0 - step(hb, abs(q.y - my)));
    float mouth = mix(shape, talk, clamp(look.w, 0.0, 1.0)) * (1.0 - clamp(eye.z, 0.0, 1.0) * 0.6);
    lit = max(lit, mouth);

    // the cheeks: two accent dots under each eye's outer corner
    float accent = 0.0;
    for (int s = -1; s <= 1; s += 2) {
        vec2 c = vec2(float(s) * 6.5 + at.x, eyeY + 4.5);
        float d = max(abs(q.y - c.y), abs(q.x - c.x) - 0.5);
        accent = max(accent, (1.0 - step(0.5, d)) * clamp(look.z, 0.0, 1.0));
    }

    // thinking: a comet runs round the rim, its head in the accent
    if (mode.x > 0.001) {
        float r = length(q);
        float a = atan(q.y, q.x);
        float behind = mod(time * 5.2 - a, 2.0 * PI);
        float on = 1.0 - smoothstep(0.45, 0.9, abs(r - rim));
        float tail = exp(-behind * 1.25);
        lit = max(lit, on * tail * mode.x);
        accent = max(accent, on * step(behind, 0.35) * mode.x);
    }

    // waking: one ripple runs out from the middle
    if (mode.w > 0.001 && mode.w < 0.999) {
        float wave = exp(-pow(length(q) - mode.w * (rim + 3.0), 2.0) * 0.9) * (1.0 - mode.w);
        lit = max(lit, wave);
    }
    return vec2(clamp(lit, 0.0, 1.0), clamp(accent, 0.0, 1.0));
}

vec4 over(vec4 src, vec4 dst) {
    return src + dst * (1.0 - src.a);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float rho = length(p);
    vec4 col = vec4(0.0);

    // ── the display: its glass, a reflection across the upper left, the rim
    float inside = smoothstep(R + px, R - px, rho);
    col = glass * inside;
    float refl = smoothstep(0.03, -0.03, p.x * 0.55 + p.y + 0.18) * smoothstep(R, R * 0.2, rho);
    col = over(ink * (0.035 * refl * inside), col);
    float rimLine = 1.0 - smoothstep(0.0, px * 1.6, abs(rho - (R + 0.022)));
    col = over(ink * (0.22 * rimLine), col);

    // ── the dots
    float n = grid;
    float cell = 2.0 * R / n;
    vec2 g = (p + R) / cell;
    vec2 ci = floor(g);
    vec2 cc = (ci + 0.5) * cell - R;
    vec2 q = ci + 0.5 - n * 0.5;
    float dist = length(p - cc);
    float r = cell * 0.36;
    float dotMask = smoothstep(r + px, r - px, dist) * step(length(cc), R - cell * 0.45);
    float glow = exp(-dist * dist / (r * r * 2.6)) * step(length(cc), R - cell * 0.45);
    float breathe = 0.93 + 0.07 * sin(time * 1.7);
    vec2 f = face(q, n * 0.5 - 1.6);
    col = over(off * (dotMask * (1.0 - max(f.x, f.y))), col);
    col = over(ink * (f.x * breathe * dotMask), col);
    col += ink * (f.x * glow * 0.38 * breathe);
    col = over(hot * (f.y * dotMask), col);
    col += hot * (f.y * glow * 0.45);

    // ── the halo: rays of dots round the display, as long as the band says
    float h0 = R + 0.075;
    float step_ = cell * 0.62;
    if (rho > h0 - step_ && rho < 1.0) {
        const float K = 72.0;
        float phi = atan(p.y, p.x);
        float k = floor(phi / (2.0 * PI / K) + 0.5);
        float th = k * 2.0 * PI / K;
        float along = rho * cos(phi - th);
        float across = rho * sin(phi - th);
        float j = floor((along - h0) / step_ + 0.5);
        float m = floor((1.0 - h0) / step_);
        if (j >= 0.0 && j < m) {
            float sj = h0 + j * step_;
            float rr = r * (0.8 - 0.35 * j / m);
            float d = length(vec2(along - sj, across));
            float mask = smoothstep(rr + px, rr - px, d);
            // the band for this ray: top … bottom, mirrored left and right
            float t = fract((th + PI * 0.5) / (2.0 * PI));
            float mir = 1.0 - abs(2.0 * t - 1.0);
            float lvl = band16(int(clamp(floor(mir * 15.99), 0.0, 15.0)));
            float idle = 0.18 + 0.14 * sin(time * 1.3 + th * 3.0) + 0.06 * sin(time * 2.1 - th * 5.0);
            float level = clamp(mix(idle, lvl, clamp(mode.z, 0.0, 1.0)), 0.0, 1.0);
            float reach = 1.0 + level * (m - 1.0);
            float on = (1.0 - smoothstep(reach - 0.5, reach + 0.5, j + 0.5)) * (1.0 - 0.5 * j / m);
            float s = clamp(mode.y, 0.0, 1.0);
            col = over(off * (mask * 0.7 * s), col);
            col = over(ink * (mask * on * s * 0.9), col);
        }
    }

    fragColor = col * qt_Opacity;
}
