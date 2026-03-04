import Foundation
import GRDB
import Yams

// MARK: - Domain Store

/// SQLite-backed persistence for domain classification data.
/// Seeds from safelist-india.yaml on first run and learns new domains over time.
final class DomainStore {
    private let dbQueue: DatabaseQueue

    init() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("FreeNet", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)

        let dbPath = dbDir.appendingPathComponent("domains.db").path
        dbQueue = try DatabaseQueue(path: dbPath)

        try migrate()
    }

    /// Test-only initializer with an in-memory database.
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()
        try migrate()
    }

    // MARK: - Migration

    private func migrate() throws {
        try dbQueue.write { db in
            try DomainRecord.createTable(in: db)
        }
        try seedIfNeeded()
    }

    // MARK: - Seeding

    private func seedIfNeeded() throws {
        let count = try dbQueue.read { db in
            try DomainRecord.filter(Column("source") == DomainSource.preSeeded.rawValue).fetchCount(db)
        }
        guard count == 0 else { return }

        guard let url = Bundle.main.url(forResource: "safelist-india", withExtension: "yaml"),
              let yamlString = try? String(contentsOf: url, encoding: .utf8),
              let parsed = try? Yams.load(yaml: yamlString) as? [String: [String]] else {
            return
        }

        let now = Date()
        try dbQueue.write { db in
            for (_, domains) in parsed {
                for domain in domains {
                    let record = DomainRecord(
                        domain: domain,
                        classification: .safe,
                        failureType: nil,
                        source: .preSeeded,
                        learnedAt: now,
                        lastSeen: now,
                        hitCount: 0,
                        confidence: 1.0
                    )
                    try record.insert(db)
                }
            }
        }
    }

    // MARK: - Lookup

    /// Looks up a domain record, falling back to parent domain matching.
    /// e.g. "api.x.com" will match a rule for "x.com".
    func lookup(_ domain: String) throws -> DomainRecord? {
        try dbQueue.read { db in
            // Exact match first
            if let record = try DomainRecord.filter(Column("domain") == domain).fetchOne(db) {
                return record
            }

            // Walk up subdomain chain: api.x.com → x.com → com
            var parts = domain.split(separator: ".")
            while parts.count > 2 {
                parts.removeFirst()
                let parent = parts.joined(separator: ".")
                if let record = try DomainRecord.filter(Column("domain") == parent).fetchOne(db) {
                    return record
                }
            }

            return nil
        }
    }

    // MARK: - Queries

    func allDomains() throws -> [DomainRecord] {
        try dbQueue.read { db in
            try DomainRecord.order(Column("lastSeen").desc).fetchAll(db)
        }
    }

    func domains(withClassification classification: DomainClassification) throws -> [DomainRecord] {
        try dbQueue.read { db in
            try DomainRecord
                .filter(Column("classification") == classification.rawValue)
                .order(Column("lastSeen").desc)
                .fetchAll(db)
        }
    }

    func domainsLearnedToday() throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try dbQueue.read { db in
            try DomainRecord
                .filter(Column("learnedAt") >= startOfDay)
                .filter(Column("source") != DomainSource.preSeeded.rawValue)
                .fetchCount(db)
        }
    }

    // MARK: - Learning

    func learn(domain: String, classification: DomainClassification, failureType: FailureType?, source: DomainSource) throws {
        let now = Date()
        try dbQueue.write { db in
            if var existing = try DomainRecord.filter(Column("domain") == domain).fetchOne(db) {
                existing.classification = classification
                existing.failureType = failureType
                existing.lastSeen = now
                existing.hitCount += 1
                // Auto-learned or crowd data has lower initial confidence than user manual
                if source == .userManual {
                    existing.confidence = 1.0
                }
                try existing.update(db)
            } else {
                let confidence: Double = switch source {
                case .preSeeded: 1.0
                case .userManual: 1.0
                case .autoLearned: 0.6
                case .crowd: 0.5
                }
                let record = DomainRecord(
                    domain: domain,
                    classification: classification,
                    failureType: failureType,
                    source: source,
                    learnedAt: now,
                    lastSeen: now,
                    hitCount: 1,
                    confidence: confidence
                )
                try record.insert(db)
            }
        }
    }

    func updateClassification(domain: String, to classification: DomainClassification) throws {
        try dbQueue.write { db in
            if var record = try DomainRecord.filter(Column("domain") == domain).fetchOne(db) {
                record.classification = classification
                record.lastSeen = Date()
                try record.update(db)
            }
        }
    }

    func incrementHitCount(domain: String) throws {
        try dbQueue.write { db in
            if var record = try DomainRecord.filter(Column("domain") == domain).fetchOne(db) {
                record.hitCount += 1
                record.lastSeen = Date()
                try record.update(db)
            }
        }
    }

    // MARK: - Crowd Import

    func importCrowdData(_ entries: [CrowdDomainEntry]) throws {
        try dbQueue.write { db in
            let now = Date()
            for entry in entries {
                if var existing = try DomainRecord.filter(Column("domain") == entry.domain).fetchOne(db) {
                    // Don't overwrite user-manual or pre-seeded entries
                    guard existing.source != .userManual, existing.source != .preSeeded else { continue }
                    // Only update if crowd confidence is higher
                    guard entry.confidence > existing.confidence else { continue }
                    existing.classification = entry.classification
                    existing.failureType = entry.failureType
                    existing.confidence = entry.confidence
                    existing.lastSeen = now
                    try existing.update(db)
                } else {
                    let record = DomainRecord(
                        domain: entry.domain,
                        classification: entry.classification,
                        failureType: entry.failureType,
                        source: .crowd,
                        learnedAt: now,
                        lastSeen: now,
                        hitCount: 0,
                        confidence: entry.confidence
                    )
                    try record.insert(db)
                }
            }
        }
    }
}
