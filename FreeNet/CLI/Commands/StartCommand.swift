import ArgumentParser
import Foundation

struct StartCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start the mihomo engine."
    )

    func run() async throws {
        // Check if already running
        if let pid = CLIState.readPID() {
            if await CLIState.isMihomoHealthy() {
                print("Mihomo is already running (PID \(pid)). Use 'freenet stop' first.")
                return
            }
            // Stale PID — clean up and proceed
            CLIState.removePIDFile()
        }

        // Also check via API in case GUI started it
        if await CLIState.isMihomoHealthy() {
            print("Mihomo is already running (started by GUI). Attaching.")
            return
        }

        // Resolve binary
        let binaryURL = try CLIState.resolveMihomoBinary()
        print("Using mihomo at: \(binaryURL.path)")

        // Build config
        let state = try CLIState()
        let config = try await state.configBuilder.build()

        // Write config to disk
        let configPath = CLIState.configFilePath
        try config.write(toFile: configPath, atomically: true, encoding: .utf8)

        // Ensure executable
        let attrs = try FileManager.default.attributesOfItem(atPath: binaryURL.path)
        let perms = (attrs[.posixPermissions] as? Int) ?? 0
        if perms & 0o111 == 0 {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryURL.path)
        }

        // Launch mihomo
        let configDir = URL(fileURLWithPath: configPath).deletingLastPathComponent().path
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = ["-d", configDir]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()

        // Write PID file
        CLIState.writePID(process.processIdentifier)
        print("Mihomo started (PID \(process.processIdentifier))")

        // Wait a moment and verify health
        try await Task.sleep(for: .seconds(1))
        if await CLIState.isMihomoHealthy() {
            let domains = try state.domainStore.allDomains()
            print("Engine healthy. \(domains.count) domains loaded.")
        } else {
            print("Warning: Engine started but API not yet responding. It may need a moment.")
        }
    }
}
