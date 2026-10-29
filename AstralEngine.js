// Hyprwhspr Astral — rendering engine.
//
// Plain ES2017 with no imports and no QML/DOM dependencies, so the same file
// drives the DankMaterialShell widget (QML Canvas, via `import "AstralEngine.js"
// as Engine`) and the browser preview in preview/index.html (HTML canvas).
// Only Canvas 2D calls that behave identically in both are used: arc, fillRect,
// moveTo/lineTo, save/translate/scale, createRadialGradient and
// createLinearGradient (no ellipse(), whose signature differs in QML).
//
// Scene: a mirrored "stardust ribbon" of twinkling grains whose height follows
// the voice. Grains at the crest shed drifting motes, and short-lived
// constellation links connect nearby grains. Everything is driven by the
// single 0–1 `audio_level` scalar that hyprwhspr writes.

var DEFAULTS = {
    sensitivity: 2.0,      // gain on the raw mic level
    peakBoost: 1.6,        // how hard peaks bloom (brightness / white-hot cores)
    onsetSparkle: 1.0,     // flash + spark burst on sudden onsets (0 = off)
    motionSpeed: 1.0,      // shimmer speed of the ribbon
    reactivity: 1.5,       // how much the voice shakes / speeds up the ribbon
    rippleSpread: 1.0,     // syllables travel from the centre outward (0 = whole ribbon at once)
    autoGain: 0.7,         // normalise to your recent loudness (0 = fixed gain)
    starCount: 220,        // grains in the ribbon
    ribbonHeight: 1.0,     // vertical spread at full level
    starSize: 1.0,         // grain radius multiplier
    twinkle: 1.0,          // twinkle depth (0 = steady)
    centerEnvelope: true,  // ribbon swells toward the middle
    bandGlow: 1.0,         // soft nebula band behind the ribbon
    driftAmount: 1.0,      // how many motes shed off the crest (0 = off)
    driftSpeed: 1.0,
    maxMotes: 500,
    linkDensity: 1.0,      // 0 off, 1 sparse, 2.2 woven, 4 dense
    linkReach: 1.0,        // max link length multiplier
    linkLifetime: 1.0,     // how long links hold before dissolving
    constellations: true,  // chain links into 3–5 star constellations at peaks
    glowQuality: 2,        // 0 cores only, 1 soft (stacked discs), 2 full gradients
    colors: [[181, 209, 125], [229, 186, 216], [173, 199, 248]]
};

var WHITE = [255, 255, 255];
var TAU = 6.283185307179586;

function rand(a, b) { return a + Math.random() * (b - a); }
function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
function mix(a, b, t) {
    return [Math.round(a[0] + (b[0] - a[0]) * t), Math.round(a[1] + (b[1] - a[1]) * t), Math.round(a[2] + (b[2] - a[2]) * t)];
}
function rgba(c, a) {
    return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + clamp(a, 0, 1).toFixed(3) + ")";
}

function create(options) {
    var st = {
        opt: {}, w: 1, h: 1, t: 0,
        level: 0, smooth: 0, peak: 0, flash: 0, lastFlash: 0, burst: false,
        agc: 0.3, noise: 0, energy: 0, phase: 0,
        hist: [], histPos: 0, histAcc: 0,
        dots: [], motes: [], links: [], linked: {}, linkAcc: 0,
        palette: [], lut: []
    };
    configure(st, options || {});
    return st;
}

// Merge new options; rebuilds the grain set only when the count changes.
function configure(st, options) {
    for (var k in DEFAULTS)
        st.opt[k] = (options[k] !== undefined && options[k] !== null) ? options[k] : (st.opt[k] !== undefined ? st.opt[k] : DEFAULTS[k]);
    st.opt.starCount = Math.round(clamp(st.opt.starCount, 20, 800));
    st.opt.maxMotes = Math.round(clamp(st.opt.maxMotes, 0, 2000));
    if (st.dots.length !== st.opt.starCount)
        buildDots(st);
    buildPalette(st);
}

function buildDots(st) {
    st.dots = [];
    st.links = [];
    st.linked = {};
    for (var i = 0; i < st.opt.starCount; i++) {
        st.dots.push({
            t: Math.random(), j: rand(-1, 1), side: Math.random() < 0.5 ? -1 : 1,
            r: Math.random() < 0.12 ? rand(1.3, 2.0) : rand(0.55, 1.1),
            p: rand(0, TAU), s: rand(0.6, 2.2), f: rand(5, 11), q: rand(0, TAU),
            x: 0, y: 0, a: 0, heat: 0, local: 0, lit: 0
        });
    }
}

