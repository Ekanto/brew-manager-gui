# BrewManager for macOS — Product & Engineering Specification

## 1. Product vision

**BrewManager** is a lightweight, native macOS GUI for managing Homebrew formulae, casks, updates, services, taps, cleanup, and Brewfiles.

The app must **not reimplement Homebrew's package-management logic**. Homebrew remains the source of truth. BrewManager is a native SwiftUI frontend that invokes the installed `brew` executable, consumes structured JSON where available, and presents the results in a polished macOS interface.

Primary goals:

- Make Homebrew understandable without requiring Terminal.
- Make updates safe and transparent.
- Show exactly what Homebrew is doing.
- Provide useful package/service details without overwhelming the user.
- Stay lightweight and native on Apple Silicon.
- Never silently perform destructive operations.
- Remain functional even when Homebrew adds commands/options in future versions.

Target platform: **macOS 14+**, Apple Silicon first.

---

# 2. Existing-product positioning

There are already capable Homebrew GUIs, especially Cork, Applite, Brewery, Brew Browser, and Taphouse.

Therefore BrewManager should NOT be positioned as "the first Homebrew GUI."

Its differentiators should be:

1. **Excellent update center**
   - Clear distinction between `brew update` and package upgrades.
   - Show pending formula/cask updates.
   - Show pinned packages.
   - Show what will change before an upgrade.
   - Per-package and bulk upgrade.

2. **Transparent operations**
   - Every operation has a live output panel.
   - Show the exact Homebrew command being executed.
   - Capture stdout/stderr.
   - Show exit status and duration.
   - Preserve operation history.

3. **Safe package management**
   - Confirmation for uninstall, cleanup, zap, reset, etc.
   - Dry-run where Homebrew supports it.
   - Never run destructive commands with `sudo` automatically.
   - Explain when macOS authentication is required.

4. **Excellent services management**
   - Start/stop/restart services.
   - Show running/stopped state.
   - Show launch-at-login/boot registration.
   - Open service logs where practical.

5. **Brewfile / machine setup**
   - Export installed state to Brewfile.
   - Import/restore Brewfile.
   - Compare current machine against a Brewfile.
   - Preview changes before applying them.

6. **Native macOS experience**
   - SwiftUI.
   - Sidebar navigation.
   - Native search.
   - Menu-bar quick access.
   - Notifications.
   - Dark/light appearance.
   - Apple Silicon optimized.

---

# 3. UX concept

## Main window

```text
┌──────────────────────────────────────────────────────────────┐
│ BrewManager                                      ● Healthy   │
├────────────────┬─────────────────────────────────────────────┤
│                │                                             │
│  Dashboard     │  Homebrew                                  │
│                │  v5.x.x                                    │
│  Packages      │                                             │
│  Updates   7   │  ┌──────────┐ ┌──────────┐ ┌────────────┐  │
│  Services      │  │ Formulae │ │  Casks   │ │  Updates   │  │
│  Taps          │  │    47    │ │    23    │ │     7      │  │
│                │  └──────────┘ └──────────┘ └────────────┘  │
│  Brewfile      │                                             │
│                │  Last checked: 2 minutes ago               │
│  History       │  [ Check for Updates ] [ Update All ]      │
│                │                                             │
│  Settings      │  Recent activity                            │
│                │  ✓ Updated Homebrew                         │
│                │  ✓ Upgraded ffmpeg                          │
│                │  ! node upgrade failed                      │
│                │                                             │
└────────────────┴─────────────────────────────────────────────┘
```

## Sidebar

- Dashboard
- Packages
- Updates
- Services
- Taps
- Brewfile
- History
- Settings

Badge counts should appear beside Updates and optionally Services.

---

# 4. Dashboard

Dashboard should answer three questions immediately:

1. Is Homebrew healthy?
2. Are updates available?
3. What happened recently?

Cards:

### Homebrew

- Homebrew version
- Prefix
- Architecture
- macOS version
- Last update/check time

### Packages

- Installed formulae
- Installed casks
- Total installed

### Updates

- Outdated formulae
- Outdated casks
- Pinned packages
- [Update All]

### Disk / cleanup

- Approximate Homebrew disk usage
- Potential cleanup candidates
- [Analyze Cleanup]

Do not make cleanup destructive from the dashboard.

---

# 5. Packages screen

Use a segmented control:

**All | Formulae | Casks**

Each row:

```text
┌──────────────────────────────────────────────────────────┐
│ ● node                                      22.18.0      │
│   JavaScript runtime                                     │
│   Formula • /opt/homebrew                                │
│                                              [•••]       │
└──────────────────────────────────────────────────────────┘
```

