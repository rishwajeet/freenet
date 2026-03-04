import Foundation

// MARK: - Failure Detector

/// Analyzes HTTP responses and connection errors to detect block signatures.
struct FailureDetector {

    // MARK: - Detection

    /// Inspects an error, status code, response body, and connection time to determine failure type.
    func detect(
        error: Error?,
        statusCode: Int?,
        responseBody: String?,
        connectionTime: TimeInterval?
    ) -> FailureType? {
        // Check error-based signals first
        if let error = error {
            let nsError = error as NSError

            // TCP RST — connection reset by peer
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 54 {
                return .connectionReset
            }

            // NXDOMAIN — DNS resolution failed
            if nsError.domain == (kCFErrorDomainCFNetwork as String) &&
               nsError.code == -1003 { // kCFURLErrorCannotFindHost
                return .dnsFailure
            }

            // TLS handshake failure
            if nsError.domain == NSURLErrorDomain &&
               (nsError.code == NSURLErrorServerCertificateUntrusted ||
                nsError.code == NSURLErrorSecureConnectionFailed ||
                nsError.code == NSURLErrorClientCertificateRejected) {
                return .tlsFailure
            }

            // Connection timeout from error
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                return .timeout
            }
        }

        // HTTP 451 — Unavailable For Legal Reasons
        if let code = statusCode, code == 451 {
            return .httpForbidden
        }

        // Content restriction — body contains geo-block message
        if let body = responseBody {
            let lowered = body.lowercased()
            let restrictionPhrases = [
                "not available in your country",
                "not available in your region",
                "this content is not available",
                "blocked in your country",
                "geo-restricted",
                "this website is blocked"
            ]
            for phrase in restrictionPhrases {
                if lowered.contains(phrase) {
                    return .contentRestriction
                }
            }

            // Empty response body where content was expected
            if body.isEmpty {
                return .emptyResponse
            }
        }

        // Slow connection — likely throttled or deep-packet inspected
        if let time = connectionTime, time > 5.0 {
            return .timeout
        }

        return nil
    }

    // MARK: - Classification

    /// Returns true if this failure type indicates the domain is being actively blocked.
    func isBlockSignature(_ failure: FailureType) -> Bool {
        switch failure {
        case .connectionReset, .dnsFailure, .tlsFailure, .httpForbidden, .contentRestriction:
            return true
        case .timeout, .emptyResponse, .dnsHostile:
            return false
        }
    }

    /// Returns true if this failure type indicates the domain is hostile to encrypted DNS.
    func isDNSHostileSignature(_ failure: FailureType) -> Bool {
        failure == .dnsHostile
    }
}
