import ArgumentParser
import Foundation

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show engine status and domain counts."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        let state = try CLIState()
        let isHealthy = await CLIState.isMihomoHealthy()
        let pid = CLIState.readPID()
        let domains = try state.domainStore.allDomains()
        let today = try state.domainStore.domainsLearnedToday()
        let hasVPN = CLIState.loadVPNConfig() != nil

        let safe = domains.filter { $0.classification == .safe }.count
        let blocked = domains.filter { $0.classification == .blocked }.count
        let dnsHostile = domains.filter { $0.classification == .dnsHostile }.count
        let unknown = domains.filter { $0.classification == .unknown }.count

        if json {
            let output: [String: Any] = [
                "engine": isHealthy ? "running" : "stopped",
                "pid": pid.map { Int($0) } as Any,
                "vpn_configured": hasVPN,
                "domains": [
                    "total": domains.count,
                    "safe": safe,
                    "blocked": blocked,
                    "dns_hostile": dnsHostile,
                    "unknown": unknown,
                    "learned_today": today,
                ]
            ]
            if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            let statusIcon = isHealthy ? "●" : "○"
            let statusLabel = isHealthy ? "running" : "stopped"
            let pidLabel = pid.map { " (PID \($0))" } ?? ""

            print("\(statusIcon) Engine: \(statusLabel)\(pidLabel)")
            print("  VPN: \(hasVPN ? "configured" : "not configured")")
            print("")
            print("  Domains")
            print("    Total:        \(domains.count)")
            print("    Safe:         \(safe)")
            print("    Blocked:      \(blocked)")
            print("    DNS Hostile:  \(dnsHostile)")
            print("    Unknown:      \(unknown)")
            print("    Learned today: \(today)")
        }
    }
}
