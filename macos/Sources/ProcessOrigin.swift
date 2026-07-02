//
//  ProcessOrigin.swift
//  Burrow
//
//  Classifies where a process was launched from by walking its parent chain
//  (PRD §Status / §α): names a login shell or an SSH session, else it descends
//  from launchd (a normal app/login). Pure: feed a pid→(name, ppid) map; the
//  proc-table read is the seam.
//

import Foundation

enum ProcessOrigin {
    enum Origin: Equatable {
        case login            // descends from launchd, no shell/ssh ancestor
        case shell(String)    // a login-shell ancestor (zsh/bash/fish/…)
        case ssh              // an sshd ancestor (remote session)
    }
    struct Info { let name: String; let ppid: Int }

    private static let shells: Set<String> = ["zsh", "bash", "fish", "sh", "tcsh", "csh", "ksh", "dash"]

    static func classify(pid: Int, table: [Int: Info]) -> Origin {
        var cur = table[pid]?.ppid ?? 0
        var hops = 0
        while let info = table[cur], hops < 64 {
            let n = info.name.lowercased()
            if n.contains("sshd") { return .ssh }
            if shells.contains(n) { return .shell(info.name) }
            if info.ppid <= 1 || info.ppid == cur { break }
            cur = info.ppid
            hops += 1
        }
        return .login
    }
}
