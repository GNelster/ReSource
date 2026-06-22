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
        let allStartup = (slots.startupResults ?? [:]).values.flatMap { $0 }
        let deadCount  = allStartup.filter { $0.isDead }.count
        Style.subheader("Startup")
        print()
        Style.item("\(allStartup.count) items")
        if deadCount > 0 {
            Style.item(Color.yellow.apply("  \(deadCount) dead \(deadCount == 1 ? "entry" : "entries") pointing to missing executables"))
            Style.item(Style.dim("  → run `resource startup` to review and remove"))
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
            Style.item(Style.dim("→ run `resource clean` to review and trash"))
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

        // ── Verdict ───────────────────────────────────────────────
        let hasWins = totalSavings > 0 || deadCount > 0
        if hasWins {
            var actions: [String] = []
            if totalSavings > 0 { actions.append("`resource clean` (\(Format.bytes(totalSavings)) recoverable)") }
            if deadCount    > 0 { actions.append("`resource startup` (\(deadCount) dead \(deadCount == 1 ? "entry" : "entries"))") }
            Style.success("Recommended: " + actions.joined(separator: "  ·  "))
        } else {
            Style.success("Everything looks clean.")
        }
        print()
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
