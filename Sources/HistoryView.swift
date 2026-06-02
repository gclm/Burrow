//
//  HistoryView.swift
//  Burrow
//
//  History window: range chips + line charts for CPU/memory/disk
//  IO/network/thermal/health, plus a top-N processes table aggregated
//  across the window.
//
//  Data path: range chip selection → DB.findRangeSampled (stride-
//  sampled, ≤720 rows) → decode each row to MoleStatus → project to
//  per-chart ChartPoint arrays → render.
//
//  The decode happens once per reload, not per chart, because every
//  chart series comes from the same MoleStatus tree. ~3 KB JSON × 720
//  rows = ~2 MB of decoding, low-tens of ms on M-series. Top-N
//  processes aggregates per-name peak CPU / peak memory across rows.
//
//  Lineage: shape lifted from the Stats fork's HistoryView. The big
//  simplification vs Stats: one prefix, one decode loop. Stats had to
//  fan out across CPU@LoadReader / RAM@UsageReader / etc; Burrow's
//  single mole.snapshot prefix carries everything.
//

import SwiftUI
import Charts

// MARK: - Range chips

struct HistoryRange: Hashable, Identifiable {
    let label: String
    let minutes: Int
    var id: Int { minutes }

    static let all: [HistoryRange] = [
        .init(label: "5m",  minutes: 5),
        .init(label: "1h",  minutes: 60),
        .init(label: "6h",  minutes: 360),
        .init(label: "24h", minutes: 1440),
        .init(label: "7d",  minutes: 10080),
        .init(label: "30d", minutes: 43200),
        .init(label: "90d", minutes: 129600),
    ]
}

// MARK: - Chart series + snapshot bag

struct ChartPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}

struct ProcessRow: Identifiable {
    let id = UUID()
    let name: String
    let peakCPU: Double
    let peakMem: Double
}

private struct HistorySnapshot {
    var cpuUsage: [ChartPoint] = []
    var cpuLoad1: [ChartPoint] = []
    var memoryUsed: [ChartPoint] = []
    var memoryPressure: String = "—"
    var diskRead: [ChartPoint] = []
    var diskWrite: [ChartPoint] = []
    var netRx: [ChartPoint] = []
    var netTx: [ChartPoint] = []
    var thermalCPU: [ChartPoint] = []
    var thermalGPU: [ChartPoint] = []
    var healthScore: [ChartPoint] = []

    var topProcesses: [ProcessRow] = []

    var generatedAt: Date = Date()
    var rowCount: Int = 0
    var staleSeconds: Int? = nil

    var windowSince: Date = Date().addingTimeInterval(-3600)
    var windowUntil: Date = Date()
}

// MARK: - Loader (off-main)

