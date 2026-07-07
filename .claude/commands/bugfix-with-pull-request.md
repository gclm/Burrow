---
name: bugfix-with-pull-request
description: Workflow command scaffold for bugfix-with-pull-request in Burrow.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /bugfix-with-pull-request

Use this workflow when working on **bugfix-with-pull-request** in `Burrow`.

## Goal

Implements a bugfix in a source file, then merges it via a pull request with a merge commit.

## Common Files

- `macos/Sources/StatusBarController.swift`
- `macos/Sources/CrashReporter.swift`
- `macos/Sources/HUDController.swift`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Identify and fix a bug in a source file (e.g., .swift).
- Commit the fix with a descriptive message.
- Open a pull request referencing the fix.
- Merge the pull request, resulting in a merge commit with the same file(s) and referencing the fix.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.