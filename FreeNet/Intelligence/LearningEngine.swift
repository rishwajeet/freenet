import Foundation

// MARK: - Learning Engine

/// Core routing decision engine. Determines the route for each domain and learns from failures.
final class LearningEngine {
    private let domainStore: DomainStore
    private let failureDetector = FailureDetector()

    /// Called whenever a new domain classification is learned.
    var onDomainLearned: ((DomainRecord) -> Void)?

    init(domainStore: DomainStore) {
        self.domainStore = domainStore
    }

    // MARK: - Routing Decision

    /// The meta-rule: determines which route to use for a domain.
    ///
    /// Decision tree:
    /// 1. SAFELISTED? -> .direct (raw, no proxy, no encrypted DNS)
    /// 2. KNOWN BLOCKED? -> .vpn (WireGuard tunnel)
    /// 3. KNOWN DNS-HOSTILE? -> .direct (raw, no encrypted DNS)
    /// 4. DEFAULT -> .encrypted (DoH + ad blocking)
    func routeFor(domain: String) -> RouteType {
        guard let record = try? domainStore.lookup(domain) else {
            return .encrypted
        }

        // Update hit count in background
        try? domainStore.incrementHitCount(domain: record.domain)

        switch record.classification {
        case .safe:
            return .direct
        case .blocked:
            return .vpn
        case .dnsHostile:
            return .direct
        case .unknown:
            return .encrypted
        }
    }

    // MARK: - Learning from Failure

    /// Reports a failure for a domain. Analyzes the failure type and updates classification.
    func reportFailure(domain: String, failureType: FailureType) async {
        let classification: DomainClassification
        if failureDetector.isDNSHostileSignature(failureType) {
            classification = .dnsHostile
        } else if failureDetector.isBlockSignature(failureType) {
            classification = .blocked
        } else {
            // Non-block failures (timeout, empty response) don't change classification
            return
        }

        do {
            try domainStore.learn(
                domain: domain,
                classification: classification,
                failureType: failureType,
                source: .autoLearned
            )

            if let record = try domainStore.lookup(domain) {
                onDomainLearned?(record)
            }
        } catch {
            print("[LearningEngine] Failed to learn domain \(domain): \(error)")
        }
    }

    // MARK: - Learning from Success

    /// Confirms that a route works for a domain, boosting confidence.
    func reportSuccess(domain: String, route: RouteType) async {
        try? domainStore.incrementHitCount(domain: domain)
    }

    // MARK: - Failure Analysis

    /// Convenience: detect + report in one call.
    func analyzeAndLearn(
        domain: String,
        error: Error?,
        statusCode: Int?,
        responseBody: String?,
        connectionTime: TimeInterval?
    ) async {
        guard let failureType = failureDetector.detect(
            error: error,
            statusCode: statusCode,
            responseBody: responseBody,
            connectionTime: connectionTime
        ) else { return }

        await reportFailure(domain: domain, failureType: failureType)
    }
}
