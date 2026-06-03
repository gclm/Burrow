//
//  Sparkline.swift
//  Burrow / Components
//
//  Compact inline line chart with no axes, no labels, no legend — just
//  a sketch of the value's recent shape. Used in metric cards and the
//  sidebar to give numbers a time dimension at a glance.
//
//  Renders via `Path` not SwiftUI Charts because at this size (typical
//  60×24 px) Charts' margins + tick logic eat all the pixels. A simple
//  scaled polyline is what the eye is actually reading.
//
//  Inputs:
//    * values — chronological samples (oldest first); empty = blank.
//    * color  — line stroke colour. Fill is the same colour at 0.18α.
//    * baseline — optional value to draw as a faint horizontal line
//      (e.g. mean, or 100% for percent metrics).
//

import SwiftUI

struct Sparkline: View {
    let values: [Double]
    var color: Color = .accentColor
    var baseline: Double? = nil
    var height: CGFloat = 24
    var width: CGFloat? = nil   // nil = fill available

    var body: some View {
        GeometryReader { geo in
            let w = self.width ?? geo.size.width
            let h = self.height

            // Empty / single-point: render nothing instead of a degenerate
            // line that would draw as a dot at the wrong place.
            if values.count < 2 {
                Rectangle().fill(Color.clear).frame(width: w, height: h)
            } else {
                let (lo, hi) = self.bounds()
                let denom = max(hi - lo, 0.0001)   // avoid div-by-zero on flatline
                let xs = stride(from: 0.0, through: 1.0, by: 1.0 / Double(values.count - 1)).map { CGFloat($0) }
                let points = zip(xs, values).map { (x, v) -> CGPoint in
                    let y = 1.0 - CGFloat((v - lo) / denom)
                    return CGPoint(x: x * w, y: y * h)
                }

                ZStack {
                    // Filled area under the line — gives the sparkline
                    // visual weight without competing with the stroke.
                    Path { p in
                        guard let first = points.first, let last = points.last else { return }
                        p.move(to: CGPoint(x: first.x, y: h))
                        p.addLine(to: first)
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: last.x, y: h))
                        p.closeSubpath()
                    }
                    .fill(self.color.opacity(0.18))

                    // Optional baseline (e.g. 100 % for percent metrics).
                    if let b = self.baseline, b >= lo, b <= hi {
                        let by = 1.0 - CGFloat((b - lo) / denom)
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: by * h))
                            p.addLine(to: CGPoint(x: w, y: by * h))
                        }
                        .stroke(self.color.opacity(0.25),
                                style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    }

                    // The line itself.
                    Path { p in
                        guard let first = points.first else { return }
                        p.move(to: first)
                        for pt in points.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(self.color,
                            style: StrokeStyle(lineWidth: 1.25,
                                               lineCap: .round,
                                               lineJoin: .round))
                }
                .frame(width: w, height: h)
            }
        }
        .frame(width: self.width, height: self.height)
    }

    /// Clamped low/high so a flat or empty series doesn't blow up the
    /// vertical scale. For series that never go negative (CPU%, bytes),
    /// we anchor lo at min(0, observed-min) to keep the floor stable
    /// across renders.
    private func bounds() -> (lo: Double, hi: Double) {
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        // If the series is essentially flat, expand range a hair so the
        // line draws somewhere visible instead of pinning to the bottom.
        if hi - lo < 0.001 {
            return (lo - 0.5, hi + 0.5)
        }
        return (min(lo, 0), hi)
    }
}
