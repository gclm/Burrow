# Burrow

**A free, open-source [mole.fit](https://mole.fit/) — a native macOS GUI for the [Mole](https://github.com/tw93/Mole) CLI (`mo`).**

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)
![Requires mole](https://img.shields.io/badge/requires-brew%20install%20mole-orange)

Burrow wraps the free, open-source `mo` CLI in a native Mac app: clean
junk, manage & uninstall apps, run safe maintenance, map your disk, and
watch live system status — five tools in one window. On top of that it
adds two things the CLI doesn't have: a **long-running history** of your
Mac's metrics in a local SQLite database, and an **MCP server** so Claude
Code can ask "what's been happening on this Mac."

> Burrow is an independent open-source project. It's *inspired by*
> mole.fit's structure and built on the same `mo` engine, but it is **not
> affiliated with or endorsed by mole.fit** — its own name, mark, palette,
> and copy are original.

## Screenshots

See [`docs/screenshots`](docs/screenshots). _(Drop clean captures of each
tab there — Status, Analyze, Software, Clean, Optimize, the menu-bar HUD.)_

## The five tools

| Tool | What it does | `mo` command |
|---|---|---|
| **Status** | Live dashboard — health score, CPU, memory, GPU, disk, network, battery with per-metric sparklines, plus a sortable/pinnable process table. | `mo status --json` |
| **Analyze** | Squarified treemap of your disk; drill into any folder, reveal in Finder. | `mo analyze --json` |
| **Software** | Installed-app list with search/sort (size, name, recent, source) and multi-select uninstall; a Homebrew **Updates** tab. | `mo uninstall --list`, `brew outdated` |
| **Clean** | Preview what's reclaimable, then clean for real — categorized cache/log/leftover removal. | `mo clean` |
| **Optimize** | One-tap safe maintenance: rebuild caches, repair metadata, flush DNS, etc. | `mo optimize` |

### Plus, Burrow's own extras

- **Menu-bar HUD** — health hero, metric tiles, top processes, and live
  status of any job running in the app, from the menu bar.
- **History** — long-range charts (5 m → 90 d) over a local SQLite history
  of every metric, plus peak-per-process tables.
- **MCP server** — both a localhost HTTP API and a stdio JSON-RPC server
  (`Burrow --mcp`) so Claude Code can query your Mac's recent state.

## Requirements

- **macOS 14+**
- **The Mole CLI** — `brew install mole`. Hard requirement; Burrow refuses
  to launch without `mo` on PATH.

## Install

### Build from source

```bash
brew install xcodegen mole
git clone https://github.com/caezium/Burrow.git
cd Burrow
xcodegen generate
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
cp -R build/Build/Products/Release/Burrow.app /Applications/
xattr -cr /Applications/Burrow.app   # unsigned dev build: clear quarantine
open /Applications/Burrow.app
```

Burrow lives in the menu bar (it's a menu-bar agent). Click the icon →
**Open Burrow**.

> A signed/notarized release and a Homebrew cask are planned so install is
> a one-liner without the Gatekeeper step.

## Wire it into Claude Code

Burrow doubles as an MCP server. Add to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "burrow": {
      "command": "/Applications/Burrow.app/Contents/MacOS/Burrow",
      "args": ["--mcp"]
    }
  }
}
```

Restart Claude Code. Tools: `burrow_snapshot`, `burrow_history`,
`burrow_top_processes`, `burrow_info`. There's also a localhost HTTP API
on `127.0.0.1:9277` (`/health`, `/info`, `/snapshot`, `/metrics`).

## Develop & test

```bash
xcodegen generate
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Debug -destination 'platform=macOS' test
```

38 tests: DB roundtrip + range + stride sampler + prune (10), Store
clamping + defaults (9), Maintenance prune (3), MCP tool routing (7),
squarified treemap invariants (9).

## Architecture

```
mo status --json   ──>  Sampler ──> SQLite (WAL) ──┬─> Status / History (charts)
                                                   ├─> HTTP QueryServer (:9277)
                                                   └─> Burrow --mcp (stdio) ─> Claude Code
mo analyze --json  ──>  DiskScanner + squarified Treemap ──> Analyze
mo clean / optimize ─>  CommandRunner (streamed) ──────────> Clean / Optimize
mo uninstall --list ─>  Software (+ brew outdated for Updates)
```

One binary, two modes: default is the menu-bar GUI; `Burrow --mcp` is the
stdio MCP server (it forks before SwiftUI claims the process). The whole
UI is one translucent window with a top-pill nav (`Brand`/`Tool` design
system); Settings and History are panes in that same window.

## Attribution & license

[MIT](LICENSE).

- **Mole CLI** (`mo`) is © [tw93](https://github.com/tw93/Mole), MIT.
  Burrow depends on it at runtime and bundles nothing from it.
- Inspired by the **mole.fit** Mac app (same author as `mo`). Burrow is an
  independent reimplementation with its own brand — no assets, icons,
  copy, or trade dress are taken from mole.fit.
- The history-DB + MCP pattern shares lineage with the same author's
  [Stats fork](https://github.com/caezium/stats) (`caezium/stats@henry/history-mcp`).
- Treemap layout: Bruls, Huijsen & van Wijk (2000), "Squarified Treemaps,"
  re-implemented from scratch in Swift.
