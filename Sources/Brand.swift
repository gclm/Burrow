//
//  Brand.swift
//  Burrow
//
//  Burrow's visual language — the caezium house identity: warm cream ink
//  on a charcoal ground, a single peach accent, soft secondary tints, and
//  generous corner radii. It matches the project site
//  (burrow.henryzh.dev) so the app and the landing page read as one
//  product — our own look, not borrowed from anyone.
//
//  This is deliberately separate from the legacy `Theme` enum so the
//  redesign can land without disturbing older views that still reference
//  `Theme.*`.
//
//  Three font roles:
//    * mono    — labels, numerics, the nav. The "instrument" voice.
//    * rounded — friendly UI chrome where mono feels too rigid.
//    * serif   — the one expressive voice: taglines / hero copy.
//

import SwiftUI

extension Color {
    /// 0xRRGGBB literal → sRGB Color. Cheaper to read than three
    /// Double divisions at every call site.
    init(hex: UInt, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum Brand {
    // MARK: Ground — the charcoal the whole app sits on (matches the site)
    static let base      = Color(hex: 0x121217)   // site --bg
    static let baseSoft  = Color(hex: 0x16161D)   // site --bg-soft
    static let nearBlack = Color(hex: 0x0E0E13)   // legacy name, now warm-charcoal

    // MARK: Text & surfaces — warm cream ink on cream-tinted glass (not white)
    static let ink           = Color(hex: 0xF3ECDD)            // the cream mark
    static let textPrimary   = Color(hex: 0xF3ECDD)
    static let textSecondary = Color(hex: 0xF3ECDD, alpha: 0.66)
    static let textTertiary  = Color(hex: 0xF3ECDD, alpha: 0.42)

    static let hairline      = Color(hex: 0xF3ECDD, alpha: 0.14)    // site --hair
    static let cardFill      = Color(hex: 0xF3ECDD, alpha: 0.045)   // site --surface
    static let cardFillHover = Color(hex: 0xF3ECDD, alpha: 0.09)
    static let chipFill      = Color(hex: 0xF3ECDD, alpha: 0.09)
    static let trackFill     = Color(hex: 0xF3ECDD, alpha: 0.10)

    // MARK: Accent — one peach for emphasis (NOT a per-tool window wash)
    static let accent   = Color(hex: 0xD9A066)   // site --accent (peach)
    static let onAccent = Color(hex: 0x241B12)   // site --on-accent (espresso)
    static let lilac    = Color(hex: 0xD6C6FF)   // site --lilac
    static let apricot  = Color(hex: 0xFFD3B6)   // site --apricot
    static let mint     = Color(hex: 0xC9F2E6)   // site --mint

    // MARK: Metric accents (monitor colour-coding — matches the site set)
    static let green  = Color(hex: 0x57D58E)
    static let gold   = Color(hex: 0xE6A93C)
    static let amber  = Color(hex: 0xF0B24A)
    static let orange = Color(hex: 0xF0714E)   // site --coral
    static let blue   = Color(hex: 0x4FA3E3)   // site --azure
    static let red    = Color(hex: 0xF0604E)
    static let teal   = Color(hex: 0x35C2A5)
    static let violet = Color(hex: 0x8E84F0)
    static let moss   = Color(hex: 0x6FB06A)
    static let ginger = Color(hex: 0xD98C5F)

    // MARK: Brand creams (kept for older callers)
    static let cream    = Color(hex: 0xF3ECDD)
    static let espresso = Color(hex: 0x241B12)

    // MARK: Shape — over-rounded, the house signature (app-scaled --r-* set)
    static let rSmall: CGFloat = 12
    static let rCard:  CGFloat = 20
    static let rLarge: CGFloat = 28

    /// A stable charcoal veil drawn over the window vibrancy — identical on
    /// every pane, so switching tools no longer re-tints the whole window in
    /// that tool's colour. The per-tool hue now lives only in small accents.
    static var windowVeil: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x16161D, alpha: 0.60), Color(hex: 0x101015, alpha: 0.80)],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: Type
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
