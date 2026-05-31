# Burrow

A macOS menu-bar app that keeps a **long-running history of your Mac's
resource usage** — sampled from [Mole](https://github.com/tw93/Mole) — and
serves it over a localhost **MCP query server** so Claude Code (and any
other client) can reason about your machine's recent state.

Free, open-source, MIT. Sits alongside `mo` and complements
[Mole for Mac](https://mole.fit/) — the time-series + MCP layer is
genuinely new vs either.

## Status

v0.1 — pre-release. The daemon, sampler, SQLite history, and MCP server
are functional. UI is a minimal menu-bar popover; History view +
cleanup integration land in v0.2.

## Requirements

- macOS 14+
- `mo` CLI installed (`brew install mole`) — hard requirement; Burrow
  refuses to launch without it.

## Features (v0.1)

- **Sampler.** Spawns `mo status --json` every 60 s, writes the full
  snapshot to SQLite at
  `~/Library/Application Support/Burrow/burrow.db`.
- **MCP query server.** `127.0.0.1:9277`. Endpoints:
  `/health`, `/info`, `/snapshot`, `/metrics?prefix=...&since=...`.
- **Menu-bar popover.** Single-screen summary of current CPU, memory,
  disk IO, thermal, and Mole's system health score. Refreshes in real
  time off the in-memory mirror; no DB hit per redraw.

## Building

```bash
brew install xcodegen
xcodegen generate
open Burrow.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

## Testing

```bash
xcodebuild -project Burrow.xcodeproj -scheme Burrow \
  -configuration Debug -destination 'platform=macOS' \
  test
```

## Architecture

```
Mole CLI                Burrow (this app)
─────────               ────────────────────────────
mo status --json   ──>  Sampler (60 s tick)
                        │
                        ▼
                       SQLite (samples table)
                        ▲      ▲
                        │      │
                    PopupView  QueryServer (MCP, :9277)
                                ▲
                                │
                           Claude Code / curl
```

The Sampler is the only piece that pulls fresh data — everything else
(popup, charts, MCP) reads from the SQLite store. That's intentional:
it keeps the read paths cheap and parallelizable (SQLite WAL mode),
and means Burrow has exactly one place to gate or throttle the spawn
cost of `mo`.

## License

[MIT](LICENSE). Mole CLI is © tw93, also MIT. Inspired by — and shares
data-model lineage with — the [Stats fork](https://github.com/caezium/stats)
at `caezium/stats@henry/history-mcp`, where the history DB + MCP server
pattern was first prototyped.
