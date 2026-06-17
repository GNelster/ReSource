import ArgumentParser
import Foundation

struct DiskCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disk",
        abstract: "Analyze disk usage with macOS-aware insights.",
        discussion: """
        Surfaces what generic tools miss: APFS purgeable space, local Time Machine
        snapshot sizes, and a breakdown of your home directory sorted by size.
        """
    )

    @Option(name: .long, help: "Scan a specific path instead of the home directory.")
    var path: String?

    mutating func run() throws {
        let analyzer = DiskAnalyzer()

        Style.header("Disk")
        print()

        // ── FDA check ─────────────────────────────────────────
        if !analyzer.hasFDA() {
            Style.warning("Full Disk Access is not enabled — sizes will be incomplete.")
            print()
            let open = Prompt.yesNo(
                Style.bold("Open System Settings → Full Disk Access?") +
                Style.dim("  y / n")
            )
            if open {
                Shell.run("/usr/bin/open",
                          arguments: ["x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"])
                print()
                Style.item(Style.dim("Grant access to Terminal, then fully quit and reopen Terminal for it to take effect."))
            }
            print()
        }

        // ── Time Machine ──────────────────────────────────────
        let tmSpinner = Spinner("Reading Time Machine snapshots")
        tmSpinner.start()
        let snaps = analyzer.tmSnapshots()
        tmSpinner.stop(success: true, label: "Time Machine snapshots")
        if !snaps.isEmpty {
            print()
            Style.subheader("Time Machine Snapshots")
            printSnapshots(snaps)
            print()
        }

        // ── Home directory (incremental — real progress) ──────
        let subdirs  = analyzer.homeSubdirectories()
        let progress = ProgressBar(label: "Scanning home directory", total: subdirs.count)
        progress.start()

        var dirs: [DirectoryEntry] = []
        for path in subdirs {
            let name = URL(fileURLWithPath: path).lastPathComponent
            let size = analyzer.sizeOf(path: path)
            dirs.append(DirectoryEntry(name: name, path: path, bytes: size))
            progress.tick(item: "~/\(name)")
        }
        progress.complete(label: "Home directory scanned")
        dirs.sort { $0.bytes > $1.bytes }

        print()
        Style.subheader("Home  (\(analyzer.homePath))")
        printDirectories(dirs)
    }

    // MARK: - Render helpers

    private func printSnapshots(_ snaps: [TMSnapshot]) {
        var total: Int64 = 0
        for snap in snaps {
            let size = snap.bytes.map { Format.bytes($0) } ?? Style.dim("size unavailable")
            Style.item("  \(snap.displayDate.padded(to: 20))  \(size)")
            total += snap.bytes ?? 0
        }
        if total > 0 {
            print()
            Style.item("  \("Total".padded(to: 20))  \(Style.bold(Format.bytes(total)))")
        }
    }

    private func printDirectories(_ dirs: [DirectoryEntry]) {
        guard !dirs.isEmpty else {
            Style.item(Style.dim("No directories found."))
            return
        }

        let maxBytes  = dirs.first?.bytes ?? 1
        let cols      = TermSize.columns
        let nameW     = min(20, dirs.map { $0.name.count }.max() ?? 10)
        let sizeW     = 9
        let barW      = min(24, max(10, cols - nameW - sizeW - 12))

        for entry in dirs {
            let name    = entry.name.padded(to: nameW)
            let size    = rightAlign(Format.bytes(entry.bytes), width: sizeW)
            let frac    = Double(entry.bytes) / Double(maxBytes)
            let bar     = frac > 0.01
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
