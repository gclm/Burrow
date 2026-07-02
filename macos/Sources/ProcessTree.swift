//
//  ProcessTree.swift
//  Burrow
//
//  Process hierarchy with rolled-up aggregates (PRD §α — Process Inspector).
//  Pure — folds a flat list of (pid, ppid, cpu, mem, threads) into a parent→
//  children tree where each node reports the summed CPU/memory/threads of its
//  whole subtree.
//

import Foundation

enum ProcessTree {
    struct Proc { let pid: Int; let ppid: Int; let cpu: Double; let mem: Int64; let threads: Int }

    final class Node {
        let proc: Proc
        var children: [Node] = []
        init(_ p: Proc) { proc = p }
        var totalCPU: Double { proc.cpu + children.reduce(0) { $0 + $1.totalCPU } }
        var totalMem: Int64 { proc.mem + children.reduce(0) { $0 + $1.totalMem } }
        var totalThreads: Int { proc.threads + children.reduce(0) { $0 + $1.totalThreads } }
    }

    /// Roots = processes whose parent isn't in the set (or who are their own
    /// parent). Children are attached under their ppid.
    static func build(_ procs: [Proc]) -> [Node] {
        let nodes = Dictionary(procs.map { ($0.pid, Node($0)) }, uniquingKeysWith: { a, _ in a })
        var roots: [Node] = []
        for p in procs {
            guard let n = nodes[p.pid] else { continue }
            if p.ppid != p.pid, let parent = nodes[p.ppid] {
                parent.children.append(n)
            } else {
                roots.append(n)
            }
        }
        return roots
    }
}
