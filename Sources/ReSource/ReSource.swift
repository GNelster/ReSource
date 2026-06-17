import ArgumentParser

@main
struct ReSourceCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resource",
        abstract: "Mac resource inspector — startup items and leftover files.",
        subcommands: [StartupCommand.self, CleanCommand.self]
    )

    mutating func run() throws {
        installSignalHandlers()
        let menu = MainMenu(entries: [
            MenuEntry(name: "startup", description: "Audit launch agents, daemons, and login items") {
                var cmd = try StartupCommand.parse([])
                try cmd.run()
            },
            MenuEntry(name: "clean",   description: "Safely reclaim space from known cleanup categories") {
                var cmd = try CleanCommand.parse([])
                try cmd.run()
            },
        ])
        try menu.run()
    }
}