// Pre-mixed 3-stop gradient (64 steps) so per-grain colour lookups are free.
function buildPalette(st) {
    var c = st.opt.colors;
    st.lut = [];
    for (var i = 0; i < 64; i++) {
        var t = i / 63;
        st.lut.push(t < 0.5 ? mix(c[0], c[1], t * 2) : mix(c[1], c[2], (t - 0.5) * 2));
    }
}
function grad(st, t) { return st.lut[Math.round(clamp(t, 0, 1) * 63)]; }

function env(st, t) {
    return st.opt.centerEnvelope ? 0.25 + 0.75 * Math.pow(Math.sin(Math.PI * t), 1.4) : 0.85;
}

function setSize(st, w, h) {
    st.w = Math.max(1, w);
    st.h = Math.max(1, h);
}

// True while anything is still visible/moving; the host can stop its frame
// loop once this goes false after recording ends.
function isActive(st, recording) {
    return recording || st.smooth > 0.002 || st.motes.length > 0 || st.links.length > 0;
}

function clear(st) {
    st.smooth = 0; st.peak = 0; st.flash = 0; st.lastFlash = 0; st.energy = 0;
    for (var h = 0; h < st.hist.length; h++) st.hist[h] = 0;
    st.motes = []; st.links = []; st.linked = {};
    for (var i = 0; i < st.dots.length; i++) st.dots[i].lit = 0;
}

// ── Signal ────────────────────────────────────────────────────────────────
function updateSignal(st, dt, rawLevel, recording) {
    var o = st.opt;
    var x = recording ? Math.max(0, rawLevel) * o.sensitivity : 0;
    var gatedNoise = 0;
    if (recording) {
        // Noise floor: follows the quietest input quickly, rises slowly, so a
        // quiet room reads as stillness instead of a constant low wobble.
        st.noise += (x - st.noise) * (1 - Math.exp(-dt / (x < st.noise ? 0.15 : 10.0)));
        st.noise = Math.min(st.noise, st.agc * 0.3);
        // Auto gain: track recent peaks (fast up, ~4 s down) and scale so
        // normal speech uses the full range regardless of mic level.
        st.agc += (x - st.agc) * (1 - Math.exp(-dt / (x > st.agc ? 0.08 : 4.0)));
        if (o.autoGain > 0) {
            var g = 1 + (clamp(0.85 / Math.max(st.agc, 0.12), 0.5, 4) - 1) * o.autoGain;
            x *= g;
            gatedNoise = st.noise * g;
        } else {
            gatedNoise = st.noise;
        }
    }
    // Perceptual curve, then a soft gate just above the noise floor (applied
    // after the curve so near-floor flicker isn't expanded into motion).
    var target = Math.pow(Math.min(1, x), 0.45);
    var floorT = Math.min(0.8, Math.pow(Math.min(1, gatedNoise * 1.4), 0.45));
    target = Math.max(0, (target - floorT) / (1 - floorT));
    var prev = st.smooth;
    // fast attack, slower release, frame-rate independent
    st.smooth += (target - st.smooth) * (1 - Math.exp(-dt / (target > st.smooth ? 0.05 : 0.18)));
    if (!recording && st.smooth < 0.002) st.smooth = 0;
    // brightness only blooms in the top part of the range
    st.peak = peakOf(st, st.smooth);
    var rise = (st.smooth - prev) / Math.max(dt, 1e-3);
    // Speech energy: how fast the level is changing (syllable onsets/offsets).
    var kickIn = Math.min(1, Math.max(0, Math.abs(rise) - 0.8) / 2.5) * Math.min(1, st.smooth * 2.5);
    st.energy += (kickIn - st.energy) * (1 - Math.exp(-dt / 0.12));
    // Undulation speeds up while speaking.
    st.phase += dt * o.motionSpeed * (1 + 1.6 * o.reactivity * st.smooth);
    // Level history (60 Hz samples, ~1 s) for the centre-out ripple.
    if (!st.hist.length) for (var hi = 0; hi < 64; hi++) st.hist.push(0);
    st.histAcc += dt;
    while (st.histAcc >= 1 / 60) {
        st.histAcc -= 1 / 60;
        st.histPos = (st.histPos + 1) % 64;
        st.hist[st.histPos] = st.smooth;
    }
    st.flash = Math.max(st.flash * Math.exp(-dt / 0.25),
                        Math.min(1, Math.max(0, rise - 2.5) / 6) * Math.min(1, o.peakBoost) * o.onsetSparkle);
    st.burst = o.onsetSparkle > 0 && st.flash > 0.35 && st.lastFlash <= 0.35;
    st.lastFlash = st.flash;
}

