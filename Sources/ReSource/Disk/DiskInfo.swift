import Foundation

struct VolumeInfo {
    let name: String
    let totalBytes: Int64
    let freeBytes: Int64
    let purgeableBytes: Int64

    var usedBytes: Int64 { totalBytes - freeBytes }
    var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
}

struct DirectoryEntry {
    let name: String
    let path: String
    let bytes: Int64
}

struct TMSnapshot {
    let name: String
    let bytes: Int64?

    var displayDate: String {
        // Name format: com.apple.TimeMachine.2024-06-15-120000.local
        let parts = name.components(separatedBy: ".")
        for part in parts {
            let digits = part.filter { $0.isNumber || $0 == "-" }
            // Match YYYY-MM-DD-HHmmss
            if digits.count >= 10 {
                let datePart = String(digits.prefix(10))  // YYYY-MM-DD
                let comps = datePart.components(separatedBy: "-")
                if comps.count >= 3 {
                    let months = ["Jan","Feb","Mar","Apr","May","Jun",
                                  "Jul","Aug","Sep","Oct","Nov","Dec"]
                    if let m = Int(comps[1]), m >= 1, m <= 12 {
                        return "\(months[m-1]) \(comps[2]), \(comps[0])"
                    }
                }
            }
        }
        return name
    }
}

struct DiskReport {
    let volume: VolumeInfo?
    let directories: [DirectoryEntry]
    let snapshots: [TMSnapshot]
}
