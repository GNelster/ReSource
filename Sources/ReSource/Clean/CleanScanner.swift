import Foundation

struct CleanScanner {
    private let fm   = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    func scan() -> [CleanItem] {
        var items: [CleanItem] = []
        items += derivedData()
        items += deviceSupport()
        items += simulators()
        items += simulatorLogs()
        items += diagnosticReports()
        items += brewCache()
        items += npmCache()
        items += yarnCache()
        items += pipCache()
        items += browserCaches()
        items += oldDownloads()
        items += appLeftovers()
        return items
    }

    // MARK: - Categories

    private func derivedData() -> [CleanItem] {
        let base = "\(home)/Library/Developer/Xcode/DerivedData"
        guard let entries = try? fm.contentsOfDirectory(atPath: base) else { return [] }

        return entries.compactMap { entry -> CleanItem? in
            guard entry != ".DS_Store" else { return nil }
            let path = "\(base)/\(entry)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let parts = entry.components(separatedBy: "-")
            let name  = parts.count > 1 ? parts.dropLast().joined(separator: "-") : entry
            return CleanItem(name: name, path: path, category: .derivedData, sizeBytes: sizeOf(path))
        }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func deviceSupport() -> [CleanItem] {
        let platforms = ["iOS DeviceSupport", "tvOS DeviceSupport", "watchOS DeviceSupport", "xrOS DeviceSupport"]
        var items: [CleanItem] = []
        for platform in platforms {
            let base = "\(home)/Library/Developer/Xcode/\(platform)"
            guard let entries = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for entry in entries where entry != ".DS_Store" {
                let path = "\(base)/\(entry)"
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                let label = platform.replacingOccurrences(of: " DeviceSupport", with: "") + "  \(entry)"
                items.append(CleanItem(name: label, path: path, category: .deviceSupport, sizeBytes: sizeOf(path)))
            }
        }
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func simulators() -> [CleanItem] {
        guard let json = Shell.output("/usr/bin/xcrun", "simctl", "list", "devices", "--json"),
              let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtimes = obj["devices"] as? [String: [[String: Any]]]
        else { return [] }

        let devBase = "\(home)/Library/Developer/CoreSimulator/Devices"
        var items: [CleanItem] = []

        for (_, deviceList) in runtimes {
            for device in deviceList {
                guard let available = device["isAvailable"] as? Bool, !available,
                      let udid = device["udid"] as? String,
                      let name = device["name"] as? String
                else { continue }

                let path = "\(devBase)/\(udid)"
                guard fm.fileExists(atPath: path) else { continue }
                items.append(CleanItem(name: name, path: path, category: .simulators, sizeBytes: sizeOf(path)))
            }
        }
        return items
    }

    private func simulatorLogs() -> [CleanItem] {
        let path = "\(home)/Library/Logs/CoreSimulator"
        guard fm.fileExists(atPath: path) else { return [] }
        let size = sizeOf(path)
        guard size > 0 else { return [] }
        return [CleanItem(name: "CoreSimulator logs", path: path, category: .simulatorLogs, sizeBytes: size)]
    }

    private func diagnosticReports() -> [CleanItem] {
        let path = "\(home)/Library/Logs/DiagnosticReports"
        guard fm.fileExists(atPath: path) else { return [] }
        let size = sizeOf(path)
        guard size > 0 else { return [] }
        return [CleanItem(name: "Crash & diagnostic reports", path: path, category: .diagnosticReports, sizeBytes: size)]
    }

    private func brewCache() -> [CleanItem] {
        let brewBins = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        var cachePath: String? = nil

        for brew in brewBins {
            if let p = Shell.output(brew, "--cache")?.trimmingCharacters(in: .whitespacesAndNewlines),
               !p.isEmpty, fm.fileExists(atPath: p) {
                cachePath = p
                break
            }
        }
        if cachePath == nil {
            let fallback = "\(home)/Library/Caches/Homebrew"
            if fm.fileExists(atPath: fallback) { cachePath = fallback }
        }

        guard let path = cachePath else { return [] }
        let size = sizeOf(path)
        guard size > 0 else { return [] }
        return [CleanItem(name: "Homebrew downloads", path: path, category: .brew, sizeBytes: size)]
    }

    private func npmCache() -> [CleanItem] {
        let path = "\(home)/.npm/_cacache"
        guard fm.fileExists(atPath: path) else { return [] }
        let size = sizeOf(path)
        guard size > 0 else { return [] }
        return [CleanItem(name: "npm cache", path: path, category: .npm, sizeBytes: size)]
    }

    private func yarnCache() -> [CleanItem] {
        var path = "\(home)/.yarn/cache"
        if !fm.fileExists(atPath: path) { path = "\(home)/Library/Caches/yarn" }
        guard fm.fileExists(atPath: path) else { return [] }
        let size = sizeOf(path)
        guard size > 0 else { return [] }
        return [CleanItem(name: "Yarn cache", path: path, category: .yarn, sizeBytes: size)]
    }

    private func pipCache() -> [CleanItem] {
        let path = "\(home)/Library/Caches/pip"
        guard fm.fileExists(atPath: path) else { return [] }
        let size = sizeOf(path)
        guard size > 0 else { return [] }
        return [CleanItem(name: "pip cache", path: path, category: .pip, sizeBytes: size)]
    }

    private func browserCaches() -> [CleanItem] {
        let candidates: [(String, String)] = [
            ("Safari",  "\(home)/Library/Caches/com.apple.Safari"),
            ("Chrome",  "\(home)/Library/Caches/Google/Chrome"),
            ("Firefox", "\(home)/Library/Caches/Firefox"),
            ("Arc",     "\(home)/Library/Caches/company.thebrowser.Browser"),
            ("Brave",   "\(home)/Library/Caches/BraveSoftware/Brave-Browser"),
            ("Edge",    "\(home)/Library/Caches/Microsoft Edge"),
        ]
        return candidates.compactMap { (name, path) -> CleanItem? in
            guard fm.fileExists(atPath: path) else { return nil }
            let size = sizeOf(path)
            guard size > 0 else { return nil }
            return CleanItem(name: "\(name) cache", path: path, category: .browserCaches, sizeBytes: size)
        }
    }

    private func oldDownloads() -> [CleanItem] {
        let base   = "\(home)/Downloads"
        guard let entries = try? fm.contentsOfDirectory(atPath: base) else { return [] }
        let cutoff = Date().addingTimeInterval(-365 * 24 * 3600)
        var items: [CleanItem] = []

        for entry in entries where entry != ".DS_Store" {
            let path = "\(base)/\(entry)"
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let modified = attrs[.modificationDate] as? Date,
                  modified < cutoff
            else { continue }

            let years = max(1, Int(Date().timeIntervalSince(modified) / (365 * 24 * 3600)))
            let label = years >= 2 ? "\(entry)  (\(years)y old)" : "\(entry)  (1y old)"
            items.append(CleanItem(name: label, path: path, category: .oldDownloads, sizeBytes: sizeOf(path)))
        }

        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func appLeftovers() -> [CleanItem] {
        let known = installedAppSet()
        var items: [CleanItem] = []

        // Application Support — folders named after apps
        let appSupport = "\(home)/Library/Application Support"
        if let entries = try? fm.contentsOfDirectory(atPath: appSupport) {
            for entry in entries where entry != ".DS_Store" {
                guard !known.matches(name: entry) else { continue }
                let path = "\(appSupport)/\(entry)"
                let size = sizeOf(path)
                guard size >= 1_048_576 else { continue }
                items.append(CleanItem(name: entry, path: path, category: .appLeftovers, sizeBytes: size))
            }
        }

        // Containers — folders named by bundle ID
        let containers = "\(home)/Library/Containers"
        if let entries = try? fm.contentsOfDirectory(atPath: containers) {
            for entry in entries where entry != ".DS_Store" {
                guard !entry.hasPrefix("com.apple.") else { continue }
                guard !known.matchesBundleID(entry) else { continue }
                let path = "\(containers)/\(entry)"
                let size = sizeOf(path)
                guard size >= 1_048_576 else { continue }
                items.append(CleanItem(name: entry, path: path, category: .appLeftovers, sizeBytes: size))
            }
        }

        // Group Containers
        let groupContainers = "\(home)/Library/Group Containers"
        if let entries = try? fm.contentsOfDirectory(atPath: groupContainers) {
            for entry in entries where entry != ".DS_Store" {
                let bundleID = entry.hasPrefix("group.") ? String(entry.dropFirst(6)) : entry
                guard !bundleID.hasPrefix("com.apple.") else { continue }
                guard !known.matchesBundleID(bundleID) else { continue }
                let path = "\(groupContainers)/\(entry)"
                let size = sizeOf(path)
                guard size >= 1_048_576 else { continue }
                items.append(CleanItem(name: entry, path: path, category: .appLeftovers, sizeBytes: size))
            }
        }

        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    // MARK: - App matching

    private struct AppSet {
        var bundleIDs: Set<String> = []
        var names: Set<String> = []

        func matchesBundleID(_ id: String) -> Bool {
            bundleIDs.contains(id.lowercased())
        }

        func matches(name: String) -> Bool {
            let lower = name.lowercased()
            if names.contains(lower) { return true }
            if bundleIDs.contains(lower) { return true }
            for id in bundleIDs where id.hasSuffix(".\(lower)") { return true }
            return false
        }
    }

    private func installedAppSet() -> AppSet {
        var set = AppSet()
        let appDirs = ["/Applications", "/System/Applications", "\(home)/Applications"]

        for dir in appDirs {
            guard let apps = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for app in apps where app.hasSuffix(".app") {
                let plist = "\(dir)/\(app)/Contents/Info.plist"
                if let dict = NSDictionary(contentsOfFile: plist) {
                    if let bid = dict["CFBundleIdentifier"] as? String {
                        set.bundleIDs.insert(bid.lowercased())
                        if let last = bid.components(separatedBy: ".").last {
                            set.names.insert(last.lowercased())
                        }
                    }
                    if let name = dict["CFBundleName"] as? String        { set.names.insert(name.lowercased()) }
                    if let name = dict["CFBundleDisplayName"] as? String { set.names.insert(name.lowercased()) }
                }
                set.names.insert(app.replacingOccurrences(of: ".app", with: "").lowercased())
            }
        }

        return set
    }

    // MARK: - Helpers

    private func sizeOf(_ path: String) -> Int64 {
        guard let out = Shell.output("/usr/bin/du", "-sk", path),
              let kbStr = out.split(separator: "\t").first,
              let kb = Int64(kbStr.trimmingCharacters(in: .whitespaces))
        else { return 0 }
        return kb * 1024
    }
}
