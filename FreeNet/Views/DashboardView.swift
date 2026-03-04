import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedTab: DashboardTab = .traffic

    var body: some View {
        VStack(spacing: 0) {
            // Stats cards row
            statsCards
                .padding(20)

            Divider()

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(DashboardTab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Content
            switch selectedTab {
            case .traffic:
                trafficTable
            case .domains:
                LearnedDomainsView()
                    .environmentObject(appState)
            }
        }
        .searchable(text: $searchText, prompt: "Filter by domain...")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Requests",
                value: appState.stats.totalRequests,
                icon: "arrow.up.arrow.down",
                color: .blue
            )
            StatCard(
                title: "VPN Proxied",
                value: appState.stats.vpnProxied,
                icon: "lock.shield.fill",
                color: .purple
            )
            StatCard(
                title: "Ads Blocked",
                value: appState.stats.adsBlocked,
                icon: "hand.raised.fill",
                color: .red
            )
            StatCard(
                title: "Domains Learned",
                value: appState.learnedDomains.count,
                icon: "brain.fill",
                color: .green
            )
        }
    }

    // MARK: - Traffic Table

    private var trafficTable: some View {
        List {
            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "No Traffic",
                    systemImage: "network.slash",
                    description: Text("Traffic events will appear here as they occur.")
                )
            } else {
                ForEach(filteredEvents) { event in
                    TrafficEventRow(event: event)
                }
            }
        }
        .font(.system(.body, design: .monospaced))
    }

    private var filteredEvents: [TrafficEvent] {
        if searchText.isEmpty {
            return appState.recentEvents
        }
        return appState.recentEvents.filter {
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Dashboard Tab

private enum DashboardTab: String, CaseIterable, Identifiable {
    case traffic
    case domains

    var id: String { rawValue }

    var label: String {
        switch self {
        case .traffic: return "Live Traffic"
        case .domains: return "Learned Domains"
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
            }

            Text("\(value)")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .contentTransition(.numericText())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Traffic Event Row

private struct TrafficEventRow: View {
    let event: TrafficEvent

    var body: some View {
        HStack(spacing: 12) {
            // Timestamp
            Text(event.timestamp, style: .time)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            // Domain
            Text(event.domain)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Route badge
            RouteBadge(route: event.route)

            // Status
            if let status = event.statusCode {
                Text("\(status)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(statusColor(status))
                    .frame(width: 36, alignment: .trailing)
            } else {
                Text("--")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)
            }

            // Latency
            if let latency = event.latencyMs {
                Text("\(latency)ms")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            } else {
                Text("--")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .strikethrough(event.route == .reject, color: .red.opacity(0.5))
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .orange
        default:        return .red
        }
    }
}
