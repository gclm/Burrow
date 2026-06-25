//
//  VenueMatcher.swift
//  Burrow
//
//  Matches a Wi-Fi network name to a known venue/airline and its captive-portal
//  tips (PRD §β — Get Online companion). Pure — the catalog is a bundled seed
//  (community-extensible via JSON later); the SSID read is the seam
//  (CoreWLAN + Location).
//

import Foundation

enum VenueMatcher {
    struct Venue: Equatable { let name: String; let tips: [String] }

    /// `keys` are lowercased substrings matched against the SSID. First match wins.
    static let catalog: [(keys: [String], venue: Venue)] = [
        (["hilton", "honors"], Venue(name: "Hilton", tips: [
            "Hilton portals often run older software that blocks encrypted DNS — turn custom/secure DNS off.",
            "Honors members can sometimes bypass the portal with their account credentials."])),
        (["marriott", "bonvoy"], Venue(name: "Marriott", tips: [
            "Marriott portals may require turning Private Relay off to load."])),
        (["delta"], Venue(name: "Delta Fly-Fi", tips: [
            "In-flight portals block VPNs and custom DNS — disable both to reach the login page."])),
        (["united"], Venue(name: "United Wi-Fi", tips: [
            "Open the free messaging/portal first; VPN and Private Relay will block it."])),
        (["alaska"], Venue(name: "Alaska Wi-Fi", tips: [
            "Starlink-backed — disable Private Relay/VPN and the portal loads fast."])),
        (["jetblue"], Venue(name: "JetBlue Fly-Fi", tips: [
            "Free Fly-Fi — turn off custom DNS if the welcome page won't load."])),
        (["southwest"], Venue(name: "Southwest Wi-Fi", tips: [
            "Open the portal before connecting any VPN."])),
        (["spirit"], Venue(name: "Spirit Wi-Fi", tips: [
            "Disable VPN/Private Relay to reach the paid portal."])),
    ]

    static func match(ssid: String) -> Venue? {
        let s = ssid.lowercased()
        for entry in catalog where entry.keys.contains(where: { s.contains($0) }) { return entry.venue }
        return nil
    }
}
