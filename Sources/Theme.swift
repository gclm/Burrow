//
//  Theme.swift
//  Burrow
//
//  Design tokens — colors, typography, spacing, corner radii — all in
//  one place so the rest of the UI references named constants instead
//  of magic numbers / ad-hoc Color(...) calls. This is what makes a
//  polish pass possible: change a token here, the whole app moves.
//
//  Principles:
//    * Lean on system colors (`accentColor`, `controlBackgroundColor`,
//      etc.) wherever possible so Burrow inherits the user's chosen
//      accent and dark-mode adaptation comes for free.
//    * Semantic naming over hex literals — `.background.surface`
//      means something the next reader can reason about; `#1c1c1e`
//      doesn't.
//    * Single spacing scale based on 4 — everything in the UI is one
//      of 4/8/12/16/20/24/32/40 px. Consistency reads as
//      intentionality.
//

import SwiftUI

enum Theme {
    // MARK: - Spacing

    enum Spacing {
        /// 4 px — text-line gaps, icon-to-label padding
        static let xxs: CGFloat = 4
        /// 8 px — close-grouping (paired labels)
        static let xs: CGFloat = 8
        /// 12 px — adjacent rows in a list, intra-card padding
        static let sm: CGFloat = 12
        /// 16 px — card padding, section row spacing
        static let md: CGFloat = 16
        /// 20 px — between cards in a grid
        static let lg: CGFloat = 20
        /// 24 px — between major sections within a page
        static let xl: CGFloat = 24
        /// 32 px — between distinct page regions
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner radii

    enum Radius {
        /// 6 — small controls (buttons, chips)
        static let sm: CGFloat = 6
        /// 10 — cards, panels
        static let md: CGFloat = 10
        /// 14 — large containers
        static let lg: CGFloat = 14
        /// 18 — sidebar items when selected
        static let xl: CGFloat = 18
    }

    // MARK: - Typography

    /// Burrow's text styles. The system fonts (`.title`, `.body`, etc.)
    /// are perfectly fine — these are named wrappers so the *intent*
    /// is visible at the call site (`.font(.brand.cardTitle)` reads
    /// better than `.font(.system(size: 13, weight: .semibold))`).
    enum Font {
        /// 22 pt semibold — main page heading ("History", "Disk Map")
        static let pageTitle = SwiftUI.Font.system(size: 22, weight: .semibold)
        /// 13 pt regular — body text, captions inside cards
        static let body = SwiftUI.Font.system(size: 13)
        /// 13 pt semibold — card titles, sidebar labels
        static let cardTitle = SwiftUI.Font.system(size: 13, weight: .semibold)
        /// 11 pt regular — secondary captions ("4 s ago")
        static let caption = SwiftUI.Font.system(size: 11)
        /// 10 pt bold, uppercased — section eyebrows ("CPU", "MEMORY")
        static let eyebrow = SwiftUI.Font.system(size: 10, weight: .bold)
        /// 28 pt semibold, monospaced numeric — big "right now" readouts
        static let metric = SwiftUI.Font.system(size: 28, weight: .semibold).monospacedDigit()
        /// 12 pt regular monospaced — table values, paths, numeric grids
        static let mono = SwiftUI.Font.system(size: 12, design: .monospaced)
    }

    // MARK: - Colours

    /// Named colour tokens. Resolve through system colours where
    /// possible — they handle dark mode + high-contrast accessibility
    /// without us having to maintain a parallel palette.
    enum Colour {
        /// Window background (the broadest fill).
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        /// Card / panel background (one tier "above" the window).
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        /// Sidebar background — system uses a slightly darker tint with
        /// a vibrancy effect by default; we mirror that intent.
        static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
        /// Selected sidebar item — uses the user's chosen accent.
        static let sidebarSelection = Color.accentColor.opacity(0.18)
        /// Hairline divider colour.
        static let divider = Color(nsColor: .separatorColor)
        /// Primary text.
        static let textPrimary = Color(nsColor: .labelColor)
        /// Secondary text (captions, hints).
        static let textSecondary = Color(nsColor: .secondaryLabelColor)
        /// Tertiary text (very faint).
        static let textTertiary = Color(nsColor: .tertiaryLabelColor)

        /// Semantic state colours. SwiftUI's `.red`/`.green`/etc are
        /// fine but these names tell readers what the colour means.
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let accent = Color.accentColor

        /// Per-metric accents used across charts + cards. Picked from
        /// the system palette so they stay consistent + dark-mode
        /// friendly. Mole's `mo status` uses similar grouping; this
        /// keeps the Burrow charts visually close to a CLI session
        /// looking at the same data.
        static let cpu = Color.orange
        static let memory = Color.purple
        static let disk = Color.cyan
        static let network = Color.green
        static let thermal = Color.red
        static let health = Color.yellow
    }
}