private enum HistoryLoader {
    static func load(db: DB, rangeMinutes: Int) -> HistorySnapshot {
        let now = Int(Date().timeIntervalSince1970)
        let since = now - rangeMinutes * 60
        var snap = HistorySnapshot()
        snap.windowSince = Date(timeIntervalSince1970: TimeInterval(since))
        snap.windowUntil = Date(timeIntervalSince1970: TimeInterval(now))

        let rows = db.findRangeSampled(prefix: Sampler.snapshotPrefix,
                                       since: since, until: now,
                                       maxPoints: 720)
        snap.rowCount = rows.count

        let dec = JSONDecoder()
        // Top-N aggregation: peak CPU% and peak memory% per process name
        // across the window. Mole's top_processes are already sorted by
        // a per-tick metric, so the union of names across the sampled
        // rows is a reasonable candidate set without us having to keep
        // every process from every tick.
        var peakCPU: [String: Double] = [:]
        var peakMem: [String: Double] = [:]

        for row in rows {
            guard let data = row.json.data(using: .utf8) else { continue }
            guard let s = try? dec.decode(MoleStatus.self, from: data) else { continue }

            let t = Date(timeIntervalSince1970: TimeInterval(row.ts))
            snap.cpuUsage.append(.init(time: t, value: s.cpu.usage))
            snap.cpuLoad1.append(.init(time: t, value: s.cpu.load1))
            snap.memoryUsed.append(.init(time: t, value: s.memory.usedPercent))
            snap.diskRead.append(.init(time: t, value: s.diskIO.readRate))
            snap.diskWrite.append(.init(time: t, value: s.diskIO.writeRate))
            // Sum interface rates — multi-interface (WiFi + cellular)
            // would otherwise show only one. Most boxes have one active.
            let rx = s.network.reduce(0.0) { $0 + $1.rxRateMbs }
            let tx = s.network.reduce(0.0) { $0 + $1.txRateMbs }
            snap.netRx.append(.init(time: t, value: rx))
            snap.netTx.append(.init(time: t, value: tx))
            if let thermal = s.thermal {
                if thermal.cpuTemp > 0 {
                    snap.thermalCPU.append(.init(time: t, value: thermal.cpuTemp))
                }
                if thermal.gpuTemp > 0 {
                    snap.thermalGPU.append(.init(time: t, value: thermal.gpuTemp))
                }
            }
            snap.healthScore.append(.init(time: t, value: Double(s.healthScore)))

            for p in (s.topProcesses ?? []) {
                if p.cpu > (peakCPU[p.name] ?? 0)    { peakCPU[p.name] = p.cpu }
                if p.memory > (peakMem[p.name] ?? 0) { peakMem[p.name] = p.memory }
            }

            // Latest-row metadata.
            snap.memoryPressure = s.memory.pressure
        }

        // Build the top-N table: union of the top-15 by peak CPU and
        // peak memory. Picking either alone misses processes that hit
        // one dimension but not the other. 15 across both ≈ 20-25
        // distinct rows, plenty for the table.
        let topByCPU = peakCPU.sorted { $0.value > $1.value }.prefix(15).map(\.key)
        let topByMem = peakMem.sorted { $0.value > $1.value }.prefix(15).map(\.key)
        var seen = Set<String>()
        var rows2: [ProcessRow] = []
        for name in topByCPU + topByMem where seen.insert(name).inserted {
            rows2.append(ProcessRow(name: name,
                                    peakCPU: peakCPU[name] ?? 0,
                                    peakMem: peakMem[name] ?? 0))
        }
        snap.topProcesses = rows2.sorted { $0.peakCPU > $1.peakCPU }

        snap.generatedAt = Date()
        if let latest = rows.last {
            snap.staleSeconds = max(0, now - latest.ts)
        }
        return snap
    }
}

// MARK: - Axis style helper

@available(macOS 14.0, *)
private struct AxisStyle {
    let format: Date.FormatStyle
    let desiredCount: Int

    static func forRangeMinutes(_ rangeMinutes: Int) -> AxisStyle {
        switch rangeMinutes {
        case ..<60:
            return AxisStyle(format: .dateTime.hour().minute(), desiredCount: 5)
        case ..<(6 * 60):
            return AxisStyle(format: .dateTime.hour().minute(), desiredCount: 5)
        case ..<(24 * 60):
            return AxisStyle(format: .dateTime.hour(), desiredCount: 6)
        case ..<(8 * 24 * 60):
            return AxisStyle(format: .dateTime.weekday(.abbreviated).day(), desiredCount: 5)
        case ..<(45 * 24 * 60):
            return AxisStyle(format: .dateTime.month(.abbreviated).day(), desiredCount: 6)
        default:
            return AxisStyle(format: .dateTime.month(.abbreviated), desiredCount: 4)
        }
    }
}

// MARK: - View

@available(macOS 14.0, *)
struct HistoryView: View {
    let db: DB

    @State private var range: HistoryRange = {
        let m = Store.lastHistoryRangeMinutes
        return HistoryRange.all.first(where: { $0.minutes == m }) ?? HistoryRange.all[1]
    }()
    @State private var snapshot: HistorySnapshot = HistorySnapshot()
    @State private var loading: Bool = false
    @State private var loadGen: Int = 0

