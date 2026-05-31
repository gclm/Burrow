//
//  PopupView.swift
//  Burrow
//
//  Menu-bar popover contents. Reads the latest snapshot from the
//  Sampler (in-memory mirror of the most recent successful sample);
//  redraws every second so the freshness timer stays current.
//
//  This is intentionally minimal for v0.1 — the goal is "see at a
//  glance whether Burrow is collecting" plus a single-screen summary
//  of the things Mole reports. The full History view + cleanup UI
//  come in later commits.
//

import SwiftUI

struct PopupView: View {
    @ObservedObject private var model: PopupModel

    init(sampler: Sampler) {
        self.model = PopupModel(sampler: sampler)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let snap = model.snapshot {
                summary(snap)
            } else {
                ContentUnavailableView(
                    "Waiting for first sample",
                    systemImage: "antenna.radiowaves.left.and.right.slash",
                    description: Text("Burrow runs `mo status --json` every 60 s. The first row appears within a minute of launch.")
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .onReceive(model.tickPublisher) { _ in model.refresh() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "house.lodge.fill").foregroundStyle(.tint)
            Text("Burrow").font(.headline)
            Spacer()
            Text(model.freshnessLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func summary(_ s: MoleStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row(label: "CPU",
                value: String(format: "%.1f %%", s.cpu.usage),
                detail: "load \(String(format: "%.2f", s.cpu.load1))")
            row(label: "Memory",
                value: String(format: "%.1f %%", s.memory.usedPercent),
                detail: s.memory.pressure)
            row(label: "Disk",
                value: String(format: "R %.1f / W %.1f MB/s",
                              s.diskIO.readRate, s.diskIO.writeRate),
                detail: nil)
            if let thermal = s.thermal, thermal.cpuTemp > 0 {
                row(label: "Temp",
                    value: String(format: "%.0f °C", thermal.cpuTemp),
                    detail: thermal.fanSpeed > 0 ? "fan \(thermal.fanSpeed)" : nil)
            }
            row(label: "Health",
                value: "\(s.healthScore)",
                detail: s.healthScoreMsg.isEmpty ? nil : s.healthScoreMsg)
        }
        .font(.system(size: 12, design: .monospaced))
    }

    private func row(label: String, value: String, detail: String?) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
            Text(value)
            Spacer()
            if let d = detail { Text(d).foregroundStyle(.tertiary) }
        }
    }

    private var footer: some View {
        HStack {
            Text("MCP @ 127.0.0.1:\(QueryServer.defaultPort)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Button("Quit", action: { NSApp.terminate(nil) })
                .keyboardShortcut("q", modifiers: .command)
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
    }
}

// MARK: - Tick driver

/// Drives a 1 Hz redraw of the popup. `ObservedObject` so SwiftUI
/// re-runs `body` when `snapshot` or `freshnessLabel` change. Lives as
/// long as the popover's `NSHostingController`.
private final class PopupModel: ObservableObject {
    @Published var snapshot: MoleStatus?
    @Published var freshnessLabel: String = "—"

    let tickPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let sampler: Sampler

    init(sampler: Sampler) {
        self.sampler = sampler
        self.refresh()
    }

    func refresh() {
        self.snapshot = self.sampler.lastSnapshot
        if let last = self.sampler.lastSampleAt {
            let elapsed = Int(Date().timeIntervalSince(last))
            self.freshnessLabel = "\(elapsed)s ago"
        } else {
            self.freshnessLabel = "—"
        }
    }
}
