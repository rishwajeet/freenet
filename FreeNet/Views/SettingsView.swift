import SwiftUI
import ServiceManagement

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newSafeDomain = ""
    @State private var safelist: [String] = []
    @State private var showVPNReconfigure = false

    var body: some View {
        Form {
            // DNS Section
            Section("DNS") {
                Picker("Provider", selection: $appState.dnsProvider) {
                    ForEach(DNSProvider.allCases) { provider in
                        VStack(alignment: .leading) {
                            Text(provider.displayName)
                            Text(provider.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(provider)
                    }
                }

                if appState.dnsProvider == .custom {
                    TextField("DoH URL", text: $appState.customDNSURL, prompt: Text("https://dns.example.com/dns-query"))
                        .textFieldStyle(.roundedBorder)
                }
            }

            // VPN Section
            Section("VPN") {
                if appState.isVPNConfigured {
                    if let config = appState.loadVPNConfig() {
                        LabeledContent("Server", value: config.serverHost)
                        LabeledContent("Port", value: "\(config.serverPort)")
                        LabeledContent("Address", value: config.address)
                    }
                    Button("Reconfigure VPN...") {
                        showVPNReconfigure = true
                    }
                } else {
                    Label("No VPN configured", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("Set Up VPN...") {
                        appState.showSetupWizard = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Safelist Section
            Section("Safelist") {
                Text("Domains that always route directly (no proxy, no DNS encryption).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(safelist, id: \.self) { domain in
                    HStack {
                        Text(domain)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            safelist.removeAll { $0 == domain }
                            saveSafelist()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Add domain", text: $newSafeDomain, prompt: Text("example.com"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addSafeDomain() }
                    Button("Add") { addSafeDomain() }
                        .disabled(newSafeDomain.isEmpty)
                }
            }

            // Intelligence Section
            Section("Intelligence") {
                Toggle("Crowd intelligence reporting", isOn: $appState.crowdIntelligenceEnabled)
                Text("Anonymously share domain routing data to improve FreeNet for everyone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Notifications", isOn: $appState.notificationsEnabled)
                Text("Get notified when FreeNet learns a new blocked domain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // General Section
            Section("General") {
                Toggle("Start at login", isOn: $appState.autoStartEnabled)
                    .onChange(of: appState.autoStartEnabled) { _, enabled in
                        setLoginItem(enabled: enabled)
                    }

                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Engine") {
                    Text("mihomo (clash-meta)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loadSafelist() }
        .sheet(isPresented: $showVPNReconfigure) {
            SetupWizard()
                .environmentObject(appState)
        }
    }

    // MARK: - Safelist Management

    private func addSafeDomain() {
        let domain = newSafeDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !domain.isEmpty, !safelist.contains(domain) else { return }
        safelist.append(domain)
        saveSafelist()
        newSafeDomain = ""
    }

    private func loadSafelist() {
        safelist = UserDefaults.standard.stringArray(forKey: "safelist") ?? []
    }

    private func saveSafelist() {
        UserDefaults.standard.set(safelist, forKey: "safelist")
    }

    // MARK: - Login Item

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}
