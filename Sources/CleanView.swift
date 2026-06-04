//
//  CleanView.swift
//  Burrow
//
//  The Clean tab — mole.fit's "Earth" flow, our brand. The hero offers
//  both a no-risk "Scan your Mac" preview (`mo clean --dry-run`) and a
//  direct "Clean Now" run. The real clean runs elevated through ONE auth
//  prompt (CommandRunner.runElevated) so you don't get a stack of
//  password dialogs, and finishes on a proper done banner.
//

import SwiftUI
import AppKit

struct CleanView: View {
    @StateObject private var runner = CommandRunner()
    @State private var mode: Mode = .dry

    enum Mode { case dry, real }

    var body: some View {
        if runner.phase == .idle {
            ToolHero(tool: .clean, title: "Clean", subtitle: Tool.clean.tagline) {
                PillButton(title: "Scan your Mac") { startDry() }
                PillButton(title: "Clean Now", filled: false) { confirmReal() }
            }
        } else {
            let report = parseTaskReport(runner.lines)
            VStack(spacing: 0) {
                statusBar.padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
                Rectangle().fill(Brand.hairline).frame(height: 1)
                if isDone, mode == .real {
                    DoneBanner(accent: Tool.clean.accent, title: "Cleaned",
                               detail: report.summary.map { "Freed up to \($0.space) · \($0.items) items" })
                } else if mode == .dry, let s = report.summary {
                    summaryBanner(s)
                }
                TaskReportView(groups: report.groups, accent: Tool.clean.accent)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if isRunning { ProgressView().controlSize(.small).tint(Tool.clean.accent) }
            Text(statusText).font(Brand.mono(12)).foregroundStyle(Brand.textSecondary)
            Spacer()
            if isDone {
                Button { startDry() } label: {
                    Label("Re-scan", systemImage: "arrow.clockwise")
                        .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                }.buttonStyle(.plain)
            }
            if mode == .dry, isDone {
                PillButton(title: "Clean for real") { confirmReal() }
            }
        }
    }

    private func summaryBanner(_ s: TaskSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(s.space.isEmpty ? "—" : s.space)
                .font(Brand.mono(24, .semibold)).foregroundStyle(Tool.clean.accent)
            Text("to free").font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
            if !s.items.isEmpty {
                Text("· \(s.items) items · \(s.categories) categories")
                    .font(Brand.mono(11)).foregroundStyle(Brand.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    private var isRunning: Bool { runner.phase == .running }
    private var isDone: Bool { if case .done = runner.phase { return true }; return false }

    private var statusText: String {
        switch runner.phase {
        case .running: return mode == .dry ? "Scanning your Mac…" : "Cleaning… don't quit."
        case .done:    return mode == .dry ? "Preview — review, then clean for real." : "Done — caches cleared."
        case .failed(let m): return "Failed: \(m)"
        case .idle:    return ""
        }
    }

    private func startDry() { mode = .dry; runner.run(["clean", "--dry-run"]) }

    private func confirmReal() {
        let alert = NSAlert()
        alert.messageText = "Clean caches for real?"
        alert.informativeText = "Burrow will run `mo clean` with administrator rights (one password prompt). Cache files are removed permanently; Mole's whitelist and safety rules still apply."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clean")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        mode = .real
        runner.run(["clean"], elevated: true)
    }
}
