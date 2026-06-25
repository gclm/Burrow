//
//  HardlinkAwareSizer.swift
//  Burrow
//
//  Computes exclusive on-disk bytes, de-counting hardlinked files that share an
//  inode (PRD §Clean) — so "space freed" is honest, not double-counted. Pure:
//  feed (inode, nlink, size) entries; the stat() is the seam.
//

import Foundation

enum HardlinkAwareSizer {
    struct Entry { let inode: UInt64; let nlink: Int; let size: Int64 }

    /// Sum sizes counting each unique inode once.
    static func exclusiveBytes(_ entries: [Entry]) -> Int64 {
        var seen = Set<UInt64>()
        var total: Int64 = 0
        for e in entries where seen.insert(e.inode).inserted { total += e.size }
        return total
    }
}
