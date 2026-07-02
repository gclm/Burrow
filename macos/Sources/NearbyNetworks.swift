//
//  NearbyNetworks.swift
//  Burrow
//
//  Read-out helpers for the nearby-networks scan (PRD §β — Home mode). Pure —
//  the CoreWLAN scan (needs Location) is the seam; this sorts by signal and
//  flags channel congestion.
//

import Foundation

enum NearbyNetworks {
    struct Net: Equatable { let ssid: String; let rssi: Int; let channel: Int; let security: String }

    /// Strongest first (rssi is negative dBm; closer to 0 = stronger).
    static func byStrength(_ nets: [Net]) -> [Net] {
        nets.sorted { $0.rssi > $1.rssi }
    }

    /// Channels carrying more than `threshold` networks (congested).
    static func congestedChannels(_ nets: [Net], threshold: Int = 2) -> Set<Int> {
        var count: [Int: Int] = [:]
        for n in nets { count[n.channel, default: 0] += 1 }
        return Set(count.filter { $0.value > threshold }.keys)
    }
}
