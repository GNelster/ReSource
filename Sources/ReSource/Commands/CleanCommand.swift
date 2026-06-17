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
        let scanner = CleanScanner()
        let spinner = Spinner("Scanning for cleanable items")
        spinner.start()
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
