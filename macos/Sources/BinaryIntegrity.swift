//
//  BinaryIntegrity.swift
//  Burrow
//
//  Classifies whether a running process's executable on disk is intact, deleted,
//  or replaced since launch (PRD §Status / §α — a security signal). Pure: feed
//  the launch inode and the current on-disk inode at the same path; the
//  proc_pidpath + stat reads are the seam.
//

import Foundation

enum BinaryIntegrity {
    enum Verdict: String, Equatable { case intact, deleted, replaced }

    /// `onDiskInode` nil = the path no longer exists (deleted/moved). A
    /// different inode at the same path = the binary was replaced underneath it.
    static func classify(launchInode: UInt64, onDiskInode: UInt64?) -> Verdict {
        guard let now = onDiskInode else { return .deleted }
        return now == launchInode ? .intact : .replaced
    }
}
