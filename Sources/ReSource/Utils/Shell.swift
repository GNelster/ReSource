import Foundation

enum Shell {
    static func run(_ executable: String, _ arguments: String...) -> String? {
        run(executable, arguments: arguments)
    }

    // Returns stdout only on clean exit (status 0).
    static func run(_ executable: String, arguments: [String]) -> String? {
        let (output, status) = exec(executable, arguments: arguments)
        return status == 0 ? output : nil
    }

    // Returns stdout regardless of exit code — use when partial output is still valid
    // (e.g. `du` exits 1 if it hits a permission-denied file but still measured the rest).
    static func output(_ executable: String, _ arguments: String...) -> String? {
        exec(executable, arguments: arguments).0
    }

    @discardableResult
    static func exec(_ executable: String, arguments: [String]) -> (output: String?, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError  = stderr

        do { try process.run() } catch { return (nil, -1) }
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8), process.terminationStatus)
    }
}
