//
//  OverviewView.swift
//  Burrow
//
//  The "Overview" tab — the default landing when the main window
//  opens. Shows a row of MetricCards covering CPU / memory / disk /
//  network / thermal / health, each with a 30-sample sparkline read
//  from the SQLite history. Below: hardware identity (model, CPU,
//  RAM), live system info (uptime, processes), and a top-5 processes
//  table for "what's running right now".
//
//  Data path: OverviewModel polls Sampler.lastSnapshot (in-memory) for
//  the current values, plus DB.findRangeSampled for the last ~30 mins
//  of sparkline data. Refreshes every second on the main timer so the
//  freshness label stays current; sparklines re-query the DB every
//  60 seconds (matches the sampler's tick rate — pulling every
//  second would just give the same data).
//

import SwiftUI

@available(macOS 14.0, *)
struct OverviewView: View {
    let db: DB
    let sampler: Sampler
    /// Lets the Overview surface route to other tabs ("Tap History to
    /// see the full chart" → switches sidebar selection).
    var navigate: (BurrowSection) -> Void = { _ in }

    @StateObject private var model: OverviewModel

    init(db: DB, sampler: Sampler, navigate: @escaping (BurrowSection) -> Void = { _ in }) {
        self.db = db
        self.sampler = sampler
        self.navigate = navigate
        self._model = StateObject(wrappedValue: OverviewModel(db: db, sampler: sampler))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                metricsGrid
                if let snap = model.latest {
                    bottomRow(snap)
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colour.windowBackground)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: - Header

    private var header: some View {
        SectionHeader(eyebrow: "Overview",
                      title: "Right now",
                      subtitle: model.freshnessLabel) {
            Button {
                self.navigate(.history)
            } label: {
                Label("View History", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    // MARK: - Metrics grid

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Theme.Spacing.lg),
            GridItem(.flexible(), spacing: Theme.Spacing.lg),
            GridItem(.flexible(), spacing: Theme.Spacing.lg),
        ], spacing: Theme.Spacing.lg) {
            MetricCard(
                title: "CPU",
                value: model.cpuValue,
                detail: model.cpuDetail,
                history: model.cpuHistory,
                accent: Theme.Colour.cpu,
                icon: "cpu",
                rangeLabel: model.rangeLabel
            )
            MetricCard(
                title: "Memory",
                value: model.memValue,
                detail: model.memDetail,
                history: model.memHistory,
                accent: Theme.Colour.memory,
                icon: "memorychip",
                rangeLabel: model.rangeLabel
            )
            MetricCard(
                title: "Disk I/O",
                value: model.diskValue,
                detail: model.diskDetail,
                history: model.diskHistory,
                accent: Theme.Colour.disk,
                icon: "internaldrive",
                rangeLabel: model.rangeLabel
            )
            MetricCard(
                title: "Network",
                value: model.netValue,
                detail: model.netDetail,
                history: model.netHistory,
                accent: Theme.Colour.network,
                icon: "wifi",
                rangeLabel: model.rangeLabel
            )
            if let _ = model.thermalValue {
                MetricCard(
                    title: "Thermal",
                    value: model.thermalValue ?? "—",
                    detail: model.thermalDetail,
                    history: model.thermalHistory,
                    accent: Theme.Colour.thermal,
                    icon: "thermometer.medium",
                    rangeLabel: model.rangeLabel
                )
            }
            MetricCard(
                title: "Health",
                value: model.healthValue,
                detail: model.healthDetail,
                history: model.healthHistory,
                accent: Theme.Colour.health,
                icon: "heart.text.square",
                rangeLabel: model.rangeLabel
            )
        }
    }

    // MARK: - Bottom row (system identity + top processes)

    @ViewBuilder
    private func bottomRow(_ snap: MoleStatus) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            systemCard(snap)
                .frame(maxWidth: .infinity)
            topProcessesCard(snap)
                .frame(maxWidth: .infinity)
        }
    }

    private func systemCard(_ snap: MoleStatus) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(eyebrow: "System",
                              title: snap.hardware.model,
                              subtitle: "\(snap.hardware.cpuModel) · \(snap.hardware.totalRam) · \(snap.hardware.osVersion)") { EmptyView() }
                Divider()
                infoRow(label: "Uptime", value: model.uptimeFormatted)
                infoRow(label: "Processes", value: "\(snap.procs)")
                infoRow(label: "Disk", value: snap.hardware.diskSize)
                if let battery = snap.batteries?.first {
                    infoRow(label: "Battery",
                            value: String(format: "%.0f %% · %@", battery.percent, battery.status))
                }
            }
        }
    }

    private func topProcessesCard(_ snap: MoleStatus) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SectionHeader(eyebrow: "Top processes",
                              title: "By current CPU",
                              subtitle: snap.topProcesses?.isEmpty == false ? nil : "no process activity") {
                    Button {
                        self.navigate(.history)
                    } label: {
                        Text("Across history →").font(Theme.Font.caption)
                    }
                    .buttonStyle(.borderless)
                }
                Divider()
                let procs = (snap.topProcesses ?? []).prefix(5)
                if procs.isEmpty {
                    Text("Idle").font(Theme.Font.caption).foregroundStyle(Theme.Colour.textTertiary)
                } else {
                    ForEach(Array(procs.enumerated()), id: \.offset) { _, p in
                        HStack {
                            Text(p.name).lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f %%", p.cpu))
                                .font(Theme.Font.mono)
                                .foregroundStyle(Theme.Colour.textSecondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(Theme.Font.body)
                    }
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(Theme.Font.caption).foregroundStyle(Theme.Colour.textSecondary)
            Spacer()
            Text(value).font(Theme.Font.mono).foregroundStyle(Theme.Colour.textPrimary)
        }
    }
}

