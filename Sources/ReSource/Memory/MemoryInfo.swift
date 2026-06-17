import Foundation

struct MemorySnapshot {
    let totalBytes: Int64
    // Activity Monitor definitions:
    // App      = anonymous pages (heap/stack — what apps explicitly allocated)
    // Wired    = kernel/driver pages that can never be paged out
    // Compressed = pages the OS compressed to free physical space
    // Used     = App + Wired + Compressed  (always >= each component)
    // Cached   = inactive file-backed pages macOS holds speculatively (free-ish)
    // Free     = truly unused
    let appBytes:        Int64
    let wiredBytes:      Int64
    let compressedBytes: Int64
    let cachedBytes:     Int64
    let freeBytes:       Int64

    var usedBytes: Int64 { appBytes + wiredBytes + compressedBytes }
}

struct ProcessMemory {
    let pid: Int
    let name: String
    let rssBytes: Int64
}

enum MemoryInfo {
    static func snapshot() -> MemorySnapshot? {
        guard let totalStr    = Shell.output("/usr/sbin/sysctl", "-n", "hw.memsize"),
              let total       = Int64(totalStr.trimmingCharacters(in: .whitespacesAndNewlines)),
              let pageSizeStr = Shell.output("/usr/sbin/sysctl", "-n", "hw.pagesize"),
              let pageSize    = Int64(pageSizeStr.trimmingCharacters(in: .whitespacesAndNewlines)),
              let vmStat      = Shell.output("/usr/bin/vm_stat")
        else { return nil }

        func pages(_ key: String) -> Int64 {
            for line in vmStat.components(separatedBy: "\n") {
                guard line.contains(key) else { continue }
                let parts = line.components(separatedBy: ":")
                guard parts.count >= 2 else { continue }
                let num = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
                return Int64(num) ?? 0
            }
            return 0
        }

        let free        = pages("Pages free")
        let inactive    = pages("Pages inactive")
        let wired       = pages("Pages wired down")
        let speculative = pages("Pages speculative")
        let compressed  = pages("Pages occupied by compressor")
        let anonymous   = pages("Anonymous pages")
        // File-backed inactive pages are the macOS disk cache (Cached Files in Activity Monitor)
        let fileBacked  = pages("File-backed pages")
        // active file-backed are counted in anonymous for our purposes; inactive file-backed = cache
        let activeFileBacked = max(0, fileBacked - inactive)
        let cache = (fileBacked - activeFileBacked) * pageSize

        return MemorySnapshot(
            totalBytes:      total,
            appBytes:        anonymous * pageSize,
            wiredBytes:      wired * pageSize,
            compressedBytes: compressed * pageSize,
            cachedBytes:     max(0, cache),
            freeBytes:       (free + speculative) * pageSize
        )
    }

    static func topProcesses(limit: Int = 15) -> [ProcessMemory] {
        guard let out = Shell.output("/bin/ps", "-axm", "-o", "pid=,rss=,ucomm=") else { return [] }
        return out.components(separatedBy: "\n")
            .compactMap { line -> ProcessMemory? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard parts.count >= 3,
                      let pid   = Int(parts[0]),
                      let rssKB = Int64(parts[1])
                else { return nil }
                let name = parts[2...].joined(separator: " ")
                return ProcessMemory(pid: pid, name: name, rssBytes: rssKB * 1024)
            }
            .filter { $0.rssBytes > 0 }
            .prefix(limit)
            .map { $0 }
    }
}
