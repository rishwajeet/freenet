import Foundation
import GRDB

// MARK: - Domain Classification

enum DomainClassification: String, Codable, DatabaseValueConvertible {
    case safe        // Banking, govt, UPI — always RAW DIRECT
    case blocked     // Geo-blocked / censored — always VPN
    case dnsHostile  // Breaks under encrypted DNS — always RAW DIRECT
    case unknown     // Default — route through ENCRYPTED
}

enum FailureType: String, Codable, DatabaseValueConvertible {
    case connectionReset     // TCP RST
    case dnsFailure          // NXDOMAIN
    case tlsFailure          // TLS handshake / SNI blocking
    case httpForbidden       // HTTP 451
    case contentRestriction  // "not available in your country"
    case timeout             // >5s connection timeout
    case emptyResponse       // Empty body where content expected
    case dnsHostile          // Site refuses encrypted DNS IPs
}

enum DomainSource: String, Codable, DatabaseValueConvertible {
    case preSeeded   // From safelist-india.yaml
    case autoLearned // Detected by FailureDetector
    case crowd       // From crowd intelligence
    case userManual  // User override
}

// MARK: - Domain State Record

struct DomainRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "domains"

    var id: Int64?
    var domain: String
    var classification: DomainClassification
    var failureType: FailureType?
    var source: DomainSource
    var learnedAt: Date
    var lastSeen: Date
    var hitCount: Int
    var confidence: Double // 0.0–1.0, higher = more certain

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Table Creation

extension DomainRecord {
    static func createTable(in db: Database) throws {
        try db.create(table: databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("domain", .text).notNull().unique()
            t.column("classification", .text).notNull().defaults(to: DomainClassification.unknown.rawValue)
            t.column("failureType", .text)
            t.column("source", .text).notNull()
            t.column("learnedAt", .datetime).notNull()
            t.column("lastSeen", .datetime).notNull()
            t.column("hitCount", .integer).notNull().defaults(to: 1)
            t.column("confidence", .double).notNull().defaults(to: 0.5)
        }

        try db.create(index: "idx_domains_classification", on: databaseTableName,
                       columns: ["classification"], ifNotExists: true)
        try db.create(index: "idx_domains_domain", on: databaseTableName,
                       columns: ["domain"], unique: true, ifNotExists: true)
    }
}
