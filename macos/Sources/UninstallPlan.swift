//
//  UninstallPlan.swift
//  Burrow
//
//  Pure planning helpers for the Uninstall flow (PRD §Uninstall): the
//  "Clear Data" subset (keep the app, remove its data), input-method
//  classification, and alias-aware search matching.
//

import Foundation

enum UninstallPlan {
    /// "Clear Data" = every enumerated leftover EXCEPT the .app bundle itself.
    static func dataOnly(paths: [String]) -> [String] {
        paths.filter { !$0.hasSuffix(".app") }
    }

    /// A leftover that is an input method (e.g. WeChat/Doubao keyboards).
    static func isInputMethod(_ path: String) -> Bool {
        let p = path.lowercased()
        return p.contains("/library/input methods/") || p.hasSuffix(".inputmethod")
    }

    /// Alias-aware search: match a query against name, bundle id, or any alias.
    static func matches(query: String, name: String, bundleID: String, aliases: [String]) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        if name.lowercased().contains(q) || bundleID.lowercased().contains(q) { return true }
        return aliases.contains { $0.lowercased().contains(q) }
    }
}
