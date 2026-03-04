import SwiftUI

@main
struct FreeNetApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .task { await appState.initialize() }
        } label: {
            MenuBarIcon(state: appState.connectionState)
        }
        .menuBarExtraStyle(.window)

        Window("FreeNet Dashboard", id: "dashboard") {
            DashboardView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 900, height: 700)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 400)
        }
        .defaultSize(width: 600, height: 500)

        Window("Setup", id: "setup") {
            SetupWizard()
                .environmentObject(appState)
        }
        .defaultSize(width: 520, height: 480)
        .windowResizability(.contentSize)
    }
}

// MARK: - Menu Bar Icon

struct MenuBarIcon: View {
    let state: ConnectionState

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch state {
        case .connected:    return "shield.checkered"
        case .connecting:   return "shield.slash"
        case .disconnected: return "shield.slash"
        case .learning:     return "shield.checkered"
        }
    }

    private var iconColor: Color {
        switch state {
        case .connected:    return .blue
        case .connecting:   return .orange
        case .disconnected: return .gray
        case .learning:     return .green
        }
    }
}
