//
//  PortInspector.swift
//  Burrow
//
//  Listening-port inspector (roadmap C.10): the GUI of `lsof -i` + `kill`.
//  Native enumeration (proc_listpids + proc_pidfdinfo socket info) and the
//  confirm-gated SIGTERM/SIGKILL are integration; this is the model plus the
//  safety rule that keeps Burrow from offering to kill system daemons.
//

import Foundation

struct ListeningPort: Equatable {
    let pid: Int
    let process: String
    let port: Int
    let proto: String   // "tcp" | "udp"
    let address: String
    let uid: Int
}

enum PortInspector {
    /// We only offer to kill a process the user actually owns. Root-owned
    /// (uid 0) and other users' processes are shown read-only — killing a
    /// system daemon by accident is exactly the footgun to avoid.
    static func isKillable(_ p: ListeningPort, currentUID: Int) -> Bool {
        p.uid != 0 && p.uid == currentUID
    }

    /// Stable display order: by port, then process name — so the table
    /// doesn't reshuffle every 5-second refresh.
    static func sorted(_ ports: [ListeningPort]) -> [ListeningPort] {
        ports.sorted { ($0.port, $0.process) < ($1.port, $1.process) }
    }
}
