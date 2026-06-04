//
//  App.swift
//  Burrow
//
//  Entry point with a process-mode fork:
//
//    * `Burrow`        → menu-bar GUI (default).
//    * `Burrow --mcp`  → stdio JSON-RPC MCP server for Claude Code.
//
//  Pure AppKit bootstrap (no SwiftUI `App`/`Settings` scene). The old
//  `Settings { EmptyView() }` scene auto-bound ⌘, to a blank window —
//  the "fake settings window". Now ⌘, is a real menu command that opens
//  the Settings *pane* inside the main window (see AppDelegate's menu).
//  Windows are managed imperatively by AppDelegate so they can be driven
//  from the status-bar HUD.
//

import AppKit

@main
enum BurrowMain {
    /// Strong reference — NSApplication.delegate is weak.
    private static var delegate: AppDelegate?

    static func main() {
        if CommandLine.arguments.contains("--mcp") {
            FileHandle.standardError.write(Data("burrow.main: --mcp stdio mode\n".utf8))
            MCP.runStdioLoop()
            exit(0)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        BurrowMain.delegate = delegate
        app.delegate = delegate
        // Start as a menu-bar agent; AppDelegate flips to .regular while a
        // window is open so the Dock icon + menu bar appear.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
