//
//  LoginItemsReader.swift
//  Burrow
//
//  Parses `sfltool dumpbtm` into the modern Login/background items macOS manages
//  via the Background Task Management database (PRD §Startup) — the ones a loose
//  LaunchAgent-plist scan misses. Pure; the sfltool spawn is the seam.
//

import Foundation

enum LoginItemsReader {
    struct Item: Equatable {
        let name: String
        let identifier: String
        let developer: String
        let type: String       // "developer", "legacy daemon", "agent", …
        let enabled: Bool
    }

    static func parse(_ dump: String) -> [Item] {
        var items: [Item] = []
        for block in blocks(dump) {
            let f = fields(block)
            let id = f["Identifier"] ?? ""
            let name = f["Name"].flatMap { $0 == "(null)" ? nil : $0 }
            guard !id.isEmpty || name != nil else { continue }   // skip empty placeholder records
            let disp = (f["Disposition"] ?? "").lowercased()
            let enabled = !disp.contains("disabled") && disp.contains("enabled")
            items.append(Item(
                name: name ?? id,
                identifier: id,
                developer: f["Developer Name"].flatMap { $0 == "(null)" ? nil : $0 } ?? "",
                type: f["Type"]?.components(separatedBy: " (").first ?? "",
                enabled: enabled))
        }
        return items
    }

    /// Each record begins with a line that trims to exactly "#<n>:".
    private static func blocks(_ s: String) -> [String] {
        var out: [String] = []
        var cur: [String] = []
        var inItem = false
        for raw in s.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.range(of: #"^#\d+:$"#, options: .regularExpression) != nil {
                if inItem, !cur.isEmpty { out.append(cur.joined(separator: "\n")) }
                cur = []; inItem = true
            } else if inItem {
                cur.append(raw)
            }
        }
        if inItem, !cur.isEmpty { out.append(cur.joined(separator: "\n")) }
        return out
    }

    /// "        Key: Value" → [Key: Value], first occurrence wins.
    private static func fields(_ block: String) -> [String: String] {
        var out: [String: String] = [:]
        for line in block.components(separatedBy: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let val = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, out[key] == nil { out[key] = val }
        }
        return out
    }
}
