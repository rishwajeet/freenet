import SwiftUI
import Combine
import UserNotifications

// MARK: - Connection State

enum ConnectionState: String {
    case connected
    case connecting
    case disconnected
    case learning
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    // Connection
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isVPNConfigured: Bool = false
    @Published var showSetupWizard: Bool = false
    @Published var connectedSince: Date? = nil
    @Published var engineStatus: String = ""
    @Published var hasCompletedOnboarding: Bool = false

    // Stats
    @Published var stats = TrafficStats()
    @Published var recentEvents: [TrafficEvent] = []

    // Intelligence
    @Published var learnedDomains: [DomainRecord] = []
    @Published var domainsLearnedToday: Int = 0

    // Settings
    @Published var dnsProvider: DNSProvider = .nextdns
    @Published var customDNSURL: String = ""
    @Published var crowdIntelligenceEnabled: Bool = true
    @Published var notificationsEnabled: Bool = true
    @Published var autoStartEnabled: Bool = true

    // Managers (initialized after app launch)
    var mihomoManager: MihomoManager?
    var learningEngine: LearningEngine?
    var domainStore: DomainStore?
    var trafficMonitor: TrafficMonitor?
    var crowdClient: CrowdClient?
    private var configBuilder: ConfigBuilder?

    private var cancellables = Set<AnyCancellable>()
    private let maxRecentEvents = 200
    private var hasInitialized = false
    static let sharedDefaults = UserDefaults(suiteName: "com.freenet.app") ?? .standard

    init() {
        self.hasCompletedOnboarding = Self.sharedDefaults.bool(forKey: "hasCompletedOnboarding")
        Task { @MainActor in
            await self.initialize()
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        Self.sharedDefaults.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Lifecycle

    func initialize() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        KeyboardShortcutMonitor.shared.install(appState: self)
        do {
            // 1. Initialize domain store (SQLite)
            let store = try DomainStore()
            self.domainStore = store

            // 2. Load learned domains into UI
            self.learnedDomains = try store.allDomains()
            self.domainsLearnedToday = try store.domainsLearnedToday()

            // 3. Initialize learning engine + wire the learning callback
            let engine = LearningEngine(domainStore: store)
            engine.onDomainLearned = { [weak self] record in
                Task { @MainActor in
                    self?.handleDomainLearned(record)
                }
            }
            self.learningEngine = engine

            // 4. Initialize crowd client
            self.crowdClient = CrowdClient()

            // 5. Sync crowd intelligence on launch (non-blocking)
            if crowdIntelligenceEnabled {
                Task.detached { [weak self] in
                    try? await self?.crowdClient?.sync(into: store)
                    await MainActor.run {
                        self?.refreshLearnedDomains()
                    }
                }
            }

            // 6. Check VPN config
            self.isVPNConfigured = Self.sharedDefaults.data(forKey: "wireguard_config") != nil

            if !hasCompletedOnboarding {
                showSetupWizard = true
            } else {
                await startEngine()
            }
        } catch {
            print("[FreeNet] Failed to initialize: \(error)")
            connectionState = .disconnected
        }
    }

    // MARK: - Engine Control

    func startEngine() async {
        connectionState = .connecting
        connectedSince = nil

        do {
            // 1. Ensure mihomo binary is executable
            engineStatus = "Checking engine binary..."
            try Permissions.ensureMihomoExecutable()

            // 2. Request TUN permission if needed
            engineStatus = "Checking network permissions..."
            if !Permissions.hasTUNPermission() {
                let granted = await Permissions.requestTUNPermission()
                if !granted {
                    print("[FreeNet] TUN permission denied")
                    engineStatus = "Failed: Network permission denied"
                    connectionState = .disconnected
                    return
                }
            }

            // 3. Create and start Mihomo
            engineStatus = "Starting proxy engine..."
            let manager = try MihomoManager()
            self.mihomoManager = manager

            engineStatus = "Loading DNS and ad blocklist..."
            let builder = ConfigBuilder(
                dnsProvider: dnsProvider,
                customDNSURL: customDNSURL.isEmpty ? nil : customDNSURL,
                domainStore: domainStore
            )
            self.configBuilder = builder

            let config = try await builder.build()

            engineStatus = "Starting encrypted DNS..."
            try manager.start(with: config)

            // 4. Start traffic monitor with learning loop
            engineStatus = "Starting traffic monitor..."
            let monitor = TrafficMonitor(baseURL: manager.apiBaseURL)
            self.trafficMonitor = monitor
            monitor.onEvent = { [weak self] event in
                Task { @MainActor in
                    self?.handleTrafficEvent(event)
                }
            }
            monitor.startPolling()

            engineStatus = "Ready"
            connectedSince = Date()
            connectionState = .connected
        } catch {
            print("[FreeNet] Failed to start engine: \(error)")
            engineStatus = "Failed: \(error.localizedDescription)"
            connectionState = .disconnected
        }
    }

    func stopEngine() {
        trafficMonitor?.stopPolling()
        mihomoManager?.stop()
        connectedSince = nil
        engineStatus = ""
        connectionState = .disconnected
    }

    func toggleConnection() async {
        if connectionState == .connected || connectionState == .learning {
            stopEngine()
        } else {
            await startEngine()
        }
    }

    // MARK: - Traffic Event Handling (the core loop)

    private func handleTrafficEvent(_ event: TrafficEvent) {
        // 1. Record stats and UI
        stats.record(event)
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeLast()
        }

        // 2. Feed failures into learning engine
        // If the event came through ENCRYPTED and looks like it failed,
        // the learning engine will analyze and potentially reclassify
        if !event.blocked, let statusCode = event.statusCode {
            let isFailure = statusCode == 451
                || statusCode >= 500
                || event.latencyMs.map({ $0 > 5000 }) == true

            if isFailure {
                connectionState = .learning
                Task {
                    await learningEngine?.analyzeAndLearn(
                        domain: event.domain,
                        error: nil,
                        statusCode: statusCode,
                        responseBody: nil,
                        connectionTime: event.latencyMs.map { TimeInterval($0) / 1000.0 }
                    )
                    // Reset state after learning
                    if connectionState == .learning {
                        connectionState = .connected
                    }
                }
            }
        }
    }

