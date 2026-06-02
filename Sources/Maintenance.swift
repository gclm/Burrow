//
//  Maintenance.swift
//  Burrow
//
//  Hourly background tick that prunes rows past their retention age and
//  optionally VACUUMs the SQLite file. Runs on a serial utility queue so
//  it can't fight the sampler or the QueryServer; either side just sees
//  the prune as a normal write while it happens.
//
//  Why hourly: matches the Stats fork's cadence and is plenty given
//  retention is in days. Tightening to minutes would amplify the
//  fixed-cost VACUUM without changing the steady-state DB size.
//
//  Failure model: a prune that errors logs and continues — the next
//  tick retries. We don't pull retention from a mid-prune crash because
//  SQLite's WAL would already have rolled back the failed transaction.
//

import Foundation

final class Maintenance {
    private let db: DB
    private let intervalSeconds: TimeInterval
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.caezium.burrow.maintenance", qos: .utility)

    /// Wall-clock time the last full maintenance cycle finished. Exposed
    /// so the Settings panel can show "last run X ago" and a debug
    /// button can confirm a manual trigger took.
    private(set) var lastRunAt: Date?

    /// Rows deleted on the last prune. Tells the Settings UI whether the
    /// retention slider is doing anything useful.
    private(set) var lastPruneDeleted: Int = 0

    init(db: DB, intervalSeconds: TimeInterval = 3600) {
        self.db = db
        self.intervalSeconds = intervalSeconds
    }

    func start() {
        // One delayed initial run so the launch path isn't competing
        // with the sampler's first sample. After that, hourly.
        let t = DispatchSource.makeTimerSource(queue: self.queue)
        t.schedule(deadline: .now() + 60, repeating: self.intervalSeconds, leeway: .seconds(30))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        self.timer = t
    }

    func stop() {
        self.timer?.cancel()
        self.timer = nil
    }

    /// Run maintenance synchronously on the calling thread. Used by the
    /// Settings "Run now" button and by tests; production code waits
    /// for the timer.
    func runNow() {
        self.queue.sync { self.tick() }
    }

    private func tick() {
        let retentionDays = Store.retentionDays
        let cutoff = Int(Date().timeIntervalSince1970) - retentionDays * 86_400

        do {
            self.lastPruneDeleted = try self.db.pruneOlderThan(cutoff)
        } catch {
            NSLog("Burrow.Maintenance: prune failed: \(error.localizedDescription)")
            // Don't bail — still advance lastRunAt so a one-off prune
            // failure doesn't make the Settings panel claim maintenance
            // never ran.
            self.lastPruneDeleted = 0
        }

        // VACUUM only when something was actually deleted AND the user
        // opted in. Pruning a few stale rows doesn't justify rewriting
        // the whole DB file every hour.
        if Store.autoVacuum, self.lastPruneDeleted > 1_000 {
            do {
                try self.db.vacuum()
            } catch {
                NSLog("Burrow.Maintenance: vacuum failed: \(error.localizedDescription)")
            }
        }

        self.lastRunAt = Date()
    }
}
