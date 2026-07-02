//
//  BurrowMark.swift
//  Burrow
//
//  Burrow's mark: a cream disc with a dark burrow mouth (a tunnel arch).
//  Used by the floating rail and the popup header.
//

import SwiftUI

/// Burrow's mark: a cream disc with a dark burrow mouth (a tunnel arch).
struct BurrowMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Brand.cream)
                Path { p in
                    let cx = s * 0.5
                    let baseY = s * 0.70
                    let r = s * 0.27
                    p.move(to: CGPoint(x: cx - r, y: baseY))
                    p.addArc(center: CGPoint(x: cx, y: baseY), radius: r,
                             startAngle: .degrees(180), endAngle: .degrees(360),
                             clockwise: false)
                    p.closeSubpath()
                }
                .fill(Brand.espresso)
            }
            .frame(width: s, height: s)
        }
    }
}
