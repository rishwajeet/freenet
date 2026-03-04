import Foundation

// MARK: - WireGuard Configuration

struct WireGuardConfig: Codable {
    var privateKey: String
    var address: String          // e.g. "10.2.0.2/32"
    var dns: String?             // e.g. "10.2.0.1"
    var peerPublicKey: String
    var peerEndpoint: String     // e.g. "sg-server.vpn.com:51820"
    var allowedIPs: String       // e.g. "0.0.0.0/0"
    var presharedKey: String?
    var mtu: Int?

    var serverHost: String {
        peerEndpoint.components(separatedBy: ":").first ?? peerEndpoint
    }

    var serverPort: Int {
        Int(peerEndpoint.components(separatedBy: ":").last ?? "51820") ?? 51820
    }
}

// MARK: - DNS Provider

enum DNSProvider: String, Codable, CaseIterable, Identifiable {
    case nextdns    = "NextDNS"
    case adguard    = "AdGuard"
    case cloudflare = "Cloudflare"
    case quad9      = "Quad9"
    case custom     = "Custom"

    var id: String { rawValue }

    var dohURL: String {
        switch self {
        case .nextdns:    return "https://dns.nextdns.io"
        case .adguard:    return "https://dns.adguard-dns.com/dns-query"
        case .cloudflare: return "https://cloudflare-dns.com/dns-query"
        case .quad9:      return "https://dns.quad9.net/dns-query"
        case .custom:     return ""
        }
    }

    var displayName: String {
        switch self {
        case .nextdns:    return "NextDNS (recommended)"
        case .adguard:    return "AdGuard DNS"
        case .cloudflare: return "Cloudflare 1.1.1.1"
        case .quad9:      return "Quad9"
        case .custom:     return "Custom DoH"
        }
    }

    var description: String {
        switch self {
        case .nextdns:    return "Privacy-focused, ad blocking built-in, customizable"
        case .adguard:    return "Ad blocking, tracker protection, family filters"
        case .cloudflare: return "Fast, privacy-first, no filtering"
        case .quad9:      return "Security-focused, blocks malicious domains"
        case .custom:     return "Bring your own DoH endpoint"
        }
    }
}

// MARK: - Route Type

enum RouteType: String, Codable {
    case encrypted  // DoH + ad blocking (default)
    case vpn        // WireGuard tunnel
    case direct     // Raw, no proxy, no encrypted DNS
    case reject     // Blocked (ads/trackers)
}
