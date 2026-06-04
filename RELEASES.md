# Burrow 0.4.0

The first release as a full, open-source **mole.fit** — a native macOS GUI
for the [Mole](https://github.com/tw93/Mole) CLI (`mo`).

## Five tools, one window
- **Status** — live dashboard: health score, CPU, memory, GPU, disk,
  network, battery with per-metric sparklines, and a sortable/pinnable
  process table.
- **Analyze** — squarified treemap of your disk; drill in, reveal in Finder.
- **Software** — installed-app list with search/sort + multi-select
  uninstall, plus a Homebrew **Updates** tab.
- **Clean** — preview what's reclaimable, then clean for real.
- **Optimize** — one-tap safe maintenance.

## Burrow's own extras
- **Menu-bar HUD** with live status of jobs running in the app.
- **History** — long-range charts (5 m → 90 d) over a local SQLite history.
- **MCP server** (HTTP + `Burrow --mcp` stdio) for Claude Code.

## Requirements
- macOS 14+
- `brew install mole`

## Install notes
Unsigned build for now. After copying to `/Applications`:
`xattr -cr /Applications/Burrow.app`, or right-click → Open the first time.
A notarized release + Homebrew cask are planned.
