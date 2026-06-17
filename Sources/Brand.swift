//
//  Brand.swift
//  Burrow
//
//  Burrow's visual language — a cool graphite ground, crisp off-white ink,
//  and a single electric-blue accent for primary emphasis. Each tool still
//  keeps its own vivid accent (teal / violet / coral / azure / gold) for
//  active states, so the app reads as one calm surface with bright,
//  purposeful pops — not a window that re-tints itself per tool.
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
    // MARK: Ground — a cool graphite the whole app sits on
    static let base      = Color(hex: 0x0E0F13)
    static let baseSoft  = Color(hex: 0x15171C)
    static let nearBlack = Color(hex: 0x0A0B0D)

    // MARK: Text & surfaces — crisp cool off-white on neutral glass
    static let ink           = Color(hex: 0xE9EAEE)
    static let textPrimary   = Color(hex: 0xE9EAEE)
    static let textSecondary = Color(hex: 0xE9EAEE, alpha: 0.62)
    static let textTertiary  = Color(hex: 0xE9EAEE, alpha: 0.40)

    static let hairline      = Color.white.opacity(0.09)
    static let cardFill      = Color.white.opacity(0.045)
    static let cardFillHover = Color.white.opacity(0.08)
    static let chipFill      = Color.white.opacity(0.08)
    static let trackFill     = Color.white.opacity(0.10)

    // MARK: Accent — one electric blue for primary emphasis
    static let accent   = Color(hex: 0x5B8DEF)
    static let onAccent = Color(hex: 0x0A0E16)   // near-black text on any bright accent
    static let lilac    = Color(hex: 0xB7B2FF)
    static let apricot  = Color(hex: 0xFFD3B6)
    static let mint     = Color(hex: 0x8FE9D0)

    // MARK: Metric / per-tool accents (vivid pops on the graphite ground)
    static let green  = Color(hex: 0x57D58E)
    static let gold   = Color(hex: 0xE6A93C)
    static let amber  = Color(hex: 0xF0B24A)
    static let orange = Color(hex: 0xF0714E)
    static let blue   = Color(hex: 0x4FA3E3)
    static let red    = Color(hex: 0xF0604E)
    static let teal   = Color(hex: 0x35C2A5)
    static let violet = Color(hex: 0x8E84F0)
    static let moss   = Color(hex: 0x6FB06A)
    static let ginger = Color(hex: 0xD98C5F)

    // MARK: Brand mark colours (the Burrow disc keeps a warm pop)
    static let cream    = Color(hex: 0xF3ECDD)
    static let espresso = Color(hex: 0x1A140E)

    // MARK: Shape — rounded, the house signature
    static let rSmall: CGFloat = 12
    static let rCard:  CGFloat = 18
    static let rLarge: CGFloat = 26

    /// A stable graphite veil drawn over the window vibrancy — identical on
    /// every pane, so switching tools no longer re-tints the whole window in
    /// that tool's colour. The per-tool hue now lives only in small accents.
    static var windowVeil: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x15171C, alpha: 0.55), Color(hex: 0x0B0C10, alpha: 0.82)],
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
