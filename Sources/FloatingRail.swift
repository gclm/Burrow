//
//  FloatingRail.swift
//  Burrow
//
//  The left-edge navigation: a floating, rounded rail of icon buttons in
//  place of a top tab bar. The Burrow mark (Home) sits at the top, the
//  tools below — each lighting up in its own accent when active — and
//  Settings is pinned to the foot. Same single `Pane` model as the rest of
//  the window; this just trades TopNav's horizontal pill strip for a
//  vertical, detached rail so the shell stops reading like a tab bar.
//

import SwiftUI

struct FloatingRail: View {
    @Binding var selected: Pane

    var body: some View {
        VStack(spacing: 8) {
            homeButton
            Rectangle().fill(Brand.hairline)
                .frame(width: 22, height: 1)
                .padding(.vertical, 2)
            ForEach(Tool.navOrder) { tool in
                toolButton(tool)
            }
            Spacer(minLength: 8)
            utilityButton("gearshape", pane: .settings,
                          help: NSLocalizedString("Settings", comment: ""))
        }
        .padding(8)
        .frame(width: 60)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Brand.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Brand.hairline, lineWidth: 1)
        )
    }

    /// The Burrow mark doubles as Home — the live dashboard. A soft inset
    /// tile marks it as selected (it's neutral, not a tool, so no accent).
    private var homeButton: some View {
        let isOn = selected == .home
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { selected = .home }
        } label: {
            BurrowMark()
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Brand.cardFillHover)
                    }
                }
                .overlay {
                    if isOn {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Brand.textSecondary.opacity(0.45), lineWidth: 1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("Home", comment: ""))
    }

    /// A tool: SF-symbol glyph that fills with the tool's own accent gradient
    /// when active — the per-tool colour, kept to the button instead of the
    /// whole window.
    private func toolButton(_ tool: Tool) -> some View {
        let isOn = selected == .tool(tool)
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { selected = .tool(tool) }
        } label: {
            Image(systemName: tool.glyph)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isOn ? Brand.onAccent : Brand.textSecondary)
                .frame(width: 44, height: 44)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [tool.accent, tool.accent.opacity(0.78)],
                                                 startPoint: .top, endPoint: .bottom))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }

    /// A utility (Settings): lights up in the single primary accent.
    private func utilityButton(_ symbol: String, pane: Pane, help: String) -> some View {
        let isOn = selected == pane
        return Button {
            withAnimation(.easeOut(duration: 0.16)) { selected = pane }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isOn ? Brand.onAccent : Brand.textSecondary)
                .frame(width: 44, height: 44)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Brand.accent)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
