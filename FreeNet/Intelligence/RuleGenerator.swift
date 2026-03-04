import Foundation

// MARK: - Rule Generator

/// Converts domain classification state into Mihomo proxy rules.
struct RuleGenerator {
    private let domainStore: DomainStore

    init(domainStore: DomainStore) {
        self.domainStore = domainStore
    }

    // MARK: - Domain Rules

    /// Generates Mihomo rules from all classified domains.
    func generateRules() throws -> [String] {
        var rules: [String] = []

        let allDomains = try domainStore.allDomains()

        for record in allDomains {
            let proxyGroup: String
            switch record.classification {
            case .safe:
                proxyGroup = "DIRECT"
            case .blocked:
                proxyGroup = "VPN"
            case .dnsHostile:
                proxyGroup = "DIRECT"
            case .unknown:
                continue // Unknown domains use the default MATCH rule
            }
            rules.append("DOMAIN-SUFFIX,\(record.domain),\(proxyGroup)")
        }

        // Default catch-all: everything else goes through encrypted DNS
        rules.append("MATCH,ENCRYPTED")

        return rules
    }

    // MARK: - Ad Block Rules

    /// Returns REJECT rules for common ad and tracker domains.
    func generateAdBlockRules() -> [String] {
        adTrackerDomains.map { "DOMAIN-SUFFIX,\($0),REJECT" }
    }

    /// Generates the full rule set: ad-block rules first, then domain rules, then MATCH.
    func generateFullRuleSet() throws -> [String] {
        var rules: [String] = []
        rules.append(contentsOf: generateAdBlockRules())

        let domainRules = try generateRules()
        // Insert domain rules before the MATCH catch-all
        if let matchIndex = domainRules.lastIndex(where: { $0.hasPrefix("MATCH,") }) {
            rules.append(contentsOf: domainRules[..<matchIndex])
            rules.append(domainRules[matchIndex])
        } else {
            rules.append(contentsOf: domainRules)
        }

        return rules
    }
}

// MARK: - Ad/Tracker Domain List

private let adTrackerDomains: [String] = [
    // Google Ads
    "googleadservices.com",
    "googlesyndication.com",
    "doubleclick.net",
    "google-analytics.com",
    "googletagmanager.com",
    "googletagservices.com",
    "adservice.google.com",

    // Facebook / Meta
    "facebook.net",
    "fbcdn.net",
    "graph.facebook.com",

    // Common ad networks
    "ads.yahoo.com",
    "adnxs.com",
    "adsrvr.org",
    "rubiconproject.com",
    "pubmatic.com",
    "openx.net",
    "casalemedia.com",
    "criteo.com",
    "criteo.net",
    "outbrain.com",
    "taboola.com",
    "moat.com",
    "serving-sys.com",

    // Trackers
    "scorecardresearch.com",
    "quantserve.com",
    "mixpanel.com",
    "amplitude.com",
    "segment.io",
    "segment.com",
    "hotjar.com",
    "mouseflow.com",
    "fullstory.com",
    "crazyegg.com",

    // India-specific ad networks
    "inmobi.com",
    "vserv.com",
    "adiquity.com",
    "adcolony.com",
    "mopub.com",
]
