import Foundation
import Darwin

final class StartupListView {

    // MARK: - Types

    private struct Row {
        let item: LaunchItem
        var selected: Bool
    }

    // MARK: - State

    private var rows: [Row]
    private var cursor: Int = 0
    private var scrollOffset: Int = 0
    private var statusMessage: String? = nil

    // MARK: - Init

    init(results: [LaunchLocation: [LaunchItem]]) {
        let order: [LaunchLocation] = [.userAgent, .systemAgent, .systemDaemon, .loginItem]
        var allRows: [Row] = []

        for location in order {
            let items = (results[location] ?? []).sorted { $0.label < $1.label }
            guard !items.isEmpty else { continue }
            for item in items {
                allRows.append(Row(item: item, selected: item.isDead))
            }
        }

        self.rows = allRows
    }

    // MARK: - Run loop

    func run() throws {
        guard !rows.isEmpty else {
            Style.item(Style.dim("No startup items found."))
            return
        }

        // Enter alternate screen + hide cursor — fully isolated from scrollback
        writeRaw("\u{1B}[?1049h\u{1B}[?25l")
        defer { writeRaw("\u{1B}[?1049l\u{1B}[?25h") }

        while true {
            render()
            let key = readKey()
            statusMessage = nil

            switch key {
            case .up:
                if cursor > 0 { cursor -= 1 }
                adjustScroll()

            case .down:
                if cursor < rows.count - 1 { cursor += 1 }
                adjustScroll()

            case .enter, .space:
                rows[cursor].selected.toggle()

            case .delete:
                if rows.filter({ $0.selected }).isEmpty {
                    statusMessage = "Nothing selected — press enter to mark items."
                } else {
                    // Exit alt screen and restore normal terminal so sudo can prompt
                    writeRaw("\u{1B}[?1049l\u{1B}[?25h")
                    var savedTerm = termios()
                    tcgetattr(STDIN_FILENO, &savedTerm)
                    var normal = savedTerm
                    normal.c_lflag |= tcflag_t(ICANON | ECHO | ISIG)
                    normal.c_iflag |= tcflag_t(ICRNL)
                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &normal)

                    removeSelected()

                    print()
                    if let msg = statusMessage { print("  \(msg)") }
                    fflush(stdout)

                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &savedTerm)
                    return
                }

            case .quit:
                return

            case .other:
                break
            }
        }
    }

    // MARK: - Deletion

    private func removeSelected() {
        let fm = FileManager.default
        var log = "=== removeSelected ===\n"

        var privilegedPaths: [String] = []
        var removed = 0
        var firstError: String? = nil
        var skippedLoginItems = 0

        let selected = rows.filter { $0.selected }
        log += "selected count: \(selected.count)\n"
        for r in selected { log += "  path: \(r.item.plistPath ?? "<login item>")\n" }

        // Login items (no plist) must be removed via System Settings
        for r in selected where r.item.plistPath == nil {
            skippedLoginItems += 1
        }

        for i in rows.indices.reversed() {
            guard rows[i].selected else { continue }
            guard let path = rows[i].item.plistPath else { continue } // login items — skip

            do {
                try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                log += "trashItem OK: \(path)\n"
                rows.remove(at: i)
                if cursor >= rows.count { cursor = max(0, rows.count - 1) }
                removed += 1
            } catch {
                log += "trashItem FAIL: \(path) — \(error)\n"
                if firstError == nil { firstError = "\(error.localizedDescription)" }
                privilegedPaths.append(path)
            }
        }

        log += "privilegedPaths count: \(privilegedPaths.count)\n"

        if !privilegedPaths.isEmpty {
            log += "calling privilegedRemove\n"
            _ = privilegedRemove(paths: privilegedPaths)
            log += "privilegedRemove returned\n"
            // Trust file-existence to determine success — don't double-count sudo exit codes
            for path in privilegedPaths where !FileManager.default.fileExists(atPath: path) {
                if let idx = rows.firstIndex(where: { $0.item.plistPath == path }) {
                    rows.remove(at: idx)
                    if cursor >= rows.count { cursor = max(0, rows.count - 1) }
                    removed += 1
                }
            }
        }

        log += "final removed: \(removed)\n"
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/resource_debug.txt")
        try? log.write(to: logURL, atomically: true, encoding: .utf8)

        var parts: [String] = []
        if removed > 0 { parts.append("\(removed) \(removed == 1 ? "item" : "items") moved to Trash") }
        if skippedLoginItems > 0 { parts.append("\(skippedLoginItems) login \(skippedLoginItems == 1 ? "item" : "items") must be removed in System Settings → General → Login Items") }
        if parts.isEmpty, let err = firstError { parts.append(err) }
        statusMessage = parts.joined(separator: "  ·  ")
    }

    /// Moves system-owned paths to Trash via sudo. Caller is responsible for
    /// restoring the terminal before this is called and re-entering the TUI after.
    private func privilegedRemove(paths: [String]) -> Int {
        let trashDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash").path

        print("\nRemoving \(paths.count) system \(paths.count == 1 ? "item" : "items") — enter your password when prompted.\n")
        for p in paths { print("  \(p)") }
        print()
        fflush(stdout)

        var removed = 0
        for path in paths {
            let src = path.replacingOccurrences(of: "'", with: "'\\''")
            let dst = trashDir.replacingOccurrences(of: "'", with: "'\\''")
            if spawnShell("sudo mv -f '\(src)' '\(dst)/'") { removed += 1 }
        }
        return removed
    }

    // MARK: - Scroll

    private func adjustScroll() {
        let h = viewportHeight
        if cursor < scrollOffset          { scrollOffset = cursor }
        if cursor >= scrollOffset + h     { scrollOffset = cursor - h + 1 }
    }

    private var viewportHeight: Int { max(4, TermSize.rows - 8) }

    // MARK: - Rendering  (entire frame built in one string, written atomically)

    private func render() {
        var buf = "\u{1B}[H"   // jump to top-left; no erase so there's no blank flash

        let selectedCount = rows.filter { $0.selected }.count
        let deadCount     = rows.filter { $0.item.isDead }.count

        // Header
        buf += Color.green.apply("==>") + " " + Style.bold("Startup Items") + eraseEOL + "\n"

        var summary = Style.dim("  \(rows.count) items")
        if deadCount     > 0 { summary += "  " + Color.yellow.apply("\(deadCount) dead") }
        if selectedCount > 0 { summary += "  " + Color.green.apply("\(selectedCount) selected") }
        buf += summary + eraseEOL + "\n"
        buf += eraseEOL + "\n"

        // Items
        let visibleEnd  = min(scrollOffset + viewportHeight, rows.count)
        var lastSection: LaunchLocation? = nil

        for i in scrollOffset..<visibleEnd {
            let loc = rows[i].item.location

            if loc != lastSection {
                if lastSection != nil { buf += eraseEOL + "\n" }
                let dc = rows.filter { $0.item.location == loc && $0.item.isDead }.count
                let tag = dc > 0 ? "  " + Color.yellow.apply("\(dc) dead") : ""
                buf += "  " + Style.dim(loc.rawValue + "  " + loc.displayPath) + tag + eraseEOL + "\n"
                lastSection = loc
            }

            buf += rowString(rows[i], index: i) + eraseEOL + "\n"
        }

        // Erase everything below the rendered content
        buf += "\u{1B}[J"

        // Footer
        buf += eraseEOL + "\n"
        if let msg = statusMessage {
            buf += "  " + Color.yellow.apply(msg) + eraseEOL + "\n"
        } else {
            buf += "  "
                + hintStr("↑↓", "move")
                + Style.dim("  ·  ") + hintStr("↵", "select")
                + Style.dim("  ·  ") + hintStr("⌫", "remove selected")
                + Style.dim("  ·  ") + hintStr("esc", "back")
                + eraseEOL + "\n"
        }

        writeRaw(buf)
    }

    private var eraseEOL: String { "\u{1B}[K" }

    private func rowString(_ row: Row, index: Int) -> String {
        let isCursor = index == cursor
        let item     = row.item
        let pointer  = isCursor ? Color.green.apply("▶") : " "

        let checkbox: String
        if row.selected          { checkbox = Color.green.apply("[✓]") }
        else if item.isDead      { checkbox = Color.yellow.apply("[ ]") }
        else                     { checkbox = Style.dim("[ ]") }

        let name = item.displayName.padded(to: 26)

        switch item.status {
        case .alive:
            let n = isCursor ? Style.bold(name) : name
            let detail = item.location == .loginItem
                ? Style.dim(item.runAtLoad ? "enabled" : "disabled")
                : Style.dim(triggerText(item))
            return "  \(pointer) \(checkbox) \(n)  \(detail)"

        case .dead(let missing):
            let n = isCursor ? Style.bold(Color.yellow.apply(name)) : Color.yellow.apply(name)
            return "  \(pointer) \(checkbox) \(n)  " + Color.yellow.apply("DEAD") + Style.dim("  \(missing)")

        case .noExecutable:
            let n = isCursor ? Style.bold(name) : name
            let detail = item.location == .loginItem
                ? Style.dim(item.runAtLoad ? "enabled" : "disabled")
                : Style.dim("no executable specified")
            return "  \(pointer) \(checkbox) \(n)  \(detail)"
        }
    }

    // MARK: - Helpers

    private func triggerText(_ item: LaunchItem) -> String {
        if item.runAtLoad, let i = item.startInterval { return "login · every \(fmt(i))" }
        if item.runAtLoad                             { return "runs at login" }
        if let i = item.startInterval                 { return "every \(fmt(i))" }
        return "on demand"
    }

    private func fmt(_ seconds: Int) -> String {
        if seconds < 60   { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}

// MARK: - File-scope helpers

/// Runs `cmd` via /bin/sh with inherited file descriptors so sudo can prompt in the terminal.
/// Uses posix_spawn (not Process) to avoid the fd-close crash on dealloc.
private func spawnShell(_ cmd: String) -> Bool {
    let sh   = strdup("/bin/sh")!
    let flag = strdup("-c")!
    let arg  = strdup(cmd)!
    defer { free(sh); free(flag); free(arg) }

    var argv: [UnsafeMutablePointer<CChar>?] = [sh, flag, arg, nil]
    var pid: pid_t = 0
    let ret = argv.withUnsafeBufferPointer { buf in
        posix_spawn(&pid, "/bin/sh", nil, nil, buf.baseAddress, environ)
    }
    guard ret == 0 else { return false }

    var status: Int32 = 0
    waitpid(pid, &status, 0)
    // Normal exit with code 0: low 7 bits == 0 (not signaled) and high byte == 0 (exit code)
    return (status & 0x7f) == 0 && ((status >> 8) & 0xff) == 0
}

private func hintStr(_ key: String, _ label: String) -> String {
    Style.bold(key) + Style.dim(" \(label)")
}

private func writeRaw(_ s: String) {
    s.withCString { ptr in
        Darwin.write(STDOUT_FILENO, ptr, strlen(ptr))
    }
}

private extension String {
    func padded(to length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }
}
