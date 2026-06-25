//
//  ProcessRule.swift
//  Burrow
//
//  Per-process watchdog rule (PRD §α). Pure decision: given a rule and a
//  process's recent metric samples (one per second, oldest→newest), decide
//  whether it has stayed over threshold for the full sustain window (fire). The
//  sampler + action dispatch (notify / quit / suspend) and Shortcuts hook are
//  the seam.
//

import Foundation

enum ProcessRule {
    enum Metric: String, Equatable { case cpu, memory, diskRead }
    enum Action: String, Equatable { case notify, quit, suspend }
    struct Rule: Equatable {
        let metric: Metric
        let threshold: Double
        let sustainSeconds: Int
        let action: Action
    }

    /// Fires when the most recent `sustainSeconds` samples are ALL over threshold.
    static func fires(_ rule: Rule, samples: [Double]) -> Bool {
        guard rule.sustainSeconds > 0, samples.count >= rule.sustainSeconds else { return false }
        return samples.suffix(rule.sustainSeconds).allSatisfy { $0 > rule.threshold }
    }
}
