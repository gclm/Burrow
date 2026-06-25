//
//  OptimizeGuards.swift
//  Burrow
//
//  Pre-run safety warnings for Optimize (PRD §Optimize): warn before a
//  maintenance run when something the user relies on is active. Pure — the
//  system-state probes (VPN / audio / display / Bluetooth input) are the seam.
//

import Foundation

enum OptimizeGuards {
    struct State {
        var vpnActive = false
        var externalAudio = false
        var externalDisplay = false
        var btInput = false
    }

    /// Human-readable warnings for whatever's active; empty = clear to run.
    static func warnings(_ s: State) -> [String] {
        var out: [String] = []
        if s.vpnActive { out.append("A VPN is active — maintenance may reset network state.") }
        if s.externalAudio { out.append("An external audio device is in use — audio maintenance may interrupt it.") }
        if s.externalDisplay { out.append("An external display is connected — display tasks may flicker it.") }
        if s.btInput { out.append("A Bluetooth keyboard/mouse is connected — avoid Bluetooth resets.") }
        return out
    }
}
