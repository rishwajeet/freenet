import ArgumentParser
import Foundation

struct TrafficCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "traffic",
        abstract: "Show live traffic events."
    )

    @Flag(name: .long, help: "Stream traffic continuously.")
    var live = false

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        guard await CLIState.isMihomoHealthy() else {
            throw CLIError.apiUnavailable
        }

        let baseURL = URL(string: "http://127.0.0.1:9090")!
        var knownIDs: Set<String> = []

        if !json && !live {
            print("DOMAIN".padding(toLength: 40, withPad: " ", startingAt: 0)
                + "  " + "ROUTE".padding(toLength: 5, withPad: " ", startingAt: 0)
                + "  " + "TYPE".padding(toLength: 5, withPad: " ", startingAt: 0)
                + "  " + "UP".padding(toLength: 10, withPad: " ", startingAt: 0)
                + "  " + "DOWN".padding(toLength: 10, withPad: " ", startingAt: 0))
            print(String(repeating: "─", count: 76))
        }

        repeat {
            let events = try await fetchConnections(baseURL: baseURL, knownIDs: &knownIDs)

            for event in events {
                if json {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    if let data = try? encoder.encode(event),
                       let str = String(data: data, encoding: .utf8) {
                        print(str)
                    }
                } else {
                    let connType = event.connectionType ?? "—"
                    let up = formatBytes(event.bytesSent)
                    let down = formatBytes(event.bytesReceived)
                    print(event.domain.padding(toLength: 40, withPad: " ", startingAt: 0)
                        + "  " + event.route.label.padding(toLength: 5, withPad: " ", startingAt: 0)
                        + "  " + connType.padding(toLength: 5, withPad: " ", startingAt: 0)
                        + "  " + up.padding(toLength: 10, withPad: " ", startingAt: 0)
                        + "  " + down.padding(toLength: 10, withPad: " ", startingAt: 0))
                }
            }

            if live {
                fflush(stdout)
                try await Task.sleep(for: .seconds(1))
            }
        } while live
    }

    // MARK: - Fetch

    private func fetchConnections(baseURL: URL, knownIDs: inout Set<String>) async throws -> [TrafficEvent] {
        let url = baseURL.appendingPathComponent("/connections")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)

        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let connections = json["connections"] as? [[String: Any]] else {
            return []
        }

        var events: [TrafficEvent] = []
        for conn in connections {
            guard let connID = conn["id"] as? String, !knownIDs.contains(connID) else { continue }
            knownIDs.insert(connID)

            let metadata = conn["metadata"] as? [String: Any] ?? [:]
            let host = metadata["host"] as? String ?? metadata["destinationIP"] as? String ?? "unknown"
            let chains = conn["chains"] as? [String] ?? []
            let upload = conn["upload"] as? Int64 ?? 0
            let download = conn["download"] as? Int64 ?? 0
            let network = metadata["network"] as? String
            let rule = conn["rule"] as? String ?? ""

            let route = routeType(from: chains)
            let blocked = rule == "REJECT"

            events.append(TrafficEvent(
                domain: host,
                route: route,
                blocked: blocked,
                bytesSent: upload,
                bytesReceived: download,
                connectionType: network?.uppercased()
            ))
        }
        return events
    }

    private func routeType(from chains: [String]) -> RouteType {
        let joined = chains.joined(separator: " ").lowercased()
        if joined.contains("reject") { return .reject }
        if joined.contains("wireguard") || joined.contains("vpn") { return .vpn }
        if joined.contains("direct") { return .direct }
        return .encrypted
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
