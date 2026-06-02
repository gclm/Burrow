//
//  StatusBarController.swift
//  Burrow
//
//  Owns the NSStatusItem and its popover. The popover is created
//  lazily on first click and reused; its NSHostingController holds
//  the SwiftUI `PopupView` bound to the Sampler (for live snapshot
//  data) and the AppDelegate (for the History / Cleanup / Settings
//  buttons that open windows).
//
//  Icon: `chart.line.uptrend.xyaxis`. Reads as "this thing tracks
//  something over time" — semantically aligned with what Burrow does.
//  Template image so it adapts to light/dark menu bars.
//

import AppKit
import SwiftUI

final class StatusBarController {
    private let item: NSStatusItem
    private let popover: NSPopover
    private let db: DB
    private let sampler: Sampler

    init(db: DB, sampler: Sampler, delegate: AppDelegate) {
        self.db = db
        self.sampler = sampler
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Build the popover before the button-target line below so all
        // `let` properties are initialized when `self` first leaks via
        // the @objc selector dispatch.
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 320)
        popover.contentViewController = NSHostingController(
            rootView: PopupView(sampler: sampler, delegate: delegate))
        self.popover = popover

        if let button = self.item.button {
            // Burrow's menu-bar glyph. The "trend" chart icon mirrors
            // the app's purpose (history-over-time) better than the
            // earlier house-lodge placeholder.
            button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis",
                                   accessibilityDescription: "Burrow")
            button.image?.isTemplate = true
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
            // Pull focus so the popover's keyboard shortcuts (⌘Q etc.)
            // are reachable without a second click.
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
