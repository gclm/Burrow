//
//  DiskHealth.swift
//  Burrow
//
//  SMART status (roadmap D.14, health half). The full wear%/temperature/hours
//  need the private IONVMeSMARTUserClient log; the pass/fail SMART verdict,
//  though, is readable from `system_profiler SPNVMeDataType` without elevation
//  or private API — so that's what we surface (as a Doctor check).
//

import Foundation

enum DiskHealth {
    /// true = SMART "Verified", false = any other status, nil = unreadable
    /// (no internal NVMe, or system_profiler failed).
    static func smartVerified() -> Bool? {
        // system_profiler routinely takes seconds; bound it so a wedge can't
        // hang the Doctor probe task. #239
        guard let text = ShellProbe.run("/usr/sbin/system_profiler", ["SPNVMeDataType"], timeout: 12) else { return nil }
        guard let line = text.split(separator: "\n").first(where: { $0.contains("SMART Status:") }) else {
            return nil
        }
        let status = line.split(separator: ":", maxSplits: 1).last
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return status.lowercased().contains("verified")
    }
}
