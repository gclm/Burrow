# Burrow

A macOS menu-bar app that keeps a **long-running history of your Mac's
resource usage** — sampled from [Mole](https://github.com/tw93/Mole) — and
serves it over a localhost MCP query server so Claude Code (and any
other client) can reason about your machine's recent state.

Free, open-source, MIT. Sits alongside `mo` and complements
[Mole for Mac](https://mole.fit/) — the time-series + MCP layer is
genuinely new vs either.

## Status — v0.2

Functional. Sampler, SQLite history, MCP HTTP server, stdio MCP shim
for Claude Code, History view with charts, Cleanup wrapping `mo
clean`, Settings panel, hourly prune.

## Requirements

- macOS 14+
- `mo` CLI installed (`brew install mole`) — hard requirement; Burrow
  refuses to launch without it.

## Features

### Background
- **Sampler.** Spawns `mo status --json` at the configured cadence
  (default 60 s). Writes the full snapshot to SQLite under
  `prefix: "mole.snapshot"`.
- **Maintenance.** Hourly prune by retention setting; optional VACUUM
  after large prunes.

### Menu-bar UI
- **Popover.** Live CPU / memory / disk IO / thermal / health score
  summary, refreshes every second off the Sampler's in-memory mirror.
- **History window.** Range chips from 5 m to 90 d; charts for CPU
  usage / load / memory / disk IO / network / thermal / health score;
  top-N processes aggregated across the range (peak CPU + peak memory
  per process).
- **Cleanup window.** Runs `mo clean --dry-run` automatically, streams
  output, gates a "Clean for real" button on a successful dry-run.
- **Settings window.** Retention, sample interval, VACUUM toggle, MCP
  server toggle + port, "Run maintenance now", live DB-size readout.

### API surfaces
- **HTTP localhost server.** `127.0.0.1:9277` (configurable). Endpoints:
  - `GET /health` — liveness probe
  - `GET /info` — prefixes + retention + reader staleness
  - `GET /snapshot` — most recent full snapshot
  - `GET /metrics?prefix=...&since=...&until=...&bucket=...` — time series
- **Stdio MCP server.** `Burrow --mcp` enters JSON-RPC 2.0 mode on
  stdin/stdout. Wires into Claude Code via `~/.claude/settings.json`:
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
  Tools exposed: `burrow_snapshot`, `burrow_history`,
  `burrow_top_processes`, `burrow_info`.

## Building

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
cp -R build/Build/Products/Debug/Burrow.app /Applications/
xattr -cr /Applications/Burrow.app
open /Applications/Burrow.app
```

## Testing

```bash
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Debug -destination 'platform=macOS' test
```

Coverage: DB roundtrip + range + stride sampler + prune (10 tests),
Store clamping + defaults (9 tests), Maintenance prune (3 tests),
MCP tool catalog routing (7 tests). 29 total.

## Architecture

```
Mole CLI                Burrow (this app)
─────────               ────────────────────────────
mo status --json   ──>  Sampler (interval tick)
                        │
                        ▼
                       SQLite (samples table, WAL mode)
                        ▲      ▲      ▲
                        │      │      │
                  PopupView    │     HTTP QueryServer (:9277)
                  HistoryView  │      ▲
                  Settings     │      │
                               │      curl / browser
                               ▼
                       Stdio MCP shim (Burrow --mcp)
                               ▲
                               │
                          Claude Code

mo clean ────────────> Cleanup window (dry-run → confirm → real)
```

One sampler, one DB. WAL mode means the MCP stdio shim can read while
the GUI is writing; both share `~/Library/Application Support/Burrow/
burrow.db`.

## License

[MIT](LICENSE). Mole CLI is © tw93, also MIT. Inspired by — and shares
data-model lineage with — the [Stats fork](https://github.com/caezium/stats)
at `caezium/stats@henry/history-mcp`, where the history DB + MCP server
pattern was first prototyped.
