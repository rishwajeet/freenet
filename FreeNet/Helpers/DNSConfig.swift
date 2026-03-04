import Foundation

// MARK: - DNS Configuration Helper

enum DNSConfig {

    /// Generate the Mihomo DNS configuration dictionary for a given provider.
    ///
    /// Produces the `dns:` block for Mihomo YAML config with DoH nameservers,
    /// fake-ip mode, and geo-based fallback filtering.
    ///
    /// - Parameters:
    ///   - provider: The selected DNS-over-HTTPS provider.
    ///   - customURL: Custom DoH URL when provider is `.custom`, or
    ///                NextDNS configuration ID (e.g. "abc123" → "https://dns.nextdns.io/abc123").
    /// - Returns: Dictionary suitable for Mihomo DNS config section.
    static func mihomoConfig(for provider: DNSProvider, customURL: String? = nil) -> [String: Any] {
        let primaryURL = resolveURL(for: provider, customURL: customURL)

        return [
            "dns": [
                "enable": true,
                "enhanced-mode": "fake-ip",
                "fake-ip-range": "198.18.0.1/16",
                "fake-ip-filter": [
                    "*.lan",
                    "*.local",
                    "*.localhost",
                    "time.*.com",
                    "ntp.*.com",
                    "*.ntp.org.cn",
                    "+.pool.ntp.org"
                ],
                "nameserver": [
                    primaryURL
                ],
                "fallback": fallbackServers(excluding: primaryURL),
                "fallback-filter": [
                    "geoip": true,
                    "geoip-code": "IN"
                ]
            ] as [String: Any]
        ]
    }

    /// Generate a plain DNS config for safelist domains (banking, gov, UPI).
    ///
    /// These domains bypass encrypted DNS and use system DNS directly
    /// to avoid any interference with sensitive services.
    ///
    /// - Returns: Dictionary for the safelist nameserver group.
    static func safelistDNS() -> [String: Any] {
        return [
            "enable": true,
            "enhanced-mode": "redir-host",
            "nameserver": [
                "system",
                "8.8.8.8",
                "1.1.1.1"
            ]
        ]
    }

    // MARK: - Private

    /// Resolve the primary DoH URL based on provider and optional custom input.
    private static func resolveURL(for provider: DNSProvider, customURL: String?) -> String {
        switch provider {
        case .nextdns:
            // Support custom NextDNS configuration ID
            if let configID = customURL, !configID.isEmpty {
                // If user passed a full URL, use it directly
                if configID.hasPrefix("https://") {
                    return configID
                }
                // Otherwise treat it as a NextDNS config ID
                return "https://dns.nextdns.io/\(configID)"
            }
            return provider.dohURL + "/dns-query"

        case .custom:
            if let url = customURL, !url.isEmpty, url.hasPrefix("https://") {
                return url
            }
            // Fallback to Cloudflare if custom URL is invalid
            return DNSProvider.cloudflare.dohURL

        default:
            return provider.dohURL
        }
    }

    /// Fallback DoH servers, excluding the primary to avoid redundancy.
    private static func fallbackServers(excluding primary: String) -> [String] {
        let candidates = [
            "https://dns.google/dns-query",
            "https://cloudflare-dns.com/dns-query",
            "https://dns.quad9.net/dns-query"
        ]
        return candidates.filter { $0 != primary }
    }
}
