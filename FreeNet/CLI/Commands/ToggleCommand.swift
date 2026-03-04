import ArgumentParser
import Foundation

struct ToggleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle the engine on or off."
    )

    func run() async throws {
        if await CLIState.isMihomoHealthy() {
            // Running → stop
            try await StopCommand.parse([]).run()
        } else {
            // Stopped → start
            try await StartCommand.parse([]).run()
        }
    }
}
