```markdown
# Burrow Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches best practices and workflows for contributing to the Burrow codebase, a Swift project with no detected framework dependencies. You'll learn the repository's coding conventions, how to perform common tasks such as bugfixes and dead code pruning via pull requests, and how to structure your code and commits for consistency.

## Coding Conventions

- **File Naming:**  
  Use PascalCase for all Swift source files.  
  _Example:_  
  ```
  StatusBarController.swift
  CrashReporter.swift
  ```

- **Import Style:**  
  Use relative imports.  
  _Example:_  
  ```swift
  import Foundation
  import Cocoa
  ```

- **Export Style:**  
  Use named exports for classes, structs, and functions.  
  _Example:_  
  ```swift
  public class StatusBarController {
      // ...
  }
  ```

- **Commit Messages:**  
  - Use prefixes such as `fix`, `chore`, or `prune`.
  - Keep messages concise (~63 characters on average).
  _Example:_  
  ```
  fix: resolve crash when opening settings window
  prune: remove unused EventHub and related code
  ```

## Workflows

### Bugfix with Pull Request
**Trigger:** When you need to fix a bug and follow the PR workflow  
**Command:** `/bugfix-pr`

1. Identify and fix a bug in a source file (e.g., `.swift`).
2. Commit the fix with a descriptive message.
   _Example:_
   ```
   fix: prevent crash when toggling HUD
   ```
3. Open a pull request referencing the fix.
4. Merge the pull request, resulting in a merge commit with the same file(s) and referencing the fix.

_Files commonly involved:_
- `macos/Sources/StatusBarController.swift`
- `macos/Sources/CrashReporter.swift`
- `macos/Sources/HUDController.swift`

### Dead Code Prune with Pull Request
**Trigger:** When you want to clean up dead code across the codebase  
**Command:** `/prune-dead-code`

1. Identify dead code using a static analysis tool (e.g., `periphery`).
2. Remove unused declarations from multiple source files.
3. Update or rename files as necessary.
4. Commit all changes with a detailed message.
   _Example:_
   ```
   prune: remove unused Brand, BurrowMark, and MenuBarWidgets
   ```
5. Open a pull request for the code prune.
6. Merge the pull request, resulting in a merge commit with the same files.

_Files commonly involved:_
- `macos/Sources/Brand.swift`
- `macos/Sources/BurrowMark.swift`
- `macos/Sources/EventHub.swift`
- `macos/Sources/MenuBarWidgets.swift`
- `macos/Sources/MoleClient.swift`
- `macos/Sources/SettingsView.swift`
- `macos/Sources/TopNav.swift`

## Testing Patterns

- **Framework:** Unknown (not detected in analysis)
- **File Pattern:** Test files follow the pattern `*Tests.cs`
  - _Note:_ This suggests some cross-platform or legacy code, as `.cs` is a C# extension. Verify and update as needed.
- **General Practice:** Place tests in dedicated files named after the component under test, suffixed with `Tests`.

_Example:_
```
StatusBarControllerTests.cs
```

## Commands

| Command           | Purpose                                 |
|-------------------|-----------------------------------------|
| /bugfix-pr        | Start the bugfix pull request workflow  |
| /prune-dead-code  | Start the dead code pruning workflow    |
```
