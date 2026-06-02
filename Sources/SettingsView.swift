//
//  SettingsView.swift
//  Burrow
//
//  SwiftUI form for the Settings window. Reads + writes Store; restart
//  requirements are noted next to the controls that actually need one
//  (port + sampler interval propagate at next tick, no restart).
//
//  The window itself is owned by SettingsWindowController so it can
//  persist position + close-on-deinit cleanly. SwiftUI's @main
//  `Settings` scene isn't used because Burrow is LSUIElement:true and
//  has no main menu — opening it from a button is more reliable.
//

import SwiftUI

struct SettingsView: View {
    @State private var sampleIntervalSeconds: Int = Store.sampleIntervalSeconds
    @State private var retentionDays: Int = Store.retentionDays
    @State private var autoVacuum: Bool = Store.autoVacuum
    @State private var queryServerEnabled: Bool = Store.queryServerEnabled
    @State private var dbSizeText: String = "—"
    @State private var lastMaintenanceText: String = "—"

    /// Optional callback when the Settings UI wants the live components
    /// to react. Wired by AppDelegate; the only consumer today is the
    /// "Run maintenance now" button.
    var onRunMaintenance: (() -> Void)?

    var body: some View {
        Form {
            Section {
                LabeledContent("Currently using", value: dbSizeText)
                LabeledContent("Last maintenance", value: lastMaintenanceText)
                Button("Run maintenance now") {
                    self.onRunMaintenance?()
                    // Refresh the labels right after — the maintenance
                    // call is synchronous from runNow.
                    self.refreshStatusLabels()
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("History lives at ~/Library/Application Support/Burrow/burrow.db. Maintenance prunes rows past the retention window every hour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("History retention") {
                Picker("Keep history for", selection: $retentionDays) {
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("180 days").tag(180)
                    Text("1 year").tag(365)
                }
                .onChange(of: retentionDays) { _, new in
                    Store.retentionDays = new
                }

                Toggle("Vacuum DB after large prunes", isOn: $autoVacuum)
                    .onChange(of: autoVacuum) { _, new in
                        Store.autoVacuum = new
                    }
            }

            Section("Sampling") {
                Picker("Sample every", selection: $sampleIntervalSeconds) {
                    Text("5 sec").tag(5)
                    Text("15 sec").tag(15)
                    Text("30 sec").tag(30)
                    Text("60 sec").tag(60)
                    Text("2 min").tag(120)
                    Text("5 min").tag(300)
                }
                .onChange(of: sampleIntervalSeconds) { _, new in
                    Store.sampleIntervalSeconds = new
                }
                Text("Burrow spawns `mo status --json` at this cadence. 60 s is plenty for charts; tighter intervals give finer detail at the cost of more subprocess churn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Enable MCP query server", isOn: $queryServerEnabled)
                    .onChange(of: queryServerEnabled) { _, new in
                        Store.queryServerEnabled = new
                    }
                LabeledContent("Port", value: "127.0.0.1:\(Store.queryServerPort)")
            } header: {
                Text("MCP query server")
            } footer: {
                Text("Toggle and port changes require a Burrow restart. The localhost JSON HTTP API exposes /health, /info, /snapshot, /metrics — see README.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 520)
        .onAppear { self.refreshStatusLabels() }
    }

    /// Reads the on-disk DB size + last maintenance time. Called on
    /// appear and after the "Run now" button so the user sees the
    /// effect of their click. Cheap — single stat call + a property
    /// read.
    private func refreshStatusLabels() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first!
            .appendingPathComponent("Burrow", isDirectory: true)
        var total: Int64 = 0
        // Walk the directory because SQLite WAL has companion files
        // (.db-wal, .db-shm) that add to the on-disk footprint.
        if let enumerator = FileManager.default.enumerator(at: support,
                                                          includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    total += Int64(size)
                }
            }
        }
        let f = ByteCountFormatter()
        f.countStyle = .file
        self.dbSizeText = f.string(fromByteCount: total)

        if let last = AppDelegate.shared?.maintenance?.lastRunAt {
            let delta = Int(Date().timeIntervalSince(last))
            self.lastMaintenanceText = "\(delta) s ago · pruned \(AppDelegate.shared?.maintenance?.lastPruneDeleted ?? 0) rows"
        } else {
            self.lastMaintenanceText = "not yet run"
        }
    }
}
