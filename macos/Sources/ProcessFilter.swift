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
}
