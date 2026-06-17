# ReSource — Project Brief

A macOS CLI tool that shows what's actually consuming a Mac's resources — disk space, startup/background processes, and leftover files — and lets you safely reclaim them. Built as a personal/portfolio project, not a commercial product.

## Motivation

Built as a deliberate change of pace from a few stalled personal projects (a focus-timer app that's a saturated market, a low-traction app, a tournament app waiting on third-party API access). The goal here is something where progress is entirely self-directed: no external gatekeepers, no downloads-as-validation, just build it, learn from it, ship it when it's done.

## Competitive landscape (be honest about this)

This space is not empty, and that's fine — the goal is the build/learning experience, not a market gap:

- **Disk usage TUIs**: `ncdu`, `gdu`, `dust`, and `lintree` already do interactive/treemap-style terminal disk visualization well.
- **macOS cleaners**: `PureMac` and `Pearcleaner` are open-source, Swift-based cache/leftover-file cleaners with a "trash, never rm" safety philosophy. `Mole` is a CLI tool that already combines disk analysis, cache cleaning, and app uninstall-with-leftover-removal in one binary.
- **Login item auditing**: Objective-See's `KnockKnock` already audits background/login items from a security angle.

**The differentiation worth keeping**: none of the above fully unify "what's been left behind" across all three domains — disk space, startup items, *and* orphaned app remnants — with deep macOS-specific awareness (APFS purgeable space, local Time Machine snapshots, System Data composition) that plain `du`-based tools can't see because that data lives at the volume level, not the file level. Cross-referencing a dead LaunchAgent (pointing to an app that no longer exists) against its matching orphaned cache/support files is a genuinely underused connection.

## Tech stack

- **Swift**, but as a plain command-line tool, not a GUI app — a Swift Package with an executable target. No Xcode app project, no `.app` bundle, no Info.plist required.
  - `swift package init --type executable` to scaffold.
  - `swift build -c release` produces a single binary; copy to `/usr/local/bin` to run as `resource` from anywhere.
- **Apple's `swift-argument-parser`** for subcommand structure (`resource disk`, `resource startup`, `resource clean`), flags, and auto-generated `--help`.
- **ConsoleKit** (Vapor team) for styled output, progress/activity indicators, and structured prompts — the foundation for the Homebrew/Claude-Code-style polish described below. Fall back to raw ANSI (`ANSITerminal` package) only for low-level cursor control ConsoleKit doesn't cover.

## Architecture: three subcommands, one shared scope

### `resource disk`
Mac-aware storage analyzer. Beyond a standard recursive size scan, it should surface what generic tools miss by shelling out to `tmutil` and `diskutil`:
- APFS purgeable space
- Local Time Machine snapshot sizes
- A breakdown of what's actually inside "System Data" / "Other"

### `resource startup`
Audits LaunchAgents, LaunchDaemons, and login items. For each: plain-English description of what it is and who installed it, and a flag for **dead entries** — items pointing to an executable/app that no longer exists on disk.

### `resource clean`
Safe cleanup, structured as a **checklist of known categories** rather than freeform folder scanning — it should only ever touch things matching a pattern it explicitly understands:
- Xcode DerivedData, old simulators/device support
- Homebrew cache
- npm / yarn / pip caches
- Orphaned `~/Library` remnants (Caches, Preferences, Application Support, Containers) matched against bundle IDs of currently-installed apps
- Dead launch agents identified by the `startup` module

**Non-negotiable safety rules:**
- Move to **Trash via `FileManager`**, never permanent delete (`rm`-equivalent).
- Always show a **preview of exactly what will be touched** before any destructive confirmation — same pattern as Claude Code showing a diff before editing a file.
- No fear-mongering language ("47GB of junk found!"); just factual, sourced findings.

### Shared scope/config system
- First run (or `resource config`) prompts which volumes/folders are in scope; detected via `/Volumes` plus home directory.
- Persisted to `~/.config/resource/config.json` so it isn't re-asked every run.
- `--path` flag allows a one-off scan outside the saved scope without modifying the config.
- **External volumes are opt-in per plug-in event** — never silently remembered/auto-scanned on reconnect.
- This scoping also minimizes the Full Disk Access ask: the tool only requests access to paths the user explicitly opted into.

## UX/styling direction

Target feel: Homebrew's clarity crossed with Claude Code/Codex's minimalism.
- `==>`-style section headers, indentation for sub-items, one-line final summaries instead of scrollback walls.
- 2–3 colors max, each with a fixed, consistent meaning (e.g., green = safe, yellow = needs attention, red = destructive). Never decorative.
- Spinner/progress indicator that overwrites itself in place (no log spam) for anything taking >1s.
- Respect the `NO_COLOR` env var and detect non-interactive/piped output to fall back to plain text.

## Suggested build order
1. Scaffold the Swift package with `swift-argument-parser` and `ConsoleKit` wired in from the start, so the styled-output foundation exists before any feature logic (a working "hello world" with the three empty subcommands stubbed in).
2. `resource disk` — most technically novel piece, build first.
3. `resource startup`.
4. `resource clean` — built last since it depends on cross-referencing data from both prior modules.

## Open questions / not yet decided
- Exact full list of "known-safe" cleanup categories beyond the ones listed above.
- Distribution plan (Homebrew tap eventually, vs. just a personal binary).
- Whether `resource disk`'s interactive view needs full keyboard-navigable treemap rendering (ncdu-style) for v1, or whether a simpler sorted list is enough to start.
