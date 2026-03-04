import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "shield.checkered")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("FreeNet")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Intelligent internet freedom for macOS")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 10) {
                Link(destination: URL(string: "https://github.com/rishwajeet/freenet")!) {
                    Label("GitHub Repository", systemImage: "link")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Link(destination: URL(string: "https://github.com/rishwajeet/freenet/issues")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Spacer()

            Text("MIT License")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 320, height: 380)
    }
}
