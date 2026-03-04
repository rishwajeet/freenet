import Foundation

// MARK: - Parser Errors

enum WireGuardParserError: LocalizedError {
    case emptyConfig
    case missingInterfaceSection
    case missingPeerSection
    case missingPrivateKey
    case missingPublicKey
    case missingEndpoint
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .emptyConfig:
            return "WireGuard config file is empty."
        case .missingInterfaceSection:
            return "Missing [Interface] section in WireGuard config."
        case .missingPeerSection:
            return "Missing [Peer] section in WireGuard config."
        case .missingPrivateKey:
            return "Missing PrivateKey in [Interface] section."
        case .missingPublicKey:
            return "Missing PublicKey in [Peer] section."
        case .missingEndpoint:
            return "Missing Endpoint in [Peer] section."
        case .invalidFormat(let detail):
            return "Invalid WireGuard config format: \(detail)"
        }
    }
}

// MARK: - WireGuard Config Parser

enum WireGuardParser {

    /// Parse a WireGuard .conf file from raw text.
    /// Handles standard INI-like format with [Interface] and [Peer] sections.
    /// Compatible with configs from Proton VPN, Mullvad, IVPN, Windscribe, etc.
    static func parse(_ configText: String) throws -> WireGuardConfig {
        let text = configText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw WireGuardParserError.emptyConfig
        }

        let lines = text.components(separatedBy: .newlines)

        var interfaceFields: [String: String] = [:]
        var peerFields: [String: String] = [:]
        var currentSection: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }

            // Section headers
            let lower = trimmed.lowercased()
            if lower == "[interface]" {
                currentSection = "interface"
                continue
            } else if lower == "[peer]" {
                // Only parse the first peer (primary server)
                if currentSection == "peer" { break }
                currentSection = "peer"
                continue
            }

            // Key = Value pairs
            guard let equalsIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<equalsIndex]
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = trimmed[trimmed.index(after: equalsIndex)...]
                .trimmingCharacters(in: .whitespaces)

            guard !value.isEmpty else { continue }

            switch currentSection {
            case "interface":
                interfaceFields[key] = value
            case "peer":
                peerFields[key] = value
            default:
                // Lines before any section header — ignore
                break
            }
        }

        // Validate required sections
        guard !interfaceFields.isEmpty else {
            throw WireGuardParserError.missingInterfaceSection
        }
        guard !peerFields.isEmpty else {
            throw WireGuardParserError.missingPeerSection
        }

        // Extract required fields
        guard let privateKey = interfaceFields["privatekey"] else {
            throw WireGuardParserError.missingPrivateKey
        }
        guard let publicKey = peerFields["publickey"] else {
            throw WireGuardParserError.missingPublicKey
        }
        guard let endpoint = peerFields["endpoint"] else {
            throw WireGuardParserError.missingEndpoint
        }

        // Extract optional/defaulted fields
        let address = interfaceFields["address"] ?? "10.0.0.2/32"
        let dns = interfaceFields["dns"]
        let allowedIPs = peerFields["allowedips"] ?? "0.0.0.0/0, ::/0"
        let presharedKey = peerFields["presharedkey"]
        let mtu = interfaceFields["mtu"].flatMap { Int($0) }

        return WireGuardConfig(
            privateKey: privateKey,
            address: address,
            dns: dns,
            peerPublicKey: publicKey,
            peerEndpoint: endpoint,
            allowedIPs: allowedIPs,
            presharedKey: presharedKey,
            mtu: mtu
        )
    }

    /// Parse a WireGuard .conf file from a file URL.
    static func parse(fileURL: URL) throws -> WireGuardConfig {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(text)
    }
}