    private let autoRefreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 18) {
                    chartCard("CPU Usage", subtitle: "%", series: [
                        ("usage", snapshot.cpuUsage, Color.orange)
                    ])
                    chartCard("CPU Load (1m)", subtitle: "load avg", series: [
                        ("load1", snapshot.cpuLoad1, Color.red)
                    ])
                    chartCard("Memory", subtitle: snapshot.memoryPressure, series: [
                        ("used %", snapshot.memoryUsed, Color.purple)
                    ])
                    chartCard("Disk I/O", subtitle: "MB/s", series: [
                        ("read", snapshot.diskRead, Color.cyan),
                        ("write", snapshot.diskWrite, Color.indigo)
                    ])
                    chartCard("Network", subtitle: "MB/s", series: [
                        ("rx", snapshot.netRx, Color.green),
                        ("tx", snapshot.netTx, Color.mint)
                    ])
                    chartCard("Thermal", subtitle: "°C", series: [
                        ("cpu", snapshot.thermalCPU, Color.red),
                        ("gpu", snapshot.thermalGPU, Color.pink)
                    ])
                    chartCard("Health score", subtitle: "0–100", series: [
                        ("health", snapshot.healthScore, Color.yellow)
                    ])
                    topProcessesCard
                }
                .padding(18)
            }
        }
        .frame(minWidth: 880, minHeight: 640)
        .onAppear { reload() }
        .onChange(of: range) { _, new in
            Store.lastHistoryRangeMinutes = new.minutes
            reload()
        }
        .onReceive(autoRefreshTimer) { _ in if !loading { reload(silent: true) } }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Text("History").font(.title2.weight(.semibold))
            Picker("Range", selection: $range) {
                ForEach(HistoryRange.all) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 360)

            ProgressView().controlSize(.small)
                .opacity(loading ? 1 : 0)

            Spacer()

            Text("\(snapshot.rowCount) samples")
                .foregroundStyle(.secondary)
                .font(.caption)
                .monospacedDigit()
            if let s = snapshot.staleSeconds {
                Text("·").foregroundStyle(.tertiary)
                Text("latest \(s) s ago")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .monospacedDigit()
            }
            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    private func chartCard(_ title: String,
                           subtitle: String,
                           series: [(name: String, points: [ChartPoint], color: Color)]) -> some View {
        let allEmpty = series.allSatisfy { $0.points.isEmpty }
        let style = AxisStyle.forRangeMinutes(range.minutes)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
                Text(subtitle).font(.caption).foregroundStyle(.tertiary)
            }
            if allEmpty {
                ContentUnavailableView("No samples in this window",
                                       systemImage: "chart.line.uptrend.xyaxis",
                                       description: Text("Either nothing was sampled yet, or the chart's range is wider than your data."))
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                Chart {
                    ForEach(series, id: \.name) { s in
                        ForEach(s.points) { p in
                            LineMark(x: .value("Time", p.time),
                                     y: .value("Value", p.value),
                                     series: .value("Series", s.name))
                                .foregroundStyle(s.color)
                        }
                    }
                }
                .chartXScale(domain: snapshot.windowSince...snapshot.windowUntil)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: style.desiredCount)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: style.format)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var topProcessesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP PROCESSES")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("peak across the window")
                .font(.caption)
                .foregroundStyle(.tertiary)
            if snapshot.topProcesses.isEmpty {
                ContentUnavailableView("No processes recorded",
                                       systemImage: "list.bullet.rectangle.portrait",
                                       description: Text("Mole's top_processes list is missing or empty in this range."))
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                ScrollView {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Process").foregroundStyle(.secondary).font(.caption)
                            Text("Peak CPU").foregroundStyle(.secondary).font(.caption)
                            Text("Peak Mem").foregroundStyle(.secondary).font(.caption)
                        }
                        Divider().gridCellColumns(3)
                        ForEach(snapshot.topProcesses.prefix(20)) { row in
                            GridRow {
                                Text(row.name).lineLimit(1)
                                Text(String(format: "%.1f %%", row.peakCPU))
                                    .monospacedDigit()
                                Text(String(format: "%.1f %%", row.peakMem))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .font(.system(size: 12))
                    .padding(.top, 4)
                }
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Load lifecycle

    private func reload(silent: Bool = false) {
        if !silent { loading = true }
        loadGen += 1
        let myGen = loadGen
        let r = self.range
        DispatchQueue.global(qos: .userInitiated).async {
            let snap = HistoryLoader.load(db: self.db, rangeMinutes: r.minutes)
            DispatchQueue.main.async {
                // If the user changed the range while we were loading,
                // drop our late result so it can't overwrite a fresher
                // load for the new range.
                if myGen != self.loadGen { return }
                self.snapshot = snap
                self.loading = false
            }
        }
    }
}
