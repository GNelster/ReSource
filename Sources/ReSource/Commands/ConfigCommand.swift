import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View and edit ReSource settings.",
        discussion: "Settings are saved to ~/.config/resource/config.json."
    )

    @Option(name: .long, help: "Age in days before a ~/Downloads file is flagged as old (default: 365).")
    var downloadsAge: Int?

    @Option(name: .long, help: "Add a path to exclude from clean scans.")
    var exclude: String?

    @Flag(name: .long, help: "Remove all exclusions.")
    var clearExclusions: Bool = false

    mutating func run() throws {
        var config = ConfigManager.load()

        var changed = false

        if let age = downloadsAge {
            config.oldDownloadsAgeDays = age
            changed = true
        }

        if let path = exclude {
            let expanded = (path as NSString).expandingTildeInPath
            if !config.excludedCleanPaths.contains(expanded) {
                config.excludedCleanPaths.append(expanded)
                changed = true
            }
        }

        if clearExclusions {
            config.excludedCleanPaths = []
            changed = true
        }

        if changed {
            try ConfigManager.save(config)
            Style.success("Config saved to \(ConfigManager.configURL.path)")
        }

        print()
        Style.header("Config")
        print()
        Style.item("Old downloads age   \(Style.bold("\(config.oldDownloadsAgeDays) days"))")
        if config.excludedCleanPaths.isEmpty {
            Style.item("Excluded paths      \(Style.dim("none"))")
        } else {
            Style.item("Excluded paths")
            for p in config.excludedCleanPaths {
                Style.item("  \(Style.dim(p))")
            }
        }
        Style.item(Style.dim("Config file: \(ConfigManager.configURL.path)"))
        print()
        Style.item(Style.dim("resource config --downloads-age 180"))
        Style.item(Style.dim("resource config --exclude ~/Downloads/keep-this"))
        Style.item(Style.dim("resource config --clear-exclusions"))
        print()
    }
}
