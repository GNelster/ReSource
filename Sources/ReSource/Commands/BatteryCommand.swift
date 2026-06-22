import ArgumentParser
import Foundation

struct BatteryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "battery",
        abstract: "Show battery health and cycle count.",
        discussion: "Reads data from system_profiler SPPowerDataType."
    )

    mutating func run() throws {
        Style.header("Battery")
        print()

        let spinner = Spinner("Reading battery info")
        spinner.start()
        let snap = BatteryInfo.snapshot()
        spinner.stop(success: snap != nil, label: snap != nil ? "Battery info loaded" : "Could not read battery data")
        print()

        guard let s = snap else {
            Style.warning("No battery found — this may be a desktop Mac or VM.")
            return
        }

        // ── Health ────────────────────────────────────────────
        Style.subheader("Health")
        print()

        let healthPct = Int((s.healthFraction * 100).rounded())
        let healthBar = Format.bar(fraction: s.healthFraction, width: 20)
        let healthColored: String
        switch healthPct {
        case 80...: healthColored = Color.green.apply(healthBar)
        case 60..<80: healthColored = Color.yellow.apply(healthBar)
        default:    healthColored = Color.red.apply(healthBar)
        }

        let conditionColored = s.condition.lowercased().contains("service")
            ? Color.yellow.apply(s.condition)
            : s.condition

        Style.item("\(healthColored)  \(Style.bold("\(healthPct)%"))  \(conditionColored)")
        print()

        let cols  = min(TermSize.columns, 80)
        let nameW = 18
        let valW  = 10

        func row(_ label: String, _ value: String) {
            Style.item("\(label.padded(to: nameW))  \(value)")
        }

        row("Cycle count",     Style.bold("\(s.cycleCount)"))
        if s.designCapacity > 0 {
            row("Max capacity",   Style.bold("\(s.maxCapacity) mAh") + Style.dim("  of \(s.designCapacity) mAh design"))
        }
        print()

        // ── Charge ────────────────────────────────────────────
        Style.subheader("Charge")
        print()

        let chargePct = Int((s.chargeFraction * 100).rounded())
        let chargeBar = Format.bar(fraction: s.chargeFraction, width: 20)
        let chargeColored = chargePct > 20
            ? Color.green.apply(chargeBar)
            : Color.yellow.apply(chargeBar)
        let chargingLabel = s.isCharging ? Style.dim("  (charging)") : ""
        Style.item("\(chargeColored)  \(Style.bold("\(chargePct)%"))\(chargingLabel)")
        if s.currentCharge > 0 && s.maxCapacity > 0 {
            print()
            Style.item(Style.dim("\(s.currentCharge) mAh remaining of \(s.maxCapacity) mAh"))
        }
        print()

        // ── Tip ───────────────────────────────────────────────
        if s.cycleCount > 800 {
            Style.warning("High cycle count (\(s.cycleCount)). Apple recommends service after ~1000 cycles.")
        } else if s.condition.lowercased().contains("service") {
            Style.warning("Battery condition is \"\(s.condition)\". Consider a replacement.")
        }
        print()
    }
}

private extension String {
    func padded(to length: Int) -> String {
        count >= length ? self : self + String(repeating: " ", count: length - count)
    }
}
