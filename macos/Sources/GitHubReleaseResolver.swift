//
//  GitHubReleaseResolver.swift
//  Burrow
//
//  Resolves whether a newer version exists on GitHub Releases for a third-party
//  app with no Sparkle/App-Store source (PRD §Software). Pure: parse the
//  releases JSON + compare to the installed version (reusing OSUpdateGate); the
//  fetch + bundle→repo mapping are the seam.
//

import Foundation

enum GitHubReleaseResolver {
    /// Latest non-prerelease, non-draft tag from a `/releases` JSON array;
    /// strips a leading "v".
    static func latestTag(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        for r in arr {
            if (r["prerelease"] as? Bool) == true || (r["draft"] as? Bool) == true { continue }
            if let tag = r["tag_name"] as? String, !tag.isEmpty {
                return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            }
        }
        return nil
    }

    /// Strictly-newer version available, or nil.
    static func newerVersion(json: String, installed: String) -> String? {
        guard let latest = latestTag(json) else { return nil }
        let l = OSUpdateGate.parse(latest), i = OSUpdateGate.parse(installed)
        let strictlyNewer = OSUpdateGate.atLeast(l, i) && !OSUpdateGate.atLeast(i, l)
        return strictlyNewer ? latest : nil
    }
}
