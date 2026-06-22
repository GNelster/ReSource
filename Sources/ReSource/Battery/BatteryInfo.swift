import Foundation

struct BatterySnapshot {
    let cycleCount:       Int
    let designCapacity:   Int       // mAh
    let maxCapacity:      Int       // mAh (current full-charge capacity)
    let currentCharge:    Int       // mAh
    let condition:        String    // "Normal", "Service Recommended", etc.
    let isCharging:       Bool

    var healthFraction: Double {
        guard designCapacity > 0 else { return 0 }
        return Double(maxCapacity) / Double(designCapacity)
    }

    var chargeFraction: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(currentCharge) / Double(maxCapacity)
    }
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

        let design  = value(for: "Full Charge Capacity (mAh)").flatMap { Int($0) }
                   ?? value(for: "Design Capacity").flatMap { Int($0) }
                   ?? 0
        let maxCap  = value(for: "Full Charge Capacity (mAh)").flatMap { Int($0) }
                   ?? value(for: "Maximum Capacity").flatMap { percentToMAh($0, design: design) }
                   ?? 0
        let current = value(for: "Charge Remaining (mAh)").flatMap { Int($0) } ?? 0
        let condition = value(for: "Condition") ?? "Unknown"
        let charging  = value(for: "Charging")?.lowercased() == "yes"
                     || value(for: "AC Charger Information") != nil

        return BatterySnapshot(
            cycleCount:     cycles,
            designCapacity: design,
            maxCapacity:    maxCap,
            currentCharge:  current,
            condition:      condition,
            isCharging:     charging
        )
    }

    private static func percentToMAh(_ str: String, design: Int) -> Int? {
        guard let pct = Double(str.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)),
              design > 0
        else { return nil }
        return Int((pct / 100.0) * Double(design))
    }
}
