.pragma library
//  VELVET  ·  components/shapes.js
//  The outlines a card can have (VISUALS → CARD SHAPE), as closed polylines.
//  Every function takes the box and returns [{x, y}, …] with the first point
//  repeated at the end. Nothing here knows about colours.

function rect(w, h) {
    return [{x: 0, y: 0}, {x: w, y: 0}, {x: w, y: h}, {x: 0, y: h}, {x: 0, y: 0}];
}

// The house tilt: the top edge leans by `off` px, the box stays inside itself.
function slash(w, h, off, contain) {
    const p = contain ? Math.abs(off) : 0;
    const x0 = off > 0 ? p : 0;
    const x1 = off > 0 ? 0 : p;
    return [{x: x0, y: 0}, {x: w - x1, y: 0}, {x: w - x0, y: h}, {x: x1, y: h}, {x: x0, y: 0}];
}

function round(w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    if (r < 0.5)
        return rect(w, h);
    const out = [];
    const n = 7;
    const arc = (cx, cy, a0) => {
        for (let i = 0; i <= n; i++) {
            const a = a0 + (Math.PI / 2) * i / n;
            out.push({x: cx + r * Math.cos(a), y: cy + r * Math.sin(a)});
        }
    };
    arc(w - r, r, -Math.PI / 2);
    arc(w - r, h - r, 0);
    arc(r, h - r, Math.PI / 2);
    arc(r, r, Math.PI);
    out.push({x: out[0].x, y: out[0].y});
    return out;
}

// Two opposite corners cut at 45° — a sci-fi plate.
function notch(w, h, c) {
    c = Math.max(0, Math.min(c, w / 2, h / 2));
    return [{x: c, y: 0}, {x: w, y: 0}, {x: w, y: h - c}, {x: w - c, y: h}, {x: 0, y: h}, {x: 0, y: c}, {x: c, y: 0}];
}

// Corners cut in two stair steps of `s` px — a sprite.
function pixel(w, h, s) {
    s = Math.max(1, Math.min(s, w / 5, h / 5));
    return [
        {x: 2 * s, y: 0}, {x: w - 2 * s, y: 0}, {x: w - 2 * s, y: s}, {x: w - s, y: s}, {x: w - s, y: 2 * s}, {x: w, y: 2 * s},
        {x: w, y: h - 2 * s}, {x: w - s, y: h - 2 * s}, {x: w - s, y: h - s}, {x: w - 2 * s, y: h - s}, {x: w - 2 * s, y: h},
        {x: 2 * s, y: h}, {x: 2 * s, y: h - s}, {x: s, y: h - s}, {x: s, y: h - 2 * s}, {x: 0, y: h - 2 * s},
        {x: 0, y: 2 * s}, {x: s, y: 2 * s}, {x: s, y: s}, {x: 2 * s, y: s}, {x: 2 * s, y: 0}
    ];
}

// The four L-shaped corner marks of a bracket frame, as separate open paths.
function brackets(w, h, l, inset) {
    l = Math.max(2, Math.min(l, w / 2.2, h / 2.2));
    const i = inset || 0;
    return [
        [{x: i, y: l}, {x: i, y: i}, {x: l, y: i}],
        [{x: w - l, y: i}, {x: w - i, y: i}, {x: w - i, y: l}],
        [{x: w - i, y: h - l}, {x: w - i, y: h - i}, {x: w - l, y: h - i}],
        [{x: l, y: h - i}, {x: i, y: h - i}, {x: i, y: h - l}]
    ];
}

// The outline of `shape` for a box. `u` is the vibe's detail unit in px.
function outline(shape, w, h, o) {
    switch (shape) {
    case "round":
        return round(w, h, o.radius);
    case "pill":
        return round(w, h, h / 2);
    case "square":
    case "bracket":
    case "bevel":
        return rect(w, h);
    case "notch":
        return notch(w, h, o.cut);
    case "pixel":
        return pixel(w, h, o.step);
    default:
        return slash(w, h, o.off, o.contain);
    }
}

function shifted(pts, dx, dy) {
    return pts.map(p => ({x: p.x + dx, y: p.y + dy}));
}
