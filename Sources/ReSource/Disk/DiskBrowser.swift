import Foundation
import Darwin

final class DiskBrowser {

    // MARK: - Types

    private struct Entry {
        let name: String
        let path: String
        var bytes: Int64
        var isDir: Bool
        var scanned: Bool = false
    }

    // MARK: - State

    private var stack:        [(path: String, entries: [Entry], cursor: Int, scrollOffset: Int)] = []
    private var currentEntries: [Entry] = []
    private var cursor        = 0
    private var scrollOffset  = 0
    private var statusMessage: String? = nil
    private var scanning      = false

    private let analyzer = DiskAnalyzer()

    // MARK: - Init

    init(rootPath: String) {
        let entries = loadEntries(at: rootPath)
        stack = [(path: rootPath, entries: entries, cursor: 0, scrollOffset: 0)]
        currentEntries = entries
    }

    // MARK: - Run loop

    func run() {
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
                if cursor < currentEntries.count - 1 { cursor += 1 }
                adjustScroll()

            case .enter, .space:
                drillIn()

            case .quit, .delete:
                if stack.count > 1 {
                    drillOut()
                } else {
                    return
                }

            case .other:
                break
            }
        }
    }

    // MARK: - Navigation

    private func drillIn() {
        guard !currentEntries.isEmpty else { return }
        let entry = currentEntries[cursor]
        guard entry.isDir else {
            statusMessage = Style.dim("Not a directory")
            return
        }

        let children = loadEntries(at: entry.path)
        stack[stack.count - 1].cursor      = cursor
        stack[stack.count - 1].scrollOffset = scrollOffset
        stack[stack.count - 1].entries     = currentEntries

        stack.append((path: entry.path, entries: children, cursor: 0, scrollOffset: 0))
        currentEntries = children
        cursor         = 0
        scrollOffset   = 0
    }

    private func drillOut() {
        guard stack.count > 1 else { return }
        stack.removeLast()
        let frame      = stack[stack.count - 1]
        currentEntries = frame.entries
        cursor         = frame.cursor
        scrollOffset   = frame.scrollOffset
    }

    // MARK: - Directory loading

    private func loadEntries(at path: String) -> [Entry] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var entries: [Entry] = names.compactMap { name -> Entry? in
            guard name != ".DS_Store" else { return nil }
            let full = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            let bytes = analyzer.sizeOf(path: full)
            return Entry(name: name, path: full, bytes: bytes, isDir: isDir.boolValue, scanned: true)
        }

        entries.sort { $0.bytes > $1.bytes }
        return entries
    }

    // MARK: - Scroll

    private func adjustScroll() {
        let h = viewportHeight
        if cursor < scrollOffset          { scrollOffset = cursor }
        if cursor >= scrollOffset + h     { scrollOffset = cursor - h + 1 }
    }

    private var viewportHeight: Int { max(4, TermSize.rows - 10) }

    // MARK: - Render

    private func render() {
        var buf = "\u{1B}[H"

        let currentPath = stack.last?.path ?? ""
        let displayPath = currentPath.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
        let totalBytes = currentEntries.reduce(Int64(0)) { $0 + $1.bytes }
        let breadcrumb = stack.dropFirst().map { ($0.path as NSString).lastPathComponent }.joined(separator: " / ")

        buf += Color.green.apply("==>") + " " + Style.bold("Disk") + eraseEOL + "\n"
        buf += Style.dim("  \(displayPath)") + eraseEOL + "\n"
        buf += Style.dim("  \(currentEntries.count) items  ·  \(Format.bytes(totalBytes)) total") + eraseEOL + "\n"
        buf += eraseEOL + "\n"

        let cols  = TermSize.columns
        let nameW = min(36, max(16, cols - 22))
        let sizeW = 9
        let barW  = min(16, max(6, cols - nameW - sizeW - 10))
        let maxBytes = currentEntries.first?.bytes ?? 1

        let visibleEnd = min(scrollOffset + viewportHeight, currentEntries.count)
        for i in scrollOffset..<visibleEnd {
            let entry     = currentEntries[i]
            let isCursor  = i == cursor
            let pointer   = isCursor ? Color.green.apply("▶") : " "

            let name      = truncate(entry.name, to: nameW).padded(to: nameW)
            let n         = isCursor ? Style.bold(name) : name
            let size      = rightAlign(Format.bytes(entry.bytes), width: sizeW)
            let frac      = maxBytes > 0 ? Double(entry.bytes) / Double(maxBytes) : 0
            let bar       = frac > 0.01
                ? Color.green.apply(Format.bar(fraction: frac, width: barW))
                : Style.dim(Format.bar(fraction: frac, width: barW))
            let dirMark   = entry.isDir ? Style.dim("/") : " "

            buf += "  \(pointer) \(n)\(dirMark)  \(bar)  \(size)" + eraseEOL + "\n"
        }

        buf += "\u{1B}[J"
        buf += eraseEOL + "\n"

        if let msg = statusMessage {
            buf += "  \(msg)" + eraseEOL + "\n"
        } else {
            let back = stack.count > 1 ? hintStr("⌫/esc", "back") + Style.dim("  ·  ") : ""
            let enter = currentEntries.isEmpty ? "" : hintStr("↵", "open folder") + Style.dim("  ·  ")
            buf += "  " + back + hintStr("↑↓", "move") + Style.dim("  ·  ") + enter + hintStr("esc", "quit") + eraseEOL + "\n"
        }

        writeRaw(buf)
    }

    private var eraseEOL: String { "\u{1B}[K" }

    private func truncate(_ s: String, to length: Int) -> String {
        guard s.count > length else { return s }
        return String(s.prefix(length - 1)) + "…"
    }

    private func rightAlign(_ s: String, width: Int) -> String {
        s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
    }
}

// MARK: - File-scope helpers

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
