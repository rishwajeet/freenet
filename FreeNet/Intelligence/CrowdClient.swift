import Foundation

// MARK: - Crowd Client

/// Reports learned domain blocks to the central FreeNet API and fetches crowd-sourced blocklists.
final class CrowdClient {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "https://api.freenet.dev")!) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Report

    /// Reports a block detection to the crowd intelligence API.
    func report(_ report: BlockReport) async throws {
        let url = baseURL.appendingPathComponent("v1/reports")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(report)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CrowdClientError.reportFailed
        }
    }

    // MARK: - Fetch Blocklist

    /// Fetches the crowd-sourced blocklist for a given country.
    func fetchBlocklist(country: String) async throws -> CrowdBlocklist {
        let url = baseURL.appendingPathComponent("v1/blocklist/\(country)")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw CrowdClientError.fetchFailed
        }

        return try decoder.decode(CrowdBlocklist.self, from: data)
    }

    // MARK: - Sync

    /// Fetches the latest crowd blocklist and imports it into the domain store.
    func sync(into domainStore: DomainStore) async throws {
        let country = Locale.current.region?.identifier ?? "IN"
        let blocklist = try await fetchBlocklist(country: country)
        try domainStore.importCrowdData(blocklist.domains)
    }
}

// MARK: - Errors

enum CrowdClientError: LocalizedError {
    case reportFailed
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .reportFailed: return "Failed to report block to crowd API"
        case .fetchFailed: return "Failed to fetch crowd blocklist"
        }
    }
}
