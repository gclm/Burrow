//
//  AppDelegate.swift
//  Burrow
//
//  Launch order (matters):
//
//    1. Verify `mo` is on PATH. Hard requirement — if missing, modal
//       alert with the install command, then quit.
//    2. Open the SQLite history DB.
//    3. Start QueryServer (Store-gated).
//    4. Start Sampler (Store-configured cadence).
//    5. Start Maintenance (hourly prune).
//    6. Install the NSStatusItem.
//
//  Windows: v0.3 collapsed the four separate windows (History,
//  DiskMap, Cleanup, Settings) into one main window with a sidebar.
//  `openMainWindow(initial:)` is the one entry point — the popover's
//  action buttons just deep-link by passing the section they want
//  selected.
//

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Singleton handle so SwiftUI views can reach the live
    /// Maintenance / Sampler / DB without threading them through every
    /// initializer.
    static private(set) var shared: AppDelegate?

    private(set) var db: DB?
    private(set) var sampler: Sampler?
    private(set) var maintenance: Maintenance?
    private var queryServer: QueryServer?
    private var statusBar: StatusBarController?

    /// Single main window. Holds the sidebar + content router. The
    /// `pendingInitialSection` is only used to pass the chosen tab
    /// across the window-creation boundary; cleared once the window's
    /// content view reads it.
    private var mainWC: NSWindowController?
    fileprivate var pendingInitialSection: BurrowSection = .overview

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        guard MoleCLI.findExecutable() != nil else {
            MoleCLI.showMissingAlert()
            NSApp.terminate(nil)
            return
        }

        let db: DB
        do {
            db = try DB.openDefault()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't open Burrow's history database"
            alert.informativeText = "\(error.localizedDescription)\n\nThe app will quit."
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        self.db = db

        if Store.queryServerEnabled {
            let port = UInt16(clamping: Store.queryServerPort)
            self.queryServer = QueryServer(db: db, port: port)
            self.queryServer?.start()
        }

        let sampler = Sampler(db: db,
                              intervalSeconds: TimeInterval(Store.sampleIntervalSeconds))
        self.sampler = sampler
        sampler.start()

        let maintenance = Maintenance(db: db)
        self.maintenance = maintenance
        maintenance.start()

        self.statusBar = StatusBarController(db: db, sampler: sampler, delegate: self)
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.sampler?.stop()
        self.queryServer?.stop()
        self.maintenance?.stop()
    }

    // MARK: - Window

    /// Open the main window, focusing the requested section. If the
    /// window already exists, just selects the section and brings the
    /// window forward. Used by every popover action button —
    /// `openMainWindow(initial: .cleanup)` etc.
    @available(macOS 14.0, *)
    func openMainWindow(initial: BurrowSection = .overview) {
        // If already open, route through the existing controller +
        // root view's selection binding.
        if let wc = self.mainWC, let window = wc.window {
            self.pendingInitialSection = initial
            // Tear down + rebuild content so the .task on MainView
            // sees the new initial section. Cheap — just rebuilds
            // SwiftUI hierarchy.
            self.installMainContent(into: window, initial: initial)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let db = self.db, let sampler = self.sampler else { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.title = "Burrow"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 900, height: 580)
        _ = (db, sampler)  // capture only via installMainContent below

        let wc = NSWindowController(window: window)
        self.mainWC = wc
        self.installMainContent(into: window, initial: initial)
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @available(macOS 14.0, *)
    private func installMainContent(into window: NSWindow, initial: BurrowSection) {
        guard let db = self.db, let sampler = self.sampler else { return }
        let root = MainView(db: db, sampler: sampler, delegate: self,
                            initialSelection: initial)
        window.contentViewController = NSHostingController(rootView: root)
    }
}
