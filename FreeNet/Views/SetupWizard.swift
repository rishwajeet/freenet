import SwiftUI
import UniformTypeIdentifiers

// MARK: - Setup Wizard

struct SetupWizard: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentStep = 0
    @State private var configText = ""
    @State private var validationState: ValidationState = .idle
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.top, 24)

            Spacer()

            // Content
            switch currentStep {
            case 0: welcomeStep
            case 1: vpnConfigStep
            case 2: successStep
            default: EmptyView()
            }

            Spacer()

            // Navigation
            navigationButtons
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
        }
        .frame(width: 520, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: step == currentStep ? 24 : 8, height: 4)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Welcome

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

    // MARK: - Step 2: VPN Config

    private var vpnConfigStep: some View {
        VStack(spacing: 20) {
            Text("Add your WireGuard config")
                .font(.title3)
                .fontWeight(.semibold)

            // Drop zone
            VStack(spacing: 12) {
                if configText.isEmpty {
                    dropZone
                } else {
                    configPreview
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
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

            Text("Works with Proton, Mullvad, or any WireGuard provider")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 40)
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

    // MARK: - Step 3: Success

    private var successStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("You're all set")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                FeatureCheck(label: "Encrypted DNS", description: "All lookups encrypted over HTTPS")
                FeatureCheck(label: "Ad blocking", description: "Ads and trackers rejected at the DNS level")
                FeatureCheck(label: "Intelligent routing", description: "Learns which sites need VPN automatically")
            }
            .padding(.horizontal, 20)

            Text("FreeNet is now in your menu bar. It learns as you browse.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
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
            case 1:
                Button("Skip for Now") {
                    withAnimation { currentStep = 2 }
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    validateConfig()
                    if case .valid = validationState {
                        withAnimation { currentStep = 2 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(configText.isEmpty)
            case 2:
                Button("Done") {
                    appState.showSetupWizard = false
                    Task { await appState.startEngine() }
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
            // Handle file URL
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
            // Handle plain text
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

// MARK: - Feature Check Row

private struct FeatureCheck: View {
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
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