Context actions:

- Show Details
- Upgrade
- Reinstall
- Uninstall
- Pin
- Unpin
- Open Homepage
- Show Dependencies
- Show Dependents
- Open in Terminal

Search should filter instantly.

Optional columns/detail fields:

- Installed version
- Latest version
- Type
- Tap
- Size
- Installed date if available
- Pinned state
- Dependencies
- Dependents
- Homepage
- License

---

# 6. Package detail view

Example:

```text
Node.js

22.18.0
Latest: 22.18.0

Formula
Installed
Not pinned

──────────────────────────────

Description
JavaScript runtime

Homepage
https://nodejs.org/

Dependencies
icu4c
libuv
...

Dependents
...

Installation
/opt/homebrew/Cellar/node/22.18.0

──────────────────────────────

[ Upgrade ] [ Reinstall ] [ Uninstall ]
```

Use `brew info --json=v2` for rich metadata when possible.

Do not scrape Homebrew web pages.

---

# 7. Updates screen

This is the core feature.

```text
Updates available — 7

Formulae (5)
☑ node       22.17.0 → 22.18.0
☑ ffmpeg     8.0 → 8.1
☐ python     3.13.6 → 3.13.7
☑ git        2.50 → 2.51
☐ openssl    3.5.1 → 3.5.2

Casks (2)
☑ IINA       1.4.0 → 1.4.1
☑ VLC        3.0.21 → 3.0.22

[ Select All ] [ Update Selected ]

Last Homebrew metadata update: 4 min ago
```

Before updating, show a preview:

```text
Upgrade 5 packages?

node       22.17.0 → 22.18.0
ffmpeg     8.0 → 8.1
git        2.50 → 2.51
...

Homebrew may also upgrade required dependencies.

[Cancel] [Run Upgrade]
```

For the initial version, execute one Homebrew upgrade operation rather than trying to manually orchestrate dependency ordering.

---

# 8. Operations console

Every command execution should have a reusable operation sheet.

```text
┌──────────────────────────────────────────────────────────┐
│ Updating packages                                  ✕    │
├──────────────────────────────────────────────────────────┤
│ Command                                                  │
│ $ /opt/homebrew/bin/brew upgrade node ffmpeg git         │
│                                                          │
│ Output                                                   │
│                                                          │
│ ==> Upgrading node                                       │
│ ==> Downloading...                                       │
│ ==> Installing...                                        │
│ 🍺 node 22.18.0                                          │
│                                                          │
│ ████████████████████████████████  100%                   │
│                                                          │
│ Completed in 28.4 seconds                    Exit: 0     │
│                                                          │
│ [Copy Output] [Open Full Log] [Done]                     │
└──────────────────────────────────────────────────────────┘
```

The operation engine should stream output while the command runs.

Do not block the UI thread.

---

# 9. Services screen

Use:

`brew services list --json`

Display:

```text
Service        Status       Run At Login
─────────────────────────────────────────
postgresql    ● Running     Yes
redis         ● Running     Yes
nginx         ○ Stopped     No
```

Actions:

- Start
- Stop
- Restart
- Open logs
- Refresh

Use Homebrew's service commands rather than manipulating launchd plist files directly.

---

# 10. Taps

Display:

```text
homebrew/core
homebrew/cask
custom/tap
```

Actions:

- View
- Update
- Untap

Untapping must require confirmation and explain that packages belonging to the tap may be affected.

---

# 11. Brewfile

This should be a major feature.

Sections:

### Current machine

[Export Brewfile]

### Existing Brewfile

[Open Brewfile]

### Compare

```text
Brewfile comparison

Installed but not in Brewfile
  + ffmpeg
  + jq

In Brewfile but not installed
  - redis
  - wget

Version differences
  ~ node

[Apply Brewfile] [Export Updated Brewfile]
```

Use Homebrew Bundle where possible instead of implementing Brewfile parsing from scratch.

Relevant commands include:

- `brew bundle`
- `brew bundle check`
- `brew bundle add`
- `brew bundle dump`

---

# 12. Cleanup

Cleanup needs a deliberately cautious UX.

First run a dry analysis:

```text
Cleanup analysis

Old formula versions          1.8 GB
Downloaded caches             420 MB
Unused dependencies           230 MB

Potential reclaimable space   2.45 GB

[View Details] [Run Cleanup]
```

Never present "Delete everything" as the primary action.

Prefer Homebrew's own cleanup behavior.

Support:

