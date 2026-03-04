import Foundation

// MARK: - Traffic Monitor

/// Polls the Mihomo REST API for live connection data and emits TrafficEvent objects.
final class TrafficMonitor {
    var onEvent: ((TrafficEvent) -> Void)?

    private let baseURL: URL
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var knownConnectionIDs: Set<String> = []
    private let session: URLSession

    init(baseURL: URL, pollInterval: TimeInterval = 1.0) {
        self.baseURL = baseURL
        self.pollInterval = pollInterval

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }

    // MARK: - Polling

    func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.poll() }
        }
        // Fire immediately
        Task { await poll() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        knownConnectionIDs.removeAll()
    }

    // MARK: - Fetch & Parse

    private func poll() async {
        let url = baseURL.appendingPathComponent("/connections")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            try parseConnections(data)
        } catch {
            // Silently skip — Mihomo may be restarting
        }
    }

    private func parseConnections(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let connections = json["connections"] as? [[String: Any]] else {
            return
        }

        for conn in connections {
            guard let connID = conn["id"] as? String else { continue }

            // Only emit new connections
            guard !knownConnectionIDs.contains(connID) else { continue }
            knownConnectionIDs.insert(connID)

            if let event = parseConnection(conn) {
                onEvent?(event)
            }
        }

        // Prune stale IDs: keep only IDs present in current response
        let currentIDs = Set(connections.compactMap { $0["id"] as? String })
        knownConnectionIDs.formIntersection(currentIDs)
    }

    private func parseConnection(_ conn: [String: Any]) -> TrafficEvent? {
        let metadata = conn["metadata"] as? [String: Any] ?? [:]

        // Extract domain
        let host = metadata["host"] as? String
            ?? metadata["destinationIP"] as? String
            ?? "unknown"

        // Extract chain (route path)
        let chains = conn["chains"] as? [String] ?? []
        let route = routeType(from: chains)

        // Extract bytes
        let upload = conn["upload"] as? Int64 ?? 0
        let download = conn["download"] as? Int64 ?? 0

        // Network type
        let network = metadata["network"] as? String

        // Determine if blocked
        let rulePayload = conn["rulePayload"] as? String ?? ""
        let rule = conn["rule"] as? String ?? ""
        let blocked = rule == "REJECT"

        return TrafficEvent(
            domain: host,
            route: route,
            latencyMs: nil,
            blocked: blocked,
            bytesSent: upload,
            bytesReceived: download,
            connectionType: network?.uppercased()
        )
    }

    // MARK: - Route Detection

    private func routeType(from chains: [String]) -> RouteType {
        let joined = chains.joined(separator: " ").lowercased()

        if joined.contains("reject") {
            return .reject
        } else if joined.contains("wireguard") || joined.contains("vpn") {
            return .vpn
        } else if joined.contains("direct") {
            return .direct
        } else {
            return .encrypted
        }
    }

    deinit {
        stopPolling()
    }
}
