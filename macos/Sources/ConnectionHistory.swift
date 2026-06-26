//
//  ConnectionHistory.swift
//  Burrow
//
//  Persisted log of Get-Online attempts (PRD §β): when, which network, and the
//  classified outcome (ConnectionFailureClassifier). The append/cap/collapse
//  core is pure + tested; the UserDefaults read/write is the seam.
//

import Foundation

enum ConnectionHistory {
    struct Entry: Codable, Equatable {
        let at: Date
        let ssid: String?
        let reason: String   // ConnectionFailureClassifier.Reason.rawValue
    }

    static let cap = 50

    /// Append newest-first, capped. A repeat of the most-recent (ssid, reason)
    /// just refreshes that row's timestamp instead of growing the log — so
    /// re-checking the same network doesn't spam identical rows.
    static func appended(_ list: [Entry], _ e: Entry) -> [Entry] {
        var out = list
        if let first = out.first, first.ssid == e.ssid, first.reason == e.reason {
            out[0] = e
        } else {
            out.insert(e, at: 0)
        }
        if out.count > cap { out = Array(out.prefix(cap)) }
        return out
    }

    // MARK: - Store (UserDefaults JSON)

    private static let key = "connection_history_v1"

    static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }

    @discardableResult
    static func record(ssid: String?, reason: String, at: Date) -> [Entry] {
        let list = appended(load(), Entry(at: at, ssid: ssid, reason: reason))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return list
    }
}
