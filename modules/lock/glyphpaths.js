//  VELVET  ·  modules/lock/glyphpaths.js
//
//  The lock's shape alphabet as closed paths, normalised to radius 1 and
//  sampled into a fixed number of points — the same count for every shape,
//  which is what makes the morph work: shape changes interpolate point by
//  point, so one glyph grows cleanly into the next instead of jumping
//  (the way the inspo shells morph their material shapes).
//
//  Every path starts at its topmost point and runs clockwise.
//
//    kind 0 circle · 1 arrow · 2 pill · 3 burst · 4 diamond · 5 clam
//    kind 6 pentagon · 8 rect (the most area-filling glyph)
//  (kind 7 — the clover — is retired: its four detached leaves rendered
//   lumpy under the smoothing pass, so no pool picks it anymore.)
//
//  Included into MorphGlyph.qml via Qt.include, so everything here lives in
//  that component's scope: pathFor(kind, n), interpolate(from, to, t) and
//  smoothPath(ctx, pts).

function circle(n) {
    const pts = [];
    for (let k = 0; k < n; k++) {
        const a = 2 * Math.PI * k / n - Math.PI / 2;
        pts.push({
            x: Math.cos(a),
            y: Math.sin(a)
        });
    }
    return pts;
}

// Arrow pointing right: tip at (1, 0), the two rear corners at (-1, ±0.75).
function arrow(n) {
    const corners = [
        { x: -1, y: 0.75 },
        { x: 1, y: 0 },
        { x: -1, y: -0.75 }
    ];
    return edgePath(corners, n);
}

// Horizontal pill, height 8/18 of the width, like the design glyph.
function pill(n) {
    const pts = [];
    const r = 8 / 18 / 2 * 2;          // half height in radius-1 space: 0.4444
    const cx = 1 - r;                  // circle centres at ±(1 - r)
    const per = n / 4;
    // top edge, left → right
    for (let k = 0; k < per; k++)
        pts.push({
            x: -cx + 2 * cx * k / per,
            y: -r
        });
    // right half circle, top → bottom
    for (let k = 0; k < per; k++) {
        const a = -Math.PI / 2 + Math.PI * k / per;
        pts.push({
            x: cx + r * Math.cos(a),
            y: r * Math.sin(a)
        });
    }
    // bottom edge, right → left
    for (let k = 0; k < per; k++)
        pts.push({
            x: cx - 2 * cx * k / per,
            y: r
        });
    // left half circle, bottom → top
    for (let k = 0; k < per; k++) {
        const a = Math.PI / 2 - Math.PI * k / per;
        pts.push({
            x: -cx + r * Math.cos(a),
            y: r * Math.sin(a)
        });
    }
    return pts;
}

// Eight-point star: spikes on the axes and diagonals, valleys between them.
function burst(n) {
    const pts = [];
    for (let k = 0; k < n; k++) {
        const a = 2 * Math.PI * k / n - Math.PI / 2;
        const r = 0.375 + 0.625 * Math.abs(Math.cos(2 * a));
        pts.push({
            x: r * Math.cos(a),
            y: r * Math.sin(a)
        });
    }
    return pts;
}

// Rhombus with its spikes on the axes.
function diamond(n) {
    const pts = [];
    for (let k = 0; k < n; k++) {
        const a = 2 * Math.PI * k / n - Math.PI / 2;
        const r = 1 / (Math.abs(Math.cos(a)) + Math.abs(Math.sin(a)));
        pts.push({
            x: r * Math.cos(a),
            y: r * Math.sin(a)
        });
    }
    return pts;
}

// The dome: a flat floor and a quadratic arc over the top.
function clam(n) {
    const pts = [];
    const half = Math.floor(n / 2);
    const rest = n - half;
    // top arc, left → right, control point (0, -0.875) lifts the dome
    for (let k = 0; k < half; k++) {
        const t = k / (half - 1);
        const mt = 1 - t;
        pts.push({
            x: mt * mt * -1 + 2 * mt * t * 0 + t * t * 1,
            y: mt * mt * 0 + 2 * mt * t * -0.875 + t * t * 0
        });
    }
    // right edge down, floor back left, left edge up — three even legs
    const legs = Math.floor(rest / 3);
    for (let k = 1; k <= legs; k++)
        pts.push({
            x: 1,
            y: 0.75 * k / legs
        });
    for (let k = 1; k <= legs; k++)
        pts.push({
            x: 1 - 2 * k / legs,
            y: 0.75
        });
    for (let k = 1; k <= rest - legs * 2; k++)
        pts.push({
            x: -1,
            y: 0.75 - 0.75 * k / (rest - legs * 2 + 1)
        });
    return pts;
}

// Pentagon, spike up.
function pentagon(n) {
    const pts = [];
    for (let k = 0; k < n; k++) {
        const t = k / n * 5;
        const c = Math.floor(t) % 5;
        const tt = t - Math.floor(t);
        const a0 = -Math.PI / 2 + c * 2 * Math.PI / 5;
        const a1 = a0 + 2 * Math.PI / 5;
        const p0 = { x: Math.cos(a0), y: Math.sin(a0) };
        const p1 = { x: Math.cos(a1), y: Math.sin(a1) };
        pts.push({
            x: p0.x + (p1.x - p0.x) * tt,
            y: p0.y + (p1.y - p0.y) * tt
        });
    }
    return pts;
}

