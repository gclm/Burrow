# Burrow 0.8.1

A stability release: the live dashboard no longer freezes, live status now
streams, and there's a one-click Homebrew update button — plus the Windows
preview catches up on its code review. Still local-first.

## Fixed
- **No more "App Hanging" freezes.** The Overview dashboard used to re-render
  its whole grid — every chart tile and the full process table — once a second;
  now only the small Disk / Network tiles update that often, the rest on the
  snapshot. Opening **Settings** and the **About** panel no longer blocks the
  main thread either (login-item status, metrics-folder sizing, and the
  engine-version lookup all moved off it), and **PostHog telemetry now flushes
  off the main thread**.

## Changed
- **Live status streams by default.** With Mole 1.44+, Burrow streams
  `mo status --watch` (newline-delimited JSON) instead of polling `mo status
  --json` — lower latency and less subprocess churn. It falls back to polling
  on older `mo` or if the stream drops, so the dashboard never stalls.

## Added
- **Update with Homebrew** — for cask installs, the update prompt now has a
  one-click button that runs `brew upgrade --cask burrow` and relaunches,
  instead of just printing the command.

## Windows preview
- Closed out the port review: **MCP tool parity with macOS**
  (`burrow_list_apps`, `burrow_purge`, `burrow_installer` — all preview-only
  over MCP), stdio MCP that survives the HTTP toggle, **brand assets / palette /
  fonts / app icon aligned to the Mac**, honest docs, and real MCP +
  deletion-guard test coverage. (Earlier review rounds added Recycle-Bin
  routing, a drive-root guard, and SHA-256 verification of the bundled engine
  binary.) Still an unsigned, build-from-source preview.
