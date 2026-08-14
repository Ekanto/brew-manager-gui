# Contributing

Thanks for taking an interest in Brew Manager.

## Ground rules

The single most important rule in this codebase:

> **Brew Manager never reimplements Homebrew logic.**

Every action shells out to the user's installed `brew` executable, prefers
Homebrew's structured JSON output (`--json=v2`) over scraping human-readable
text, and shows the real command and its real output. If you find yourself
parsing a version number to decide what Homebrew *would* do, stop and ask
Homebrew instead.

Two consequences worth stating explicitly:

- **Nothing destructive happens without confirmation.** Uninstall, cleanup and
  cask repair all require an explicit confirmation, and cleanup offers a
  `--dry-run` preview first.
- **Failures are explained, not dumped.** When a `brew` command fails, classify
  it in `BrewError` and give the user an action, rather than showing raw stderr
  and leaving them stuck.

## Requirements

- macOS 14 (Sonoma) or later
- [Homebrew](https://brew.sh)
- Swift 6 toolchain

Note that a **Command Line Tools–only install cannot run the unit tests**,
because XCTest is not present. The tests are wrapped in
`#if canImport(XCTest)` so the package still builds; they compile and run in
CI, which uses a full Xcode toolchain.

## Getting started

```bash
git clone https://github.com/Ekanto/brew-manager-gui.git
cd brew-manager-gui
swift build
./Scripts/build-app.sh release
open build/BrewManager.app
```

### Do not use `swift run`

A bare SwiftPM executable has no `Info.plist`, so macOS registers it as a
background-only process. Such a process can draw a window and receive mouse
events, but its windows can never become key — which means **text fields
silently receive no keyboard input**. Always launch the assembled `.app`
bundle. `AppDelegate` also promotes the activation policy to `.regular` to
guard against this.

## Project layout

```
Sources/BrewManager/
  App/          App entry point, AppState, preferences, menu bar, commands
  Components/   Reusable SwiftUI views and the Theme
  Features/     One folder per sidebar section, each a View + ViewModel
  Models/       Value types and their parsing/classification logic
  Services/     The Homebrew wrapper, process runner and persistence
  Utilities/    Small helpers (logging, formatting, validation)
Scripts/        Icon generation, .app assembly, DMG, notarisation
Tests/          Unit tests for pure parsing and locating logic
docs/           The original product specification
```

Features follow a consistent shape: a `@MainActor @Observable` view model owns
all state and talks to `HomebrewService`, and the view is a thin rendering of
that state.

## Architectural notes

Please read these before changing the service layer — each one exists because
of a bug that was hit in practice.

- **`actor` alone does not serialise subprocesses.** An actor suspends at every
  `await`, so two `brew` commands can interleave. `OperationGate` provides an
  explicit FIFO mutex, applied centrally inside `HomebrewService.runCommand` by
  inspecting the subcommand — deliberately *not* at each call site, so a new
  command cannot forget to serialise. Read-only commands are not gated.
- **Not every non-zero exit is a failure.** `brew search` exits `1` when it
  finds nothing, and `brew doctor` exits non-zero for purely advisory warnings.
  Treat both as normal results.
- **Homebrew prints noise around JSON.** `brew outdated --greedy --json=v2`
  emits a download banner before the JSON, so output is sliced from the first
  `{` rather than parsed whole.
- **Anything parsed from output is untrusted.** A package name recovered from
  Homebrew's text is only used after it is confirmed against the installed
  list, so parsed text can never become an arbitrary command argument.

### SwiftUI hazards

- Pass the item to an alert with `presenting:`. An `isPresented` binding clears
  the pending state *before* the confirm button's `Task` runs.
- Use `@Bindable` with `.sheet(item:)`. A computed `Binding` over an
  `@Observable` breaks dependency tracking.
- Give each detail view root
  `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)`, or the
  layout collapses.

## Style

- Follow the conventions already in the file you are editing.
- Comment *why*, not *what*. The existing comments explain non-obvious
  Homebrew behaviour and past bugs; keep that bar.
- No new third-party dependencies without discussion. The app currently has
  none, which is why it builds with plain SwiftPM and no Xcode project.

## Before opening a pull request

```bash
swift build        # must be clean, no warnings
swift test         # runs only with a full Xcode toolchain
./Scripts/build-app.sh release
```

Then actually launch the app and exercise the screen you changed against a
real Homebrew installation. Describe in the PR what you ran and what you saw.
