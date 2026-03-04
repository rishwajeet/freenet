import ArgumentParser
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage mihomo configuration.",
        subcommands: [ShowSubcommand.self, ReloadSubcommand.self],
        defaultSubcommand: ShowSubcommand.self
    )
}

// MARK: - Show

struct ShowSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print the active mihomo config."
    )

    func run() throws {
        let path = CLIState.configFilePath
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.configNotFound
        }
        let content = try String(contentsOfFile: path, encoding: .utf8)
        print(content)
    }
}

// MARK: - Reload

struct ReloadSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reload",
        abstract: "Regenerate and hot-reload mihomo config."
    )

    func run() async throws {
        guard await CLIState.isMihomoHealthy() else {
            throw CLIError.apiUnavailable
        }

        let state = try CLIState()

        // Regenerate config from current domain store
        let config = try await state.configBuilder.build()
        try config.write(toFile: CLIState.configFilePath, atomically: true, encoding: .utf8)

        // Hot-reload via API
        let url = URL(string: "http://127.0.0.1:9090/configs")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["path": CLIState.configFilePath]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MihomoError.reloadFailed
        }

        print("Config regenerated and hot-reloaded.")
    }
}
