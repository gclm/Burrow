//
//  ProcessDeepMetrics.swift
//  Burrow
//
//  Per-process deep metrics for the inspector (PRD §α 56): threads, memory
//  footprint + lifetime peak, page-ins, user/sys CPU split, and per-process
//  disk I/O — from proc_pid_rusage (flavor 4) + proc_pidinfo. The syscalls are
//  the seam; the split/format helpers are pure + tested.
//

import Foundation
import Darwin

enum ProcessDeepMetrics {
    struct Metrics: Equatable {
        let threads: Int
        let footprintBytes: Int64
        let peakFootprintBytes: Int64
        let pageIns: Int64
        let userSeconds: Double
        let systemSeconds: Double
        let diskReadBytes: Int64
        let diskWriteBytes: Int64
        /// Wall-clock seconds since the process started (0 when unknown).
        let runtimeSeconds: Double
    }

    /// Live deep metrics for a pid. nil when the kernel won't report (permission
    /// or exited). ri_*_time are nanoseconds. `proc_pidinfo` for the thread
    /// count is best-effort (0 when unavailable).
    static func read(pid: Int) -> Metrics? {
        var usage = rusage_info_v4()
        let r = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) {
                proc_pid_rusage(Int32(pid), 4, $0)
            }
        }
        guard r == 0 else { return nil }
        var ti = proc_taskinfo()
        let tiSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let got = proc_pidinfo(Int32(pid), PROC_PIDTASKINFO, 0, &ti, tiSize)
        let threads = got == tiSize ? Int(ti.pti_threadnum) : 0

        // Runtime = (now − start) in mach units → seconds.
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        let now = mach_absolute_time()
        let startAbs = usage.ri_proc_start_abstime
        let runtime = (startAbs > 0 && now > startAbs && tb.denom > 0)
            ? Double(now - startAbs) * Double(tb.numer) / Double(tb.denom) / 1_000_000_000
            : 0

        return Metrics(
            threads: threads,
            footprintBytes: Int64(bitPattern: usage.ri_phys_footprint),
            peakFootprintBytes: Int64(bitPattern: usage.ri_lifetime_max_phys_footprint),
            pageIns: Int64(bitPattern: usage.ri_pageins),
            userSeconds: Double(usage.ri_user_time) / 1_000_000_000,
            systemSeconds: Double(usage.ri_system_time) / 1_000_000_000,
            diskReadBytes: Int64(bitPattern: usage.ri_diskio_bytesread),
            diskWriteBytes: Int64(bitPattern: usage.ri_diskio_byteswritten),
            runtimeSeconds: runtime)
    }

    /// User share of CPU time, 0…1 — nil when the process has used no CPU yet.
    static func userFraction(userSeconds: Double, systemSeconds: Double) -> Double? {
        let total = userSeconds + systemSeconds
        return total > 0 ? userSeconds / total : nil
    }
}
