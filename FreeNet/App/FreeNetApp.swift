import SwiftUI

@main
struct FreeNetApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
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
        .defaultSize(width: 560, height: 520)
        .windowResizability(.contentSize)

        Window("About FreeNet", id: "about") {
            AboutView()
        }
        .defaultSize(width: 320, height: 380)
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

// MARK: - Keyboard Shortcuts (LSUIElement apps have no menu bar)

final class KeyboardShortcutMonitor {
    static let shared = KeyboardShortcutMonitor()
    private var monitor: Any?

    func install(appState: AppState) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }

            switch event.charactersIgnoringModifiers {
            case "q":
                Task { @MainActor in
                    appState.stopEngine()
                    NSApp.terminate(nil)
                }
                return nil
            case ",":
                // Open the Settings window by ID — since LSUIElement=true, there's no app menu
                for window in NSApp.windows where window.title == "Settings" {
                    window.makeKeyAndOrderFront(nil)
                    return nil
                }
                return nil
            default:
                return event
            }
        }
    }
}
