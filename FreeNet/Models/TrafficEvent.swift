import Foundation

// MARK: - Traffic Event

struct TrafficEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let domain: String
    let route: RouteType
    let statusCode: Int?
    let latencyMs: Int?
    let blocked: Bool        // Was this an ad/tracker that got rejected?
    let bytesSent: Int64
    let bytesReceived: Int64
    let connectionType: String? // TCP, UDP, etc.

    init(
        domain: String,
        route: RouteType,
        statusCode: Int? = nil,
        latencyMs: Int? = nil,
        blocked: Bool = false,
        bytesSent: Int64 = 0,
        bytesReceived: Int64 = 0,
        connectionType: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.domain = domain
        self.route = route
        self.statusCode = statusCode
        self.latencyMs = latencyMs
        self.blocked = blocked
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.connectionType = connectionType
    }
}

// MARK: - Traffic Stats

struct TrafficStats {
    var totalRequests: Int = 0
    var adsBlocked: Int = 0
    var vpnProxied: Int = 0
    var directRouted: Int = 0
    var encryptedRouted: Int = 0
    var domainsLearned: Int = 0
    var totalBytesSent: Int64 = 0
    var totalBytesReceived: Int64 = 0

    mutating func record(_ event: TrafficEvent) {
        totalRequests += 1
        totalBytesSent += event.bytesSent
        totalBytesReceived += event.bytesReceived

        if event.blocked {
            adsBlocked += 1
        }

        switch event.route {
        case .encrypted: encryptedRouted += 1
        case .vpn:       vpnProxied += 1
        case .direct:    directRouted += 1
        case .reject:    adsBlocked += 1
        }
    }
}
