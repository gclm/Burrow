//
//  UpdateSeenStore.swift
//  Burrow
//
//  "Unseen updates" badge count (PRD §Software): how many currently-available
//  third-party updates the user hasn't acknowledged. Pure — the persisted
//  "seen" set is supplied by the seam. A key is bundleID@version, so a NEW
//  version of an already-seen app re-badges.
//

import Foundation

enum UpdateSeenStore {
    static func key(bundleID: String, version: String) -> String { "\(bundleID)@\(version)" }

    static func unseenCount(available: [(bundleID: String, version: String)], seen: Set<String>) -> Int {
        available.filter { !seen.contains(key(bundleID: $0.bundleID, version: $0.version)) }.count
    }

    /// The set to persist once the user has viewed the list.
    static func markAllSeen(available: [(bundleID: String, version: String)], seen: Set<String>) -> Set<String> {
        seen.union(available.map { key(bundleID: $0.bundleID, version: $0.version) })
    }
}
