//
//  RemovableVolumeGuard.swift
//  Burrow
//
//  Startup-item false-positive guard (PRD §Startup): a LaunchAgent whose
//  executable lives on an external drive that's currently unplugged must NOT be
//  flagged "broken" (and never auto-removed). Pure — given the missing path and
//  the set of currently-mounted volume roots, classify unplugged-vs-broken; the
//  mounted-volume enumeration is the impure seam in the startup scanner.
//

import Foundation

enum RemovableVolumeGuard {
    enum Verdict: Equatable { case broken, onUnpluggedVolume }

    /// A path under `/Volumes/<name>/…` whose volume root isn't in the mounted
    /// set is on an unplugged drive (skip). Anything else that's missing is
    /// genuinely broken.
    static func classify(missingPath: String, mountedVolumes: Set<String>) -> Verdict {
        guard missingPath.hasPrefix("/Volumes/") else { return .broken }
        let comps = missingPath.split(separator: "/", omittingEmptySubsequences: true)
        guard comps.count >= 2 else { return .broken }   // ["Volumes", "<name>", …]
        let volRoot = "/Volumes/\(comps[1])"
        return mountedVolumes.contains(volRoot) ? .broken : .onUnpluggedVolume
    }
}
