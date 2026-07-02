# Competitor feature scan — additions to the feature plan

> Running capture of features from other Mac apps the user is sending, to fold into Burrow's plan. Local only; not posted. Separate from the Mole-parity PRD (`mole-parity-prd-2026-06-25.md`) and from the other session's "one big plan". Each app: what it does → how it maps to Burrow (have / partial / new) → leverage (what existing Burrow infra it reuses) → value.
>
> Burrow context that keeps recurring here: Burrow already has a **process sampler + per-process history** (ProcessSampler/MetricsStore.processWindow, used by spike-forensics), **per-process nettop bandwidth** (NetUsage — built for Ports), an **alert/threshold engine** (AlertEngine/ThresholdAlerts + notifier), **proc_pidfdinfo socket enumeration** (PortEnumerator), **SSE event stream + notifications**, and a **menu-bar widget row**. Several asks below are mostly "surface infra we already have."

---

## Synthesis & recommendations (after both apps)

Two clean new epics fall out, plus a handful of standalone wins. Deduped against the Mole-parity PRD (`mole-parity-prd-2026-06-25.md`) and the already-shipped Get Online pane.

### Epic α — "Process Inspector" (deepen Status) — from ProcessSpy
Turn Burrow's sortable process list into a real inspector. This is the single biggest depth gap a power user notices. Reuses a lot we already have.
- **Tier 1 (high value ÷ low cost, reuses infra):**
  - **Per-process watchdog + actions** — per-process rules ("X holds >N% CPU/mem/disk for T s" → notify / quit / suspend). Reuses AlertEngine + notifier. Most-requested ProcessSpy feature; they're hesitant to build it. *Our actuating direction makes this on-brand.*
  - **Per-process network column** — surface NetUsage (already parses nettop) in the table + inspector. Near-free; ProcessSpy **refuses** to do it.
  - **Inspector panel** — extend the Mole PRD's **ProcessOrigin + BinaryIntegrity** into a full detail panel (signing/hardened/entitlements/Rosetta, QoS, footprint+peak, page-ins, per-process disk I/O, threads, parent/children). Extra metrics via unprivileged `proc_pidinfo`/`proc_pid_rusage`.
  - **Shortcuts / event hooks on process events** — same event plumbing as the watchdog + SSE. Pairs with the watchdog.
- **Tier 2:** process **tree view** (summed CPU/mem/threads, XPC-linked) · **predicate/JS filters + saved smart-filter tabs** (Unsigned/Neural/Startup/Recent/app) · per-row **CPU sparkline**.
- **Tier 3 / cheap polish:** suspend/resume signals · reveal **open files** (extend proc_pidfdinfo to vnodes) · **finished-process recall** ("Recent") · **JSON/CSV export** · multi-select aggregation.

### Epic β — "Get Online → travel companion" (extend the shipped pane) — from Hotspot Guide
We own the *fixes* (not sandboxed). Add the *companion* layer:
- **Venue/airline tips DB** (SSID-keyed known-issues + bypass tips) — content moat; ship curated + **community-extensible JSON**.
- **Connection History** (per-SSID success/fail + measured speed + failure reason) — reuse the SQLite history DB.
- **Speed test done right** (multi-stream + jitter/packet-loss).
- **Network Info / nearby-networks scan** (RSSI/channel/security) + **Public-vs-Home mode**.
- **Offline guides** (bundled markdown) · **lifetime stats** · staged check animation.
- **One gating decision:** **CoreWLAN + Location** permission — unlocks SSID auto-detect (→ venue DB), Home mode, and the scanner. The Mole PRD currently *defers* this; β is the reason to reconsider.

