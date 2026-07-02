//
//  ProcessFilter.swift
//  Burrow
//
//  Typed predicate filter over a process record (PRD §α). Chosen over embedding
//  a JS runtime so the same predicates work from MCP/agents and ship no JS
//  engine (Cross-cutting decision). Pure.
//

import Foundation

enum ProcessFilter {
    enum Field: String { case cpu, memory, threads, name, pid }
    enum Op: String { case gt = ">", lt = "<", ge = ">=", le = "<=", eq = "==", contains = "~" }
    struct Predicate { let field: Field; let op: Op; let value: String }
    struct Record { let pid: Int; let name: String; let cpu: Double; let memBytes: Int64; let threads: Int }

    private static func numeric(_ r: Record, _ f: Field) -> Double? {
        switch f {
        case .cpu: return r.cpu
        case .memory: return Double(r.memBytes)
        case .threads: return Double(r.threads)
        case .pid: return Double(r.pid)
        case .name: return nil
        }
    }

    static func matches(_ r: Record, _ p: Predicate) -> Bool {
        if p.field == .name {
            let v = p.value.lowercased(), n = r.name.lowercased()
            switch p.op {
            case .eq: return n == v
            case .contains: return n.contains(v)
            default: return false
            }
        }
        guard let lhs = numeric(r, p.field), let rhs = Double(p.value) else { return false }
        switch p.op {
        case .gt: return lhs > rhs
        case .lt: return lhs < rhs
        case .ge: return lhs >= rhs
        case .le: return lhs <= rhs
        case .eq: return lhs == rhs
        case .contains: return false
        }
    }

    static func apply(_ records: [Record], _ p: Predicate) -> [Record] {
        records.filter { matches($0, p) }
    }

    /// Parse a filter expression: "cpu > 20", "mem >= 1e8", "name ~ chrome",
    /// "pid == 1". A bare term with no operator is a name-contains filter
    /// ("chrome" → name ~ chrome). "mem" aliases "memory". nil for empty input
    /// or an unknown field. Multi-char operators are matched before their
    /// single-char prefixes so ">=" wins over ">".
    static func parse(_ raw: String) -> Predicate? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        for op in [Op.ge, .le, .eq, .gt, .lt, .contains] {
            guard let r = s.range(of: op.rawValue) else { continue }
            let fieldStr = s[..<r.lowerBound].trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let field = field(fieldStr), !value.isEmpty else { return nil }
            return Predicate(field: field, op: op, value: value)
        }
        return Predicate(field: .name, op: .contains, value: s)   // bare term → name contains
    }

    private static func field(_ s: String) -> Field? {
        switch s {
        case "cpu":                return .cpu
        case "mem", "memory":      return .memory
        case "thread", "threads":  return .threads
        case "name":               return .name
        case "pid":                return .pid
        default:                   return nil
        }
    }
}