- `brew cleanup --dry-run`
- `brew cleanup`

---

# 13. Doctor / diagnostics

Add:

**Diagnostics**

Actions:

- Run `brew doctor`
- Show `brew config`
- Show Homebrew version
- Show prefix
- Copy diagnostic report

Example:

```text
System
Apple Silicon
macOS 15.x

Homebrew
5.x.x
/opt/homebrew

Diagnostics
✓ Homebrew installation
✓ Permissions
✓ Git repository
⚠ 1 warning

[View Full Output]
```

Do not attempt to automatically "fix" `brew doctor` warnings in MVP.

---

# 14. Menu bar

Optional after MVP.

Menu-bar icon:

```text
🍺 BrewManager

7 updates available

[View Updates]
[Update All]
──────────────
[Open BrewManager]
[Quit]
```

Menu-bar update should be opt-in.

Never silently upgrade packages.

---

# 15. Notifications

Optional setting:

- Notify when updates are available
- Notify only when Homebrew itself has an update
- Notify after failed operation
- Notify after successful upgrade

Default:

**Notify on failed operations: ON**

**Automatic upgrades: OFF**

---

# 16. Architecture

Recommended stack:

- Swift 6+
- SwiftUI
- Observation framework / `@Observable`
- Foundation `Process`
- Swift Concurrency (`async/await`, `AsyncStream`)
- OSLog
- UserNotifications
- AppKit only where SwiftUI needs help

Architecture:

```text
┌──────────────────────────────┐
│          SwiftUI             │
│ Views / Sheets / Navigation  │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│        View Models            │
│ Dashboard / Packages / etc. │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│       HomebrewService         │
│ discovery / commands / JSON  │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│       ProcessRunner           │
│ async process + stdout/stderr│
└──────────────┬───────────────┘
               │
               ▼
          /opt/homebrew/bin/brew
```

Important separation:

- `ProcessRunner` knows how to execute processes.
- `HomebrewService` knows Homebrew commands.
- View models know application state.
- Views only display state and trigger actions.
- JSON decoding lives in dedicated models.

---

# 17. Homebrew discovery

GUI applications may not inherit the user's interactive shell PATH.

Do NOT assume `brew` can be found by simply calling `brew`.

Search in this order:

1. `/opt/homebrew/bin/brew`
2. `/usr/local/bin/brew`
3. `brew` resolved from a controlled PATH
4. Ask the user to locate Homebrew if none is found.

The primary Apple Silicon path should be `/opt/homebrew/bin/brew`.

After discovery, store the resolved executable path for the session.

Do not ask the user for sudo credentials inside the application.

---

# 18. Process execution

Create a reusable abstraction:

```swift
struct BrewCommand {
    let arguments: [String]
}

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: Duration
}

protocol ProcessRunning {
    func run(
        executable: URL,
        arguments: [String]
    ) async throws -> ProcessResult
}
```

For streaming:

```swift
struct ProcessEvent {
    enum Stream {
        case stdout
        case stderr
    }

    let stream: Stream
    let text: String
}
```

Use `Process` with pipes.

Do not execute commands through:

```text
/bin/sh -c "..."
```

when direct argument passing is possible.

This avoids quoting and injection problems.

---

# 19. Homebrew commands for MVP

Use structured output whenever available.

### Detect

```bash
brew --version
brew --prefix
brew config
```

### Installed formulae

```bash
brew list --formula --versions
```

### Installed casks

```bash
brew list --cask --versions
```

### Outdated

```bash
brew outdated --json=v2
```

### Rich package information

```bash
brew info --json=v2 <package>
```

### Update metadata

```bash
brew update
```

### Upgrade

```bash
brew upgrade
brew upgrade <package>
```

### Uninstall

```bash
brew uninstall <package>
```

### Reinstall

```bash
brew reinstall <package>
```

### Pin

```bash
brew pin <package>
```

### Unpin

```bash
brew unpin <package>
```

### Services

```bash
brew services list --json
brew services start <formula>
brew services stop <formula>
brew services restart <formula>
```

### Cleanup

```bash
brew cleanup --dry-run
brew cleanup
```

### Diagnostics

```bash
brew doctor
brew config
```

### Bundle

```bash
brew bundle dump
brew bundle check
brew bundle
```

Homebrew's current documentation confirms JSON support for querying package information and `brew outdated --json=v2`, as well as JSON output for services. Use the installed Homebrew version as the ultimate compatibility authority.

---

# 20. Data models

Suggested models:

