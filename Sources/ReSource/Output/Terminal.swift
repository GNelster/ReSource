import Foundation

enum Terminal {
    static var isColorEnabled: Bool {
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
        return isatty(STDOUT_FILENO) != 0
    }

    static var isInteractive: Bool {
        isatty(STDIN_FILENO) != 0
    }

    static func writeError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
