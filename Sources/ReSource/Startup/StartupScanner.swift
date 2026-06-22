import Foundation

struct StartupScanner {
    private let fm = FileManager.default

    func scan() -> [LaunchLocation: [LaunchItem]] {
        var result: [LaunchLocation: [LaunchItem]] = [:]
        for location in [LaunchLocation.userAgent, .systemAgent, .systemDaemon] {
            result[location] = scanDirectory(location)
        }
        let logins = loginItems()
        if !logins.isEmpty { result[.loginItem] = logins }
        return result
    }

    // MARK: - Login items (SMAppService / BTM)

    private func loginItems() -> [LaunchItem] {
        guard let raw = Shell.output("/usr/bin/sfltool", "dumpbtm"), !raw.isEmpty else { return [] }

        var items: [LaunchItem] = []
        var name: String?
        var bundleID: String?
        var urlStr: String?
        var enabled = true

        func flush() {
            guard let n = name else { return }
            let execPath: String? = urlStr
                .flatMap { URL(string: $0) }
                .map { url -> String in
                    var path = url.path
                    if path.hasSuffix("/") { path = String(path.dropLast()) }
                    return path
                }
            let status: LaunchStatus
            if let path = execPath {
                status = fm.fileExists(atPath: path) ? .alive : .dead(missingPath: path)
            } else {
                status = .noExecutable
            }
            items.append(LaunchItem(
                label:          bundleID ?? n,
                plistPath:      nil,
                location:       .loginItem,
                executablePath: execPath,
                displayName:    n,
                runAtLoad:      enabled,
                startInterval:  nil,
                status:         status
            ))
        }

        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Name:") {
                flush()
                name      = field(t, prefix: "Name:")
                bundleID  = nil
                urlStr    = nil
                enabled   = true
            } else if t.hasPrefix("Bundle ID:") || t.hasPrefix("BundleID:") {
                bundleID  = t.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            } else if t.hasPrefix("URL:") {
                urlStr    = field(t, prefix: "URL:")
            } else if t.hasPrefix("Enabled:") {
                let v = field(t, prefix: "Enabled:").lowercased()
                enabled   = v == "yes" || v == "true" || v == "1"
            }
        }
        flush()
        return items
    }

    private func field(_ line: String, prefix: String) -> String {
        String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Directory scan

    private func scanDirectory(_ location: LaunchLocation) -> [LaunchItem] {
        guard let dir = location.directory else { return [] }
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        return files
            .filter  { $0.hasSuffix(".plist") }
            .compactMap { parsePlist(at: (dir as NSString).appendingPathComponent($0), location: location) }
            .sorted  { $0.label < $1.label }
    }

    // MARK: - Plist parsing

    private func parsePlist(at path: String, location: LaunchLocation) -> LaunchItem? {
        guard let data = fm.contents(atPath: path),
              let raw  = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        let label = raw["Label"] as? String
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        let execPath = resolvedExecutable(from: raw)
        let status   = checkStatus(execPath)
        let name     = displayName(label: label, execPath: execPath)

        return LaunchItem(
            label:         label,
            plistPath:     path,
            location:      location,
            executablePath: execPath,
            displayName:   name,
            runAtLoad:     raw["RunAtLoad"] as? Bool ?? false,
            startInterval: raw["StartInterval"] as? Int,
            status:        status
        )
    }

    // MARK: - Executable resolution

    private let interpreters: Set<String> = [
        "/bin/sh", "/bin/bash", "/bin/zsh",
        "/usr/bin/python3", "/usr/bin/python",
        "/usr/bin/perl", "/usr/bin/ruby",
        "/usr/bin/osascript"
    ]

    private func resolvedExecutable(from plist: [String: Any]) -> String? {
        if let program = plist["Program"] as? String {
            return expand(program)
        }
        guard let args = plist["ProgramArguments"] as? [String], !args.isEmpty else {
            return nil
        }
        let first = expand(args[0])
        // If first arg is an interpreter, the real file is args[1]
        if interpreters.contains(first), args.count > 1 {
            return expand(args[1])
        }
        return first
    }

    private func expand(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return fm.homeDirectoryForCurrentUser.path + path.dropFirst(1)
        }
        return path
    }

    // MARK: - Status check

    private func checkStatus(_ execPath: String?) -> LaunchStatus {
        guard let path = execPath else { return .noExecutable }
        return fm.fileExists(atPath: path) ? .alive : .dead(missingPath: path)
    }

    // MARK: - Display name

    private func displayName(label: String, execPath: String?) -> String {
        // Try to find the .app bundle in the exec path and read its display name
        if let exec = execPath, let name = appName(fromPath: exec) {
            return name
        }
        // Fall back: humanise the label (com.spotify.webhelper → Spotify)
        return humanise(label)
    }

    private func appName(fromPath path: String) -> String? {
        let components = path.components(separatedBy: "/")
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }
        let bundlePath    = "/" + components[1...appIndex].joined(separator: "/")
        let infoPlistPath = bundlePath + "/Contents/Info.plist"

        if let data  = fm.contents(atPath: infoPlistPath),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let name = plist["CFBundleDisplayName"] as? String { return name }
            if let name = plist["CFBundleName"]        as? String { return name }
        }
        // Fall back to the .app filename without extension
        return components[appIndex].replacingOccurrences(of: ".app", with: "")
    }

    func humanise(_ label: String) -> String {
        // com.spotify.webhelper → Spotify
        // io.tailscale.ipn.macos → Tailscale
        let parts = label.components(separatedBy: ".")
        guard parts.count >= 2 else { return label }
        // parts[0] is the TLD (com, io, org…); parts[1] is the brand/company name
        let namePart = parts[1]
        return namePart
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
