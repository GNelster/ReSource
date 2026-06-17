import Foundation

struct MenuEntry {
    let name: String
    let description: String
    let action: () throws -> Void
}

final class MainMenu {
    private let entries: [MenuEntry]
    private var selected = 0
    private var exitPrimed = false          // first q/Ctrl-C arms the exit
    private var terminal = RawTerminal()

    init(entries: [MenuEntry]) {
        self.entries = entries
    }

    func run() throws {
        terminal.enable()
        Cursor.hide()

        defer {
            Cursor.show()
            terminal.disable()
            Cursor.clear()
        }

        while true {
            render(exitWarning: exitPrimed)

            let key = readKey()

            // Reset exit-prime on any non-quit key
            if key != .quit { exitPrimed = false }

            switch key {
            case .up:
                selected = max(0, selected - 1)

            case .down:
                selected = min(entries.count - 1, selected + 1)

            case .enter:
                try runSelected()

            case .space, .delete:
                break

            case .quit:
                if exitPrimed {
                    return      // second press → actually exit
                }
                exitPrimed = true

            case .other:
                break
            }
        }
    }

    // MARK: - Private

    private func runSelected() throws {
        Cursor.show()
        Cursor.clear()

        let entry = entries[selected]
        try entry.action()

        print()
        print("  " + hint("any key", "return to menu"))
        fflush(stdout)
        _ = readKey()

        Cursor.hide()
    }

    private func render(exitWarning: Bool) {
        Cursor.clear()
        Style.banner()
        print()

        for (i, entry) in entries.enumerated() {
            if i == selected {
                let marker = Color.green.apply("  ▶")
                let name   = Style.bold(entry.name.padded(to: 10))
                print("\(marker)  \(name)  \(entry.description)")
            } else {
                let name = entry.name.padded(to: 10)
                print("       \(name)  \(Style.dim(entry.description))")
            }
        }

        print()
        if exitWarning {
            let msg = Color.yellow.apply("  esc") + Style.dim(" exit  ·  ") + Color.yellow.apply("press again to confirm")
            print(msg)
        } else {
            let hints = hint("↑↓", "move") + Style.dim("  ·  ") + hint("↵", "select") + Style.dim("  ·  ") + hint("esc", "exit")
            print("  " + hints)
        }
        fflush(stdout)
    }
}

// MARK: - Helpers

private func hint(_ key: String, _ label: String) -> String {
    Style.bold(key) + Style.dim(" \(label)")
}

private extension String {
    func padded(to length: Int) -> String {
        if count >= length { return self }
        return self + String(repeating: " ", count: length - count)
    }
}

// Make Key equatable so we can compare to .quit
extension Key: Equatable {}
