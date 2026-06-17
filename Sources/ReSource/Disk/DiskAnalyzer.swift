import Foundation

struct DiskAnalyzer {
    let homePath: String

    init() {
        homePath = FileManager.default.homeDirectoryForCurrentUser.path
    }

    func analyze() throws -> DiskReport {
        let volume = volumeInfo()
        let dirs   = homeDirectorySizes()
        let snaps  = tmSnapshots()
        return DiskReport(volume: volume, directories: dirs, snapshots: snaps)
    }

    // MARK: - Volume

    func volumeInfo() -> VolumeInfo? {
        guard let raw = Shell.run("/usr/sbin/diskutil", "info", "-plist", "/"),
              let data = raw.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        let name          = plist["VolumeName"] as? String ?? "Macintosh HD"
        let total         = int64(plist, "TotalSize")
        let containerFree = int64(plist, "APFSContainerFree")
        let volumeFree    = int64(plist, "VolumeAvailableSpace")
        let free          = containerFree > 0 ? containerFree : volumeFree
        let purgeable     = containerFree > 0 ? max(0, containerFree - volumeFree) : 0

        return VolumeInfo(name: name, totalBytes: total, freeBytes: free, purgeableBytes: purgeable)
    }

    private func int64(_ dict: [String: Any], _ key: String) -> Int64 {
        if let v = dict[key] as? Int64 { return v }
        if let v = dict[key] as? Int   { return Int64(v) }
        if let v = dict[key] as? UInt  { return Int64(v) }
        return 0
    }

    // MARK: - Home directory

    /// Returns the list of immediate subdirectories without sizes (fast).
    func homeSubdirectories() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: homePath) else { return [] }
        return contents.compactMap { name -> String? in
            let full = (homePath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            return isDir.boolValue ? full : nil
        }
    }

    /// Returns the disk usage of a single directory (blocks until du completes).
    /// Uses Shell.output so partial results from permission-denied subdirectories
    /// are still captured — du exits 1 on any permission error even if it measured most files.
    func sizeOf(path: String) -> Int64 {
        guard let raw = Shell.output("/usr/bin/du", "-sk", path),
              let kbStr = raw.components(separatedBy: "\t").first,
              let kb = Int64(kbStr.trimmingCharacters(in: .whitespaces)) else { return 0 }
        return kb * 1024
    }

    /// Returns true if the process has Full Disk Access.
    /// ~/Library/Messages/chat.db is TCC-gated and only readable with FDA.
    func hasFDA() -> Bool {
        let probe = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db").path
        return FileManager.default.isReadableFile(atPath: probe)
    }

    func homeDirectorySizes() -> [DirectoryEntry] {
        homeSubdirectories().map { path in
            let name = (path as NSString).lastPathComponent
            return DirectoryEntry(name: name, path: path, bytes: sizeOf(path: path))
        }.sorted { $0.bytes > $1.bytes }
    }

    /// Returns true if iCloud Drive Desktop & Documents syncing is active.
    func iCloudDriveEnabled() -> Bool {
        let icloudDocs = homeDirectory
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Documents")
        return FileManager.default.fileExists(atPath: icloudDocs.path)
    }

    private var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: - Time Machine

    func tmSnapshots() -> [TMSnapshot] {
        // Try plist output first (macOS 14+ may include sizes)
        if let raw = Shell.run("/usr/bin/tmutil", "listlocalsnapshots", "-plist", "/"),
           let data = raw.data(using: .utf8),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let list = plist["Snapshots"] as? [[String: Any]] {
            return list.compactMap { snap in
                guard let name = snap["SnapshotName"] as? String else { return nil }
                let size = snap["SnapshotSize"].flatMap { v -> Int64? in
                    if let i = v as? Int64 { return i }
                    if let i = v as? Int   { return Int64(i) }
                    return nil
                }
                return TMSnapshot(name: name, bytes: size)
            }
        }

        // Fall back to plain text output
        guard let raw = Shell.run("/usr/bin/tmutil", "listlocalsnapshots", "/") else { return [] }
        return raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { TMSnapshot(name: $0, bytes: nil) }
    }
}
