<div align="center">

<img src="docs/icon.png" alt="Brew Manager icon" width="128" height="128">

# Brew Manager

**A native macOS app for managing Homebrew.**

[![CI](https://github.com/Ekanto/brew-manager-gui/actions/workflows/ci.yml/badge.svg)](https://github.com/Ekanto/brew-manager-gui/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

</div>

Brew Manager never reimplements Homebrew logic. It runs your installed `brew`
executable, consumes its structured JSON output where available, and shows you
the real command and the real output for every action it performs.

Homebrew stays the source of truth — this is a window onto it, not a
replacement for it.

## Requirements

- macOS 14 (Sonoma) or later
- [Homebrew](https://brew.sh) installed
- Swift 6 toolchain (Xcode or Command Line Tools) — only needed to build

## Install

There is no prebuilt release yet, so build the disk image yourself. It takes
about a minute and needs no Xcode project:

```bash
git clone https://github.com/Ekanto/brew-manager-gui.git
cd brew-manager-gui
./Scripts/build-dmg.sh
open build/BrewManager-1.0.0.dmg
```

Then drag **BrewManager.app** onto the **Applications** folder in the window
that opens, eject the disk image, and launch Brew Manager from Launchpad,
Spotlight or Applications.

### First launch

This build is signed ad-hoc rather than with a paid Apple Developer ID, so
macOS may report that the developer "cannot be verified". To get past it once:

- Right-click (or Control-click) the app and choose **Open**, then confirm; or
- Open **System Settings → Privacy & Security** and click **Open Anyway**.

If you moved the DMG between machines, macOS may also have flagged it as
quarantined. Clear that with:

```bash
xattr -dr com.apple.quarantine /Applications/BrewManager.app
```

### Uninstall

```bash
rm -rf /Applications/BrewManager.app
```

## Features

| Section | What it does |
| --- | --- |
| Dashboard | Homebrew health, package counts and quick actions |
| Packages | Browse, search, inspect, upgrade, reinstall, pin and uninstall formulae and casks |
| Discover | Search the whole Homebrew catalogue and install packages you do not have yet |
| Updates | Review outdated packages and upgrade individually or in bulk |
| Services | Start, stop and restart Homebrew services |
| Taps | Browse, add and remove third-party repositories |
| Brewfile | Export, check and apply Brewfiles via Homebrew Bundle |
| Maintenance | Purge the download cache, run cleanup, remove orphans and run `brew doctor` |
| History | Every command that was run, with exit code, duration and output |

Destructive actions always require a confirmation, and cleanup tasks offer a
dry-run preview first so you can see exactly what would be removed.

### Beyond the basics

- **Menu bar item** — outdated count at a glance, with actions to open the app,
  check for updates or upgrade everything. Hide it in Settings if you prefer.
- **Background update checks** — Brew Manager polls for outdated packages on an
  interval you choose and posts a notification only when something is *newly*
  outdated, so an unchanged machine stays silent.
- **Greedy cask updates** — plain `brew outdated` ignores casks that
  auto-update themselves. Enable *Include auto-updating casks* in Settings to
  surface those too.
- **Uninstall safety** — before uninstalling, Brew Manager asks Homebrew what
  else depends on the package and warns you if removing it would break things.
- **Stale cask repair** — dragging an app to the Trash leaves Homebrew still
  tracking it, which makes every later `brew upgrade` fail with *"It seems the
  App source ... is not there"*. Brew Manager detects this on the Updates screen
  and offers one click to either reinstall the app or forget the record.
- **Disk usage** — see how much space each package occupies and sort by size to
  find what is worth removing.
- **Persistent history** — command history survives relaunches instead of
  disappearing when you quit.
- **Serialised operations** — only one mutating `brew` command runs at a time,
  queued in order, so concurrent actions can never corrupt Homebrew's state.
- **Reduce transparency** — blurred surfaces become solid when either macOS or
  the app preference asks for it.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘K` | Command palette |
| `⌘R` | Refresh the current section |
| `⌘⇧U` | Check for updates |
| `⌘1`–`⌘9` | Jump to a sidebar section |

## How it works

Brew Manager is a plain SwiftPM package with **no third-party dependencies and
no Xcode project**. `Scripts/build-app.sh` assembles the `.app` bundle by hand,
including an `Info.plist` and an icon that is generated from code.

```
Sources/BrewManager/
  App/          App entry point, AppState, preferences, menu bar, commands
  Components/   Reusable SwiftUI views and the Theme
  Features/     One folder per sidebar section, each a View + ViewModel
  Models/       Value types and their parsing/classification logic
  Services/     The Homebrew wrapper, process runner and persistence
  Utilities/    Small helpers (logging, formatting, validation)
```

Three decisions are worth knowing about, each the result of a real bug:

- **Commands are serialised.** Making `HomebrewService` an `actor` is not
  enough, because an actor suspends at every `await` and lets two `brew`
  commands interleave. A FIFO gate inside `runCommand` serialises everything
  that mutates state, while read-only commands stay concurrent.
- **Non-zero does not always mean failure.** `brew search` exits `1` when it
  finds nothing and `brew doctor` exits non-zero for advisory warnings, so both
  are treated as normal results.
- **Parsed output is untrusted.** A package name recovered from Homebrew's text
  is only used after being confirmed against the installed list, so it can
  never become an arbitrary command argument.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full set, and
[docs/SPEC.md](docs/SPEC.md) for the original product specification.

## Development

```bash
swift build                      # compile
swift test                       # unit tests (needs a full Xcode toolchain)
./Scripts/build-app.sh release   # produce build/BrewManager.app
./Scripts/build-dmg.sh           # produce build/BrewManager-<version>.dmg
```

The unit tests are wrapped in `#if canImport(XCTest)` so the package still
builds with a Command Line Tools–only install, where XCTest is missing. On such
a machine `swift test` reports success without running anything; CI uses a full
Xcode toolchain, so that is where the tests really execute.

Run the app from the bundle (`open build/BrewManager.app`) rather than with
`swift run`. A bare SwiftPM executable has no `Info.plist`, so macOS treats it
as a background-only process whose windows can never become key — which means
text fields receive no keyboard input.

### Scripts

| Script | Purpose |
| --- | --- |
| `Scripts/build-app.sh` | Builds and assembles the `.app` bundle, then ad-hoc signs it |
| `Scripts/build-dmg.sh` | Builds the app and wraps it in a drag-to-install disk image |
| `Scripts/make-icon.swift` | Regenerates `Resources/AppIcon.icns` from code |
| `Scripts/notarize.sh` | Signs with a Developer ID and notarises with Apple (needs your account) |

### Distributing without the Gatekeeper warning

`Scripts/notarize.sh` produces a disk image that installs cleanly on any Mac,
but it needs credentials that cannot be checked into the repository: a paid
Apple Developer account, a *Developer ID Application* certificate, and a
`notarytool` keychain profile. The script's header documents the one-time setup.
Once that exists:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./Scripts/notarize.sh
```

## Contributing

Issues and pull requests are welcome — please read
[CONTRIBUTING.md](CONTRIBUTING.md) first, particularly the rule that Brew
Manager never reimplements Homebrew logic.

## License

[MIT](LICENSE) © Umar

Brew Manager is an independent project and is not affiliated with or endorsed
by the Homebrew project.
