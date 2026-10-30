// VELVET · assets/shaders/velvet.frag — Velly herself (modules/island/VellyFace.qml): a
// little ball of velvet. Velvet is dark where it faces you and glows where it turns
// away, so the ball has a deep middle and a soft bright rim, a fine pile on it, and
// a fuzz round its edge that stands up with the voice (yours while she listens, hers
// while she speaks). Two glowing eyes blink, look about, go wide, squint happily
// or cross out; cheeks blush; a mouth moves as she talks. Thinking, she kneads
// herself and a sheen runs round her; waking, she squashes and a ring runs out.
// Rebuild: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o velvet.frag.qsb velvet.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float px;       // one screen pixel, in face units (the item spans -1 … 1)
    float time;     // seconds
    float squash;   // -1 flattened … 0 round … 1 stretched (a hop, a squeeze)
    vec4 deep;      // the velvet where it faces you (premultiplied, like every colour)
    vec4 sheen;     // where it turns away: the glowing rim and the fuzz
    vec4 ink;       // the eyes
    vec4 blush;     // the cheeks
    vec4 eye;       // x open (0 shut … 1), y smile, z cross (error), w wide (listening)
    vec4 look;      // xy where she looks (-1 … 1), z cheeks, w mouth open (speaking)
    vec4 mouthA;    // the voice for the mouth, eight bars, 0 … 1
    vec4 mouthB;
    vec4 haloA;     // the voice round the rim, sixteen bands (top … bottom, both sides)
    vec4 haloB;
    vec4 haloC;
    vec4 haloD;
    vec4 mode;      // x think, y fuzz (0 … 1), z energy (the voice counts), w wake ring (0 … 1)
};

const float PI = 3.14159265;

float band16(int i) {
    vec4 v = i < 4 ? haloA : (i < 8 ? haloB : (i < 12 ? haloC : haloD));
    int j = i - (i / 4) * 4;
    return j == 0 ? v.x : (j == 1 ? v.y : (j == 2 ? v.z : v.w));
}

