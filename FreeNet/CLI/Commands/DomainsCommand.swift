import ArgumentParser
import Foundation

struct DomainsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "domains",
        abstract: "Manage learned domains.",
        subcommands: [ListSubcommand.self, LookupSubcommand.self, LearnSubcommand.self],
        defaultSubcommand: ListSubcommand.self
    )
}

// MARK: - List

struct ListSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all learned domains."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    @Option(name: .long, help: "Filter by classification: safe, blocked, dns-hostile, unknown.")
    var filter: String?

    func run() throws {
        let state = try CLIState()

        var domains: [DomainRecord]
        if let filterValue = filter {
            guard let classification = parseClassification(filterValue) else {
                throw CLIError.invalidClassification(filterValue)
            }
            domains = try state.domainStore.domains(withClassification: classification)
        } else {
            domains = try state.domainStore.allDomains()
        }

        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(domains)
            print(String(data: data, encoding: .utf8) ?? "[]")
        } else {
            if domains.isEmpty {
                print("No domains found.")
                return
            }

            // Table header
            print("DOMAIN".padding(toLength: 40, withPad: " ", startingAt: 0)
                + "  " + "CLASS".padding(toLength: 12, withPad: " ", startingAt: 0)
                + "  " + "FAIL".padding(toLength: 6, withPad: " ", startingAt: 0)
                + "  " + "SOURCE".padding(toLength: 6, withPad: " ", startingAt: 0)
                + "  " + "HITS".padding(toLength: 5, withPad: " ", startingAt: 0))
            print(String(repeating: "─", count: 75))

            for d in domains {
                let fail = d.failureType?.shortLabel ?? "—"
                print(d.domain.padding(toLength: 40, withPad: " ", startingAt: 0)
                    + "  " + d.classification.displayLabel.padding(toLength: 12, withPad: " ", startingAt: 0)
                    + "  " + fail.padding(toLength: 6, withPad: " ", startingAt: 0)
                    + "  " + d.source.shortLabel.padding(toLength: 6, withPad: " ", startingAt: 0)
                    + "  " + "\(d.hitCount)".padding(toLength: 5, withPad: " ", startingAt: 0))
            }

            print("\n\(domains.count) domain(s)")
        }
    }
}

// MARK: - Lookup

struct LookupSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lookup",
        abstract: "Check the route decision for a domain."
    )

    @Argument(help: "The domain to look up (e.g. hdfcbank.com).")
    var domain: String

    func run() throws {
        let state = try CLIState()
        let route = state.learningEngine.routeFor(domain: domain)

        if let record = try state.domainStore.lookup(domain) {
            print("\(domain)")
            print("  Route:          \(route.label) (\(route.rawValue))")
            print("  Classification: \(record.classification.displayLabel)")
            if let ft = record.failureType {
                print("  Failure:        \(ft.shortLabel) (\(ft.rawValue))")
            }
            print("  Source:         \(record.source.shortLabel)")
            print("  Confidence:     \(String(format: "%.1f%%", record.confidence * 100))")
            print("  Hit count:      \(record.hitCount)")
        } else {
            print("\(domain)")
            print("  Route:          \(route.label) (\(route.rawValue))")
            print("  Classification: Unknown (no record)")
        }
    }
}

// MARK: - Learn

struct LearnSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "learn",
        abstract: "Manually classify a domain."
    )

    @Argument(help: "The domain to classify.")
    var domain: String

    @Argument(help: "Classification: safe, blocked, dns-hostile, unknown.")
    var classification: String

    func run() throws {
        guard let c = parseClassification(classification) else {
            throw CLIError.invalidClassification(classification)
        }

        let state = try CLIState()
        try state.domainStore.learn(
            domain: domain,
            classification: c,
            failureType: nil,
            source: .userManual
        )

        let route = state.learningEngine.routeFor(domain: domain)
        print("Learned: \(domain) → \(c.displayLabel) (route: \(route.label))")
    }
}

// MARK: - Helper

private func parseClassification(_ value: String) -> DomainClassification? {
    switch value.lowercased() {
    case "safe":                        return .safe
    case "blocked":                     return .blocked
    case "dns-hostile", "dnshostile":   return .dnsHostile
    case "unknown":                     return .unknown
    default:                            return nil
    }
}
