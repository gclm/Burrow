//
//  SecurityPosture.swift
//  Burrow
//
//  Security-posture verdicts for the Doctor report (PRD §Doctor): SIP,
//  Gatekeeper, FileVault, firewall — parsed from the standard system tools.
//  Pure parsers; the command spawns are the impure seam in Doctor. Each tool's
//  output is tiny and stable. An unrecognized line reads as `.unknown` — never
//  a wrong "secure".
//

import Foundation

enum SecurityPosture {
    enum State: String, Equatable { case on, off, unknown }

    /// `csrutil status` → "System Integrity Protection status: enabled."
    static func sip(_ out: String) -> State {
        let s = out.lowercased()
        if s.contains("status: enabled") { return .on }
        if s.contains("status: disabled") { return .off }
        return .unknown
    }

    /// `spctl --status` → "assessments enabled".
    static func gatekeeper(_ out: String) -> State {
        let s = out.lowercased()
        if s.contains("assessments enabled") { return .on }
        if s.contains("assessments disabled") { return .off }
        return .unknown
    }

    /// `fdesetup status` → "FileVault is On."
    static func fileVault(_ out: String) -> State {
        let s = out.lowercased()
        if s.contains("filevault is on") { return .on }
        if s.contains("filevault is off") { return .off }
        return .unknown
    }

    /// `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate`
    /// → "Firewall is enabled. (State = 1)". State 0 = off, 1 = on, 2 = block-all.
    static func firewall(_ out: String) -> State {
        let s = out.lowercased()
        if s.contains("state = 1") || s.contains("state = 2") { return .on }
        if s.contains("state = 0") { return .off }
        if s.contains("enabled") { return .on }
        if s.contains("disabled") { return .off }
        return .unknown
    }
}