// Rounded rectangle: nearly the whole 2×2 box — the most area-filling
// glyph of the alphabet. The corners are eased just enough to keep the
// family's curve language. kind 8. Sampled evenly along the perimeter so
// the morphs stay smooth.
function rect(n) {
    const pts = [];
    const r = 0.16;                  // corner radius in radius-1 space
    const c = 1 - r;
    const edge = 2 * c;
    const arc = Math.PI / 2 * r;
    const total = 4 * edge + 4 * arc;
    for (let k = 0; k < n; k++) {
        let t = (k / n) * total;
        // top edge, left → right
        if (t < edge) {
            pts.push({ x: -c + 2 * c * t / edge, y: -1 });
            continue;
        }
        t -= edge;
        // top-right corner arc, top → right
        if (t < arc) {
            const a = -Math.PI / 2 + Math.PI / 2 * t / arc;
            pts.push({ x: c + r * Math.cos(a), y: -c + r * Math.sin(a) });
            continue;
        }
        t -= arc;
        // right edge, top → bottom
        if (t < edge) {
            pts.push({ x: 1, y: -c + 2 * c * t / edge });
            continue;
        }
        t -= edge;
        // bottom-right corner arc, right → bottom
        if (t < arc) {
            const a = Math.PI / 2 * t / arc;
            pts.push({ x: c + r * Math.cos(a), y: c + r * Math.sin(a) });
            continue;
        }
        t -= arc;
        // bottom edge, right → left
        if (t < edge) {
            pts.push({ x: c - 2 * c * t / edge, y: 1 });
            continue;
        }
        t -= edge;
        // bottom-left corner arc, bottom → left
        if (t < arc) {
            const a = Math.PI / 2 + Math.PI / 2 * t / arc;
            pts.push({ x: -c + r * Math.cos(a), y: c + r * Math.sin(a) });
            continue;
        }
        t -= arc;
        // left edge, bottom → top
        if (t < edge) {
            pts.push({ x: -1, y: c - 2 * c * t / edge });
            continue;
        }
        t -= edge;
        // top-left corner arc, left → top
        const a = Math.PI + Math.PI / 2 * t / arc;
        pts.push({ x: -c + r * Math.cos(a), y: -c + r * Math.sin(a) });
    }
    return pts;
}

// Even sampling along a closed corner path.
function edgePath(corners, n) {
    const pts = [];
    const per = Math.floor(n / corners.length);
    for (let c = 0; c < corners.length; c++) {
        const p0 = corners[c];
        const p1 = corners[(c + 1) % corners.length];
        for (let k = 0; k < per; k++) {
            const t = k / per;
            pts.push({
                x: p0.x + (p1.x - p0.x) * t,
                y: p0.y + (p1.y - p0.y) * t
            });
        }
    }
    return pts;
}

// The lock screen's background-shape names mapped onto glyph kinds —
// the same table ShapeBackdrop.qml uses, so the profile picture's hover
// shape can wear exactly the glyph the background wears (circle→0,
// arrow→1, pill→2, burst→3, diamond→4, clam→5, pentagon→6). "off" and
// anything unrecognised answer -1.
const SHAPE_NAMES = ["circle", "arrow", "pill", "burst", "diamond", "clam", "pentagon"];

function kindOfName(name) {
    const i = SHAPE_NAMES.indexOf(name);
    return i >= 0 ? i : -1;
}

function pathFor(kind, n) {
    switch (kind) {
        case 0:
            return circle(n);
        case 1:
            return arrow(n);
        case 2:
            return pill(n);
        case 3:
            return burst(n);
        case 4:
            return diamond(n);
        case 5:
            return clam(n);
        case 6:
            return pentagon(n);
        case 8:
            return rect(n);
    }
    return circle(n);
}

// Point-by-point interpolation between two equal-length paths — the morph.
function interpolate(from, to, t) {
    const out = [];
    const n = Math.min(from.length, to.length);
    for (let i = 0; i < n; i++)
        out.push({
            x: from[i].x + (to[i].x - from[i].x) * t,
            y: from[i].y + (to[i].y - from[i].y) * t
        });
    return out;
}

// Draw the path through all points as one smooth closed curve (uniform
// catmull-rom), so 48 samples read as a single fluid silhouette at any size.
function smoothPath(ctx, pts) {
    const n = pts.length;
    if (n < 3) {
        ctx.moveTo(0, 0);
        ctx.closePath();
        return;
    }
    ctx.moveTo(pts[0].x, pts[0].y);
    for (let i = 0; i < n; i++) {
        const p0 = pts[(i - 1 + n) % n];
        const p1 = pts[i];
        const p2 = pts[(i + 1) % n];
        const p3 = pts[(i + 2) % n];
        ctx.bezierCurveTo(
            p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
            p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
            p2.x, p2.y
        );
    }
    ctx.closePath();
}
