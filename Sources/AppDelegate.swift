//
//  AppDelegate.swift
//  Burrow
//
//  Wires the menu-bar item, kicks off the Mole sampler, starts the MCP
//  query server. Order of operations matters at launch:
//
//    1. Verify `mo` is on PATH. Hard requirement — if missing, present
//       a modal alert with the install command, then quit. Burrow has no
//       useful behaviour without it.
//    2. Open the SQLite history DB at `~/Library/Application Support/Burrow/burrow.db`.
//       Creates the file + tables on first run.
//    3. Start the QueryServer on 127.0.0.1:9277 so MCP / curl clients
//       can hit `/health` while the sampler warms up.
//    4. Start the Sampler — spawns `mo status --json` every N seconds,
//       parses the snapshot, writes it to the DB.
//    5. Install the NSStatusItem.
//
//  Order matters: (1) gates everything; (2) must precede (3) and (4) so
//  they have a backing store; (3) and (4) are independent.
//

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private var sampler: Sampler?
    private var queryServer: QueryServer?
    private var db: DB?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Hard requirement: `mo` on PATH.
        guard MoleCLI.findExecutable() != nil else {
            MoleCLI.showMissingAlert()
            NSApp.terminate(nil)
            return
        }

        // 2. Open the DB.
        do {
            self.db = try DB.openDefault()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't open Burrow's history database"
            alert.informativeText = "\(error.localizedDescription)\n\nThe app will quit."
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        // 3. Start MCP query server (binds 127.0.0.1:9277). Best-effort:
        //    if the port is taken, log and continue without it rather than
        //    blocking the menu bar from coming up.
        self.queryServer = QueryServer(db: self.db!)
        self.queryServer?.start()

        // 4. Start the Mole sampler.
        self.sampler = Sampler(db: self.db!)
        self.sampler?.start()

        // 5. Menu bar item.
        self.statusBar = StatusBarController(db: self.db!, sampler: self.sampler!)
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.sampler?.stop()
        self.queryServer?.stop()
        // DB closes via deinit.
    }
}
