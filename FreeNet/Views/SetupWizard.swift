import SwiftUI
import UniformTypeIdentifiers

// MARK: - Setup Wizard

struct SetupWizard: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var configText = ""
    @State private var validationState: ValidationState = .idle
    @State private var isDropTargeted = false
    @State private var engineStarted = false
    @State private var engineFailed = false
    @State private var showProviderGuide = false
    @State private var selectedProvider: VPNProvider?

    private let totalSteps = 6

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.top, 24)

            Spacer()

            // Content
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: problemStep
                case 2: howItWorksStep
                case 3: vpnConfigStep
                case 4: permissionsStep
                case 5: allSetStep
                default: EmptyView()
                }
            }
            .transition(.opacity)

            Spacer()

            // Navigation
            navigationButtons
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: step == currentStep ? 24 : 8, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            Text("Your internet, the way it should be")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Encrypted DNS, intelligent routing, and ad blocking\nthat learns as you browse.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 1: The Problem

    private var problemStep: some View {
        VStack(spacing: 20) {
            Text("The problem with today's tools")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                ProblemCard(
                    icon: "tortoise.fill",
                    title: "VPNs slow everything down",
                    description: "They route ALL traffic through a remote server, even sites that don't need it."
                )
                ProblemCard(
                    icon: "globe",
                    title: "Encrypted DNS can't unblock sites",
                    description: "It protects your lookups, but blocked sites stay blocked."
                )
                ProblemCard(
                    icon: "arrow.left.arrow.right",
                    title: "Manual switching is a pain",
                    description: "Toggling VPN on and off for different sites wastes your time."
                )
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 2: How FreeNet Works

    private var howItWorksStep: some View {
        VStack(spacing: 20) {
            Text("FreeNet routes each site the smart way")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                PathwayCard(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "Encrypted DNS",
                    badge: "Default",
                    description: "Every lookup encrypted. Ads and trackers blocked."
                )
                PathwayCard(
                    icon: "network",
                    color: .purple,
                    title: "VPN Tunnel",
                    badge: "When needed",
                    description: "Only blocked sites go through VPN — everything else stays fast."
                )
                PathwayCard(
                    icon: "arrow.right",
                    color: .gray,
                    title: "Direct Connection",
                    badge: "Exceptions",
                    description: "Banking, UPI, and sites that break under proxy go direct."
                )
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 3: VPN Config

    private var vpnConfigStep: some View {
        VStack(spacing: 12) {
            Text("Add your WireGuard config")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Optional but recommended — without it, FreeNet can't unblock geo-restricted sites.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Drop zone
            VStack(spacing: 12) {
                if configText.isEmpty {
                    dropZone
                } else {
                    configPreview
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: configText.isEmpty ? [6] : [])
                    )
            )
            .background(isDropTargeted ? Color.accentColor.opacity(0.05) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }

            // Validation feedback
            validationFeedback

            // Provider guide toggle
            DisclosureGroup(isExpanded: $showProviderGuide) {
                providerGuideContent
            } label: {
                Label("How do I get a WireGuard config?", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Provider Guide

    private var providerGuideContent: some View {
        VStack(spacing: 8) {
            // Provider picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(VPNProvider.allCases) { provider in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedProvider = provider }
                        } label: {
                            Text(provider.name)
                                .font(.caption2)
                                .fontWeight(selectedProvider == provider ? .semibold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedProvider == provider ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                .foregroundStyle(selectedProvider == provider ? .primary : .secondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Steps for selected provider
            if let provider = selectedProvider {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(provider.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(.caption2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.accentColor)
                                .clipShape(Circle())

                            Text(step)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let url = provider.helpURL {
                        Link(destination: url) {
                            Label("Open \(provider.name) guide", systemImage: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Pick your VPN provider above to see instructions.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }
        }
        .padding(.top, 4)
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Drop .conf file here")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("or paste config below")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Paste from Clipboard") {
                if let text = NSPasteboard.general.string(forType: .string) {
                    configText = text
                    validateConfig()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var configPreview: some View {
        ScrollView {
            Text(configText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                configText = ""
                validationState = .idle
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    @ViewBuilder
    private var validationFeedback: some View {
        switch validationState {
        case .idle:
            EmptyView()
        case .valid:
            Label("Valid WireGuard configuration", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .invalid(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Step 4: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            Text("One permission needed")
                .font(.title3)
                .fontWeight(.semibold)

            Text("FreeNet creates a local network tunnel to route your traffic intelligently. macOS will ask for your password to authorize this.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                PermissionItem(text: "Creates a local TUN interface for traffic routing")
                PermissionItem(text: "All processing happens on your Mac — nothing leaves your device")
                PermissionItem(text: "FreeNet never sends your password anywhere")
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 5: All Set

    private var allSetStep: some View {
        VStack(spacing: 20) {
            Image(systemName: engineFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(engineFailed ? .orange : .green)

            Text(engineFailed ? "Partially ready" : "You're all set")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                FeatureCheck(
                    label: "Encrypted DNS",
                    description: "All lookups encrypted over HTTPS",
                    active: appState.connectionState == .connected || appState.connectionState == .connecting
                )
                FeatureCheck(
                    label: "Ad blocking",
                    description: "Ads and trackers rejected at the DNS level",
                    active: appState.connectionState == .connected || appState.connectionState == .connecting
                )
                FeatureCheck(
                    label: "Intelligent routing",
                    description: "Learns which sites need VPN automatically",
                    active: appState.isVPNConfigured
                )
            }
            .padding(.horizontal, 20)

            if engineFailed {
                Text("Some features couldn't start. You can try again from Settings.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Text("Click the menu bar icon to see live stats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 && currentStep < 5 {
                Button("Back") {
                    withAnimation { currentStep -= 1 }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            switch currentStep {
            case 0:
                Button("Get Started") {
                    withAnimation { currentStep = 1 }
                }
                .buttonStyle(.borderedProminent)

            case 1, 2:
                Button("Next") {
                    withAnimation { currentStep += 1 }
                }
                .buttonStyle(.borderedProminent)

            case 3:
                Button("Skip for Now") {
                    withAnimation { currentStep = 4 }
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    validateConfig()
                    if case .valid = validationState {
                        withAnimation { currentStep = 4 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(configText.isEmpty)

            case 4:
                Button("Authorize & Start") {
                    Task {
                        await appState.startEngine()
                        engineStarted = true
                        engineFailed = appState.connectionState != .connected
                        withAnimation { currentStep = 5 }
                    }
                }
                .buttonStyle(.borderedProminent)

            case 5:
                Button("Done") {
                    appState.completeOnboarding()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Logic

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let content = try? String(contentsOf: url, encoding: .utf8)
                    else { return }
                    Task { @MainActor in
                        configText = content
                        validateConfig()
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                    guard let data = data as? Data,
                          let text = String(data: data, encoding: .utf8)
                    else { return }
                    Task { @MainActor in
                        configText = text
                        validateConfig()
                    }
                }
                return true
            }
        }
        return false
    }

    private func validateConfig() {
        guard !configText.isEmpty else {
            validationState = .idle
            return
        }

        do {
            let config = try WireGuardParser.parse(configText)
            appState.saveVPNConfig(config)
            validationState = .valid
        } catch {
            validationState = .invalid(error.localizedDescription)
        }
    }
}

// MARK: - Validation State

private enum ValidationState {
    case idle
    case valid
    case invalid(String)
}

// MARK: - Problem Card

private struct ProblemCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Pathway Card

private struct PathwayCard: View {
    let icon: String
    let color: Color
    let title: String
    let badge: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(badge)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(color.opacity(0.15))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Permission Item

private struct PermissionItem: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.blue)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Feature Check Row

private struct FeatureCheck: View {
    let label: String
    let description: String
    var active: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(active ? .green : .secondary)
                .font(.body)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - VPN Provider Tutorials

enum VPNProvider: String, CaseIterable, Identifiable {
    case proton
    case mullvad
    case surfshark
    case nordvpn
    case windscribe
    case ivpn

    var id: String { rawValue }

    var name: String {
        switch self {
        case .proton:     return "Proton VPN"
        case .mullvad:    return "Mullvad"
        case .surfshark:  return "Surfshark"
        case .nordvpn:    return "NordVPN"
        case .windscribe: return "Windscribe"
        case .ivpn:       return "IVPN"
        }
    }

    var steps: [String] {
        switch self {
        case .proton:
            return [
                "Open protonvpn.com and sign in to your account",
                "Go to Downloads \u{2192} WireGuard configuration",
                "Select a server location (any country you want to appear from)",
                "Click \"Create\" to generate the config",
                "Download the .conf file and drop it here"
            ]
        case .mullvad:
            return [
                "Open mullvad.net/account and sign in",
                "Go to WireGuard configuration",
                "Click \"Generate key\" if you haven't already",
                "Select a server location and click \"Download file\"",
                "Drop the downloaded .conf file here"
            ]
        case .surfshark:
            return [
                "Open my.surfshark.com and sign in",
                "Go to VPN \u{2192} Manual setup \u{2192} Router/Other",
                "Select WireGuard and choose a server location",
                "Click \"Get Credentials\" and then \"Download .conf\"",
                "Drop the .conf file here"
            ]
        case .nordvpn:
            return [
                "Open nordvpn.com/servers/tools to get your service credentials",
                "Copy your NordVPN access token",
                "Go to nordvpn.com/servers and pick a server",
                "Use the NordVPN Linux CLI: nordvpn set technology nordlynx",
                "Export config with: nordvpn export-wireguard, then drop the file here"
            ]
        case .windscribe:
            return [
                "Open windscribe.com and sign in to your account",
                "Go to Account \u{2192} WireGuard Config Generator",
                "Pick a server location from the dropdown",
                "Click \"Get Config\" to generate and download the .conf file",
                "Drop the .conf file here"
            ]
        case .ivpn:
            return [
                "Open ivpn.net/account and sign in",
                "Go to WireGuard \u{2192} Configuration",
                "Generate a new key pair (or use existing)",
                "Select a server and download the .conf file",
                "Drop the .conf file here"
            ]
        }
    }

    var helpURL: URL? {
        switch self {
        case .proton:     return URL(string: "https://protonvpn.com/support/wireguard-configurations/")
        case .mullvad:    return URL(string: "https://mullvad.net/en/help/wireguard-and-mullvad-vpn/")
        case .surfshark:  return URL(string: "https://support.surfshark.com/hc/en-us/articles/6585805139474")
        case .nordvpn:    return URL(string: "https://support.nordvpn.com/hc/en-us/articles/20164827795345")
        case .windscribe: return URL(string: "https://windscribe.com/guides/wireguard")
        case .ivpn:       return URL(string: "https://www.ivpn.net/knowledgebase/general/wireguard-config-file-generation/")
        }
    }
}
