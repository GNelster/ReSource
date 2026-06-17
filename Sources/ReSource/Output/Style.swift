import Foundation

enum Style {
    // MARK: - Banner

    static func banner() {
        let art = #"""
  _____       _____
 |  __ \     / ____|
 | |__) |___| (___   ___  _   _ _ __ ___ ___
 |  _  // _ \\___ \ / _ \| | | | '__/ __/ _ \
 | | \ \  __/____) | (_) | |_| | | | (_|  __/
 |_|  \_\___|_____/ \___/ \__,_|_|  \___\___|
"""#
        if Terminal.isColorEnabled {
            print(Color.green.apply(art))
        } else {
            print(art)
        }
        let tagline = "  Mac resource inspector"
        print(Terminal.isColorEnabled ? Color.dim.apply(tagline) : tagline)
        let credit = "  Developed by Nelcore Studios"
        print(Terminal.isColorEnabled ? Color.dim.apply(credit) : credit)
    }

    // MARK: - Section headers

    static func header(_ text: String) {
        let arrow = Color.green.apply("==>")
        print("\(arrow) \(bold(text))")
    }

    static func subheader(_ text: String) {
        let arrow = Color.dim.apply("-->")
        print("  \(arrow) \(text)")
    }

    // MARK: - Items

    static func item(_ text: String) {
        print("    \(text)")
    }

    // MARK: - Status lines

    static func success(_ text: String) {
        print("\(Color.green.apply("  ✓")) \(text)")
    }

    static func warning(_ text: String) {
        print("\(Color.yellow.apply("  !"))" + " \(text)")
    }

    static func error(_ text: String) {
        Terminal.writeError("\(Color.red.apply("  ✗")) \(text)")
    }

    // MARK: - Text modifiers

    static func bold(_ text: String) -> String {
        Terminal.isColorEnabled ? "\u{1B}[1m\(text)\u{1B}[0m" : text
    }

    static func dim(_ text: String) -> String {
        Terminal.isColorEnabled ? Color.dim.apply(text) : text
    }
}

// MARK: - Colors

enum Color: String {
    case green  = "\u{1B}[32m"
    case yellow = "\u{1B}[33m"
    case red    = "\u{1B}[31m"
    case dim    = "\u{1B}[2m"
    case reset  = "\u{1B}[0m"

    func apply(_ text: String) -> String {
        Terminal.isColorEnabled ? rawValue + text + Color.reset.rawValue : text
    }
}
