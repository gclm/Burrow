//
//  ConnectivityView.swift
//  Burrow
//
//  "Get Online" pane (plan §2.2): the travel-Wi-Fi rescue surface. Runs the
//  device-side checks (VPN / proxy / custom DNS / Private Relay) plus a
//  captive-portal + reachability probe, then offers a one-tap "Open Login Page"
//  and a Settings deep-link per blocker. Detection is best-effort and honest —
//  Private Relay has no public API, so that row says "check manually."
//
//  NOTE (hand-test): the probes are network/system I/O (URLSession, scutil,
//  CFNetwork) and can't run in CI — verify on a real hotspot.
//

import SwiftUI
import AppKit
import CoreWLAN

struct ConnectivityView: View {
    var isActive: Bool = true

    @State private var checks: [Connectivity.Check] = []
    @State private var iface: String?
    @State private var loading = false
    @State private var loaded = false
    @State private var actionBusy: Connectivity.Fix?
    @State private var actionResult: String?
    /// Venue-specific captive-portal tips when the SSID is recognised (PRD §β).
    @State private var venue: VenueMatcher.Venue?
    /// On-demand nearby-Wi-Fi scan (PRD §β Home mode): strongest networks +
    /// congested channels. User-initiated — a scan briefly disrupts the link.
    @State private var nearby: [NearbyNetworks.Net] = []
    @State private var scanning = false
    @State private var scanned = false
    /// On-demand throughput + latency test (PRD §β). User-initiated — it
    /// transfers data to/from Cloudflare's public speed endpoint.
    @State private var speed: SpeedTest.Result?
    @State private var speedTesting = false