    // MARK: - Learning Callback (fired by LearningEngine)

    private func handleDomainLearned(_ record: DomainRecord) {
        // 1. Refresh UI
        refreshLearnedDomains()

        // 2. Hot-reload Mihomo config with new rules
        if let manager = mihomoManager, let builder = configBuilder {
            Task {
                do {
                    try await builder.hotReload(manager: manager)
                    print("[FreeNet] Config hot-reloaded after learning: \(record.domain) → \(record.classification.rawValue)")
                } catch {
                    print("[FreeNet] Hot-reload failed: \(error)")
                }
            }
        }

        // 3. Send notification
        if notificationsEnabled {
            sendLearnedNotification(record)
        }

        // 4. Report to crowd intelligence
        if crowdIntelligenceEnabled, record.classification == .blocked, let failureType = record.failureType {
            let report = BlockReport(domain: record.domain, failureType: failureType)
            Task.detached { [weak self] in
                try? await self?.crowdClient?.report(report)
            }
        }
    }

    // MARK: - Notifications

    private func sendLearnedNotification(_ record: DomainRecord) {
        let content = UNMutableNotificationContent()
        content.title = "FreeNet learned"

        switch record.classification {
        case .blocked:
            content.body = "\(record.domain) is blocked — now routing through VPN"
        case .dnsHostile:
            content.body = "\(record.domain) needs direct connection — bypassing encrypted DNS"
        default:
            return
        }

        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "domain-learned-\(record.domain)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - VPN Config

    func saveVPNConfig(_ config: WireGuardConfig) {
        if let data = try? JSONEncoder().encode(config) {
            Self.sharedDefaults.set(data, forKey: "wireguard_config")
            isVPNConfigured = true
        }
    }

    func loadVPNConfig() -> WireGuardConfig? {
        guard let data = Self.sharedDefaults.data(forKey: "wireguard_config") else { return nil }
        return try? JSONDecoder().decode(WireGuardConfig.self, from: data)
    }

    // MARK: - Intelligence

    func refreshLearnedDomains() {
        guard let store = domainStore else { return }
        do {
            learnedDomains = try store.allDomains()
            domainsLearnedToday = try store.domainsLearnedToday()
        } catch {
            print("[FreeNet] Failed to refresh domains: \(error)")
        }
    }
}
