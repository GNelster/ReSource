# ReSource

A macOS terminal tool for auditing startup items, reclaiming disk space, monitoring memory, and checking battery health. Built for people who want to know what's running on their machine and clean it up without installing a GUI app.

![ReSource](screenshot.png)

## Features

### Doctor
Runs a quick health check across all domains and surfaces the biggest wins in one view: disk usage, cleanable cache totals by category, dead startup entries, and battery health. Ends with an action menu so you can jump straight into `clean` or `startup`.

### Disk
Surfaces what `du`-based tools miss: APFS purgeable space, local Time Machine snapshot sizes, and a breakdown of your home directory sorted by size.

### Startup
Scans LaunchAgents, LaunchDaemons, and modern login items (via `sfltool dumpbtm` for apps registered with `SMAppService`). Flags "dead" entries — plists that point to executables that no longer exist. Navigate the list, select items, and delete them to Trash with `⌫`. System-owned items are moved via `sudo`. Login items without a backing plist show a reminder to use System Settings.

### Clean
Scans known-safe cache and artifact locations and shows how much space each one takes. All items are pre-selected — deselect anything you want to keep, then `⌫` to move the rest to Trash.

Scanned locations:
- Xcode DerivedData (per-project)
- Xcode Device Support (iOS, tvOS, watchOS, xrOS)
- Unavailable iOS Simulators
- Simulator & CoreSimulator logs
- Crash & diagnostic reports
- Homebrew download cache
- npm, Yarn, pnpm, pip caches
- Rust / Cargo cache (`~/.cargo/registry` and `~/.cargo/git`)
- Gradle, Maven, CocoaPods, Swift Package Manager caches
- Browser caches (Safari, Chrome, Firefox, Arc, Brave, Edge)
- Old Downloads — files in `~/Downloads` older than a configurable threshold (default: 1 year)
- App Leftovers — orphaned support files, containers, and preferences from apps no longer installed
- Dead Agent Leftovers — library remnants cross-referenced with dead LaunchAgent entries found by `resource startup`

All scans run in parallel for fast results. Settings (download age threshold, excluded paths) are saved to `~/.config/resource/config.json` and editable with `resource config`.

### Memory
Shows a live breakdown of system RAM and top processes sorted by usage — same categories as Activity Monitor (Used, App, Wired, Compressed, Cached, Free).

### Battery
Shows battery health (maximum capacity %), cycle count, current charge, and charging status. Warns when cycle count is high or the condition requires service. Gracefully skips on desktop Macs.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 (Xcode 16+)

## Install

**Homebrew (recommended)**

```bash
brew install GNelster/resource/resource
```

Or as two steps:
```bash
brew tap GNelster/resource
brew install resource
```

**Build from source**

```bash
git clone https://github.com/GNelster/ReSource.git
cd ReSource
swift build -c release
sudo cp .build/release/ReSource /usr/local/bin/resource
```

Then just type `resource` in any terminal window.

## Usage

```
resource           # interactive menu
resource doctor    # quick health check
resource disk      # analyze disk usage
resource startup   # audit startup items
resource clean     # reclaim cache space
resource memory    # show RAM by process
resource battery   # show battery health
resource config    # view and edit settings
```

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move cursor |
| `↵` or `Space` | Toggle selection |
| `⌫` (Delete) | Move selected items to Trash |
| `Esc` or `q` | Back / quit |

## Built with

- [swift-argument-parser](https://github.com/apple/swift-argument-parser)
- Swift 6, macOS 14+
- No other dependencies

---

Built by [Nelcore Studios](https://portfolio.nelsonarrangements.com)