// ── Primitives ────────────────────────────────────────────────────────────
function star(st, ctx, x, y, r, col, a, heat) {
    if (a <= 0.004) return;
    var q = st.opt.glowQuality;
    var halo = r * (2.6 + 3.5 * heat);
    if (q >= 2 && halo > 2.2) {
        var g = ctx.createRadialGradient(x, y, 0, x, y, halo);
        g.addColorStop(0, rgba(col, a * (0.35 + 0.35 * heat)));
        g.addColorStop(0.35, rgba(col, a * (0.10 + 0.15 * heat)));
        g.addColorStop(1, rgba(col, 0));
        ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(x, y, halo, 0, TAU); ctx.fill();
    } else if (q === 1 && halo > 2.2) {
        ctx.fillStyle = rgba(col, a * (0.07 + 0.08 * heat));
        ctx.beginPath(); ctx.arc(x, y, halo, 0, TAU); ctx.fill();
        ctx.fillStyle = rgba(col, a * (0.12 + 0.12 * heat));
        ctx.beginPath(); ctx.arc(x, y, halo * 0.45, 0, TAU); ctx.fill();
    }
    ctx.fillStyle = rgba(mix(col, WHITE, Math.min(0.85, heat * 0.9)), a);
    ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
}

function bandGlow(st, ctx, cy, strength, thick) {
    strength *= st.opt.bandGlow;
    if (strength <= 0.01 || thick < 1) return;
    ctx.save();
    ctx.translate(st.w / 2, cy);
    ctx.scale(st.w * 0.48, thick);
    var g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1);
    g.addColorStop(0, rgba(grad(st, 0.5), 0.22 * strength));
    g.addColorStop(0.5, rgba(grad(st, 0.35), 0.08 * strength));
    g.addColorStop(1, rgba(grad(st, 0.5), 0));
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(0, 0, 1, 0, TAU); ctx.fill();
    ctx.restore();
}

// ── Ribbon ────────────────────────────────────────────────────────────────
// Level as it was `delay` seconds ago (from the 60 Hz history ring).
function smoothAt(st, delay) {
    if (!st.hist.length || delay <= 0) return st.smooth;
    var k = Math.min(63, Math.round(delay * 60));
    return st.hist[(st.histPos - k + 64) % 64];
}
function peakOf(st, s) {
    return Math.min(1, Math.pow(Math.max(0, (s - 0.35) / 0.65), 1.3) * st.opt.peakBoost);
}

function layoutRibbon(st) {
    var o = st.opt, t = st.phase;
    var cy = st.h / 2, x0 = st.w * 0.05, span = st.w * 0.9;
    var shake = st.energy * o.reactivity;
    for (var i = 0; i < st.dots.length; i++) {
        var d = st.dots[i];
        var e = env(st, d.t);
        // Ripple: grains further from the centre see the voice a little later,
        // so each syllable travels outward along the ribbon.
        var s = smoothAt(st, Math.abs(d.t - 0.5) * 2 * 0.28 * o.rippleSpread);
        var wob = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(t * d.f * 0.35 + d.q + d.t * 9));
        var amp = s * e * wob * st.h * 0.46 * o.ribbonHeight;
        // Syllable kick: fast per-grain jitter proportional to speech energy.
        var kick = shake * st.h * 0.07 * o.ribbonHeight * Math.sin(st.t * d.f * 2.3 + d.q * 3);
        d.x = x0 + d.t * span + shake * 3 * Math.sin(st.t * d.f * 1.7 + d.p);
        d.y = cy + d.side * (Math.abs(d.j) * amp + Math.abs(d.j) * kick) + d.j * 1.6;
        var tw = 1 - o.twinkle * (0.45 - 0.45 * Math.sin(st.t * d.s + d.p));
        var local = peakOf(st, s) * wob * e;
        d.local = local;
        d.a = Math.min(1, (0.18 + 0.82 * st.smooth * wob) * (tw + (1 - tw) * local) + st.flash * 0.35 * tw + d.lit * 0.4);
        d.heat = Math.min(1, local * 1.1 + st.flash * 0.6 * (d.r > 1.2 ? 1 : 0.4) + d.lit * 0.5);
    }
}

