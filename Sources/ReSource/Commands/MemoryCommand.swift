import ArgumentParser
import Foundation

struct MemoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "memory",
        abstract: "Show memory usage by process.",
        discussion: "Displays system memory breakdown and top processes sorted by RAM usage."
    )

    mutating func run() throws {
        Style.header("Memory")
        print()

        let spinner = Spinner("Reading memory stats")
        spinner.start()
        let snap  = MemoryInfo.snapshot()
        let procs = MemoryInfo.topProcesses()
        spinner.stop(success: true, label: "Memory stats loaded")
        print()

        if let s = snap {
            Style.subheader("System")
            print()

            let cols  = min(TermSize.columns, 80)
            let nameW = 12
            let sizeW = 9
            let barW  = min(30, max(10, cols - nameW - sizeW - 10))
            let total = s.totalBytes

            func memRow(_ label: String, _ bytes: Int64) {
                let name = label.padded(to: nameW)
                let size = rightAlign(Format.bytes(bytes), width: sizeW)
                let frac = total > 0 ? Double(bytes) / Double(total) : 0
                let bar  = frac > 0.01
                    ? Color.green.apply(Format.bar(fraction: frac, width: barW))
                    : Style.dim(Format.bar(fraction: frac, width: barW))
                Style.item("  \(name)  \(bar)  \(size)")
            }

            // Used = App + Wired + Compressed, so it's always >= each sub-row
            memRow("Used",        s.usedBytes)
            memRow("  App",       s.appBytes)
            memRow("  Wired",     s.wiredBytes)
            memRow("  Compressed",s.compressedBytes)
            memRow("Cached",      s.cachedBytes)
            memRow("Free",        s.freeBytes)

            print()
            Style.item("  \("Total".padded(to: nameW))  \(String(repeating: " ", count: barW + 2))  \(rightAlign(Format.bytes(total), width: sizeW))")
            print()
        }

        guard !procs.isEmpty else { return }
        Style.subheader("Top Processes")
        print()

        let maxRSS = procs.first?.rssBytes ?? 1
        let cols   = min(TermSize.columns, 80)
        let nameW  = min(28, procs.map { $0.name.count }.max() ?? 16)
        let sizeW  = 9
        let barW   = min(24, max(10, cols - nameW - sizeW - 10))

        for proc in procs {
            let name = proc.name.padded(to: nameW)
            let size = rightAlign(Format.bytes(proc.rssBytes), width: sizeW)
            let frac = Double(proc.rssBytes) / Double(maxRSS)
            let bar  = frac > 0.01
                ? Color.green.apply(Format.bar(fraction: frac, width: barW))
                : Style.dim(Format.bar(fraction: frac, width: barW))
            Style.item("  \(name)  \(bar)  \(size)")
        }
    }

    private func rightAlign(_ s: String, width: Int) -> String {
        s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
    }
}

private extension String {
    func padded(to length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }
}