// MARK: - Overview model

@MainActor
final class OverviewModel: ObservableObject {
    @Published var latest: MoleStatus?
    @Published var freshnessLabel: String = "—"
    @Published var rangeLabel: String = "30 m"

    // Sparkline series — oldest first; ~30 points each at 60s cadence
    // = 30 minutes of recent history.
    @Published var cpuHistory: [Double] = []
    @Published var memHistory: [Double] = []
    @Published var diskHistory: [Double] = []
    @Published var netHistory: [Double] = []
    @Published var thermalHistory: [Double] = []
    @Published var healthHistory: [Double] = []

    private let db: DB
    private let sampler: Sampler
    private var freshnessTimer: Timer?
    private var historyTimer: Timer?

    init(db: DB, sampler: Sampler) {
        self.db = db
        self.sampler = sampler
    }

    func start() {
        self.refreshCurrent()
        self.refreshHistory()
        // Freshness refresh ticks every second so "12 s ago" stays
        // current without me having to debounce a TimelineView. History
        // refresh ticks every 30 s — same as the sample cadence in
        // practice, so we're never staler than one tick behind disk.
        self.freshnessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCurrent() }
        }
        self.historyTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshHistory() }
        }
    }

    func stop() {
        self.freshnessTimer?.invalidate(); self.freshnessTimer = nil
        self.historyTimer?.invalidate(); self.historyTimer = nil
    }

    // MARK: - Current value formatting

    var cpuValue: String { latest.map { String(format: "%.1f %%", $0.cpu.usage) } ?? "—" }
    var cpuDetail: String? { latest.map { String(format: "load %.2f", $0.cpu.load1) } }

    var memValue: String { latest.map { String(format: "%.1f %%", $0.memory.usedPercent) } ?? "—" }
    var memDetail: String? { latest.map { "pressure \($0.memory.pressure)" } }

    var diskValue: String {
        guard let s = latest else { return "—" }
        return String(format: "%.1f / %.1f MB/s", s.diskIO.readRate, s.diskIO.writeRate)
    }
    var diskDetail: String? { "read / write" }

    var netValue: String {
        guard let s = latest else { return "—" }
        let rx = s.network.reduce(0.0) { $0 + $1.rxRateMbs }
        let tx = s.network.reduce(0.0) { $0 + $1.txRateMbs }
        return String(format: "%.2f / %.2f MB/s", rx, tx)
    }
    var netDetail: String? { "rx / tx" }

    var thermalValue: String? {
        guard let t = latest?.thermal, t.cpuTemp > 0 else { return nil }
        return String(format: "%.0f °C", t.cpuTemp)
    }
    var thermalDetail: String? {
        guard let t = latest?.thermal else { return nil }
        if t.fanSpeed > 0 { return "fan \(t.fanSpeed) RPM" }
        return nil
    }

    var healthValue: String { latest.map { "\($0.healthScore)" } ?? "—" }
    var healthDetail: String? {
        guard let s = latest, !s.healthScoreMsg.isEmpty else { return nil }
        return s.healthScoreMsg
    }

    var uptimeFormatted: String {
        guard let secs = latest?.uptimeSeconds else { return "—" }
        let d = Int(secs / 86_400)
        let h = Int((secs % 86_400) / 3_600)
        let m = Int((secs % 3_600) / 60)
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Refresh

    private func refreshCurrent() {
        self.latest = self.sampler.lastSnapshot
        if let when = self.sampler.lastSampleAt {
            let elapsed = Int(Date().timeIntervalSince(when))
            self.freshnessLabel = "\(elapsed) s since last sample"
        } else {
            self.freshnessLabel = "waiting for first sample…"
        }
    }

    /// Pulls the last ~30 minutes of mole.snapshot rows and projects
    /// each metric into its sparkline series. One SQL query, decoded
    /// once.
    private func refreshHistory() {
        let now = Int(Date().timeIntervalSince1970)
        let since = now - 30 * 60  // 30 min — matches the rangeLabel below
        // 60 points at 30s spacing — plenty of resolution for sparklines.
        let rows = self.db.findRangeSampled(prefix: Sampler.snapshotPrefix,
                                            since: since, until: now,
                                            maxPoints: 60)

        var cpu: [Double] = [], mem: [Double] = [], disk: [Double] = []
        var net: [Double] = [], thermal: [Double] = [], health: [Double] = []
        cpu.reserveCapacity(rows.count); mem.reserveCapacity(rows.count)
        disk.reserveCapacity(rows.count); net.reserveCapacity(rows.count)
        thermal.reserveCapacity(rows.count); health.reserveCapacity(rows.count)

        let dec = JSONDecoder()
        for r in rows {
            guard let data = r.json.data(using: .utf8) else { continue }
            guard let s = try? dec.decode(MoleStatus.self, from: data) else { continue }
            cpu.append(s.cpu.usage)
            mem.append(s.memory.usedPercent)
            disk.append(s.diskIO.readRate + s.diskIO.writeRate)
            let nrx = s.network.reduce(0.0) { $0 + $1.rxRateMbs }
            let ntx = s.network.reduce(0.0) { $0 + $1.txRateMbs }
            net.append(nrx + ntx)
            if let t = s.thermal, t.cpuTemp > 0 { thermal.append(t.cpuTemp) }
            health.append(Double(s.healthScore))
        }
        self.cpuHistory = cpu
        self.memHistory = mem
        self.diskHistory = disk
        self.netHistory = net
        self.thermalHistory = thermal
        self.healthHistory = health
    }
}
