import Foundation
import Darwin


// Class for Clean Viewing of Lists.
final class CleanListView {

    // MARK: - Types

    private struct Row {
        let item: CleanItem
        var selected: Bool
    }


    // MARK: - State

    private var rows: [Row]
    private var cursor: Int = 0
    private var scrollOffset: Int = 0
    private var statusMessage: String? = nil

    // MARK: - Init

    init(items: [CleanItem]) {
        self.rows = items.map { Row(item: $0, selected: true) }
    }

    // MARK: - Run loop

    func run() throws {
        guard !rows.isEmpty else {
            print(Style.dim("  Nothing found to clean."))
            return
        }

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
                let selected = rows.filter { $0.selected }
                if selected.isEmpty {
                    statusMessage = "Nothing selected — press enter to mark items."
                } else {
                    writeRaw("\u{1B}[?1049l\u{1B}[?25h")
                    var savedTerm = termios()
                    tcgetattr(STDIN_FILENO, &savedTerm)
                    var normal = savedTerm
                    normal.c_lflag |= tcflag_t(ICANON | ECHO | ISIG)
                    normal.c_iflag |= tcflag_t(ICRNL)
                    tcsetattr(STDIN_FILENO, TCSAFLUSH, &normal)

                    trashSelected(selected)

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

    // MARK: - Action

    private func trashSelected(_ selected: [Row]) {
        let fm = FileManager.default
        var trashed = 0
        for row in selected {
            do {
                try fm.trashItem(at: URL(fileURLWithPath: row.item.path), resultingItemURL: nil)
                trashed += 1
            } catch {
                print("  Could not trash \(row.item.name): \(error.localizedDescription)")
                fflush(stdout)
            }
        }
        let freed = selected.prefix(trashed).reduce(Int64(0)) { $0 + $1.item.sizeBytes }
        if trashed == selected.count {
            statusMessage = "\(trashed) \(trashed == 1 ? "item" : "items") moved to Trash  ·  ~\(Format.bytes(freed)) freed."
        } else {
            statusMessage = "\(trashed) of \(selected.count) moved to Trash — see above for errors."
        }
    }

    // MARK: - Scroll

    private func adjustScroll() {
        let h = viewportHeight
        if cursor < scrollOffset      { scrollOffset = cursor }
        if cursor >= scrollOffset + h  { scrollOffset = cursor - h + 1 }
    }

    private var viewportHeight: Int { max(4, TermSize.rows - 9) }

    // MARK: - Render

    private func render() {
        var buf = "\u{1B}[H"

        let selectedItems = rows.filter { $0.selected }
        let totalSize     = rows.reduce(Int64(0)) { $0 + $1.item.sizeBytes }
        let selectedSize  = selectedItems.reduce(Int64(0)) { $0 + $1.item.sizeBytes }

        buf += Color.green.apply("==>") + " " + Style.bold("Clean") + eraseEOL + "\n"

        var summary = Style.dim("  \(rows.count) items  ·  \(Format.bytes(totalSize))")
        if !selectedItems.isEmpty {
            summary += "  " + Color.green.apply("\(selectedItems.count) selected  ·  \(Format.bytes(selectedSize))")
        }
        buf += summary + eraseEOL + "\n"
        buf += eraseEOL + "\n"

        let visibleEnd = min(scrollOffset + viewportHeight, rows.count)
        var lastCat: CleanCategory? = nil

        for i in scrollOffset..<visibleEnd {
            let cat = rows[i].item.category
            if cat != lastCat {
                if lastCat != nil { buf += eraseEOL + "\n" }
                buf += "  " + Style.dim(cat.rawValue) + eraseEOL + "\n"
                lastCat = cat
            }
            buf += rowString(rows[i], index: i) + eraseEOL + "\n"
        }

        buf += "\u{1B}[J"
        buf += eraseEOL + "\n"

        if let msg = statusMessage {
            buf += "  " + Color.yellow.apply(msg) + eraseEOL + "\n"
        } else {
            buf += "  "
                + cleanHint("↑↓", "move")
                + Style.dim("  ·  ") + cleanHint("↵", "select")
                + Style.dim("  ·  ") + cleanHint("⌫", "move to Trash")
                + Style.dim("  ·  ") + cleanHint("esc", "back")
                + eraseEOL + "\n"
        }

        writeRaw(buf)
    }

    private var eraseEOL: String { "\u{1B}[K" }

    private func rowString(_ row: Row, index: Int) -> String {
        let isCursor = index == cursor
        let pointer  = isCursor ? Color.green.apply("▶") : " "
        let checkbox = row.selected ? Color.green.apply("[✓]") : Style.dim("[ ]")
        let name     = row.item.name.cleanPadded(to: 32)
        let n        = isCursor ? Style.bold(name) : name
        let size     = Style.dim(Format.bytes(row.item.sizeBytes))
        return "  \(pointer) \(checkbox) \(n)  \(size)"
    }
}

// MARK: - File-scope helpers

private func cleanHint(_ key: String, _ label: String) -> String {
    Style.bold(key) + Style.dim(" \(label)")
}

private func writeRaw(_ s: String) {
    s.withCString { ptr in
        Darwin.write(STDOUT_FILENO, ptr, strlen(ptr))
    }
}

private extension String {
    func cleanPadded(to length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }
}
