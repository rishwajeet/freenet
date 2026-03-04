import Foundation

// MARK: - Block Report (sent to crowd API)

struct BlockReport: Codable {
    let domain: String
    let country: String
    let failureType: FailureType
    let timestamp: Date
    let appVersion: String

    init(domain: String, failureType: FailureType) {
        self.domain = domain
        self.country = Locale.current.region?.identifier ?? "unknown"
        self.failureType = failureType
        self.timestamp = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - Crowd Blocklist (received from crowd API)

struct CrowdBlocklist: Codable {
    let version: Int
    let updatedAt: Date
    let domains: [CrowdDomainEntry]
}

struct CrowdDomainEntry: Codable {
    let domain: String
    let classification: DomainClassification
    let failureType: FailureType?
    let reportCount: Int
    let countries: [String]
    let confidence: Double
}
