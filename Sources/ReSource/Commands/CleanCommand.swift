import ArgumentParser
import Darwin
import Foundation

struct CleanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Reclaim disk space from caches and build artifacts.",
        discussion: """
        Scans known-safe locations. All items are pre-selected — use enter to
        deselect anything you want to keep, then ⌫ to move the rest to Trash.
        """
    )

    mutating func run() throws {
        let spinner = Spinner("Scanning for cleanable items")
        spinner.start()

        // Scan startup items first so dead agents can be cross-referenced
        let startupResults = StartupScanner().scan()
        let deadItems = startupResults.values.flatMap { $0 }.filter { $0.isDead }

        let scanner = CleanScanner(deadLaunchItems: deadItems)
        let items = scanner.scan()
        spinner.stop(success: true, label: "Scan complete — \(items.count) items found")

        if items.isEmpty {
            print()
            print(Style.dim("  Nothing found to clean."))
            return
        }

        try CleanListView(items: items).run()
    }
}
