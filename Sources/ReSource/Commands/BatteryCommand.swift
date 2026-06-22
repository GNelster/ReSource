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

        let healthBar = Format.bar(fraction: s.healthFraction, width: 20)
        let healthColored: String
        switch s.healthPercent {
        case 80...: healthColored = Color.green.apply(healthBar)
        case 60..<80: healthColored = Color.yellow.apply(healthBar)
        default:    healthColored = Color.red.apply(healthBar)
        }

        let conditionColored = s.condition.lowercased().contains("service")
            ? Color.yellow.apply(s.condition)
            : s.condition

        Style.item("\(healthColored)  \(Style.bold("\(s.healthPercent)%"))  \(conditionColored)")
        print()
        Style.item("Cycle count  \(Style.bold("\(s.cycleCount)"))")
        print()

        // ── Charge ────────────────────────────────────────────
        Style.subheader("Charge")
        print()

        let chargeBar = Format.bar(fraction: s.chargeFraction, width: 20)
        let chargeColored = s.chargePercent > 20
            ? Color.green.apply(chargeBar)
            : Color.yellow.apply(chargeBar)
        let chargingLabel = s.isCharging ? Style.dim("  (charging)") : ""
        Style.item("\(chargeColored)  \(Style.bold("\(s.chargePercent)%"))\(chargingLabel)")
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
