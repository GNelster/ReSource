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
    case browserCaches     = "Browser Caches"
}

struct CleanItem {
    let name: String
    let path: String
    let category: CleanCategory
    let sizeBytes: Int64
}

