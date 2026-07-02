//
//  OSUpdateGate.swift
//  Burrow
//
//  App Store update gating (PRD §Software): decide whether an update is
//  actually installable on the running macOS (hide it if it needs a newer OS —
//  the false-prompt Mole suppresses), and when a shown "update available" row
//  should clear (the on-disk version finally caught up). Pure — the Updates
//  pane supplies `minimumOsVersion` (from the iTunes lookup) + the on-disk
//  version.
//

import Foundation

enum OSUpdateGate {
    /// Dotted version → comparable integer components ("14", "26.5.1").
    static func parse(_ v: String) -> [Int] {
        v.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    /// a >= b over dotted versions (ragged lengths padded with 0).
    static func atLeast(_ a: [Int], _ b: [Int]) -> Bool {
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return true
    }

    /// Whether an App Store update requiring `minimumOS` can install on the
    /// running OS. nil/empty minimum = no requirement → installable.
    static func isInstallable(minimumOS: String?, running: String) -> Bool {
        guard let m = minimumOS?.trimmingCharacters(in: .whitespaces), !m.isEmpty else { return true }
        return atLeast(parse(running), parse(m))
    }

    /// Whether a previously-shown update row should clear: the on-disk version
    /// is now at least the version we offered (the update actually landed).
    static func updateLanded(offered: String, onDisk: String) -> Bool {
        atLeast(parse(onDisk), parse(offered))
    }
}
