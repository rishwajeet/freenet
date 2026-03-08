import Foundation
import GRDB

// MARK: - CLI State

/// Lightweight wrapper around the reusable engine/intelligence layer.
/// No @MainActor, no @Published, no SwiftUI — pure Foundation.
final class CLIState {
    let domainStore: DomainStore
    let learningEngine: LearningEngine
    let crowdClient: CrowdClient
    let configBuilder: ConfigBuilder

    private static let appSupportDir: URL = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        return appSupport.appendingPathComponent("FreeNet", isDirectory: true)
    }()

    static let pidFilePath: String = appSupportDir.appendingPathComponent("mihomo.pid").path
    static let configFilePath: String = appSupportDir.appendingPathComponent("config.yaml").path
    static let sharedDefaults = UserDefaults(suiteName: "com.freenet.app") ?? .standard

    init() throws {
        self.domainStore = try DomainStore()

        self.learningEngine = LearningEngine(domainStore: domainStore)
        self.crowdClient = CrowdClient()

        let dnsProvider = DNSProvider(rawValue: Self.sharedDefaults.string(forKey: "dns_provider") ?? "") ?? .nextdns
        let customURL = Self.sharedDefaults.string(forKey: "custom_dns_url")

        self.configBuilder = ConfigBuilder(
            dnsProvider: dnsProvider,
            customDNSURL: customURL,
            domainStore: domainStore
        )
    }

    // MARK: - Mihomo Binary Resolution

    /// Resolves mihomo binary path using the priority chain:
    /// 1. $FREENET_MIHOMO_PATH env var
    /// 2. ~/Library/Application Support/FreeNet/mihomo
    /// 3. /usr/local/bin/mihomo
    /// 4. /Applications/FreeNet.app/Contents/Resources/mihomo
    static func resolveMihomoBinary() throws -> URL {
        let candidates: [String] = [
            ProcessInfo.processInfo.environment["FREENET_MIHOMO_PATH"],
            Self.appSupportDir.appendingPathComponent("mihomo").path,
            "/usr/local/bin/mihomo",
            "/Applications/FreeNet.app/Contents/Resources/mihomo"
        ].compactMap { $0 }

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        throw CLIError.mihomoNotFound
    }

    // MARK: - PID File

    static func writePID(_ pid: Int32) {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? "\(pid)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    }

    static func readPID() -> pid_t? {
        guard let content = try? String(contentsOfFile: pidFilePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(content) else {
            return nil
        }
        // Verify process is actually running
        if kill(pid, 0) == 0 {
            return pid
        }
        // Stale PID file — clean up
        try? FileManager.default.removeItem(atPath: pidFilePath)
        return nil
    }

    static func removePIDFile() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
    }

    // MARK: - Health Check

    /// Checks if mihomo API is responding.
    static func isMihomoHealthy() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:9090/version") else { return false }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: config)
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - VPN Config

    static func loadVPNConfig() -> WireGuardConfig? {
        guard let data = sharedDefaults.data(forKey: "wireguard_config") else { return nil }
        return try? JSONDecoder().decode(WireGuardConfig.self, from: data)
    }

    static func saveVPNConfig(_ config: WireGuardConfig) {
        if let data = try? JSONEncoder().encode(config) {
            sharedDefaults.set(data, forKey: "wireguard_config")
        }
    }
}
