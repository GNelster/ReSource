import Foundation

final class ProgressBar {
    private let label: String
    private let total: Int
    private var current = 0
    private var lastLineLen = 0
    private let barWidth: Int

    init(label: String, total: Int) {
        self.label   = label
        self.total   = max(1, total)
        self.barWidth = max(20, min(40, TermSize.columns - 20))
    }

    func start() {
        print("  \(Style.bold(label))")
        render(item: "")
    }

    func tick(item: String = "") {
        current = min(current + 1, total)
        render(item: item)
    }

    // Prints a fully-filled bar immediately — for fast single-step operations.
    static func instant(label: String) {
        let barWidth = max(20, min(40, TermSize.columns - 20))
        let bar  = Color.green.apply(String(repeating: "#", count: barWidth))
        let line = "  [\(bar)]  100%  \(Style.dim(label))"
        print(line)
    }

    func complete(label completionLabel: String? = nil) {
        current = total
        // Overwrite the bar line with a final checkmark line
        let check = Color.green.apply("✓")
        let text  = completionLabel ?? label
        print("\r  \(check)  \(text)\u{1B}[K")
    }

    // MARK: - Private

    private func render(item: String) {
        let fraction = Double(current) / Double(total)
        let filled   = Int(fraction * Double(barWidth))
        let empty    = barWidth - filled

        let bar   = Color.green.apply(String(repeating: "#", count: filled))
                  + Style.dim(String(repeating: ".", count: empty))
        let pct   = String(format: "%3d%%", Int(fraction * 100))
        let trunc = item.count > 28 ? "…" + item.suffix(27) : item

        let line = "  [\(bar)]  \(pct)  \(Style.dim(trunc))"
        lastLineLen = 4 + barWidth + 2 + 5 + 2 + trunc.count   // approximate visible length

        print("\r\(line)\u{1B}[K", terminator: "")
        fflush(stdout)
    }
}
