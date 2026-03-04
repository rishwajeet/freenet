import SwiftUI

// MARK: - Menu Bar Popover

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header: Connection Toggle
            connectionHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()

            // Stats bars
            statsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Recent traffic
            recentTrafficSection
                .padding(.vertical, 8)

            Divider()

            // Footer buttons
            footerButtons
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 320)
    }

    // MARK: - Connection Header

    private var connectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FreeNet")
                    .font(.headline)
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(connectionColor)
            }

            Spacer()

            Toggle("", isOn: connectionBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private var connectionLabel: String {
        switch appState.connectionState {
        case .connected:    return "Protected"
        case .connecting:   return "Connecting..."
        case .disconnected: return "Disconnected"
        case .learning:     return "Learning..."
        }
    }

    private var connectionColor: Color {
        switch appState.connectionState {
        case .connected:    return .green
        case .connecting:   return .orange
        case .disconnected: return .secondary
        case .learning:     return .blue
        }
    }

    private var connectionBinding: Binding<Bool> {
        Binding(
            get: {
                appState.connectionState == .connected || appState.connectionState == .learning
            },
            set: { _ in
                Task { await appState.toggleConnection() }
            }
        )
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 8) {
            StatBar(
                label: "Ads Blocked",
                value: appState.stats.adsBlocked,
                color: .red
            )
            StatBar(
                label: "VPN Proxied",
                value: appState.stats.vpnProxied,
                color: .purple
            )
            StatBar(
                label: "Domains Learned",
                value: appState.learnedDomains.count,
                color: .green
            )
        }
    }

    // MARK: - Recent Traffic

    private var recentTrafficSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Traffic")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            if appState.recentEvents.isEmpty {
                Text("No traffic yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(appState.recentEvents.prefix(8)) { event in
                    TrafficRow(event: event)
                }
            }
        }
    }

    // MARK: - Footer Buttons

    private var footerButtons: some View {
        HStack {
            Button {
                openWindow(id: "dashboard")
            } label: {
                Label("Dashboard", systemImage: "chart.bar.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                openWindow(id: "settings")
            } label: {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Stat Bar

private struct StatBar: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(value)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Traffic Row

private struct TrafficRow: View {
    let event: TrafficEvent

    var body: some View {
        HStack(spacing: 8) {
            Text(event.domain)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            RouteBadge(route: event.route)

            if let latency = event.latencyMs {
                Text("\(latency)ms")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }
}

// MARK: - Route Badge

struct RouteBadge: View {
    let route: RouteType

    var body: some View {
        Text(route.label)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(route.color.opacity(0.15))
            .foregroundStyle(route.color)
            .clipShape(Capsule())
    }
}

// MARK: - RouteType Helpers

extension RouteType {
    var color: Color {
        switch self {
        case .encrypted: return .green
        case .vpn:       return .purple
        case .direct:    return .gray
        case .reject:    return .red
        }
    }

    var label: String {
        switch self {
        case .encrypted: return "ENC"
        case .vpn:       return "VPN"
        case .direct:    return "DIR"
        case .reject:    return "BLK"
        }
    }
}
