//
//  SensitiveRemnantMatcher.swift
//  Burrow
//
//  Flags credential/keychain-style leftover paths so Clean review can show a
//  caution badge instead of a plain "Safe" chip (PRD §Clean). Pure pattern
//  match — never hides anything, only flags for deliberate review.
//

import Foundation

enum SensitiveRemnantMatcher {
    private static let needles = [
        "keychain", "credential", "/.ssh", "id_rsa", "id_ed25519", ".gnupg",
        "token", "secret", "password", ".aws/credentials", ".netrc", "cookies",
    ]
    static func isSensitive(_ path: String) -> Bool {
        let p = path.lowercased()
        return needles.contains { p.contains($0) }
    }
}
