import Darwin

enum Format {
    static func bytes(_ value: Int64) -> String {
        let units: [(String, Int64)] = [
            ("TB", 1_099_511_627_776),
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1_024),
        ]
        for (label, factor) in units {
            if value >= factor {
                let d = Double(value) / Double(factor)
                return d >= 100 ? String(format: "%.0f %@", d, label)
                               : String(format: "%.1f %@", d, label)
            }
        }
        return "\(value) B"
    }

    static func bar(fraction: Double, width: Int) -> String {
        let clamped = max(0.0, min(1.0, fraction))
        let filled  = Int((clamped * Double(width)).rounded())
        let empty   = width - filled
        let fill    = String(repeating: "█", count: filled)
        let space   = String(repeating: "░", count: empty)
        return fill + space
    }
}

enum TermSize {
    static var columns: Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_col > 0 { return Int(ws.ws_col) }
        return 80
    }
    static var rows: Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0, ws.ws_row > 0 { return Int(ws.ws_row) }
        return 24
    }
}
