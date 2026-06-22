import Testing
import Foundation
@testable import ReSource

// MARK: - Format.bytes

@Test func bytesFormatsKilobytes() {
    #expect(Format.bytes(1024) == "1.0 KB")
}

@Test func bytesFormatsMegabytes() {
    #expect(Format.bytes(1_048_576) == "1.0 MB")
}

@Test func bytesFormatsGigabytes() {
    #expect(Format.bytes(1_073_741_824) == "1.0 GB")
}

@Test func bytesFormatsLargeGigabytes() {
    // >= 100 GB should omit the decimal
    #expect(Format.bytes(107_374_182_400) == "100 GB")
}

@Test func bytesFormatsBytes() {
    #expect(Format.bytes(512) == "512 B")
}

// MARK: - Format.bar

@Test func barFullFraction() {
    let bar = Format.bar(fraction: 1.0, width: 10)
    #expect(bar == String(repeating: "█", count: 10))
}

@Test func barZeroFraction() {
    let bar = Format.bar(fraction: 0.0, width: 10)
    #expect(bar == String(repeating: "░", count: 10))
}

@Test func barClampsBeyondOne() {
    let bar = Format.bar(fraction: 2.0, width: 5)
    #expect(bar == String(repeating: "█", count: 5))
}

@Test func barHalfFraction() {
    let bar = Format.bar(fraction: 0.5, width: 10)
    #expect(bar.filter { $0 == "█" }.count == 5)
    #expect(bar.filter { $0 == "░" }.count == 5)
}

// MARK: - TMSnapshot.displayDate

@Test func snapshotDisplayDateParsesStandardName() {
    let snap = TMSnapshot(name: "com.apple.TimeMachine.2024-06-15-120000.local", bytes: nil)
    #expect(snap.displayDate == "Jun 15, 2024")
}

@Test func snapshotDisplayDateFallsBackToRawName() {
    let snap = TMSnapshot(name: "unknown-format", bytes: nil)
    #expect(snap.displayDate == "unknown-format")
}

@Test func snapshotDisplayDateHandlesJanuaryAndDecember() {
    let jan = TMSnapshot(name: "com.apple.TimeMachine.2023-01-01-000000", bytes: nil)
    #expect(jan.displayDate == "Jan 01, 2023")

    let dec = TMSnapshot(name: "com.apple.TimeMachine.2023-12-31-235959", bytes: nil)
    #expect(dec.displayDate == "Dec 31, 2023")
}

// MARK: - LaunchItem.isDead

@Test func launchItemIsDeadWhenStatusIsDead() {
    let item = LaunchItem(
        label: "com.example.helper",
        plistPath: "/Library/LaunchAgents/com.example.helper.plist",
        location: .userAgent,
        executablePath: "/nonexistent/helper",
        displayName: "Example Helper",
        runAtLoad: true,
        startInterval: nil,
        status: .dead(missingPath: "/nonexistent/helper")
    )
    #expect(item.isDead == true)
}

@Test func launchItemIsNotDeadWhenAlive() {
    let item = LaunchItem(
        label: "com.example.helper",
        plistPath: "/Library/LaunchAgents/com.example.helper.plist",
        location: .userAgent,
        executablePath: "/usr/bin/true",
        displayName: "Example Helper",
        runAtLoad: false,
        startInterval: nil,
        status: .alive
    )
    #expect(item.isDead == false)
}

@Test func loginItemHasNilPlistPath() {
    let item = LaunchItem(
        label: "com.example.app",
        plistPath: nil,
        location: .loginItem,
        executablePath: nil,
        displayName: "Example App",
        runAtLoad: true,
        startInterval: nil,
        status: .noExecutable
    )
    #expect(item.plistPath == nil)
    #expect(item.location == .loginItem)
}

// MARK: - StartupScanner.humanise

@Test func humanisesReverseDomainsToName() {
    let scanner = StartupScanner()
    #expect(scanner.humanise("com.spotify.webhelper") == "Spotify")
    #expect(scanner.humanise("io.tailscale.ipn.macos") == "Tailscale")
}

@Test func humanisesHyphensToSpaces() {
    let scanner = StartupScanner()
    // parts[1] is the brand name; hyphens in it become spaces
    let result = scanner.humanise("com.my-app.helper")
    #expect(result == "My App")
}

@Test func humanisesShortLabelUnchanged() {
    let scanner = StartupScanner()
    #expect(scanner.humanise("myhelper") == "myhelper")
}

// MARK: - CleanScanner.AppSet matching

@Test func appSetMatchesByBundleID() {
    var set = CleanScanner.AppSet()
    set.bundleIDs = ["com.spotify.client"]
    set.names = ["spotify"]
    #expect(set.matchesBundleID("com.spotify.client") == true)
    #expect(set.matchesBundleID("com.apple.finder")   == false)
}

@Test func appSetMatchesByNameSuffix() {
    var set = CleanScanner.AppSet()
    set.bundleIDs = ["com.spotify.client"]
    set.names = []
    // matches(name:) also checks if any bundleID ends with ".<name>"
    #expect(set.matches(name: "client") == true)
    #expect(set.matches(name: "unknown") == false)
}

@Test func appSetMatchesByDisplayName() {
    var set = CleanScanner.AppSet()
    set.bundleIDs = []
    set.names = ["spotify"]
    #expect(set.matches(name: "Spotify") == true)  // case-insensitive
    #expect(set.matches(name: "Discord") == false)
}

// MARK: - Config Codable

@Test func configRoundTrips() throws {
    var config = Config()
    config.oldDownloadsAgeDays = 180
    config.excludedCleanPaths = ["/tmp/keep", "/home/user/keep"]

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(Config.self, from: data)

    #expect(decoded.oldDownloadsAgeDays == 180)
    #expect(decoded.excludedCleanPaths == ["/tmp/keep", "/home/user/keep"])
}

@Test func configDefaultsAreReasonable() {
    let config = Config()
    #expect(config.oldDownloadsAgeDays == 365)
    #expect(config.excludedCleanPaths.isEmpty)
}

// MARK: - VolumeInfo computed properties

@Test func volumeInfoUsedBytes() {
    let vol = VolumeInfo(name: "Macintosh HD", totalBytes: 1000, freeBytes: 300, purgeableBytes: 0)
    #expect(vol.usedBytes == 700)
}

@Test func volumeInfoUsedFraction() {
    let vol = VolumeInfo(name: "Macintosh HD", totalBytes: 1000, freeBytes: 250, purgeableBytes: 0)
    #expect(abs(vol.usedFraction - 0.75) < 0.001)
}

@Test func volumeInfoUsedFractionZeroTotalIsZero() {
    let vol = VolumeInfo(name: "Empty", totalBytes: 0, freeBytes: 0, purgeableBytes: 0)
    #expect(vol.usedFraction == 0)
}

// MARK: - MemorySnapshot.usedBytes

@Test func memorySnapshotUsedBytesIsSum() {
    let snap = MemorySnapshot(
        totalBytes:      16_000_000_000,
        appBytes:        4_000_000_000,
        wiredBytes:      2_000_000_000,
        compressedBytes: 1_000_000_000,
        cachedBytes:     3_000_000_000,
        freeBytes:       6_000_000_000
    )
    #expect(snap.usedBytes == 7_000_000_000)
}
