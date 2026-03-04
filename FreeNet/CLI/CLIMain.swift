import ArgumentParser

@main
struct FreeNetCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "freenet",
        abstract: "FreeNet — intelligent internet routing from the terminal.",
        version: "1.0.0",
        subcommands: [
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            ToggleCommand.self,
            DomainsCommand.self,
            TrafficCommand.self,
            SyncCommand.self,
            ConfigCommand.self,
            VPNCommand.self,
        ]
    )
}
