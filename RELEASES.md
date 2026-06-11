# Burrow 0.6.7

The biggest release yet. Burrow gets a unified **Home dashboard**, **Traditional
Chinese** alongside Simplified and English, native **fan/temperature sensors**,
**1-second live** net & disk charts, **Trash-from-the-treemap**, and a sharper
**AI Explain** lens. It also gains opt-out usage analytics + crash reporting —
documented honestly, hardened, and behind a single switch — on top of a large
internal refactor that makes the whole app easier to trust and test.

## New
- **One Home dashboard.** The Burrow icon now opens Home, folding Status,
  History, and Activity into a single live view — vitals, charts, and recent
  jobs in one place.
- **Bluetooth & battery on Home.** Connected Bluetooth devices and battery
  health surface alongside the rest of your Mac's vitals.
- **Traditional Chinese (繁體中文, Taiwan).** Plus an in-app language switch —
  System / English / 简体中文 / 繁體中文 — so you're not tied to the system
  language. The AI Explain lens answers in your chosen language too.
- **Native sensors.** Real fan RPM and CPU/GPU die temperatures, read directly
  via SMC, fill the gaps Mole leaves on Apple Silicon.
- **1-second live charts.** A unified net + disk monitor drives Home and History
  at the same fast cadence, so bursts actually show up instead of being averaged
  away.
- **Move to Trash from Analyze.** Spot a forgotten folder in the treemap and
  send it to the Trash right there — no detour to Finder.
- **Sharper AI Explain.** It now briefs the whole picture — current snapshot,
  recent trend, and your recent cleanups — not just one moment.

## Privacy & security
- **Opt-out analytics + crash reporting, stated plainly.** Burrow now sends
  anonymous product analytics (PostHog) and crash reports (Sentry): a random
  install id, app/OS version, CPU type, and bucketed feature counts — **never**
  files, paths, contents, or your metrics. It's asked once at first launch, is a
  single switch in **Settings → Anonymous usage**, and is **inert in builds from
  source**. Full list in [TELEMETRY.md](TELEMETRY.md).
- **Local HTTP server tightened.** The loopback metrics server no longer sends a
  CORS grant, so a web page in your browser can't read it; it also caps request
  size and times out idle connections.
- **Agents ask twice for the irreversible.** Letting an AI agent run real
  cleanups is one opt-in; **uninstalls and permanent deletes need a second,
  separate switch** — and a real uninstall aborts unless Mole matches exactly the
  apps you named.
- **Safer elevation & key storage.** Admin runs resolve only your trusted
  Homebrew `mo`, and any hosted-AI API key now lives in the **Keychain** instead
  of plain preferences.

## Fixes
- **Clear message on older Mole.** On Mole before 1.29 the treemap could fail
  with a cryptic `/dev/tty` error; it now tells you to update Mole instead.
- **Treemap feels right again.** Hover and click land on the correct cell, and
  the breadcrumb "go up" works as expected.
- **Homebrew cask installs on macOS 14+** correctly on both old and new
  Homebrew.
- **History database is more robust.** It survives the GUI and an agent opening
  it at the same time instead of risking a reset, and large Mole output (Analyze,
  the app list) no longer truncates or hangs.

## Under the hood
- A large deep-module refactor: one metrics query/aggregation layer, one snapshot
  engine behind testable ports, one shared operation flow for Clean/Optimize, and
  shared formatters — retiring a stack of duplicated, drift-prone code.
- CI now runs the full test suite on every push and PR; GitHub Actions are pinned
  to commit SHAs and dependencies to exact versions.
- Test suite grew from 124 to 244.

## Install
```
brew install --cask caezium/tap/burrow
```
Pulls in the `mole` engine and clears the Gatekeeper quarantine for you.
Ad-hoc signed (so Full Disk Access grants stick); not yet notarized.

---
Older releases: see the
[Releases page](https://github.com/caezium/Burrow/releases).
