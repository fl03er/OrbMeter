// Renders thinking-orbs states into OrbMeter menu bar frames (44x44 px color PNGs, 22 pt at 2x).
import { rasterizeColor } from './raster.mjs';
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
const [engineDir, outDir] = process.argv.slice(2);
const E = await import(engineDir + '/engine.es.js');

// period: loop length in natural seconds (from raster self-similarity search).
const CONFIG = {
  working:    { period: 2.0 },
  searching:  { period: 2.0 },
  solving:    { period: 5.88 },
  listening:  { period: 2.16 },
  connecting: { period: 2.88 },
  weaving:    { period: 4.22 },
  composing:  { period: 3.58 },
  breathing:  { period: 2.94 },
  shaping:    { period: 6.44 },
};
const FRAMES_PER_SEC = 8;  // RunCat plays 2*speed fps, so natural pace lands at speed 4 (~20% CPU).
const PX = 44, GEO = 20, FADE = 0.35, U0 = 100;
const PRESET = 32, RADIUS = 1.1;  // the 32 preset carries ~2.5x the dots of the 20 preset at finer radii
const GLOW = 1.6, BREATH = 0.15;  // alpha boost for menu bar legibility; brightness swing per loop

const crc = (() => { const t = new Int32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c; } return b => { let c = -1; for (const x of b) c = t[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }; })();
function png(rgba, w, h) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const o = y * (w * 4 + 1) + 1 + x * 4, q = (y * w + x) * 4, a = Math.min(1, rgba[q + 3]);
      for (let k = 0; k < 3; k++) raw[o + k] = a > 0 ? Math.round(Math.min(1, rgba[q + k] / a) * 255) : 0;  // un-premultiply
      raw[o + 3] = Math.round(a * 255);
    }
  }
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([len, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
const scaleAlpha = (f, k) => ({ dots: f.dots.map(d => ({ ...d, a: (d.a ?? 1) * k })), lines: f.lines.map(l => ({ ...l, a: (l.a ?? 1) * k })) });
const smooth = x => x * x * (3 - 2 * x);
// Scale a frame about the center so the orb fills the canvas instead of the presets' built-in margin.
const zoomFrame = (f, z, c) => ({
  dots: f.dots.map(d => ({ ...d, x: c + (d.x - c) * z, y: c + (d.y - c) * z, r: d.r * z })),
  lines: f.lines.map(l => ({ ...l, x1: c + (l.x1 - c) * z, y1: c + (l.y1 - c) * z, x2: c + (l.x2 - c) * z, y2: c + (l.y2 - c) * z, w: l.w * z })),
});
const FILL = 0.97;  // fraction of the half-size the farthest visible mark may reach

const summary = {};
for (const [state, { period }] of Object.entries(CONFIG)) {
  const R = E.resolvePreset(state, PRESET), fn = E.MODE_FRAMES[R.mode];
  const n = Math.max(10, Math.round(period * FRAMES_PER_SEC));
  const span = period * R.speed;
  mkdirSync(`${outDir}/${state}`, { recursive: true });
  // Measure the farthest visible mark across one loop (plus the crossfade source) to pick the zoom.
  let reach = 0;
  for (let i = 0; i < 4 * n; i++) {
    const u = U0 + (i / (4 * n) - 1) * span;
    for (const d of fn(GEO, u, R.opts).dots) if ((d.a ?? 1) >= 0.05)
      reach = Math.max(reach, Math.abs(d.x - GEO / 2) + d.r * RADIUS, Math.abs(d.y - GEO / 2) + d.r * RADIUS);
  }
  const zoom = Math.min(1.6, FILL * (GEO / 2) / reach);
  for (let i = 0; i < n; i++) {
    const p = i / n, u = U0 + p * span;
    let frame = fn(GEO, u, R.opts);
    if (RADIUS !== 1) frame.dots.forEach(d => d.r *= RADIUS);
    if (p > 1 - FADE) {  // crossfade into the loop start so the wrap is seamless
      const w = smooth((p - (1 - FADE)) / FADE);
      const prev = fn(GEO, u - span, R.opts);
      if (RADIUS !== 1) prev.dots.forEach(d => d.r *= RADIUS);
      const a = scaleAlpha(frame, 1 - w), b = scaleAlpha(prev, w);
      frame = { dots: [...a.dots, ...b.dots].sort((x, y) => x.z - y.z), lines: [...a.lines, ...b.lines] };
    }
    // Palette turns once per loop and breathes, so both stay seamless at the wrap.
    const glow = GLOW * (1 - BREATH / 2 + (BREATH / 2) * Math.cos(2 * Math.PI * p));
    writeFileSync(`${outDir}/${state}/frame-${i}.png`, png(rasterizeColor(zoomFrame(frame, zoom, GEO / 2), GEO, PX, 4, -360 * p, glow), PX, PX));
  }
  summary[state] = n;
  console.error(state, 'zoom', zoom.toFixed(3));
}
writeFileSync(`${outDir}/frames.json`, JSON.stringify(summary));
console.log(summary);
