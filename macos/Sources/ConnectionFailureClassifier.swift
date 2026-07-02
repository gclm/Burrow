//
//  ConnectionFailureClassifier.swift
//  Burrow
//
//  Classifies why a Get Online attempt failed, from the probe verdicts, for the
//  connection-history log (PRD §β). Pure.
//

import Foundation

enum ConnectionFailureClassifier {
    enum Reason: String, Equatable {
        case ok                 // online
        case captivePortal      // portal present, login page reachable
        case loginUnreachable   // portal present, login page itself didn't respond
        case noInternet         // no portal, no reachability
    }

    static func classify(online: Bool, portal: Bool, loginReachable: Bool) -> Reason {
        if online { return .ok }
        if portal { return loginReachable ? .captivePortal : .loginUnreachable }
        return .noInternet
    }
}
