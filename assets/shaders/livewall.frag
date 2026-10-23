// VELVET · assets/shaders/livewall.frag — a live wallpaper's moving layer over its still
// (modules/wallpaper/Wallpaper.qml). The video is packed: the TOP half holds what the
// effect adds (light, and the colour of what it lays over the picture, premultiplied),
// the BOTTOM half how much of the picture it covers (grey). Written premultiplied, so
// the ordinary blending lays it over the still: still × (1 − a) + add — the picture
// itself is never in the video and keeps every pixel of the still.
// Rebuild: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o livewall.frag.qsb livewall.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float strength;     // 0 … 1: how much of the effect shows (SETTINGS → STRENGTH, live)
    float texelY;       // half a texel of the packed video, so the halves never bleed
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float y = clamp(qt_TexCoord0.y, texelY, 1.0 - texelY) * 0.5;
    vec3 add = texture(source, vec2(qt_TexCoord0.x, y)).rgb;
    float a = texture(source, vec2(qt_TexCoord0.x, y + 0.5)).r;
    float s = strength * qt_Opacity;
    fragColor = vec4(add * s, clamp(a, 0.0, 1.0) * s);
}