```swift
enum PackageType {
    case formula
    case cask
}

struct Package: Identifiable {
    let id: String
    let name: String
    let type: PackageType
    let installedVersions: [String]
    let currentVersion: String?
    let latestVersion: String?
    let description: String?
    let homepage: URL?
    let tap: String?
    let isPinned: Bool
}

struct OutdatedPackage: Identifiable {
    let id: String
    let name: String
    let type: PackageType
    let installedVersion: String
    let latestVersion: String
}

struct BrewService: Identifiable {
    let id: String
    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
}
```

Keep models independent of raw Homebrew JSON schemas where practical.

---

# 21. Error handling

Errors should be human-readable.

Instead of:

```text
Process terminated with status 1
```

show:

```text
Upgrade failed

Homebrew exited with code 1.

The package manager reported:

<stderr>

[Copy Error] [Open Terminal]
```

Classify common errors:

- Homebrew not installed
- Permission error
- Network failure
- Package not found
- Package conflict
- User cancellation
- Homebrew command failure
- Invalid JSON / unsupported Homebrew version

Never hide stderr.

---

# 22. Security rules

This app executes package-manager commands, so security is important.

Rules:

1. Never run arbitrary shell strings.
2. Use direct process arguments.
3. Validate package names before passing them to commands.
4. Do not execute user-entered text as shell syntax.
5. Never automatically use `sudo`.
6. Never collect passwords.
7. Show the command before destructive operations.
8. Require confirmation for uninstall, cleanup, untap, reset.
9. Keep logs local.
10. Do not send Homebrew output to external services.
11. No analytics in MVP.
12. Do not require network access except when Homebrew itself needs it.

---

# 23. MVP scope

Build only these first:

### Phase 1 — Foundation

- SwiftUI project
- Homebrew detection
- ProcessRunner
- HomebrewService
- Error model
- Logging
- Basic navigation

### Phase 2 — Dashboard

- Homebrew version
- Prefix
- Formula count
- Cask count
- Update count
- Refresh

### Phase 3 — Packages

- Formula list
- Cask list
- Search
- Package detail
- Uninstall
- Reinstall

### Phase 4 — Updates

- `brew update`
- `brew outdated --json=v2`
- Update list
- Upgrade selected
- Upgrade all
- Streaming console

### Phase 5 — Services

- List services
- Start
- Stop
- Restart

### Phase 6 — Brewfile

- Export
- Check
- Apply

### Phase 7 — Polish

- Notifications
- Menu bar
- History
- Cleanup
- Diagnostics
- Accessibility
- Keyboard shortcuts

---

# 24. Suggested project structure

```text
BrewManager/
├── App/
│   ├── BrewManagerApp.swift
│   └── AppState.swift
│
├── Models/
│   ├── Package.swift
│   ├── BrewService.swift
│   ├── BrewInfo.swift
│   ├── BrewError.swift
│   └── Operation.swift
│
├── Services/
│   ├── HomebrewService.swift
│   ├── ProcessRunner.swift
│   ├── BrewLocator.swift
│   ├── BrewJSONDecoder.swift
│   └── NotificationService.swift
│
├── Features/
│   ├── Dashboard/
│   ├── Packages/
│   ├── Updates/
│   ├── Services/
│   ├── Taps/
│   ├── Brewfile/
│   ├── History/
│   └── Settings/
│
├── Components/
│   ├── PackageRow.swift
│   ├── StatusBadge.swift
│   ├── OperationConsole.swift
│   ├── ConfirmationSheet.swift
│   └── EmptyState.swift
│
├── Utilities/
│   ├── Logger.swift
│   └── Extensions.swift
│
└── Resources/
```

---

# 25. Copilot implementation strategy

Do NOT ask Copilot to build the entire application in one prompt.

Build incrementally.

## Prompt 1 — Foundation

> Create a native macOS SwiftUI application called BrewManager.
>
> Requirements:
> - Swift 6+
> - SwiftUI
> - macOS 14+
> - Apple Silicon first
> - Use Observation where appropriate.
> - Do not use third-party dependencies initially.
> - Create a clean architecture with Models, Services, Features, Components, and Utilities.
> - Implement BrewLocator that detects `/opt/homebrew/bin/brew`, `/usr/local/bin/brew`, and controlled PATH fallback.
> - Implement an async ProcessRunner using Foundation Process and Pipe.
> - Support streaming stdout/stderr using AsyncStream.
> - Never execute shell command strings through `sh -c` when direct argument passing is possible.
> - Add OSLog logging.
> - Create a basic NavigationSplitView with Dashboard, Packages, Updates, Services, Brewfile, History, and Settings placeholders.
> - Make the project compile before proceeding.

