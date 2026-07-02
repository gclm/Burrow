//
//  ElectronVersionResolver.swift
//  Burrow
//
//  Resolves an Electron app's latest version from its Squirrel.Mac update feed
//  (PRD §Software) — so Electron rows show a real available version, not just a
//  badge. Pure parse over the fetched payload (reusing OSUpdateGate to compare);
//  the fetch is the seam.
//

import Foundation

enum ElectronVersionResolver {
    /// Squirrel.Mac feeds return JSON carrying "version" (or "name"); strip "v".
    static func version(fromFeed json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let raw = (obj["version"] as? String) ?? (obj["name"] as? String), !raw.isEmpty else { return nil }
        return raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
    }

    static func newerVersion(feed: String, installed: String) -> String? {
        guard let latest = version(fromFeed: feed) else { return nil }
        let l = OSUpdateGate.parse(latest), i = OSUpdateGate.parse(installed)
        return (OSUpdateGate.atLeast(l, i) && !OSUpdateGate.atLeast(i, l)) ? latest : nil
    }
}
