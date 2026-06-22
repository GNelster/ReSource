import Foundation

struct BatterySnapshot {
    let cycleCount:    Int
    let healthPercent: Int      // Maximum Capacity %
    let chargePercent: Int      // State of Charge %
    let condition:     String
    let isCharging:    Bool

    var healthFraction: Double { Double(healthPercent) / 100.0 }
    var chargeFraction: Double { Double(chargePercent) / 100.0 }
}

enum BatteryInfo {
    static func snapshot() -> BatterySnapshot? {
        guard let raw = Shell.run("/usr/sbin/system_profiler", "SPPowerDataType"),
              !raw.isEmpty
        else { return nil }

        func value(for key: String) -> String? {
            for line in raw.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.lowercased().hasPrefix(key.lowercased() + ":") {
                    return t.components(separatedBy: ":").dropFirst()
                        .joined(separator: ":")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            return nil
        }

        guard let cycleStr = value(for: "Cycle Count"), let cycles = Int(cycleStr) else { return nil }

        // "Maximum Capacity: 100%"
        let healthPct = value(for: "Maximum Capacity")
            .map { $0.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces) }
            .flatMap { Int($0) } ?? 0

        // "State of Charge (%): 97"
        let chargePct = value(for: "State of Charge (%)")
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0

        let condition  = value(for: "Condition") ?? "Normal"
        let charging   = value(for: "Charging")?.trimmingCharacters(in: .whitespaces).lowercased() == "yes"

        return BatterySnapshot(
            cycleCount:    cycles,
            healthPercent: healthPct,
            chargePercent: chargePct,
            condition:     condition,
            isCharging:    charging
        )
    }
}
