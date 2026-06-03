//
//  MetricCard.swift
//  Burrow / Components
//
//  The "right now + how it's trending" card used on the Overview tab
//  and (smaller variant) inside the popover. Layout:
//
//      ┌────────────────────────────────────────────┐
//      │ CPU                          load 1.24     │  ← eyebrow + caption
//      │                                            │
//      │ 47.3 %                                     │  ← big monospaced metric
//      │                                            │
//      │ ╱╲     ╱╲╱╲                                │  ← sparkline
//      │   ╲___╱    ╲___                            │
//      │                              5 m            │  ← time range hint
//      └────────────────────────────────────────────┘
//
//  Reusing `Card` for the chrome means the metric card automatically
//  picks up the design-system corner radius + border + background tier
//  — there's nothing card-shaped in the app that doesn't go through
//  one of these.
//

import SwiftUI

struct MetricCard: View {
    /// What this card is about — "CPU", "Memory", "Disk I/O", etc.
    let title: String
    /// Headline value, already formatted ("47.3 %", "12.4 GB", "—").
    let value: String
    /// Optional sub-detail to the right of the title ("load 1.24",
    /// "pressure normal"). Trimmed away if empty.
    var detail: String? = nil
    /// Sparkline samples — oldest first, ~30-120 points is the sweet
    /// spot. Empty array hides the sparkline gracefully.
    var history: [Double] = []
    /// Accent — both for the sparkline stroke and the (optional) icon.
    var accent: Color = .accentColor
    /// SF Symbol name to render next to the title. Skip with nil.
    var icon: String? = nil
    /// Range label shown bottom-right of the sparkline. Hidden if nil.
    var rangeLabel: String? = nil

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                self.headerRow
                self.metricRow
                self.sparkRow
            }
        }
    }

    // MARK: - Slices

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
            if let icon = self.icon {
                Image(systemName: icon)
                    .foregroundStyle(self.accent)
                    .imageScale(.small)
            }
            Text(self.title.uppercased())
                .font(Theme.Font.eyebrow)
                .tracking(0.6)
                .foregroundStyle(Theme.Colour.textSecondary)
            Spacer(minLength: Theme.Spacing.xs)
            if let d = self.detail, !d.isEmpty {
                Text(d)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colour.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private var metricRow: some View {
        Text(self.value)
            .font(Theme.Font.metric)
            .foregroundStyle(Theme.Colour.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sparkRow: some View {
        ZStack(alignment: .bottomTrailing) {
            if self.history.count >= 2 {
                Sparkline(values: self.history, color: self.accent, height: 28)
                    .frame(height: 28)
            } else {
                // Pad the same vertical space so cards with sparse data
                // don't shrink vs ones with full history — keeps the
                // grid tidy.
                Color.clear.frame(height: 28)
                Text("—")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colour.textTertiary)
            }
            if let r = self.rangeLabel {
                Text(r)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colour.textTertiary)
                    .padding(.trailing, 2)
                    .padding(.bottom, 0)
            }
        }
    }
}