float voice() {
    return (mouthA.x + mouthA.y + mouthA.z + mouthA.w + mouthB.x + mouthB.y + mouthB.z + mouthB.w) / 8.0;
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 over(vec4 src, vec4 dst) {
    return src + dst * (1.0 - src.a);
}

float cover(float d) {
    return smoothstep(px * 1.2, -px * 1.2, d);
}

// one eye at c (ball units): a soft upright capsule, the smile's arch, or a cross
float eyeShape(vec2 q, vec2 c) {
    vec2 e = q - c;
    float open = clamp(eye.x, 0.0, 1.0);
    float w = 0.045 * (1.0 + 0.18 * eye.w);
    float h = max(0.004, 0.07 * (1.0 + 0.3 * eye.w) * open);
    float capsule = length(vec2(e.x, max(abs(e.y) - h, 0.0))) - w;
    float body = cover(capsule);
    // the smile: the top of a ring, an upturned arch
    float arch = cover(abs(length(e - vec2(0.0, 0.045)) - 0.06) - 0.016) * step(e.y, 0.03);
    float b = mix(body, arch, clamp(eye.y, 0.0, 1.0));
    // crossed out
    float x = abs(abs(e.x) - abs(e.y)) - 0.014;
    float cross = cover(x) * step(max(abs(e.x), abs(e.y)), 0.06);
    return mix(b, cross, clamp(eye.z, 0.0, 1.0));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    vec4 col = vec4(0.0);

    // ── where she sits: a little bob, the squash
    float bob = 0.02 * sin(time * 1.7) * (1.0 - 0.6 * mode.x);
    vec2 q = p - vec2(0.0, bob);
    float s = clamp(squash, -1.0, 1.0);
    q = vec2(q.x * (1.0 + 0.14 * s), q.y * (1.0 - 0.14 * s));

    // ── the ground under her: a soft shadow that shrinks as she rises
    float R = 0.56;
    vec2 sp = (p - vec2(0.0, R + 0.25)) * vec2(1.35, 5.0);
    float shade = exp(-dot(sp, sp) * 2.2) * 0.32 * (1.0 - 6.0 * max(bob, 0.0));
    col = vec4(0.0, 0.0, 0.0, 1.0) * shade;

    // ── the outline: round, its fuzz standing up with the voice, kneaded while she thinks
    float th = atan(q.y, q.x);
    float t = fract((th + PI * 0.5) / (2.0 * PI));
    float mir = 1.0 - abs(2.0 * t - 1.0);
    // the bands blend into each other round the rim: a soft fuzz, never steps
    float fb = mir * 15.0;
    float lvl = mix(band16(int(floor(fb))), band16(int(min(15.0, floor(fb) + 1.0))), fract(fb));
    float idle = 0.5 + 0.5 * sin(time * 1.3 + th * 3.0);
    float fuzz = clamp(mode.y, 0.0, 1.0);
    float swell = mix(0.012 * idle, 0.09 * lvl, clamp(mode.z, 0.0, 1.0)) * fuzz;
    float knead = clamp(mode.x, 0.0, 1.0) * 0.03 * sin(th * 3.0 - time * 2.6);
    float r = R * (1.0 + swell + knead);
    float rho = length(q);
    float d = rho - r;
    float inside = cover(d);

    // ── the velvet: deep where it faces you, glowing where it turns away, a soft
    // light from above, the pile's fine grain
    float z = sqrt(max(0.0, 1.0 - pow(min(rho / r, 1.0), 2.0)));
    float fres = pow(1.0 - z, 2.0);
    vec3 n = normalize(vec3(q / r, max(z, 0.05)));
    float lit = clamp(dot(n, normalize(vec3(-0.35, -0.7, 0.62))), 0.0, 1.0);
    float grain = (hash(floor(qt_TexCoord0 * 260.0)) - 0.5) * 0.07;
    vec4 velvet = deep * (0.62 + 0.38 * lit + grain);
    velvet = mix(velvet, sheen, clamp(fres * 0.9, 0.0, 1.0));
    // thinking: a sheen runs round her
    float a = mod(th - time * 2.2, 2.0 * PI);
    velvet += sheen * (exp(-a * 2.5) * fres * 0.8 * clamp(mode.x, 0.0, 1.0));
    col = over(velvet * inside, col);

    // ── the fuzz outside the rim: a soft halo of pile, brighter with the voice
    float halo = exp(-max(d, 0.0) * 30.0) * (1.0 - inside);
    col += sheen * (halo * (0.18 + 0.45 * fuzz * (0.4 + clamp(mode.z, 0.0, 1.0) * lvl)));

    // ── waking: one ring runs out of her
    if (mode.w > 0.001 && mode.w < 0.999) {
        float ring = abs(rho - (r + 0.04 + mode.w * 0.36)) - 0.006;
        col += sheen * (cover(ring) * (1.0 - mode.w) * 0.7);
    }

    // ── the face, on the ball (it squashes with her)
    vec2 g = vec2(clamp(look.x, -1.0, 1.0) * 0.09, clamp(look.y, -1.0, 1.0) * 0.07);
    float eyes = max(eyeShape(q, vec2(-0.16, -0.05) + g), eyeShape(q, vec2(0.16, -0.05) + g));
    col = over(ink * (eyes * inside), col);

    // cheeks
    for (int k = -1; k <= 1; k += 2) {
        vec2 c = vec2(float(k) * 0.29, 0.1) + g * 0.6;
        vec2 e = (q - c) * vec2(1.0, 1.7);
        col = over(blush * (exp(-dot(e, e) * 160.0) * clamp(look.z, 0.0, 1.0) * 0.8 * inside), col);
    }

    // the mouth: a small smile at rest, open with her voice as she speaks
    vec2 m = q - (vec2(0.0, 0.13) + g * 0.7);
    float smileArc = cover(abs(length(m - vec2(0.0, -0.05)) - 0.05) - 0.011) * step(-0.02, m.y) * step(abs(m.x), 0.045);
    // talking: a small oval that opens with her voice
    vec2 ab = vec2(0.042, 0.016 + 0.06 * voice());
    float talk = cover((length(m / ab) - 1.0) * min(ab.x, ab.y));
    float mouth = mix(smileArc * (0.55 + 0.45 * clamp(eye.y, 0.0, 1.0)), talk, clamp(look.w, 0.0, 1.0)) * (1.0 - clamp(eye.z, 0.0, 1.0));
    col = over(ink * (mouth * inside * 0.95), col);

    fragColor = col * qt_Opacity;
}
