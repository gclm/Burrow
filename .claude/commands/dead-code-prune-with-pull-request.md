---
name: dead-code-prune-with-pull-request
description: Workflow command scaffold for dead-code-prune-with-pull-request in Burrow.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /dead-code-prune-with-pull-request

Use this workflow when working on **dead-code-prune-with-pull-request** in `Burrow`.

## Goal

Removes dead code from multiple source files, typically flagged by a tool, and merges via a pull request.

## Common Files

- `macos/Sources/Brand.swift`
- `macos/Sources/BurrowMark.swift`
- `macos/Sources/EventHub.swift`
- `macos/Sources/MenuBarWidgets.swift`
- `macos/Sources/MoleClient.swift`
- `macos/Sources/SettingsView.swift`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Identify dead code using a static analysis tool (e.g., periphery).
- Remove unused declarations from multiple source files.
- Update or rename files as necessary.
- Commit all changes with a detailed message.
- Open a pull request for the code prune.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.