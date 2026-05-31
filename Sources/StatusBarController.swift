//
//  StatusBarController.swift
//  Burrow
//
//  Owns the NSStatusItem and the popover that opens from it. The
//  popover is created lazily on first click (cheaper launch path) and
//  reused — its contentViewController holds the SwiftUI `PopupView`,
//  bound to the Sampler so it can read the latest snapshot directly
//  rather than going through the DB.
//
//  The icon is a simple SF Symbol for v0.1. A custom asset can replace
//  it later — the controller doesn't care.
//

import AppKit
import SwiftUI

final class StatusBarController {
    private let item: NSStatusItem
    private let popover: NSPopover
    private let db: DB
    private let sampler: Sampler

    init(db: DB, sampler: Sampler) {
        self.db = db
        self.sampler = sampler
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Build the popover before we touch `self` from the button-target
        // assignment below: Swift requires every `let` stored property to
        // be initialized before any method (including the @objc target
        // path) can reference `self`.
        let popover = NSPopover()
        popover.behavior = .transient   // closes on outside click
        popover.contentSize = NSSize(width: 320, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: PopupView(sampler: sampler))
        self.popover = popover

        if let button = self.item.button {
            // Burrow's icon for v0.1. Picked for semantic fit ("burrow" / "den")
            // — a future custom asset will replace it.
            button.image = NSImage(systemSymbolName: "house.lodge.fill",
                                   accessibilityDescription: "Burrow")
            button.image?.isTemplate = true  // adapts to light/dark menu bar
            button.action = #selector(self.handleClick(_:))
            button.target = self
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        guard let button = self.item.button else { return }
        if self.popover.isShown {
            self.popover.performClose(sender)
        } else {
            self.popover.show(relativeTo: button.bounds,
                              of: button,
                              preferredEdge: .minY)
            // Bring the app forward so the popover gets keyboard focus —
            // without this, opening from a background app puts the
            // popover up but key events go elsewhere.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
