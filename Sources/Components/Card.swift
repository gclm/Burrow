//
//  Card.swift
//  Burrow / Components
//
//  General-purpose card container. One rounded rectangle, one
//  background tier above the window, optional hairline border, content
//  inside. Used for chart cards, metric cards, the disk-map header
//  region, settings sub-panels.
//
//  Why a wrapper instead of inlining `.background(.regular,
//  in: RoundedRectangle(...))` at every call site: one knob in
//  Theme.Radius.md tunes every card in the app, and the comment
//  block at the call site stays focused on what the card holds rather
//  than how it's framed.
//

import SwiftUI

struct Card<Content: View>: View {
    enum Variant {
        /// Default card — opaque background, soft border.
        case solid
        /// Quieter — for nested groupings inside another card.
        case quiet
        /// For warning / danger states.
        case alert(Color)
    }

    var variant: Variant = .solid
    var padding: CGFloat = Theme.Spacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(self.padding)
            // `.background { }` (closure form) accepts any View, so we
            // can hand it a shape filled with the variant's colour
            // without fighting SwiftUI's ShapeStyle constraint on the
            // (style, in:) overload — Color *is* a ShapeStyle but the
            // typed `some View` return from @ViewBuilder erases that.
            .background {
                self.shape.fill(self.fillColour)
            }
            .overlay {
                self.border
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
    }

    private var fillColour: Color {
        switch self.variant {
        case .solid: return Theme.Colour.cardBackground
        case .quiet: return Theme.Colour.cardBackground.opacity(0.5)
        case .alert(let c): return c.opacity(0.08)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch self.variant {
        case .solid:
            self.shape.strokeBorder(Theme.Colour.divider, lineWidth: 0.5)
        case .quiet:
            EmptyView()
        case .alert(let c):
            self.shape.strokeBorder(c.opacity(0.4), lineWidth: 1)
        }
    }
}

// MARK: - Section header (used inside cards and at page top)

/// Tight three-piece section heading: small uppercase eyebrow, larger
/// title, optional trailing accessory (range picker, button, etc).
/// Replaces ad-hoc `HStack { Text("UPPERCASE")...Text("subtitle")... }`
/// blocks at every call site.
struct SectionHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    init(eyebrow: String? = nil,
         title: String,
         subtitle: String? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                if let e = self.eyebrow {
                    Text(e.uppercased())
                        .font(Theme.Font.eyebrow)
                        .tracking(0.6)
                        .foregroundStyle(Theme.Colour.textSecondary)
                }
                Text(self.title).font(Theme.Font.cardTitle)
                if let s = self.subtitle {
                    Text(s).font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colour.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            self.trailing()
        }
    }
}
