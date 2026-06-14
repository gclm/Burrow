# Burrow 0.7.1

A stability release. The 0.7.0 redesign shipped with a handful of freezes — and
one crash — that telemetry caught in the first day. This clears every app-hang
and the crash reported since launch, plus two long-standing freezes that predate
the redesign. No new features; just the redesign, holding still.

## Freezes & a crash, fixed
- **History view no longer locks up.** Opening a wide time range (up to 90 days)
  could freeze the app for a couple of seconds while the bar charts laid out —
  the worst regression from the redesign. Charts now down-sample cleanly and stay
  responsive. *(#57)*
- **Faster launch, no hang.** Startup no longer blocks the main thread while it
  looks for the `mo` engine — the lookup moved off-thread. (This one predates
  0.7.0 and has been one of the most common freezes in the wild.) *(#72)*
- **Fixed a crash opening the menu-bar popover.** The mini charts in the popover
  and the Status tiles could segfault during a transition; they now draw as a
  single shape, the same way the History charts do. *(#75)*
- **Smooth typing in Uninstall & Purge.** Keystrokes sent to the interactive `mo`
  sessions no longer risk parking the UI when the engine's output backs up. *(#73)*
- **Steadier process list.** The per-row Quit / Force-Kill menu in Status no
  longer rebuilds its labels on every two-second refresh. *(#74)*

## Charts & metrics
- **GPU history bars draw again** on Apple Silicon (they'd been reading as a flat
  zero).

## Under the hood
- **One refresh pump for live metrics.** The HUD, Status, and Activity panels now
  share a single refresh source instead of each spinning its own timer — less
  churn and fewer redundant `mo` calls. *(#53)*
- **One audited engine path.** Every `mo` call — snapshot, streaming, the
  interactive PTY sessions, and privileged operations — now flows through a single
  facade, which makes future privileged-operation work safer to build on. *(#48)*
