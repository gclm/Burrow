//
//  ProcessExport.swift
//  Burrow
//
//  Serializes a visible process list to CSV or JSON for export (PRD §α). Pure.
//

import Foundation

enum ProcessExport {
    struct Row { let pid: Int; let name: String; let cpu: Double; let memBytes: Int64; let threads: Int }

    static func csv(_ rows: [Row]) -> String {
        var out = "pid,name,cpu,memoryBytes,threads\n"
        for r in rows {
            out += "\(r.pid),\(escape(r.name)),\(r.cpu),\(r.memBytes),\(r.threads)\n"
        }
        return out
    }

    static func json(_ rows: [Row]) -> String {
        let arr: [[String: Any]] = rows.map {
            ["pid": $0.pid, "name": $0.name, "cpu": $0.cpu, "memoryBytes": $0.memBytes, "threads": $0.threads]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: arr, options: [.sortedKeys]) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func escape(_ s: String) -> String {
        (s.contains(",") || s.contains("\"") || s.contains("\n"))
            ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
    }
}
