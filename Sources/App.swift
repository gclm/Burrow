//
//  App.swift
//  Burrow
//
//  Entry point. Burrow is a `LSUIElement: true` agent app — no Dock icon,
//  no main menu, just a menu bar item managed by `AppDelegate`. SwiftUI
//  windows (popup, history, settings) are presented imperatively from the
//  delegate rather than as a `WindowGroup`, because most of the time the
//  app has no windows and shouldn't show up in the dock.
//

import SwiftUI

@main
struct BurrowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // `Settings` scene exists only so SwiftUI is satisfied. Burrow's
        // real windows are created from AppDelegate. The Settings scene
        // is never opened — `LSUIElement: true` hides the main menu so
        // there's no Stats → Preferences command path to it.
        Settings { EmptyView() }
    }
}
