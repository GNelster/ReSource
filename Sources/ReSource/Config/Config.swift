import Foundation

struct Config: Codable {
    /// Age in days before a file in ~/Downloads is considered "old". Default: 365.
    var oldDownloadsAgeDays: Int = 365

    /// Paths explicitly excluded from all clean scans.
    var excludedCleanPaths: [String] = []
}

enum ConfigManager {
    static var configURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/resource")
        return dir.appendingPathComponent("config.json")
    }

    static func load() -> Config {
        let url = configURL
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return Config() }
        return config
    }

    static func save(_ config: Config) throws {
        let url = configURL
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: url, options: .atomic)
    }
}
