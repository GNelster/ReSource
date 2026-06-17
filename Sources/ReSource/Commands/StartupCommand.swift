import ArgumentParser
import Foundation

struct StartupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "startup",
        abstract: "Audit launch agents, daemons, and login items.",
        discussion: "Scans LaunchAgents and LaunchDaemons. Navigate with arrow keys, space to select, d to remove."
    )

    @Flag(name: .long, help: "Show only dead entries.")
    var deadOnly: Bool = false

    mutating func run() throws {
        let scanner = StartupScanner()

        let spinner = Spinner("Scanning startup items")
        spinner.start()
        var results = scanner.scan()
        spinner.stop(success: true, label: "Startup items scanned")

        if deadOnly {
            for key in results.keys {
                results[key] = results[key]?.filter { $0.isDead }
            }
        }

        try StartupListView(results: results).run()
    }
}
