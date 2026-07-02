//
//  SpeedTest.swift
//  Burrow
//
//  Aggregates a speed test's per-sample measurements into a result (PRD §β).
//  Pure — the multi-stream transfer + latency pings are the seam. Multi-stream
//  byte samples are summed by the caller (single-stream undercounts badly).
//

import Foundation

enum SpeedTest {
    struct Result: Equatable { let mbps: Double; let jitterMs: Double; let lossPercent: Double }

    /// `byteSamples` = bytes transferred per 1s window. `latenciesMs` = ping RTTs
    /// (nil entry = a lost packet).
    static func aggregate(byteSamples: [Int64], latenciesMs: [Double?]) -> Result {
        let mbps = byteSamples.isEmpty ? 0
            : (Double(byteSamples.reduce(0, +)) / Double(byteSamples.count)) * 8 / 1_000_000
        let got = latenciesMs.compactMap { $0 }
        let jitter = meanAbsDiff(got)
        let loss = latenciesMs.isEmpty ? 0
            : Double(latenciesMs.count - got.count) / Double(latenciesMs.count) * 100
        return Result(mbps: round2(mbps), jitterMs: round2(jitter), lossPercent: round2(loss))
    }

    private static func meanAbsDiff(_ xs: [Double]) -> Double {
        guard xs.count >= 2 else { return 0 }
        var sum = 0.0
        for i in 1..<xs.count { sum += abs(xs[i] - xs[i - 1]) }
        return sum / Double(xs.count - 1)
    }
    private static func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }
}
