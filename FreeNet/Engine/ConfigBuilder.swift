import Foundation
import Yams

enum ConfigBuilderError: LocalizedError {
    case noAppSupportDirectory

    var errorDescription: String? {
        switch self {
        case .noAppSupportDirectory:
            return "Could not locate Application Support directory"
        }
    }
}

// MARK: - Config Builder

/// Generates a complete Mihomo YAML configuration from the current DNS provider,
/// optional custom DNS URL, and classified domain rules.
struct ConfigBuilder {
    let dnsProvider: DNSProvider
    let customDNSURL: String?
    let domainStore: DomainStore?

    // MARK: - Build

    /// Generates a full Mihomo config as a YAML string.
    func build() async throws -> String {
        let config = try buildDictionary()
        return try Yams.dump(object: config)
    }

    /// Regenerates config, writes to disk, and signals Mihomo to hot-reload.
    func hotReload(manager: MihomoManager) async throws {
        let yaml = try await build()

        // Write updated config
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ConfigBuilderError.noAppSupportDirectory
        }
        let configFile = appSupport
            .appendingPathComponent("FreeNet", isDirectory: true)
            .appendingPathComponent("config.yaml")
        try yaml.write(to: configFile, atomically: true, encoding: .utf8)

        // Signal Mihomo to reload
        try await manager.reloadConfig()
    }

    // MARK: - Config Assembly

    private func buildDictionary() throws -> [String: Any] {
        var config: [String: Any] = [:]

        // General
        config["mixed-port"] = 7890
        config["allow-lan"] = false
        config["mode"] = "rule"
        config["log-level"] = "warning"
        config["external-controller"] = "127.0.0.1:9090"

        // TUN
        config["tun"] = buildTUN()

        // DNS
        config["dns"] = buildDNS()

        // Proxies
        config["proxies"] = buildProxies()

        // Proxy Groups
        config["proxy-groups"] = buildProxyGroups()

        // Rules
        config["rules"] = try buildRules()

        return config
    }

    // MARK: - TUN

    private func buildTUN() -> [String: Any] {
        [
            "enable": true,
            "device": "utun199",
            "stack": "system",
            "auto-route": true,
            "auto-detect-interface": true,
            "dns-hijack": ["any:53"]
        ]
    }

    // MARK: - DNS

    private func buildDNS() -> [String: Any] {
        let dohURL: String
        if dnsProvider == .custom, let custom = customDNSURL, !custom.isEmpty {
            dohURL = custom
        } else {
            dohURL = dnsProvider.dohURL
        }

        return [
            "enable": true,
            "listen": "0.0.0.0:1053",
            "enhanced-mode": "fake-ip",
            "fake-ip-range": "198.18.0.1/16",
            "nameserver": [dohURL],
            "fallback": [
                "https://dns.google/dns-query",
                "https://cloudflare-dns.com/dns-query"
            ],
            "fallback-filter": [
                "geoip": true,
                "geoip-code": "IN",
                "ipcidr": ["240.0.0.0/4"]
            ]
        ]
    }

    // MARK: - Proxies

    private func buildProxies() -> [[String: Any]] {
        // WireGuard proxy loaded from saved config, if available
        guard let vpnConfig = loadWireGuardConfig() else {
            return []
        }

        var proxy: [String: Any] = [
            "name": "WireGuard-VPN",
            "type": "wireguard",
            "server": vpnConfig.serverHost,
            "port": vpnConfig.serverPort,
            "private-key": vpnConfig.privateKey,
            "ip": vpnConfig.address.components(separatedBy: "/").first ?? vpnConfig.address,
            "public-key": vpnConfig.peerPublicKey,
            "allowed-ips": ["0.0.0.0/0", "::/0"],
            "udp": true
        ]

        if let psk = vpnConfig.presharedKey {
            proxy["preshared-key"] = psk
        }
        if let dns = vpnConfig.dns {
            proxy["remote-dns-resolve"] = true
            proxy["dns"] = [dns]
        }
        if let mtu = vpnConfig.mtu {
            proxy["mtu"] = mtu
        }

        return [proxy]
    }

    // MARK: - Proxy Groups

    private func buildProxyGroups() -> [[String: Any]] {
        let hasVPN = loadWireGuardConfig() != nil

        var groups: [[String: Any]] = [
            [
                "name": "ENCRYPTED",
                "type": "select",
                "proxies": ["DIRECT"]
            ]
        ]

        if hasVPN {
            groups.append([
                "name": "VPN",
                "type": "select",
                "proxies": ["WireGuard-VPN", "DIRECT"]
            ])
        } else {
            groups.append([
                "name": "VPN",
                "type": "select",
                "proxies": ["DIRECT"]
            ])
        }

        return groups
    }

    // MARK: - Rules

    private func buildRules() throws -> [String] {
        var rules: [String] = []

        // Ad-blocking reject rules
        for domain in Self.adDomains {
            rules.append("DOMAIN-SUFFIX,\(domain),REJECT")
        }

        // Domain-store rules
        if let store = domainStore {
            // SAFE domains -> DIRECT (raw, no encrypted DNS)
            let safeDomains = try store.domains(withClassification: .safe)
            for record in safeDomains {
                rules.append("DOMAIN-SUFFIX,\(record.domain),DIRECT")
            }

            // BLOCKED domains -> VPN
            let blockedDomains = try store.domains(withClassification: .blocked)
            for record in blockedDomains {
                rules.append("DOMAIN-SUFFIX,\(record.domain),VPN")
            }

            // DNS-HOSTILE domains -> DIRECT (raw)
            let hostileDomains = try store.domains(withClassification: .dnsHostile)
            for record in hostileDomains {
                rules.append("DOMAIN-SUFFIX,\(record.domain),DIRECT")
            }
        }

        // Default: route through ENCRYPTED (DoH path)
        rules.append("MATCH,ENCRYPTED")

        return rules
    }

    // MARK: - Helpers

    private func loadWireGuardConfig() -> WireGuardConfig? {
        let defaults = UserDefaults(suiteName: "com.freenet.app") ?? .standard
        guard let data = defaults.data(forKey: "wireguard_config") else { return nil }
        return try? JSONDecoder().decode(WireGuardConfig.self, from: data)
    }

    // MARK: - Known Ad Domains

    static let adDomains: [String] = [
        "doubleclick.net",
        "googlesyndication.com",
        "googleadservices.com",
        "google-analytics.com",
        "googletagmanager.com",
        "facebook.net",
        "fbcdn.net",
        "analytics.facebook.com",
        "ads.yahoo.com",
        "ad.doubleclick.net",
        "adservice.google.com",
        "pagead2.googlesyndication.com",
        "amazon-adsystem.com",
        "ads-twitter.com",
        "app-measurement.com",
        "crashlytics.com",
        "scorecardresearch.com",
        "taboola.com",
        "outbrain.com",
        "adcolony.com",
        "appsflyer.com",
        "adjust.com",
        "branch.io",
        "mopub.com",
        "inmobi.com",
        "unity3d.com",
        "chartboost.com",
        "vungle.com",
        "admob.com"
    ]
}
