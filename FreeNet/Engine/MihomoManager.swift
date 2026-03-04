import Foundation

// MARK: - Mihomo Manager

/// Manages the Mihomo proxy core process lifecycle.
/// Launches the embedded binary, writes config to disk, and exposes the REST API URL.
final class MihomoManager {
    let apiBaseURL: URL

    private var process: Process?
    private let configDirectory: URL
    private let binaryURL: URL
    private let apiPort: Int

    init(apiPort: Int = 9090) throws {
        self.apiPort = apiPort
        self.apiBaseURL = URL(string: "http://127.0.0.1:\(apiPort)")!

        // Resolve embedded binary
        guard let binary = Bundle.main.url(forResource: "mihomo", withExtension: nil) else {
            throw MihomoError.binaryNotFound
        }
        self.binaryURL = binary

        // Config lives in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.configDirectory = appSupport.appendingPathComponent("FreeNet", isDirectory: true)
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Lifecycle

    func start(with config: String) throws {
        stop()

        // Write YAML config to disk
        let configFile = configDirectory.appendingPathComponent("config.yaml")
        try config.write(to: configFile, atomically: true, encoding: .utf8)

        // Launch mihomo with config directory
        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["-d", configDirectory.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        proc.qualityOfService = .userInitiated

        // Auto-restart on unexpected termination
        proc.terminationHandler = { [weak self] terminated in
            guard let self else { return }
            // Only restart if we didn't intentionally stop
            if self.process != nil && terminated.terminationStatus != 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    try? self.restart(with: config)
                }
            }
        }

        try proc.run()
        self.process = proc
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            process = nil
            return
        }
        process = nil // Clear first so termination handler doesn't restart
        proc.terminate()
        proc.waitUntilExit()
    }

    func restart(with config: String? = nil) throws {
        let yaml: String
        if let config {
            yaml = config
        } else {
            // Re-read existing config from disk
            let configFile = configDirectory.appendingPathComponent("config.yaml")
            yaml = try String(contentsOf: configFile, encoding: .utf8)
        }
        try start(with: yaml)
    }

    // MARK: - Config Reload via API

    /// Tells Mihomo to hot-reload its config without restarting the process.
    func reloadConfig() async throws {
        let configPath = configDirectory.appendingPathComponent("config.yaml").path
        let url = apiBaseURL.appendingPathComponent("/configs")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["path": configPath]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MihomoError.reloadFailed
        }
    }

    // MARK: - Status

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    deinit {
        stop()
    }
}

// MARK: - Errors

enum MihomoError: LocalizedError {
    case binaryNotFound
    case reloadFailed

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Mihomo binary not found in app bundle. Ensure 'mihomo' is in Resources."
        case .reloadFailed:
            return "Failed to hot-reload Mihomo configuration via API."
        }
    }
}
