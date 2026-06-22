import Foundation

enum CleanCategory: String, CaseIterable {
    case derivedData       = "Xcode DerivedData"
    case deviceSupport     = "Xcode Device Support"
    case simulators        = "iOS Simulators"
    case simulatorLogs     = "Simulator Logs"
    case diagnosticReports = "Diagnostic Reports"
    case brew              = "Homebrew Cache"
    case npm               = "npm Cache"
    case yarn              = "Yarn Cache"
    case pip               = "pip Cache"
    case cargo             = "Rust / Cargo Cache"
    case gradle            = "Gradle Cache"
    case maven             = "Maven Cache"
    case cocoapods         = "CocoaPods Cache"
    case swiftPM           = "Swift Package Cache"
    case pnpm              = "pnpm Cache"
    case browserCaches     = "Browser Caches"
    case oldDownloads      = "Old Downloads  (1+ year)"
    case appLeftovers      = "App Leftovers"
    case deadAgentLeftovers = "Dead Agent Leftovers"
}

struct CleanItem {
    let name: String
    let path: String
    let category: CleanCategory
    let sizeBytes: Int64
}
