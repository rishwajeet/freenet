import ArgumentParser
import Foundation

struct VPNCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vpn",
        abstract: "Manage WireGuard VPN configuration.",
        subcommands: [LoadSubcommand.self, VPNShowSubcommand.self],
        defaultSubcommand: VPNShowSubcommand.self
    )
}

// MARK: - Load

struct LoadSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "load",
        abstract: "Import a WireGuard .conf file."
    )

    @Argument(help: "Path to the WireGuard .conf file.")
    var file: String

    func run() throws {
        let path = (file as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw CLIError.fileNotFound(file)
        }

        let url = URL(fileURLWithPath: path)
        let config = try WireGuardParser.parse(fileURL: url)
        CLIState.saveVPNConfig(config)

        print("VPN config imported:")
        print("  Server:   \(config.serverHost):\(config.serverPort)")
        print("  Address:  \(config.address)")
        if let dns = config.dns {
            print("  DNS:      \(dns)")
        }
        if let mtu = config.mtu {
            print("  MTU:      \(mtu)")
        }
        print("\nUse 'freenet config reload' to apply, or 'freenet start' to launch with new config.")
    }
}

// MARK: - Show

struct VPNShowSubcommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show the current VPN configuration."
    )

    func run() throws {
        guard let config = CLIState.loadVPNConfig() else {
            throw CLIError.vpnConfigNotFound
        }

        print("VPN Configuration:")
        print("  Server:      \(config.serverHost):\(config.serverPort)")
        print("  Address:     \(config.address)")
        print("  Allowed IPs: \(config.allowedIPs)")
        if let dns = config.dns {
            print("  DNS:         \(dns)")
        }
        if let mtu = config.mtu {
            print("  MTU:         \(mtu)")
        }
        if config.presharedKey != nil {
            print("  PSK:         (set)")
        }
    }
}
