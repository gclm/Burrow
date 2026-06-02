//
//  App.swift
//  Burrow
//
//  Entry point with a process-mode fork:
//
//    * `Burrow`                  → menu-bar GUI (default).
//    * `Burrow --mcp`            → stdio JSON-RPC MCP server. Used by
//                                  Claude Code (and any other MCP
//                                  client). Reads from stdin, writes to
//                                  stdout, exits on EOF.
//
//  Same binary serves both modes so the user doesn't have to manage a
//  separate helper executable and so the MCP path always reads the
//  same `~/Library/Application Support/Burrow/burrow.db` the GUI
//  writes to. Disambiguation happens here, before SwiftUI's `App.main()`
//  takes over for the GUI side.
//
//  Why bypass `@main` on BurrowApp: with `@main` SwiftUI claims the
//  process and we can't peel off a non-GUI mode. Wrapping in BurrowMain
//  with explicit `static func main()` is the canonical workaround.
//

import SwiftUI

struct BurrowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // SwiftUI requires a Scene, but Burrow's real windows are
        // managed imperatively from AppDelegate so they can be opened
        // from a status-bar menu (LSUIElement: true means no main menu).
        Settings { EmptyView() }
    }
}

@main
struct BurrowMain {
    static func main() {
        if CommandLine.arguments.contains("--mcp") {
            // One-line stderr breadcrumb so when this is wired into
            // Claude Code's MCP config and something stops working
            // there's a confirmation the binary even got the flag.
            // Claude Code routes stderr to its MCP debug log.
            FileHandle.standardError.write(Data("burrow.main: --mcp stdio mode\n".utf8))
            MCP.runStdioLoop()
            exit(0)
        }
        BurrowApp.main()
    }
}
