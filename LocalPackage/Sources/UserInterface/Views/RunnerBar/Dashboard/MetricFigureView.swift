/*
 MetricFigureView.swift
 UserInterface

 Created by fl03er on 2026/10/20.
 Copyright 2026 fl03er

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import SwiftUI

/// An isometric hardware render whose parts light up and move with a metric: dark machined faces,
/// hairline edges, and a glowing accent on whatever is active. The background stays transparent.
struct MetricFigureView: View, @preconcurrency Animatable {
    enum Kind {
        case cpu
        case memory
        case storage
        case battery
        case network
    }

    var kind: Kind
    /// The metric in 0...1: load, fill, charge or traffic activity.
    var value: Double
    /// Battery: 1 on power, 0 on battery. Network: -1 all upload ... 1 all download.
    var aux: Double
    /// Seconds, for the idle motion that keeps the drawing alive.
    var time: Double = 0
    /// The chip's marketing name split in two, such as ("M1", "PRO"); only the CPU figure uses it.
    var chip = ChipName.current

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(value, aux) }
        set {
            value = newValue.first
            aux = newValue.second
        }
    }

    var body: some View {
        Canvas { context, size in
            let pen = IsoPen(context: context, size: size, extent: kind.extent, time: time)
            switch kind {
            case .cpu: pen.drawCPU(load: value, chip: chip)
            case .memory: pen.drawMemory(used: value)
            case .storage: pen.drawStorage(used: value)
            case .battery: pen.drawBattery(level: value, onPower: aux)
            case .network: pen.drawNetwork(activity: value, direction: aux)
            }
        }
    }
}

/// Plays a MetricFigureView on its own: it fills up from zero when shown, eases to each new value,
/// and keeps idling in between. Still under Reduce Motion.
struct LiveMetricFigure: View {
    var kind: MetricFigureView.Kind
    var value: Double
    var aux: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            MetricFigureView(
                kind: kind,
                value: isShown ? value : 0,
                aux: isShown ? aux : 0,
                time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            )
        }
        .animation(.spring(duration: 0.9, bounce: 0.15), value: value)
        .animation(.spring(duration: 0.9, bounce: 0.15), value: aux)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 1.4, bounce: 0.2)) { isShown = true }
        }
        .onDisappear { isShown = false }
    }
}

/// The Apple silicon name read from the system, e.g. "Apple M1 Pro" becomes ("M1", "PRO").
struct ChipName: Equatable {
    var family: String
    var tier: String

    static let current: ChipName = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        let words = String(cString: buffer).split(separator: " ").map(String.init).filter { $0 != "Apple" }
        guard let family = words.first, family.hasPrefix("M") else { return ChipName(family: "CPU", tier: "") }
        return ChipName(family: family, tier: words.dropFirst().joined(separator: " ").uppercased())
    }()
}

private extension MetricFigureView.Kind {
    /// Model-space bounds of the drawing at its largest, used to fit it into the view.
    var extent: (min: SIMD3<Double>, max: SIMD3<Double>) {
        switch self {
        case .cpu: (SIMD3(0, 0, 0), SIMD3(40, 40, 4))
        case .memory: (SIMD3(0, 10, 0), SIMD3(60, 16, 18))
        case .storage: (SIMD3(1, 1, 0), SIMD3(29, 29, 20.5))
        case .battery: (SIMD3(0, 0, 0), SIMD3(48, 22, 34))
        case .network: (SIMD3(-8, 0, 0), SIMD3(48, 24, 24))
        }
    }
}

/// Isometric projection plus the render primitives.
private struct IsoPen {
    var context: GraphicsContext
    var scale: Double
    var origin: CGPoint
    var t: Double

    // Machined dark faces, lit from above.
    let topShade = Color(red: 0.17, green: 0.18, blue: 0.21)
    let rightShade = Color(red: 0.10, green: 0.105, blue: 0.12)
    let leftShade = Color(red: 0.07, green: 0.075, blue: 0.085)
    let edge = Color.white.opacity(0.30)
    let crease = Color.white.opacity(0.10)
    // The PRO gradient.
    let cyan = Color(red: 0.39, green: 0.85, blue: 1.0)
    let blue = Color(red: 0.25, green: 0.48, blue: 1.0)
    let green = Color(red: 0.19, green: 0.86, blue: 0.40)
    let red = Color(red: 1.0, green: 0.30, blue: 0.25)
    let gold = Color(red: 0.80, green: 0.66, blue: 0.38)
    let lineWidth = 0.7

    private static let cos30 = cos(Double.pi / 6)
    private static let sin30 = 0.5

    init(context: GraphicsContext, size: CGSize, extent: (min: SIMD3<Double>, max: SIMD3<Double>), time: Double) {
        self.context = context
        t = time
        let a = extent.min, b = extent.max
        let corners = [a.x, b.x].flatMap { x in [a.y, b.y].flatMap { y in [a.z, b.z].map { z in Self.raw(x, y, z) } } }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        let width = xs.max()! - xs.min()!, height = ys.max()! - ys.min()!
        let pad = 3.0
        scale = min((size.width - 2 * pad) / width, (size.height - 2 * pad) / height)
        origin = CGPoint(
            x: size.width / 2 - scale * (xs.min()! + xs.max()!) / 2,
            y: size.height / 2 - scale * (ys.min()! + ys.max()!) / 2
        )
    }

    private static func raw(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
        CGPoint(x: (x - y) * cos30, y: (x + y) * sin30 - z)
    }

    func p(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
        let r = Self.raw(x, y, z)
        return CGPoint(x: origin.x + scale * r.x, y: origin.y + scale * r.y)
    }

    /// Maps the plane z = const, in model units, onto the screen, for drawing text and patterns flat on a face.
    func topPlane(_ z: Double) -> CGAffineTransform {
        let o = p(0, 0, z)
        return CGAffineTransform(a: scale * Self.cos30, b: scale * Self.sin30, c: -scale * Self.cos30, d: scale * Self.sin30, tx: o.x, ty: o.y)
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        Path { $0.addLines(points); $0.closeSubpath() }
    }

    private func stroke(_ path: Path, _ color: Color, width: Double? = nil) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width ?? lineWidth, lineCap: .round, lineJoin: .round))
    }

    /// A soft bloom under a sharp line, the glow of a lit part.
    func glow(_ path: Path, _ color: Color, strength: Double, width: Double = 1) {
        guard strength > 0.01 else { return }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 2.2))
            layer.opacity = min(1, strength)
            layer.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width * 2.4, lineCap: .round, lineJoin: .round))
        }
        var sharp = context
        sharp.opacity = min(1, 0.4 + strength)
        sharp.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// An axis-aligned solid seen from +x, +y, above. `lit` in 0...1 floods its top with the accent.
    func box(_ x0: Double, _ y0: Double, _ z0: Double, _ x1: Double, _ y1: Double, _ z1: Double,
             lit: Double = 0, accent: Color? = nil) {
        let top = polygon([p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)])
        let right = polygon([p(x1, y0, z1), p(x1, y1, z1), p(x1, y1, z0), p(x1, y0, z0)])
        let left = polygon([p(x0, y1, z1), p(x1, y1, z1), p(x1, y1, z0), p(x0, y1, z0)])
        context.fill(right, with: .color(rightShade))
        context.fill(left, with: .color(leftShade))
        context.fill(top, with: .linearGradient(
            Gradient(colors: [topShade, topShade.mix(with: .black, by: 0.35)]),
            startPoint: p(x0, y0, z1), endPoint: p(x1, y1, z1)
        ))
        let corner = p(x1, y1, z1)
        stroke(Path { path in
            for q in [p(x1, y0, z1), p(x0, y1, z1), p(x1, y1, z0)] {
                path.move(to: corner)
                path.addLine(to: q)
            }
        }, crease)
        stroke(polygon([p(x0, y0, z1), p(x1, y0, z1), p(x1, y0, z0), p(x1, y1, z0), p(x0, y1, z0), p(x0, y1, z1)]), edge)
        if lit > 0.01 {
            let color = accent ?? cyan
            var flood = context
            flood.opacity = 0.45 * lit
            flood.fill(top, with: .linearGradient(Gradient(colors: [color, accent ?? blue]),
                                                  startPoint: p(x0, y0, z1), endPoint: p(x1, y1, z1)))
            glow(top, color, strength: lit, width: 0.8)
        }
    }

    private func ellipse(_ cx: Double, _ cy: Double, _ r: Double, _ z: Double, from a0: Double, to a1: Double) -> [CGPoint] {
        let steps = 40
        return (0...steps).map { k in
            let a = a0 + (a1 - a0) * Double(k) / Double(steps)
            return p(cx + r * cos(a), cy + r * sin(a), z)
        }
    }

    /// An upright platter; `level` in 0...1 draws a glowing fill ring around its front.
    func cylinder(_ cx: Double, _ cy: Double, _ r: Double, _ z0: Double, _ z1: Double, full: Bool, level: Double) {
        let left = 3 * Double.pi / 4, right = -Double.pi / 4
        let side = Path {
            // One run of points: the top's back arc, then the bottom's front arc. Each addLines starts a new subpath.
            $0.addLines(ellipse(cx, cy, r, z1, from: left, to: right + 2 * .pi).reversed() + ellipse(cx, cy, r, z0, from: left, to: right))
            $0.closeSubpath()
        }
        context.fill(side, with: .linearGradient(Gradient(colors: [leftShade, rightShade, leftShade]),
                                                 startPoint: p(cx - r, cy + r, z0), endPoint: p(cx + r, cy - r, z0)))
        let top = Path { $0.addLines(ellipse(cx, cy, r, z1, from: 0, to: 2 * .pi)); $0.closeSubpath() }
        context.fill(top, with: .color(topShade))
        stroke(side, edge)
        stroke(top, crease)
        if full {
            glow(Path { $0.addLines(ellipse(cx, cy, r, z1, from: right, to: left)) }, cyan, strength: 0.8, width: 0.8)
        } else if level > 0.02 {
            let ring = Path { $0.addLines(ellipse(cx, cy, r, z0 + (z1 - z0) * min(1, level), from: right, to: left)) }
            glow(ring, cyan, strength: 0.9, width: 0.9)
        }
    }

    // MARK: Figures

    /// An Apple silicon package: substrate, lid with the chip's name, a row of cores that light with load,
    /// a sheen that sweeps the lid, and a halo that grows with load.
    func drawCPU(load: Double, chip: ChipName) {
        let halo = polygon([p(0, 0, 1.2), p(40, 0, 1.2), p(40, 40, 1.2), p(0, 40, 1.2)])
        glow(halo, blue, strength: 0.15 + 0.75 * load, width: 1.2)
        box(0, 0, 0, 40, 40, 1.2)
        box(2.5, 2.5, 1.2, 37.5, 37.5, 3.6)

        // Sheen: a soft diagonal band that crosses the lid every few seconds.
        let lid = polygon([p(2.5, 2.5, 3.6), p(37.5, 2.5, 3.6), p(37.5, 37.5, 3.6), p(2.5, 37.5, 3.6)])
        let phase = (t / 4.5).truncatingRemainder(dividingBy: 1) * 1.8 - 0.4
        var sheen = context
        sheen.clip(to: lid)
        sheen.fill(lid, with: .linearGradient(
            Gradient(stops: [
                .init(color: .clear, location: max(0, phase - 0.12)),
                .init(color: .white.opacity(0.10), location: max(0, min(1, phase))),
                .init(color: .clear, location: min(1, phase + 0.12)),
            ]),
            startPoint: p(2.5, 2.5, 3.6), endPoint: p(37.5, 37.5, 3.6)
        ))

        var face = context
        face.concatenate(topPlane(3.6))
        var family = face.resolve(Text(chip.family).font(.system(size: 13, weight: .semibold)))
        var tier = face.resolve(Text(chip.tier).font(.system(size: 6.4, weight: .semibold)))
        family.shading = .linearGradient(Gradient(colors: [.white, Color(white: 0.78)]),
                                         startPoint: CGPoint(x: 0, y: 12), endPoint: CGPoint(x: 0, y: 22))
        tier.shading = .linearGradient(Gradient(colors: [cyan, blue]),
                                       startPoint: CGPoint(x: 12, y: 0), endPoint: CGPoint(x: 28, y: 0))
        face.draw(family, at: CGPoint(x: 20, y: chip.tier.isEmpty ? 18 : 15.5))
        if !chip.tier.isEmpty {
            face.draw(tier, at: CGPoint(x: 20, y: 24.5))
        }

        // Ten cores (eight performance, two efficiency) light in turn as load rises, and shimmer while busy.
        for k in 0..<10 {
            let u = 6 + Double(k) * 2.9 + (k >= 8 ? 0.8 : 0)
            let w = k >= 8 ? 1.6 : 2.2
            let fill = min(1, max(0, load * 10 - Double(k)))
            let shimmer = fill > 0 ? 0.75 + 0.25 * sin(t * 5 + Double(k) * 1.7) : 0
            let pad = Path { $0.addRect(CGRect(x: u, y: 30.5, width: w, height: 2.6)) }
            face.fill(pad, with: .color(Color.white.opacity(0.08)))
            if fill > 0 {
                var lit = face
                lit.opacity = fill * shimmer
                lit.addFilter(.shadow(color: cyan, radius: 1.5))
                lit.fill(pad, with: .linearGradient(Gradient(colors: [cyan, blue]),
                                                    startPoint: CGPoint(x: u, y: 30.5), endPoint: CGPoint(x: u, y: 33.1)))
            }
        }
    }

    /// A memory module standing on edge with gold contacts; its packages light and push out as memory fills.
    func drawMemory(used: Double) {
        box(0, 10, 0, 60, 12, 18)
        for k in 0..<29 {
            let x = 1.5 + Double(k) * 2
            stroke(Path { $0.move(to: p(x, 12, 0.5)); $0.addLine(to: p(x, 12, 2.8)) }, gold.opacity(0.8), width: 0.9)
        }
        for k in 0..<8 {
            let fill = min(1, max(0, used * 8 - Double(k)))
            let wave = 0.9 * fill * (0.5 + 0.5 * sin(t * 2.2 - Double(k) * 0.8))
            let x = 1.75 + Double(k) * 7.25
            box(x, 12, 5, x + 5.5, 12.8 + 2.6 * fill + wave, 15, lit: fill * (0.7 + 0.3 * sin(t * 2.2 - Double(k) * 0.8)))
        }
    }

    /// Four platters stacked like a database; a glowing ring rises through them as the disk fills,
    /// and a read head circles the top.
    func drawStorage(used: Double) {
        for i in 0..<4 {
            let z0 = Double(i) * 5.5
            let fill = min(1, max(0, used * 4 - Double(i)))
            let slosh = fill > 0.02 && fill < 0.98 ? 0.06 * sin(t * 2.4) : 0
            cylinder(15, 15, 14, z0, z0 + 4, full: fill >= 0.98, level: fill + slosh)
        }
        let angle = (t * 1.6).truncatingRemainder(dividingBy: 2 * .pi) - Double.pi / 4
        if angle < 3 * Double.pi / 4 {
            let c = p(15 + 10 * cos(angle), 15 + 10 * sin(angle), 20.5)
            var head = context
            head.addFilter(.shadow(color: cyan, radius: 2))
            head.fill(Path(ellipseIn: CGRect(x: c.x - 1.2, y: c.y - 1.2, width: 2.4, height: 2.4)), with: .color(cyan))
        }
    }

    /// A cell lying flat with five charge pads on top; a bolt floats over it on power.
    func drawBattery(level: Double, onPower: Double) {
        let accent = onPower > 0.5 ? green : level < 0.2 ? red : cyan
        box(0, 0, 0, 44, 22, 12)
        box(44, 7, 3, 48, 15, 9)
        for k in 0..<5 {
            let fill = min(1, max(0, level * 5 - Double(k)))
            let speed = onPower > 0.5 ? 4.0 : 1.4, depth = onPower > 0.5 ? 0.9 : 0.35
            let pulse = depth * fill * (0.5 + 0.5 * sin(t * speed - Double(k) * 0.9))
            let x = 3 + Double(k) * 8
            box(x, 4, 12, x + 6.5, 18, 12.6 + 2 * fill + pulse,
                lit: fill * (0.75 + 0.25 * sin(t * speed - Double(k) * 0.9)), accent: accent)
        }
        if onPower > 0.05 {
            let c = p(22, 11, 27 + 2 * onPower), u = scale * 0.8
            let bolt = Path {
                $0.addLines([
                    CGPoint(x: c.x + 1.6 * u, y: c.y - 5 * u), CGPoint(x: c.x - 1.6 * u, y: c.y + 0.6 * u),
                    CGPoint(x: c.x + 0.8 * u, y: c.y + 0.6 * u), CGPoint(x: c.x - 1.6 * u, y: c.y + 6 * u),
                ])
            }
            glow(bolt, green, strength: onPower * (0.7 + 0.3 * sin(t * 3)), width: 1.2)
        }
    }

    /// A router whose antennas lean toward the busier direction, tipped with lights, and whose front LEDs count the traffic.
    func drawNetwork(activity: Double, direction: Double) {
        let lean = direction * activity * Double.pi / 5
        for x in [8.0, 20, 32] {
            let sway = (0.04 + 0.08 * activity) * sin(t * 1.8 + x * 0.3)
            let base = p(x, 4, 6), tip = p(x + 16 * sin(lean + sway), 4, 6 + 16 * cos(lean + sway))
            let rod = Path { $0.move(to: base); $0.addLine(to: tip) }
            context.stroke(rod, with: .color(rightShade), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            stroke(rod, edge, width: 0.6)
            if activity > 0.02 {
                let pulse = 0.6 + 0.4 * sin(t * 4 + x)
                var light = context
                light.opacity = activity * pulse
                light.addFilter(.shadow(color: cyan, radius: 2))
                light.fill(Path(ellipseIn: CGRect(x: tip.x - 1.2, y: tip.y - 1.2, width: 2.4, height: 2.4)), with: .color(cyan))
            }
        }
        box(0, 0, 0, 40, 24, 6)
        for k in 0..<5 {
            let c = p(6 + Double(k) * 7, 24, 3)
            let blink = sin(t * 7 + Double(k) * 2.1) > -0.4
            let isLit = activity * 5 > Double(k) + 0.5 && blink
            let dot = Path(ellipseIn: CGRect(x: c.x - 0.9, y: c.y - 0.9, width: 1.8, height: 1.8))
            if isLit {
                var light = context
                light.addFilter(.shadow(color: cyan, radius: 1.8))
                light.fill(dot, with: .color(cyan))
            } else {
                context.fill(dot, with: .color(.white.opacity(0.12)))
            }
        }
    }
}