function drawRibbon(st, ctx, dt) {
    var size = st.opt.starSize;
    for (var i = 0; i < st.dots.length; i++) {
        var d = st.dots[i];
        star(st, ctx, d.x, d.y, d.r * size * (1 + st.smooth * 0.5 + d.local * 1.4 + d.lit * 0.6), grad(st, d.t), d.a, d.heat);
        d.lit *= Math.exp(-dt / 0.5);
    }
}

// ── Constellation links ───────────────────────────────────────────────────
// A link references two ribbon grains and follows them as they move. Life:
// fade in 0.18 s → hold → fade out; snaps early when overstretched.
function linkKey(i, j) { return i < j ? i * 4096 + j : j * 4096 + i; }
function reach(st) { return (22 + 70 * st.smooth + 30 * st.peak) * st.opt.linkReach; }

function nearest(st, i, R, chain) {
    var a = st.dots[i], best = [];
    for (var k = 0; k < st.dots.length; k++) {
        if (k === i || chain[k] || st.linked[linkKey(i, k)]) continue;
        var b = st.dots[k];
        var dd = Math.hypot(a.x - b.x, a.y - b.y);
        if (dd > 6 && dd < R && b.a > 0.12) best.push([dd, k]);
    }
    if (!best.length) return -1;
    best.sort(function (p, q) { return p[0] - q[0]; });
    return best[Math.floor(Math.random() * Math.min(3, best.length))][1];
}

function addLink(st, i, j, strength, delay) {
    var key = linkKey(i, j);
    if (st.linked[key]) return;
    st.linked[key] = true;
    st.links.push({
        i: i, j: j, key: key, life: -delay, s: strength, snap: 0,
        hold: (rand(0.25, 0.7) + strength * 0.8) * st.opt.linkLifetime,
        out: rand(0.7, 1.3) * Math.max(0.3, st.opt.linkLifetime)
    });
}

function spawnLinks(st, dt) {
    var o = st.opt;
    if (o.linkDensity <= 0 || st.smooth <= 0.01) return;
    st.linkAcc += dt * o.linkDensity * (0.6 + 6 * st.smooth * st.smooth + 9 * st.peak);
    var guard = 0;
    while (st.linkAcc >= 1 && guard++ < 20) {
        st.linkAcc -= 1;
        if (st.links.length > 60 * o.linkDensity) { st.linkAcc = 0; break; }
        // prefer bright grains as anchors
        var i = Math.floor(Math.random() * st.dots.length);
        for (var tries = 0; tries < 5 && st.dots[i].a <= 0.3; tries++)
            i = Math.floor(Math.random() * st.dots.length);
        var R = reach(st), chain = {}, from = i, len = 1;
        chain[i] = true;
        var maxLen = 1 + (o.constellations && Math.random() < st.peak * 0.85 ? Math.floor(rand(2, 5)) : 0);
        while (len <= maxLen) {
            var to = nearest(st, from, R, chain);
            if (to < 0) break;
            addLink(st, from, to, Math.min(1, 0.25 + st.smooth * 0.6 + st.peak), (len - 1) * 0.07);
            chain[to] = true; from = to; len++;
        }
    }
    st.linkAcc = Math.min(st.linkAcc, 1);
}

function drawLinks(st, ctx, dt) {
    var R = reach(st), keep = [];
    for (var n = 0; n < st.links.length; n++) {
        var L = st.links[n];
        L.life += dt;
        if (L.life < 0) { keep.push(L); continue; }
        var a = st.dots[L.i], b = st.dots[L.j];
        if (!a || !b) { delete st.linked[L.key]; continue; }
        var dd = Math.hypot(a.x - b.x, a.y - b.y);
        if (dd > R * 1.8 && !L.snap) L.snap = L.life;
        var k;
        if (L.snap) k = Math.max(0, 1 - (L.life - L.snap) / 0.2);
        else if (L.life < 0.18) k = L.life / 0.18;
        else if (L.life < 0.18 + L.hold) k = 1;
        else k = Math.max(0, 1 - (L.life - 0.18 - L.hold) / L.out);
        if (k <= 0 && L.life > 0.18) { delete st.linked[L.key]; continue; }
        keep.push(L);
        if (L.life < 0.25) {
            a.lit = Math.max(a.lit, k * L.s);
            b.lit = Math.max(b.lit, k * L.s);
        }
        var alpha = k * (0.22 + 0.7 * Math.min(a.a, b.a)) * (0.55 + 0.45 * L.s) * (1 - Math.min(1, dd / (R * 2)) * 0.4);
        if (alpha < 0.01) continue;
        var ca = mix(grad(st, a.t), WHITE, a.heat * 0.5), cb = mix(grad(st, b.t), WHITE, b.heat * 0.5);
        var g = ctx.createLinearGradient(a.x, a.y, b.x, b.y);
        g.addColorStop(0, rgba(ca, alpha));
        g.addColorStop(0.5, rgba(mix(ca, cb, 0.5), alpha * 0.55));
        g.addColorStop(1, rgba(cb, alpha));
        ctx.strokeStyle = g;
        ctx.lineWidth = 0.7 + 0.8 * L.s * k;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
    }
    st.links = keep;
}

