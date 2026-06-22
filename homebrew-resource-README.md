# homebrew-resource

Homebrew tap for [ReSource](https://github.com/GNelster/ReSource) — a macOS terminal tool that audits startup items, analyzes disk usage, and reclaims space from caches and app leftovers.

## Install

```bash
brew install GNelster/resource/resource
```

Or as two steps:

```bash
brew tap GNelster/resource
brew install resource
```

## Upgrade

```bash
brew upgrade GNelster/resource/resource
```

## Usage

```
resource           # interactive menu
resource doctor    # health check — biggest wins at a glance
resource disk      # interactive disk usage browser
resource startup   # audit launch agents, daemons, and login items
resource clean     # reclaim space from caches and app leftovers
resource memory    # live RAM breakdown by process
resource battery   # battery health and cycle count
resource config    # view and edit settings
```

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (installed automatically by Homebrew)

## Source

[github.com/GNelster/ReSource](https://github.com/GNelster/ReSource)
