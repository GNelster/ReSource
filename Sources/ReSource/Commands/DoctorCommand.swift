import ArgumentParser
import Foundation

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Quick health check — biggest wins across disk, startup, and cache.",
        discussion: "Scans all domains and surfaces the top actionable items in one view."
    )

    mutating func run() throws {
        Style.header("Doctor")
        print()

        let spinner = Spinner("Scanning…")
        spinner.start()

        // Run disk and startup scans concurrently, then use startup results for clean
        let slots = DoctorSlots()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        group.enter()
        queue.async {
            slots.volume = DiskAnalyzer().volumeInfo()
            group.leave()
        }

        group.enter()
        queue.async {
            slots.startupResults = StartupScanner().scan()
            group.leave()
        }

        group.enter()
        queue.async {
            slots.battery = BatteryInfo.snapshot()
            group.leave()
        }

        group.wait()

        // Clean scan uses dead launch items from startup
        let deadItems = (slots.startupResults ?? [:]).values.flatMap { $0 }.filter { $0.isDead }
        slots.cleanItems = CleanScanner(deadLaunchItems: deadItems).scan()

        spinner.stop(success: true, label: "Scan complete")
        print()

        // ── Disk ─────────────────────────────────────────────────
        Style.subheader("Disk")
        print()
        if let vol = slots.volume {
            let usedPct = Int((vol.usedFraction * 100).rounded())
            let bar     = Format.bar(fraction: vol.usedFraction, width: 20)
            let colored = vol.usedFraction > 0.85
                ? Color.yellow.apply(bar)
                : Color.green.apply(bar)
            Style.item("\(colored)  \(Format.bytes(vol.usedBytes)) / \(Format.bytes(vol.totalBytes))  (\(usedPct)%)")
            if vol.purgeableBytes > 0 {
                Style.item(Style.dim("  \(Format.bytes(vol.purgeableBytes)) purgeable (APFS can reclaim automatically)"))
            }
        } else {
            Style.item(Style.dim("Could not read volume info."))
        }
        print()

        // ── Startup ───────────────────────────────────────────────
        let startupResults = slots.startupResults ?? [:]
        let allStartup     = startupResults.values.flatMap { $0 }
        let deadCount      = allStartup.filter { $0.isDead }.count
        Style.subheader("Startup")
        print()
        Style.item("\(allStartup.count) items")
        if deadCount > 0 {
            Style.item(Color.yellow.apply("  \(deadCount) dead \(deadCount == 1 ? "entry" : "entries") pointing to missing executables"))
        } else {
            Style.item(Style.dim("  No dead entries found"))
        }
        print()

        // ── Cleanable ─────────────────────────────────────────────
        let items        = slots.cleanItems ?? []
        let totalSavings = items.reduce(Int64(0)) { $0 + $1.sizeBytes }
        Style.subheader("Cleanable Cache")
        print()

        if items.isEmpty {
            Style.item(Style.dim("Nothing found to clean."))
        } else {
            // Group by category and sum sizes
            var byCat: [(category: CleanCategory, total: Int64)] = []
            var seen = Set<CleanCategory>()
            for item in items {
                if seen.contains(item.category) {
                    if let i = byCat.firstIndex(where: { $0.category == item.category }) {
                        byCat[i].total += item.sizeBytes
                    }
                } else {
                    byCat.append((item.category, item.sizeBytes))
                    seen.insert(item.category)
                }
            }
            byCat.sort { $0.total > $1.total }

            let top = byCat.prefix(5)
            let labelW = top.map { $0.category.rawValue.count }.max() ?? 20
            for entry in top where entry.total > 0 {
                let label = entry.category.rawValue.padded(to: labelW)
                Style.item("\(label)  \(Style.bold(Format.bytes(entry.total)))")
            }
            if byCat.count > 5 {
                Style.item(Style.dim("  … and \(byCat.count - 5) more categories"))
            }
            print()
            Style.item("Total recoverable: \(Style.bold(Format.bytes(totalSavings)))")
        }

        print()

        // ── Battery ───────────────────────────────────────────────
        if let b = slots.battery {
            Style.subheader("Battery")
            print()
            let healthPct = Int((b.healthFraction * 100).rounded())
            let bar       = Format.bar(fraction: b.healthFraction, width: 20)
            let colored   = healthPct >= 80
                ? Color.green.apply(bar)
                : Color.yellow.apply(bar)
            Style.item("\(colored)  \(Style.bold("\(healthPct)% health"))  ·  \(b.cycleCount) cycles  ·  \(b.condition)")
            if b.condition.lowercased().contains("service") || b.cycleCount > 800 {
                Style.item(Color.yellow.apply("  → run `resource battery` for details"))
            }
            print()
        }

        // ── Actions ───────────────────────────────────────────────
        let hasWins = totalSavings > 0 || deadCount > 0
        guard hasWins else {
            Style.success("Everything looks clean.")
            print()
            return
        }

        struct Action {
            let label: String
            let detail: String
        }
        var actions: [Action] = []
        if !items.isEmpty   { actions.append(Action(label: "clean",   detail: "\(Format.bytes(totalSavings)) recoverable")) }
        if deadCount > 0    { actions.append(Action(label: "startup", detail: "\(deadCount) dead \(deadCount == 1 ? "entry" : "entries")")) }
        actions.append(Action(label: "quit", detail: ""))

        var selected = 0
        var rawTerm  = RawTerminal()
        rawTerm.enable()

        func renderMenu() {
            for (i, action) in actions.enumerated() {
                let pointer = i == selected ? Color.green.apply("  ▶") : "     "
                let name    = i == selected ? Style.bold(action.label.padded(to: 10)) : action.label.padded(to: 10)
                let detail  = action.detail.isEmpty ? "" : Style.dim("  \(action.detail)")
                print("\(pointer)  \(name)\(detail)")
            }
            let hints = Style.bold("↑↓") + Style.dim(" move  ·  ") + Style.bold("↵") + Style.dim(" select")
            print("\n  \(hints)")
            fflush(stdout)
        }

        // Move cursor up to re-render in place
        let lineCount = actions.count + 2
        func clearMenu() {
            for _ in 0..<lineCount { print("\u{1B}[A\u{1B}[2K", terminator: "") }
            fflush(stdout)
        }

        print()
        renderMenu()

        var choice: Action? = nil
        while true {
            let key = readKey()
            switch key {
            case .up:
                if selected > 0 { selected -= 1 }
            case .down:
                if selected < actions.count - 1 { selected += 1 }
            case .enter:
                choice = actions[selected]
                break
            case .quit:
                break
            default:
                continue
            }
            if key == .enter || key == .quit { break }
            clearMenu()
            renderMenu()
        }

        rawTerm.disable()

        guard let picked = choice, picked.label != "quit" else { return }

        Cursor.clear()
        switch picked.label {
        case "clean":   try CleanListView(items: items).run()
        case "startup": try StartupListView(results: startupResults).run()
        default:        break
        }
    }
}

// @unchecked Sendable: written from concurrent closures but each field is written
// by exactly one closure before being read after group.wait().
private final class DoctorSlots: @unchecked Sendable {
    var volume:         VolumeInfo?
    var startupResults: [LaunchLocation: [LaunchItem]]?
    var cleanItems:     [CleanItem]?
    var battery:        BatterySnapshot?
}

private extension String {
    func padded(to length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }
}