### Cross-cutting decisions to make
1. **CoreWLAN + Location permission** — yes/no. Gates the entire β companion layer (venue auto-detect, Home mode, scanner). Without it, β degrades to a manual venue picker + history + offline guides (still useful).
2. **Per-process deep metrics** (`proc_pidinfo`/`proc_pid_rusage` for QoS/footprint/page-ins/disk) — a small native reader that feeds the whole α inspector. Build once.
3. **Predicate-filter language** — JS (ProcessSpy's choice) vs a typed predicate. Burrow already exposes data to agents; a small predicate DSL might fit the agent-native angle better than embedding JS.

### Highest-ROI shortlist (build these first)
1. **Per-process network column** (α) — almost free, real differentiator.
2. **Per-process watchdog + actions + Shortcuts hooks** (α) — top ask, reuses alert engine, fits actuating direction.
3. **Connection History + venue DB** (β) — makes Get Online a companion; history reuses the DB, venue DB is curated content.
4. **Inspector panel + proc_pidinfo metrics** (α) — extends modules already in the Mole PRD.

### Integration notes
- α overlaps the Mole-PRD modules **ProcessOrigin** + **BinaryIntegrity** — don't duplicate; the inspector *is* their home.
- β **extends** the Mole-PRD connectivity items + the shipped Get Online — fold in, don't fork.
- Another session wrote `plans/burrow-cli-master-plan-2026-06-25.md` ("one big plan"). These two epics should be **reconciled into** it (or the Mole PRD) rather than living only here — flag for the user. Don't edit that file from this session (collision).

---

## 1. ProcessSpy — process-spy.app (advanced process monitor / Activity Monitor replacement)

Deep, native, fully-local process inspector. Freemium ($34.99 lifetime). macOS 14+, notarized, Homebrew cask. The depth is in the **per-process inspector, tree view, per-process history, and power-user filtering** — exactly the layer where Burrow's Status process table is currently shallow (sortable list + pin + spike-forensics, no inspector).

### Features → Burrow mapping

**A. Rich per-process inspector panel** (click a process → detail) — Burrow: **new** (row menu only does pin/reveal/copy/quit today). Fields:
- Identity/Time: start time, run time, **lifetime timeline vs system uptime** (log scale), last-seen.
- Process details: bundle ID, **format/arch + native-vs-Rosetta (emulated) status**, command line, main exec path, **Launched-By / responsible PID**, **startup-entry type** (daemon/agent/login).
- Security: **sandboxed, hardened-runtime, signature/signing org, entitlements, Info.plist**.
- Resources: CPU, CPU time, **user/sys split, QoS class**, memory, **footprint + peak footprint**, **page-ins**, **per-process disk I/O read/write (+per-sec)**, threads — and Burrow can add **per-process network up/down** that ProcessSpy deliberately omits.
- Hierarchy: parent + children, XPC services linked by responsible PID.
- *Leverage:* reuses the PRD's **BinaryIntegrity** + **ProcessOrigin** modules; QoS/footprint/page-ins/disk come from `proc_pid_rusage`/`proc_pidinfo`; net from existing **NetUsage**; signing from existing signature checks.

**B. Process tree / hierarchy view** with rolled-up aggregate CPU/Memory/Threads + multi-select sum — Burrow: **new** (we have ppid, no tree). XPC-link children by responsible PID. *Leverage:* ProcessSampler already captures ppid.

**C. Per-process history graphs** (CPU% + memory over time, avg/peak) + **export CSV/JSON** — Burrow: **partial** (we record per-process samples for spike-forensics + system history graphs; not surfaced as a per-process live graph or export). *Leverage:* MetricsStore.processWindow already holds the data.

**D. Per-process mini CPU sparkline in the table row** — Burrow: **new** (we have a PWR column, no per-row sparkline).

**E. ⭐ Per-process alert rules / watchdog** — "alert when a process holds >N% CPU/mem/disk for T seconds," optional auto-action (notify / quit / suspend). The single most-requested ProcessSpy feature in the thread (users even want auto-kill of a runaway AI process). Burrow: **partial→high-value** — we have system-level CPU/mem threshold alerts; extend the rule engine to **per-process** with actions. *Leverage:* AlertEngine + ThresholdAlerts + notifier + SSE. **Strong fit + differentiator** (ProcessSpy hasn't built it; the dev is hesitant).

**F. Advanced filters** — JS/predicate filters over process props (`process.residentMemory > X`), regex multi-property search, and **saved smart-filter tabs** (All/System/Apps/My/Unsigned/Neural-ANE/java/Microsoft/Startup-Entry/Recent/app-specific) — Burrow: **partial** (basic search). Predicate filters + saved-filter tabs are the power layer.

**G. ⭐ Per-process network column** (up/down per process) — Burrow: **near-free win**. ProcessSpy **refuses** this (doesn't want to parse nettop / overlap Little Snitch). Burrow **already parses nettop per-process** (NetUsage) for Ports → surface it in the process table as a column + inspector field. Low cost, real differentiator.

**H. Point-and-click process discovery** — click a window → identify its owning process — Burrow: **new** (CGWindowList/AX → pid). Power feature, modest.

**I. Pause / Resume (SIGSTOP/SIGCONT)** from the row menu — Burrow: **partial** (we have quit + force-kill; add suspend/resume). Cheap. (ProcessSpy markets that resume actually works vs Activity Monitor's broken button.)

**J. Reveal a process's open files** (lsof-style) + reveal in Finder — Burrow: **partial** (we enumerate sockets via proc_pidfdinfo for Ports; extend to file vnodes). Modest.

**K. Finished / recently-exited process recall** ("Recent" tab) — keep recently-dead processes + last metrics for forensics — Burrow: **new** but adjacent to spike-forensics. Modest.

**L. Run Shortcuts on process events** — fire a macOS Shortcut when a process matching a filter spawns/exits/crosses a threshold — Burrow: **new, on-brand** (Burrow's "actuating / agent-native" direction). *Leverage:* same event plumbing as the watchdog (E) + SSE. Pairs naturally with E.

**M. Per-process metrics we lack**: QoS class, footprint+peak, page-ins, user/sys CPU split, per-process disk I/O — Burrow: **new**, native via `proc_pid_rusage`/`proc_pidinfo` (rusage_info_v*). Feeds A.

**N. Misc**: process tagging; export visible processes to JSON/CSV; multi-select aggregation; native-vs-Rosetta badge; status-bar system indicators (Burrow **has** the menu-bar widget row — parity); local/no-telemetry (Burrow **matches**).

### Standouts for Burrow (high value ÷ low cost, mostly reusing our infra)
1. **Per-process watchdog with actions (E)** + **Shortcuts/automation on events (L)** — biggest ask, strong fit with Burrow's alert engine + actuating direction; ProcessSpy is hesitant to build it.
2. **Per-process network column (G)** — almost free (NetUsage exists); a thing ProcessSpy explicitly won't do.
3. **Rich inspector panel (A) + extra metrics (M)** — turns Burrow's shallow process list into a real inspector; reuses BinaryIntegrity/ProcessOrigin from the Mole PRD.
4. **Process tree view (B)** and **predicate filters + saved tabs (F)** — the "power user" depth.
5. Cheap wins: **suspend/resume (I)**, **per-process sparkline (D)**, **open-files reveal (J)**, **export (N)**.

### Notes / cautions
- This is a coherent **"deepen Status into a real process inspector"** epic — overlaps the Mole-PRD's ProcessOrigin + BinaryIntegrity (don't duplicate; extend them into the inspector).
- Keep it honest/local (matches Burrow's stance). Per-process disk/QoS/page-ins are all unprivileged `proc_pidinfo` reads — no signing needed.
- Where ProcessSpy gates things behind paid (history export, env-vars/entitlements inspector), Burrow is open-core — these can be free.

---

## 2. Hotspot Guide — hotspotguide.app (captive-portal Wi-Fi rescue for travelers)

The connectivity app our **Get Online** pane was already modeled on (deep-researched earlier; the checks + one-click fixes are built). $6.99 MAS, **sandboxed** — which is its ceiling: it can only deep-link to Settings, never actually fix anything. **Burrow already beats it on the fixes** (real one-click Flush DNS / Renew DHCP via the privilege broker). So this capture is only the **net-new layer** the screenshots reveal beyond our current Get Online.

### Already built in Burrow's Get Online (do NOT re-add)
The 9 device-side checks (Private Relay / VPN / proxy / custom DNS / MDM / gateway / captive-portal / reachability), Open-Settings deep-links, Open Login Page, per-item "recheck", and — where we **exceed** it — actual one-click Flush DNS / Renew DHCP.

### Net-new → Burrow mapping

**A. ⭐ Curated venue/airline/hotel tips database** — auto-detect the venue by SSID → show **known issues + bypass tips** ("Hilton properties run older portal software that blocks encrypted DNS; Honors members can bypass with their credentials"). Covers hotels (Hilton, Marriott) + airlines (Delta Fly-Fi, United, American, Southwest, Alaska, JetBlue, Spirit). Burrow: **new**. This is the **content moat** — curated knowledge, not code. Open-core angle: ship a small curated list, make it **community-extensible** (a JSON others can PR) — turns their static asset into our growing one. *Leverage:* SSID via CoreWLAN+Location (see D).

**B. ⭐ Connection History** — per-attempt log: SSID, timestamp, success/fail, **measured speed (Mbps)**, and the **failure reason** (captive portal required / login page unreachable / no internet access), expandable + clearable. "Know which lounge has the fastest Wi-Fi." Burrow: **new** (we have a SQLite history DB for system metrics → reuse it for connection events). *Leverage:* DB + the Get Online probe results we already compute.

**C. Public Wi-Fi mode vs Home mode** toggle — Public = the rescue checklist; Home = network details + surrounding-networks scan (WiFi-Explorer-lite). Burrow: **new** (small — a mode switch over existing + new Network Info).

**D. Network Info / surrounding-networks scan** — per visible network: **RSSI / signal, channel, channel-congestion, security**; plus current SSID/IP/gateway/DNS. Burrow: **partial** (we already show IP/gateway/DNS in Get Online; SSID/signal/channel scan needs **CoreWLAN + Location permission** — already flagged *deferred* in the Mole PRD). This single permission unlocks A (SSID detect), C, and D.

**E. Speed test (done right)** — throughput **+ packet loss + jitter** to distinguish "slow" from "flaky." Burrow: **new**. Note: Hotspot Guide's one-stream Cloudflare test reads badly low (user feedback: 37 Mbps vs real 2.5 Gbps) → if we build it, **multi-stream** (my earlier research flagged single-stream undercounts). Pairs with B (record the speed per attempt).

**F. Offline troubleshooting Guides** — readable with **zero connectivity** (Private Relay / VPN / DNS / MDM / captive-portal basics, "slow vs flaky", internet-sharing tether). Burrow: **new**. Bundled markdown; cheap, high trust-value (the app works when the internet doesn't).

**G. Lifetime stats** — "N networks · M checks run · K portals fixed." Burrow: **new**, cheap (we already persist; just count).

**H. Sequential animated check run** with live per-check status ("Checking… / Waiting… / detected"). Burrow: **partial** (we run checks; match the staged live presentation).

**I. Per-SSID credential autofill** (keychain: name/email/loyalty #, autofill on return) — Burrow: **new but niche**; only if we add a portal browser. Lower priority.

### Standouts for Burrow
1. **Venue/airline tips DB (A)** + **Connection History with speeds & failure reasons (B)** — the two things that make Get Online feel like a *travel companion* rather than a diagnostic. A is a defensible content asset; make it community-extensible.
2. **Network Info / nearby-networks + SSID (D)** — one CoreWLAN+Location permission unlocks venue auto-detect, Home mode, and the scanner. Decide if we want that permission (Mole PRD currently defers it).
3. **Speed test + jitter/loss (E)** and **offline guides (F)** — round out the "rescue kit."
4. Cheap polish: **lifetime stats (G)**, **staged check animation (H)**.

### Notes
- **Strategic position:** combine *our* real fixes (not sandboxed) + their venue DB + history + speed test + offline guides → Burrow's Get Online becomes strictly better than Hotspot Guide. The only thing gating the travel-companion half is the **CoreWLAN+Location** decision.
- Don't duplicate the Mole-parity PRD's connectivity items — this **extends** Get Online; fold A–H into that pane's roadmap.
- All of this is unsigned/sandbox-free work (CoreWLAN+Location is a normal permission prompt, not Developer ID).
