//
//  ShellProbe.swift
//  Burrow
//
//  Minimal timeout-guarded runner for the handful of one-off system probes
//  (system_profiler, tmutil, csrutil, spctl, …) that don't go through the mo
//  engine. Two things the old hand-rolled `Process()` + `waitUntilExit()` sites
//  lacked (#239): a kill timer, so a wedged tool can't block its task forever;
//  and a concurrent stdout drain, so a tool whose output exceeds the ~64 KB pipe
//  buffer can't deadlock (child blocks on write, parent blocks on exit).
//

import Foundation

enum ShellProbe {
    /// Run `path args`, returning stdout on a clean exit (status 0), or nil on
    /// spawn failure, nonzero/timeout exit. `timeout` seconds bounds a wedged
    /// child — on expiry the process is terminated and nil is returned.
    static func run(_ path: String, _ args: [String], timeout: TimeInterval = 10) -> String? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice   // we never read stderr; don't let it fill

        // Drain stdout to EOF on a background queue so large output can't block
        // the child (and thus waitUntilExit) on a full pipe.
        let reader = DispatchQueue(label: "dev.caezium.burrow.shellprobe")
        var data = Data()
        let group = DispatchGroup()
        group.enter()
        reader.async {
            data = out.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        do { try p.run() } catch { return nil }

        // Kill the child if it wedges past the timeout; terminate() closes its
        // pipe, so the reader hits EOF and the group completes.
        let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: killer)
        p.waitUntilExit()
        killer.cancel()
        group.wait()

        guard p.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