    private var accent: Color { Tool.status.accent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let venue { venueCard(venue) }
                actionsCard
                ForEach(checks) { checkRow($0) }
                if loaded, checks.isEmpty {
                    Text(NSLocalizedString("Couldn't run the checks.", comment: ""))
                        .font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                }
                speedCard
                nearbyCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onAppear { if isActive, !loaded { reload() } }
        .onChange(of: isActive) { _, now in if now, !loaded { reload() } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("Get Online", comment: ""))
                    .font(Brand.serif(26, .medium)).foregroundStyle(Brand.textPrimary)
                HStack(spacing: 7) {
                    if loading {
                        ProgressView().controlSize(.small).tint(accent)
                        Text(NSLocalizedString("Checking your connection…", comment: ""))
                            .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                    } else {
                        Text(NSLocalizedString("What might be blocking the login page.", comment: ""))
                            .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                    }
                }
            }
            Spacer()
            Button { reload() } label: {
                Label(NSLocalizedString("Re-check", comment: ""), systemImage: "arrow.clockwise")
                    .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
            }
            .buttonStyle(.plain).disabled(loading).opacity(loading ? 0.4 : 1)
        }
    }

    private var actionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Fixes", glyph: "wrench.and.screwdriver", color: accent)
                Text(NSLocalizedString("Force the login page open, or clear the two things that most often wedge a hotspot connection. Burrow runs these for you (one password) — it doesn't just point at Settings.", comment: ""))
                    .font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PillButton(title: "Open Login Page") { NSWorkspace.shared.open(Connectivity.probeURL) }
                    fixButton("Flush DNS", .flushDNS)
                    fixButton("Renew DHCP", .renewDHCP)
                    Spacer()
                }
                if let msg = actionResult {
                    Text(msg).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                }
            }
        }
    }

    @ViewBuilder private func fixButton(_ title: String, _ fix: Connectivity.Fix) -> some View {
        if actionBusy == fix {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(title).font(Brand.sans(12)).foregroundStyle(Brand.textTertiary)
            }
        } else {
            PillButton(title: title, filled: false) { runFix(fix) }
                .disabled(actionBusy != nil)
                .opacity(actionBusy != nil ? 0.4 : 1)
        }
    }

    private func runFix(_ fix: Connectivity.Fix) {
        actionBusy = fix
        actionResult = nil
        let iface = self.iface
        Task.detached(priority: .userInitiated) {
            let r = Connectivity.run(fix, interface: iface)
            await MainActor.run {
                actionBusy = nil
                actionResult = r.message
                if r.ok { reload() }   // re-check after a successful fix
            }
        }
    }

    /// Venue-specific captive-portal tips when the SSID is recognised (PRD §β).
    private func venueCard(_ v: VenueMatcher.Venue) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: v.name, glyph: "mappin.and.ellipse", color: accent)
                ForEach(Array(v.tips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 11)).foregroundStyle(accent)
                        Text(tip).font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Current Wi-Fi SSID. nil when not on Wi-Fi, or when Location access (which
    /// macOS now gates the SSID behind) hasn't been granted — the venue card just
    /// stays hidden. Off-main: CoreWLAN reads can block.
    private static func currentSSID() -> String? {
        CWWiFiClient.shared().interface()?.ssid()
    }

    /// Nearby-Wi-Fi card (PRD §β Home mode): strongest networks with their
    /// channel, plus a "busy ch" marker for congested channels.
    private var nearbyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: "Nearby Wi-Fi", glyph: "dot.radiowaves.left.and.right", color: accent)
                    Spacer()
                    if scanning {
                        ProgressView().controlSize(.small).tint(accent)
                    } else {
                        Button(scanned ? NSLocalizedString("Rescan", comment: "")
                                       : NSLocalizedString("Scan", comment: "")) { scanNearby() }
                            .buttonStyle(.plain).font(Brand.sans(11, .semibold)).foregroundStyle(accent)
                    }
                }
                if !nearby.isEmpty {
                    let congested = NearbyNetworks.congestedChannels(nearby)
                    let strongest = Array(NearbyNetworks.byStrength(nearby).prefix(8))
                    ForEach(Array(strongest.enumerated()), id: \.offset) { _, n in
                        HStack(spacing: 8) {
                            Image(systemName: n.security == "Open" ? "lock.open" : "lock")
                                .font(.system(size: 9)).foregroundStyle(Brand.textTertiary)
                            Text(n.ssid).font(Brand.sans(12)).foregroundStyle(Brand.textPrimary).lineLimit(1)
                            Spacer(minLength: 8)
                            if congested.contains(n.channel) {
                                Text(NSLocalizedString("busy", comment: ""))
                                    .font(Brand.mono(9)).foregroundStyle(Brand.amber)
                            }
                            Text(verbatim: "ch \(n.channel)").font(Brand.mono(10)).foregroundStyle(Brand.textTertiary)
                            Text(verbatim: "\(n.rssi) dBm").font(Brand.mono(10))
                                .foregroundStyle(Brand.textSecondary).frame(width: 64, alignment: .trailing)
                        }
                    }
                } else if scanned, !scanning {
                    Text(NSLocalizedString("No networks found — scanning needs Location access (System Settings ▸ Privacy & Security ▸ Location).", comment: ""))
                        .font(Brand.mono(10)).foregroundStyle(Brand.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !scanned {
                    Text(NSLocalizedString("See which channels are crowded near you.", comment: ""))
                        .font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                }
            }
        }
    }

    /// Speed-test card (PRD §β): throughput + latency, on demand.
    private var speedCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: "Speed Test", glyph: "speedometer", color: accent)
                    Spacer()
                    if speedTesting {
                        ProgressView().controlSize(.small).tint(accent)
                    } else {
                        Button(speed == nil ? NSLocalizedString("Test", comment: "")
                                            : NSLocalizedString("Retest", comment: "")) { runSpeedTest() }
                            .buttonStyle(.plain).font(Brand.sans(11, .semibold)).foregroundStyle(accent)
                    }
                }
                if let speed {
                    HStack(spacing: 20) {
                        metric(String(format: "%.0f", speed.mbps), NSLocalizedString("Mbps down", comment: ""))
                        metric(String(format: "%.0f ms", speed.jitterMs), NSLocalizedString("jitter", comment: ""))
                        metric(String(format: "%.0f%%", speed.lossPercent), NSLocalizedString("loss", comment: ""))
                    }
                } else if speedTesting {
                    Text(NSLocalizedString("Measuring…", comment: ""))
                        .font(Brand.mono(11)).foregroundStyle(Brand.textTertiary)
                } else {
                    Text(NSLocalizedString("Measures download throughput and latency against Cloudflare.", comment: ""))
                        .font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                }
            }
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Brand.mono(16, .medium)).foregroundStyle(Brand.textPrimary)
            Text(label).font(Brand.mono(9)).foregroundStyle(Brand.textTertiary)
        }
    }

    private func runSpeedTest() {
        speedTesting = true
        Task.detached(priority: .userInitiated) {
            let r = await ConnectivityView.measureSpeed()
            await MainActor.run {
                speed = r
                speedTesting = false
            }
        }
    }

    /// Throughput from a few timed downloads (per-second byte rates) + latency
    /// from a few small-payload round trips, aggregated by the tested SpeedTest
    /// module. Cloudflare's `__down` endpoint is public + CORS-open. nil on
    /// total failure (offline) → the card keeps its idle copy.
    private static func measureSpeed() async -> SpeedTest.Result? {
        let down = URL(string: "https://speed.cloudflare.com/__down?bytes=8000000")!
        let ping = URL(string: "https://speed.cloudflare.com/__down?bytes=1")!
        var rates: [Int64] = []
        for _ in 0..<3 {
            let start = Date()
            guard let (data, _) = try? await URLSession.shared.data(from: down) else { continue }
            let elapsed = Date().timeIntervalSince(start)
            guard elapsed > 0 else { continue }
            rates.append(Int64(Double(data.count) / elapsed))   // bytes per second
        }
        var lats: [Double?] = []
        for _ in 0..<5 {
            let start = Date()
            if (try? await URLSession.shared.data(from: ping)) != nil {
                lats.append(Date().timeIntervalSince(start) * 1000)
            } else {
                lats.append(nil)
            }
        }
        guard !rates.isEmpty else { return nil }
        return SpeedTest.aggregate(byteSamples: rates, latenciesMs: lats)
    }

    private func scanNearby() {
        scanning = true
        Task.detached(priority: .utility) {
            let nets = ConnectivityView.scanNearbyNetworks()
            await MainActor.run {
                nearby = nets
                scanning = false
                scanned = true
            }
        }
    }

    /// Active scan via CoreWLAN. Throws/empty without Location access or off
    /// Wi-Fi → the card shows the permission hint. A scan briefly disrupts the
    /// link, so it's only ever user-initiated.
    private static func scanNearbyNetworks() -> [NearbyNetworks.Net] {
        guard let iface = CWWiFiClient.shared().interface() else { return [] }
        let nets = (try? iface.scanForNetworks(withSSID: nil)) ?? []
        return nets.compactMap { n in
            guard let ssid = n.ssid, !ssid.isEmpty else { return nil }
            return NearbyNetworks.Net(ssid: ssid, rssi: n.rssiValue,
                                      channel: n.wlanChannel?.channelNumber ?? 0,
                                      security: n.supportsSecurity(.none) ? "Open" : "Secured")
        }
    }

    private func checkRow(_ c: Connectivity.Check) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: Self.glyph(c.status))
                    .font(.system(size: 15)).foregroundStyle(Self.color(c.status))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.title).font(Brand.sans(13, .semibold)).foregroundStyle(Brand.textPrimary)
                    Text(c.detail).font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let hint = c.settingsHint {
                        Text(hint).font(Brand.mono(10)).foregroundStyle(Brand.textTertiary)
                    }
                }
                Spacer()
                if c.settingsHint != nil {
                    Button { openSystemSettings() } label: {
                        Text(NSLocalizedString("Open Settings", comment: ""))
                            .font(Brand.sans(11, .semibold)).foregroundStyle(accent)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private static func glyph(_ s: Connectivity.Status) -> String {
        switch s {
        case .ok:      return "checkmark.circle.fill"
        case .warn:    return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        case .info:    return "info.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    private static func color(_ s: Connectivity.Status) -> Color {
        switch s {
        case .ok:      return Brand.green
        case .warn:    return Brand.amber
        case .blocked: return Brand.red
        case .info:    return Brand.blue
        case .unknown: return Brand.textTertiary
        }
    }

    private func openSystemSettings() {
        // Settings layouts shift between macOS versions, so we open System
        // Settings and let the per-row hint say where — reliable over fragile
        // deep-link URLs.
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }

    private func reload() {
        loading = true
        Task {
            let result = await Connectivity.probeAll()
            checks = result.checks
            iface = result.interface
            loading = false
            loaded = true
        }
        // Recognise the venue from the SSID, off-main (CoreWLAN can block).
        Task.detached(priority: .utility) {
            let v = ConnectivityView.currentSSID().flatMap { VenueMatcher.match(ssid: $0) }
            await MainActor.run { venue = v }
        }
    }
}
