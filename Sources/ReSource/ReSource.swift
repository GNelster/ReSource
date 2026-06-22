import ArgumentParser

@main
struct ReSourceCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resource",
        abstract: "Mac resource inspector — startup items, disk cleanup, and memory.",
        subcommands: [DoctorCommand.self, DiskCommand.self, StartupCommand.self, CleanCommand.self, MemoryCommand.self, BatteryCommand.self, ConfigCommand.self]
    )

    mutating func run() throws {
        installSignalHandlers()
        let menu = MainMenu(entries: [
            MenuEntry(name: "doctor",  description: "Quick health check — biggest wins at a glance") {
                var cmd = try DoctorCommand.parse([])
                try cmd.run()
            },
            MenuEntry(name: "disk",    description: "Analyze disk usage with macOS-aware insights") {
                var cmd = try DiskCommand.parse([])
                try cmd.run()
            },
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
            MenuEntry(name: "battery", description: "Show battery health and cycle count") {
                var cmd = try BatteryCommand.parse([])
                try cmd.run()
            },
        ])
        try menu.run()
    }
}