## Prompt 2 — Homebrew service

> Implement HomebrewService on top of ProcessRunner.
>
> Add:
> - brew --version
> - brew --prefix
> - brew config
> - brew list --formula --versions
> - brew list --cask --versions
> - brew outdated --json=v2
> - brew info --json=v2 <package>
>
> Parse JSON using Codable.
>
> Keep raw Homebrew JSON models separate from application domain models.
>
> Return typed errors.
>
> Add unit tests for JSON parsing using local fixture strings.
>
> Do not modify UI yet.

## Prompt 3 — Dashboard

> Implement the Dashboard using HomebrewService.
>
> Show:
> - Homebrew version
> - prefix
> - formula count
> - cask count
> - outdated formula count
> - outdated cask count
> - refresh action
>
> Run independent read-only Homebrew commands concurrently where safe.
>
> Never block the main actor.
>
> Add loading, empty, and error states.

## Prompt 4 — Packages

> Implement the Packages feature.
>
> Requirements:
> - Formulae/Casks segmented control
> - Search
> - Package rows
> - Detail view
> - Package metadata
> - Upgrade
> - Reinstall
> - Uninstall
>
> Destructive operations require confirmation.
>
> All commands must stream output into the reusable OperationConsole.

## Prompt 5 — Updates

> Implement the Updates feature.
>
> Use `brew update` followed by `brew outdated --json=v2`.
>
> Display installed and latest versions.
>
> Support:
> - Select all
> - Select individual packages
> - Upgrade selected
> - Upgrade all
>
> Before executing, show a confirmation preview.
>
> Stream Homebrew output live.
>
> Preserve operation result and error details.

## Prompt 6 — Services

> Implement Homebrew Services using:
>
> `brew services list --json`
> `brew services start`
> `brew services stop`
> `brew services restart`
>
> Display service name, status, user, and registration information where available.
>
> Add start/stop/restart actions with live output.

## Prompt 7 — Brewfile

> Implement Brewfile support using Homebrew Bundle.
>
> Support:
> - Export installed state
> - Check Brewfile
> - Apply Brewfile
> - Show a preview where possible
>
> Do not create a custom Brewfile parser unless required.

---

# 26. Testing strategy

Use three layers.

### Unit tests

Test:

- JSON decoding
- Package mapping
- Version mapping
- Error mapping
- BrewLocator
- command argument generation

### Process integration tests

Do not depend on the developer's real Homebrew installation.

Create a fake executable/test runner that returns controlled stdout/stderr and exit codes.

### UI tests

Test:

- Navigation
- Search
- Selecting packages
- Confirmation dialogs
- Update selection
- Error states

---

# 27. Important implementation principle

The application must remain useful if Homebrew changes.

Prefer:

```text
brew command → structured JSON → Codable → domain model
```

Avoid:

```text
brew command → regex over human-readable output → fragile UI
```

Use human-readable output primarily for the live operation console.

---

# 28. Future features

Do not implement these until the core app is stable:

- Menu-bar app
- Scheduled update checks
- Automatic update notifications
- Package health scoring
- Dependency graph visualization
- Disk usage visualization
- Multiple Brew prefixes
- Remote Mac management
- SSH package management
- Homebrew analytics
- AI package explanations
- Package changelog summaries

AI should be optional and off by default.

---

# 29. Definition of done for MVP

BrewManager MVP is complete when a user can:

1. Open the app.
2. Detect an existing Homebrew installation.
3. See Homebrew version and package counts.
4. Browse installed formulae.
5. Browse installed casks.
6. Search packages.
7. View package details.
8. See outdated packages.
9. Run Homebrew update.
10. Upgrade selected packages.
11. Upgrade all packages.
12. See live command output.
13. Install/reinstall/uninstall packages.
14. Start/stop/restart Homebrew services.
15. Export and check a Brewfile.
16. See useful errors when operations fail.
17. Never accidentally execute destructive operations without confirmation.
18. Use the application without needing Terminal for normal Homebrew management.

---

# 30. Recommended first milestone

Do not start with the beautiful UI.

Start with:

```text
BrewLocator
      ↓
ProcessRunner
      ↓
HomebrewService
      ↓
JSON Models
      ↓
Dashboard
```

Once that pipeline works reliably, the rest of the UI becomes comparatively straightforward.

The first successful milestone should be:

**Launch BrewManager → detect `/opt/homebrew/bin/brew` → run `brew --version` → run `brew outdated --json=v2` → display the results.**

That gives the project a solid foundation before adding destructive commands.
