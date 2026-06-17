import Foundation

enum LaunchLocation: String {
    case userAgent    = "User Agents"
    case systemAgent  = "System Agents"
    case systemDaemon = "System Daemons"

    var directory: String {
        switch self {
        case .userAgent:
            return (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
                .appendingPathComponent("Library/LaunchAgents")
        case .systemAgent:  return "/Library/LaunchAgents"
        case .systemDaemon: return "/Library/LaunchDaemons"
        }
    }

    var displayPath: String {
        switch self {
        case .userAgent: return "~/Library/LaunchAgents"
        default:         return directory
        }
    }
}

enum LaunchStatus {
    case alive
    case dead(missingPath: String)
    case noExecutable
}

struct LaunchItem {
    let label: String
    let plistPath: String
    let location: LaunchLocation
    let executablePath: String?
    let displayName: String          // human-readable app/service name
    let runAtLoad: Bool
    let startInterval: Int?          // seconds between runs, if periodic
    let status: LaunchStatus

    var isDead: Bool {
        if case .dead = status { return true }
        return false
    }
}
