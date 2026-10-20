// Rasterizes an OrbFrame into an alpha mask (dark-theme ink: brightness * alpha, source-over).
export function rasterize(frame, size, px, ss = 4) {
  const N = px * ss, k = N / size;
  const lum = new Float32Array(N * N), al = new Float32Array(N * N);
  const over = (i, g, a) => { const na = a + al[i] * (1 - a); if (na > 0) lum[i] = (g * a + lum[i] * al[i] * (1 - a)) / na; al[i] = na; };
  for (const l of frame.lines) {
    const a = l.a ?? 1, g = 1 - Math.min(1, Math.max(0, l.white)), hw = l.w * k / 2;
    const x1 = l.x1 * k, y1 = l.y1 * k, x2 = l.x2 * k, y2 = l.y2 * k, dx = x2 - x1, dy = y2 - y1, L2 = dx * dx + dy * dy || 1;
    for (let y = Math.max(0, Math.floor(Math.min(y1, y2) - hw)); y <= Math.min(N - 1, Math.ceil(Math.max(y1, y2) + hw)); y++)
      for (let x = Math.max(0, Math.floor(Math.min(x1, x2) - hw)); x <= Math.min(N - 1, Math.ceil(Math.max(x1, x2) + hw)); x++) {
        const px_ = x + .5, py = y + .5, t = Math.max(0, Math.min(1, ((px_ - x1) * dx + (py - y1) * dy) / L2));
        const ex = x1 + t * dx - px_, ey = y1 + t * dy - py;
        if (ex * ex + ey * ey <= hw * hw) over(y * N + x, g, a);
      }
  }
  for (const d of frame.dots) {
    const a = d.a ?? 1, g = 1 - Math.min(1, Math.max(0, d.white)), cx = d.x * k, cy = d.y * k, r = d.r * k;
    for (let y = Math.max(0, Math.floor(cy - r)); y <= Math.min(N - 1, Math.ceil(cy + r)); y++)
      for (let x = Math.max(0, Math.floor(cx - r)); x <= Math.min(N - 1, Math.ceil(cx + r)); x++) {
        const ex = x + .5 - cx, ey = y + .5 - cy;
        if (ex * ex + ey * ey <= r * r) over(y * N + x, g, a);
      }
  }
  // Downsample: output mask = luminance * alpha (what shows on a dark menu bar).
  const out = new Float32Array(px * px);
  for (let y = 0; y < px; y++) for (let x = 0; x < px; x++) {
    let s = 0;
    for (let j = 0; j < ss; j++) for (let i = 0; i < ss; i++) { const q = (y * ss + j) * N + x * ss + i; s += lum[q] * al[q]; }
    out[y * px + x] = s / (ss * ss);
  }
  return out;
}

// Apple-style conic palette, clockwise from 12 o'clock (system colors, dark-appearance variants).
const STOPS = [
  [0, [100, 210, 255]], [55, [94, 92, 230]], [105, [191, 90, 242]], [155, [255, 55, 145]],
  [200, [255, 69, 58]], [245, [255, 159, 10]], [290, [255, 214, 10]], [330, [48, 209, 88]], [360, [100, 210, 255]],
];
export function palette(deg) {
  deg = ((deg % 360) + 360) % 360;
  for (let i = 1; i < STOPS.length; i++) {
    const [d1, c1] = STOPS[i];
    if (deg <= d1) {
      const [d0, c0] = STOPS[i - 1], f = (deg - d0) / (d1 - d0);
      return c0.map((v, k) => v + (c1[k] - v) * f);
    }
  }
  return STOPS[0][1];
}

// Rasterizes an OrbFrame into premultiplied RGBA, coloring each mark by its angle around the center.
// rot: palette rotation in degrees. glow: brightness multiplier on the depth-shaded alpha.
export function rasterizeColor(frame, size, px, ss, rot, glow) {
  const N = px * ss, k = N / size, c = size / 2;
  const R = new Float32Array(N * N), G = new Float32Array(N * N), B = new Float32Array(N * N), A = new Float32Array(N * N);
  const over = (i, col, a) => { const ia = 1 - a; R[i] = col[0] * a + R[i] * ia; G[i] = col[1] * a + G[i] * ia; B[i] = col[2] * a + B[i] * ia; A[i] = a + A[i] * ia; };
  const colorAt = (x, y) => palette(Math.atan2(x - c, -(y - c)) * 180 / Math.PI + rot).map(v => v / 255);
  // Depth ink (white: 0 near/dark .. 1 far/light) -> visible strength; lifted so far dots stay readable.
  const strength = (white, a) => Math.min(1, a * glow * (0.65 + 0.35 * (1 - Math.min(1, Math.max(0, white)))));
  for (const l of frame.lines) {
    const a = strength(l.white, l.a ?? 1), col = colorAt((l.x1 + l.x2) / 2, (l.y1 + l.y2) / 2), hw = l.w * k / 2;
    const x1 = l.x1 * k, y1 = l.y1 * k, x2 = l.x2 * k, y2 = l.y2 * k, dx = x2 - x1, dy = y2 - y1, L2 = dx * dx + dy * dy || 1;
    for (let y = Math.max(0, Math.floor(Math.min(y1, y2) - hw)); y <= Math.min(N - 1, Math.ceil(Math.max(y1, y2) + hw)); y++)
      for (let x = Math.max(0, Math.floor(Math.min(x1, x2) - hw)); x <= Math.min(N - 1, Math.ceil(Math.max(x1, x2) + hw)); x++) {
        const px_ = x + .5, py = y + .5, t = Math.max(0, Math.min(1, ((px_ - x1) * dx + (py - y1) * dy) / L2));
        const ex = x1 + t * dx - px_, ey = y1 + t * dy - py;
        if (ex * ex + ey * ey <= hw * hw) over(y * N + x, col, a);
      }
  }
  for (const d of frame.dots) {
    const a = strength(d.white, d.a ?? 1), col = colorAt(d.x, d.y), cx = d.x * k, cy = d.y * k, r = d.r * k;
    for (let y = Math.max(0, Math.floor(cy - r)); y <= Math.min(N - 1, Math.ceil(cy + r)); y++)
      for (let x = Math.max(0, Math.floor(cx - r)); x <= Math.min(N - 1, Math.ceil(cx + r)); x++) {
        const ex = x + .5 - cx, ey = y + .5 - cy;
        if (ex * ex + ey * ey <= r * r) over(y * N + x, col, a);
      }
  }
  const out = new Float32Array(px * px * 4);
  for (let y = 0; y < px; y++) for (let x = 0; x < px; x++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let j = 0; j < ss; j++) for (let i = 0; i < ss; i++) { const q = (y * ss + j) * N + x * ss + i; r += R[q]; g += G[q]; b += B[q]; a += A[q]; }
    const n = ss * ss, o = (y * px + x) * 4;
    out[o] = r / n; out[o + 1] = g / n; out[o + 2] = b / n; out[o + 3] = a / n;
  }
  return out;  // premultiplied
}
