//
//  ReceiptLinker.swift
//  Burrow
//
//  Links macOS installer receipts (pkgutil) to an app for the uninstall set
//  (PRD §Uninstall). Pure parsing + matching; the pkgutil spawns are the seam.
//

import Foundation

enum ReceiptLinker {
    struct Receipt: Equatable { let packageID: String; let version: String; let location: String }

    /// Parse `pkgutil --pkg-info <id>` key:value output.
    static func parseInfo(_ out: String) -> Receipt? {
        var f: [String: String] = [:]
        for line in out.components(separatedBy: "\n") {
            guard let c = line.firstIndex(of: ":") else { continue }
            f[String(line[..<c]).trimmingCharacters(in: .whitespaces)] =
                String(line[line.index(after: c)...]).trimmingCharacters(in: .whitespaces)
        }
        guard let id = f["package-id"], !id.isEmpty else { return nil }
        return Receipt(packageID: id, version: f["version"] ?? "", location: f["location"] ?? "")
    }

    /// Package-ids plausibly belonging to a bundle id (shared reverse-DNS stem).
    static func matching(bundleID: String, packageIDs: [String]) -> [String] {
        let parts = bundleID.lowercased().split(separator: ".")
        guard parts.count >= 2 else { return [] }
        let stem = parts.suffix(2).joined(separator: ".")   // e.g. "docker.docker"
        return packageIDs.filter { $0.lowercased().contains(stem) }
    }
}
