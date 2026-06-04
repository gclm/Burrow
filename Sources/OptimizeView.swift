//
//  OptimizeView.swift
//  Burrow
//
//  The Optimize tab — mole.fit's "Mercury" one-tap maintenance, our
//  brand. "Optimize" runs the safe maintenance tasks (elevated through a
//  single auth prompt so there aren't repeated password dialogs);
//  "Preview" is a no-auth `--dry-run`. Results render through the shared
//  TaskReportView and finish on a done banner.
//

import SwiftUI

struct OptimizeView: View {
    @StateObject private var runner = CommandRunner()
    @State private var preview = false

    var body: some View {
        if runner.phase == .idle {
            ToolHero(tool: .optimize, title: "Optimize", subtitle: Tool.optimize.tagline) {
                PillButton(title: "Optimize") { preview = false; runner.run(["optimize"], label: "Optimizing") }
                PillButton(title: "Preview", filled: false) { preview = true; runner.run(["optimize", "--dry-run"], label: "Optimize preview") }
            }
        } else {
            let report = parseTaskReport(runner.lines)
            VStack(spacing: 0) {
                statusBar.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
                Rectangle().fill(Brand.hairline).frame(height: 1)
                if isDone, !preview {
                    DoneBanner(accent: Tool.optimize.accent, title: "Maintenance complete",
                               detail: "\(report.groups.count) areas refreshed")
                }
                TaskReportView(groups: report.groups, accent: Tool.optimize.accent)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if runner.phase == .running { ProgressView().controlSize(.small).tint(Tool.optimize.accent) }
            Text(statusText).font(Brand.mono(12)).foregroundStyle(Brand.textSecondary)
            Spacer()
            if isDone {
                Button { preview = false; runner.run(["optimize"], label: "Optimizing") } label: {
                    Label("Run again", systemImage: "arrow.clockwise")
                        .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                }.buttonStyle(.plain)
            }
        }
    }

    private var isDone: Bool { if case .done = runner.phase { return true }; return false }

    private var statusText: String {
        switch runner.phase {
        case .running: return preview ? "Previewing maintenance…" : "Running maintenance…"
        case .done:    return preview ? "Preview complete." : "Maintenance complete."
        case .failed(let m): return "Failed: \(m)"
        case .idle:    return ""
        }
    }
}
