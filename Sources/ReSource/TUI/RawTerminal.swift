import Darwin
import Foundation

struct RawTerminal {
    private var saved = termios()

    mutating func enable() {
        tcgetattr(STDIN_FILENO, &saved)
        var raw = saved
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL)
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            let bytes = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
            bytes[Int(VMIN)]  = 1
            bytes[Int(VTIME)] = 0
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }

    mutating func disable() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved)
    }
}

// MARK: - Key reading

enum Key {
    case up, down, enter, quit, space, delete, other
}

func readKey() -> Key {
    var c: UInt8 = 0
    read(STDIN_FILENO, &c, 1)

    guard c == 27 else {
        switch c {
        case 13, 10: return .enter
        case 32:     return .space
        case 127:    return .delete  // Delete / Backspace key
        case 3:      return .quit    // Ctrl-C
        default:     return .other
        }
    }

    // Try to read an escape sequence (e.g. arrow keys)
    var seq = [UInt8](repeating: 0, count: 2)
    let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
    _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
    let n = read(STDIN_FILENO, &seq, 2)
    _ = fcntl(STDIN_FILENO, F_SETFL, flags)

    if n == 2 && seq[0] == 91 {
        switch seq[1] {
        case 65: return .up
        case 66: return .down
        default: return .other
        }
    }
    return .quit  // bare ESC
}

// MARK: - Cursor control

enum Cursor {
    static func hide()  { print("\u{1B}[?25l", terminator: ""); fflush(stdout) }
    static func show()  { print("\u{1B}[?25h", terminator: ""); fflush(stdout) }
    // \u{1B}[3J clears the scrollback buffer so old content doesn't linger above
    static func clear() { print("\u{1B}[3J\u{1B}[2J\u{1B}[H", terminator: ""); fflush(stdout) }
}

// Call once at startup — restores the terminal cleanly if the process is killed
nonisolated(unsafe) private var _savedForSignal = termios()

func installSignalHandlers() {
    tcgetattr(STDIN_FILENO, &_savedForSignal)
    signal(SIGINT) { _ in
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &_savedForSignal)
        print("\u{1B}[?25h")   // show cursor
        print("\u{1B}[3J\u{1B}[2J\u{1B}[H", terminator: "")
        exit(0)
    }
    signal(SIGTERM) { _ in
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &_savedForSignal)
        print("\u{1B}[?25h")
        exit(0)
    }
}
