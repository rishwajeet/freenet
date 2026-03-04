import Foundation

// MARK: - CLI Errors

enum CLIError: LocalizedError {
    case mihomoNotFound
    case mihomoAlreadyRunning
    case mihomoNotRunning
    case configNotFound
    case databaseError(String)
    case vpnConfigNotFound
    case invalidClassification(String)
    case fileNotFound(String)
    case apiUnavailable

    var errorDescription: String? {
        switch self {
        case .mihomoNotFound:
            return """
                Mihomo binary not found. Searched:
                  1. $FREENET_MIHOMO_PATH
                  2. ~/Library/Application Support/FreeNet/mihomo
                  3. /usr/local/bin/mihomo
                  4. /Applications/FreeNet.app/Contents/Resources/mihomo
                """
        case .mihomoAlreadyRunning:
            return "Mihomo is already running. Use 'freenet stop' first, or 'freenet status' to check."
        case .mihomoNotRunning:
            return "Mihomo is not running. Use 'freenet start' to start."
        case .configNotFound:
            return "Config file not found at ~/Library/Application Support/FreeNet/config.yaml"
        case .databaseError(let msg):
            return "Database error: \(msg)"
        case .vpnConfigNotFound:
            return "No VPN config found. Use 'freenet vpn load <file>' to import a WireGuard .conf."
        case .invalidClassification(let value):
            return "Invalid classification '\(value)'. Use: safe, blocked, dns-hostile, or unknown."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .apiUnavailable:
            return "Mihomo API not responding at http://127.0.0.1:9090"
        }
    }
}
