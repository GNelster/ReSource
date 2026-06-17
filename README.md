# ReSource

A macOS terminal tool for auditing startup items and reclaiming disk space. Built for people who want to know what's running on their machine and clean it up without installing a GUI app.

![ReSource](screenshot.png)

## Features

### Startup
Scans all launch agents and daemons across user, system, and system daemon locations. Flags "dead" items — plists that point to executables that no longer exist. Navigate the list, select items, and delete them to Trash with `⌫`. System-owned items are moved via `sudo`.

### Clean
Scans known-safe cache and artifact locations and shows how much space each one takes. All items are pre-selected — deselect anything you want to keep, then `⌫` to move the rest to Trash.

Scanned locations:
- Xcode DerivedData (per-project)
- Xcode Device Support (iOS, tvOS, watchOS, xrOS)
- Unavailable iOS Simulators
- Simulator & CoreSimulator logs
- Crash & diagnostic reports
- Homebrew download cache
- npm, Yarn, pip caches
- Browser caches (Safari, Chrome, Firefox, Arc, Brave, Edge)

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 (Xcode 16+)

## Build & Install

```bash
git clone https://github.com/YOUR_USERNAME/ReSource.git
cd ReSource
swift build -c release
sudo cp .build/release/ReSource /usr/local/bin/resource
```

Then just type `resource` in any terminal window.

## Usage

```
resource           # interactive menu
resource startup   # jump straight to startup audit
resource clean     # jump straight to clean
```

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move cursor |
| `↵` or `Space` | Toggle selection |
| `⌫` (Delete) | Move selected items to Trash |
| `Esc` or `q` | Back / quit |

## Running on a Mac without Xcode

If you're installing a pre-built binary on someone else's Mac, macOS will block it because it isn't signed by a known developer. To get around this, right-click the binary in Finder and choose **Open**, then click **Open** again when prompted. After that first approval it runs normally.

Or from Terminal:
```bash
xattr -dr com.apple.quarantine /usr/local/bin/resource
```

## Project structure

```
Sources/ReSource/
  ReSource.swift          # entry point, main menu
  Commands/               # argument-parser subcommands
  Startup/                # launch item scanning and list view
  Clean/                  # cache scanning and list view
  TUI/                    # raw terminal, menu, key reading
  Output/                 # spinner, progress bar, styles
  Utils/                  # shell runner, formatter, prompt
```

## Built with

- [swift-argument-parser](https://github.com/apple/swift-argument-parser)
- Swift 6, macOS 14+
- No other dependencies

---

Built by [Nelcore Studios](https://portfolio.nelsonarrangements.com)
