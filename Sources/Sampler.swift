//
//  Sampler.swift
//  Burrow
//
//  Periodic sampler: spawns `mo status --json` on a background queue,
//  parses the JSON, writes the raw text to the DB under
//  `prefix: "mole.snapshot"`.
//
//  Cadence model: Burrow doesn't run kernel sample loops itself (that's
//  Mole's job). The "energy gate" from Stats reduces here to a single
//  knob — `intervalSeconds` — defaulting to 60. At that rate, the
//  subprocess spawn cost is amortized to negligible; the popup-state
//  gate Stats needed for in-process readers doesn't apply.
//
//  Failure model: a single failed `mo status` invocation (timeout,
//  exec error, malformed JSON) is logged and retried at the next tick.
//  Repeated failure becomes visible through `/info`'s reader-staleness
//  surface — a Burrow consumer sees `mole.snapshot` getting older just
//  the same way the Stats fork's stale-reader chip works.
//

import Foundation

final class Sampler {
    /// Bare-key prefix used by the QueryServer + chart code. One row per
    /// successful invocation, value = raw `mo status --json` payload.
    static let snapshotPrefix = "mole.snapshot"

    private let db: DB
    private let intervalSeconds: TimeInterval
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.caezium.burrow.sampler", qos: .utility)
    private let dec = JSONDecoder()

    /// Wall-clock time of the most recent successful sample. Exposed for
    /// the menu-bar status surface so we can show "12s ago" without
    /// hitting the DB.
    private(set) var lastSampleAt: Date?

    /// Last decoded snapshot — kept in memory so the popup can render the
    /// current values without a DB read on every redraw.
    private(set) var lastSnapshot: MoleStatus?

    init(db: DB, intervalSeconds: TimeInterval = 60) {
        self.db = db
        self.intervalSeconds = intervalSeconds
    }

    func start() {
        // One initial sample on launch so the popup has data immediately,
        // then the periodic timer takes over. Both run on the sampler
        // queue — no chance of two concurrent invocations of `mo`.
        self.queue.async { self.tick() }

        let t = DispatchSource.makeTimerSource(queue: self.queue)
        // Loose leeway: we don't care about sub-second jitter at a 60s
        // cadence, and looser timing lets macOS coalesce wakeups with
        // other timers (less energy use).
        t.schedule(deadline: .now() + self.intervalSeconds,
                   repeating: self.intervalSeconds,
                   leeway: .seconds(5))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        self.timer = t
    }

    func stop() {
        self.timer?.cancel()
        self.timer = nil
    }

    /// Single sample iteration. Synchronous from the caller's perspective —
    /// the timer queue is utility-priority so we don't block anything
    /// user-visible. Failures are swallowed and surfaced only through
    /// `lastSampleAt` not advancing.
    private func tick() {
        let result: MoleCLI.Result
        do {
            result = try MoleCLI.run(args: ["status", "--json"], timeout: 8)
        } catch {
            NSLog("Burrow.Sampler: mo status failed to spawn: \(error.localizedDescription)")
            return
        }
        guard result.exitCode == 0 else {
            NSLog("Burrow.Sampler: mo status exit=\(result.exitCode) stderr=\(result.stderr.prefix(200))")
            return
        }
        guard let data = result.stdout.data(using: .utf8) else { return }

        // Parse first — a malformed snapshot shouldn't pollute the DB.
        let snapshot: MoleStatus
        do {
            snapshot = try self.dec.decode(MoleStatus.self, from: data)
        } catch let DecodingError.keyNotFound(key, ctx) {
            // Surface the full coding path so a schema drift in `mo` shows
            // up as "missing key 'X' at path [a, b]" rather than the
            // useless "data couldn't be read" localized string.
            let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
            NSLog("Burrow.Sampler: missing key '\(key.stringValue)' at path '\(path)'")
            return
        } catch let DecodingError.typeMismatch(type, ctx) {
            let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
            NSLog("Burrow.Sampler: type mismatch (expected \(type)) at path '\(path)' — \(ctx.debugDescription)")
            return
        } catch let DecodingError.valueNotFound(type, ctx) {
            let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
            NSLog("Burrow.Sampler: nil value where \(type) expected at path '\(path)'")
            return
        } catch let DecodingError.dataCorrupted(ctx) {
            let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
            NSLog("Burrow.Sampler: data corrupted at path '\(path)' — \(ctx.debugDescription)")
            return
        } catch {
            NSLog("Burrow.Sampler: JSON decode failed: \(error). First 200b: \(result.stdout.prefix(200))")
            return
        }

        // Use the timestamp Mole stamped on the snapshot rather than
        // Date() here. Two reasons: (1) if our tick lags by 200 ms, the
        // chart x-axis is still accurate; (2) Mole's `collected_at`
        // captures the sample window, not the JSON-emit time.
        let ts = Int(snapshot.collectedAt.timeIntervalSince1970)
        do {
            try self.db.insert(prefix: Sampler.snapshotPrefix, ts: ts, json: result.stdout)
        } catch {
            NSLog("Burrow.Sampler: DB insert failed: \(error.localizedDescription)")
            return
        }

        self.lastSampleAt = Date()
        self.lastSnapshot = snapshot
    }
}
