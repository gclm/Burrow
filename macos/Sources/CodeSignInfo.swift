//
//  CodeSignInfo.swift
//  Burrow
//
//  Code-signing facts for the process inspector's Security section (PRD §α 55):
//  signer, team id, hardened-runtime, app-sandbox, and signature validity —
//  via the Security framework's SecCode APIs (unprivileged, by pid). All a
//  syscall seam; there's no pure logic to unit-test here.
//

import Foundation
import Security

enum CodeSignInfo {
    struct Info: Equatable {
        let signer: String?     // leaf-cert common name, else team id
        let teamID: String?
        let hardened: Bool
        let sandboxed: Bool
        let valid: Bool         // signature validates against its designated requirement
    }

    // SecCSFlags raw values (CSCommon.h) — used numerically to avoid the
    // constants' uneven Swift import.
    private static let kSigningInfo: UInt32 = 0x2 | 0x4   // signing + requirement information
    private static let kRuntimeFlag: UInt32 = 0x1_0000    // hardened runtime (CS_RUNTIME)

    static func read(pid: Int) -> Info? {
        let attrs = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess, let code else { return nil }
        var stat: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &stat) == errSecSuccess, let stat else { return nil }

        let valid = SecStaticCodeCheckValidity(stat, [], nil) == errSecSuccess

        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(stat, SecCSFlags(rawValue: kSigningInfo), &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any] else {
            return Info(signer: nil, teamID: nil, hardened: false, sandboxed: false, valid: valid)
        }

        let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String
        let csFlags = (info[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0
        let hardened = (csFlags & kRuntimeFlag) != 0

        var sandboxed = false
        if let ent = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
            sandboxed = (ent["com.apple.security.app-sandbox"] as? Bool) == true
        }

        var signer: String? = teamID
        if let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate], let leaf = certs.first {
            var cn: CFString?
            if SecCertificateCopyCommonName(leaf, &cn) == errSecSuccess, let name = cn as String? {
                signer = name
            }
        }
        return Info(signer: signer, teamID: teamID, hardened: hardened, sandboxed: sandboxed, valid: valid)
    }
}
