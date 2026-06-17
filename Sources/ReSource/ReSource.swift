import ArgumentParser

@main
struct ReSourceCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resource",
        abstract: "Mac resource inspector — startup items, disk cleanup, and memory.",
        subcommands: [StartupCommand.self, CleanCommand.self, MemoryCommand.self]
    )

    mutating func run() throws {
        installSignalHandlers()
        let menu = MainMenu(entries: [
            MenuEntry(name: "startup", description: "Audit launch agents, daemons, and login items") {
                var cmd = try StartupCommand.parse([])
                try cmd.run()
            },
            MenuEntry(name: "clean",   description: "Reclaim space from caches, leftovers, and old downloads") {
                var cmd = try CleanCommand.parse([])
                try cmd.run()
            },
            MenuEntry(name: "memory",  description: "Show RAM usage by process") {
                var cmd = try MemoryCommand.parse([])
                try cmd.run()
            },
        ])
        try menu.run()
    }
}