// ── Drift motes ───────────────────────────────────────────────────────────
function spawnMote(st, x, y, u, dir, e, speedMul) {
    if (st.motes.length >= st.opt.maxMotes) return;
    st.motes.push({
        x: x, y: y, u: u, e: e,
        vx: rand(-10, 10) * (1 + e) * st.opt.driftSpeed,
        vy: dir * rand(6, 26) * (0.4 + st.smooth * 1.4) * env(st, u) * speedMul * st.opt.driftSpeed,
        life: 0, max: rand(1.2, 2.6) * (1 + e * 0.6),
        r: Math.random() < 0.12 ? rand(1.2, 1.8) : rand(0.55, 1)
    });
}

function stepMotes(st, ctx, dt) {
    var keep = [], size = st.opt.starSize;
    for (var n = 0; n < st.motes.length; n++) {
        var m = st.motes[n];
        m.life += dt;
        m.x += m.vx * dt; m.y += m.vy * dt;
        m.vy *= Math.exp(-dt * 0.6); m.vx *= Math.exp(-dt * 0.3);
        var k = m.life / m.max;
        if (k >= 1 || m.y < -10 || m.y > st.h + 10) continue;
        keep.push(m);
        var fade = Math.sin(Math.PI * Math.min(1, k * 1.6 + 0.05)) * (1 - k * 0.35);
        star(st, ctx, m.x, m.y, m.r * size * (1 + m.e * 1.3 * (1 - k * 0.6)), grad(st, m.u), fade * (0.55 + 0.45 * m.e), m.e * (1 - k));
    }
    st.motes = keep;
}

// ── Frame ─────────────────────────────────────────────────────────────────
// Advance the simulation by dt seconds and paint one frame into ctx.
function frame(st, ctx, dt, rawLevel, recording) {
    dt = clamp(dt, 0, 0.05);
    st.t += dt;
    updateSignal(st, dt, rawLevel, recording);

    ctx.globalCompositeOperation = "source-over";
    ctx.clearRect(0, 0, st.w, st.h);
    ctx.globalCompositeOperation = "lighter";

    layoutRibbon(st);
    bandGlow(st, ctx, st.h / 2, st.smooth * 0.6 + st.peak * 1.2 + st.flash * 0.8, st.h * (0.12 + 0.22 * st.smooth) * st.opt.ribbonHeight);
    spawnLinks(st, dt);
    drawLinks(st, ctx, dt);
    drawRibbon(st, ctx, dt);

    var o = st.opt;
    if (o.driftAmount > 0) {
        var p = 0.05 * o.driftAmount;
        for (var i = 0; i < st.dots.length; i++) {
            var d = st.dots[i];
            if (d.local > 0.35 && Math.random() < d.local * p * Math.abs(d.j))
                spawnMote(st, d.x, d.y, d.t, d.side, Math.min(1, st.peak), 1.3);
        }
        if (st.burst) {
            var n = Math.round(22 * o.onsetSparkle * Math.min(2, o.driftAmount));
            for (var b = 0; b < n; b++) {
                var u = rand(0.3, 0.7);
                spawnMote(st, st.w * (0.05 + 0.9 * u), st.h / 2, u, Math.random() < 0.5 ? -1 : 1, 1, 1.8);
            }
        }
    }
    stepMotes(st, ctx, dt);
    ctx.globalCompositeOperation = "source-over";
}

// Static, faint resting thread used for the idle placeholder (painted once).
function drawIdle(st, ctx) {
    ctx.globalCompositeOperation = "source-over";
    ctx.clearRect(0, 0, st.w, st.h);
    var cy = st.h / 2, x0 = st.w * 0.05, span = st.w * 0.9, size = st.opt.starSize;
    for (var i = 0; i < st.dots.length; i++) {
        var d = st.dots[i];
        var tw = 0.55 + 0.45 * Math.sin(d.p * 3.1);
        star(st, ctx, x0 + d.t * span, cy + d.j * 1.6, d.r * size, grad(st, d.t), 0.8 * tw, 0);
    }
}
