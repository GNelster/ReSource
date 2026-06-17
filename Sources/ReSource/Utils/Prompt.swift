import Darwin
import Foundation

enum Prompt {
    /// Reads a single keypress (raw mode). Returns true for y/Y, false for anything else.
    static func yesNo(_ message: String) -> Bool {
        print("  \(message)  ", terminator: "")
        fflush(stdout)
        var c: UInt8 = 0
        read(STDIN_FILENO, &c, 1)
        print()
        return c == 121 || c == 89  // y or Y
    }
}
