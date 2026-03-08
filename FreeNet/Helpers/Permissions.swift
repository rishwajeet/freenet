import Foundation

// MARK: - Permission Errors

enum PermissionError: LocalizedError {
    case mihomoNotFound
    case helperInstallFailed(String)
    case authorizationDenied
    case chmodFailed(String)

    var errorDescription: String? {
        switch self {
        case .mihomoNotFound:
            return "Mihomo binary not found in app bundle."
        case .helperInstallFailed(let reason):
            return "Failed to install helper tool: \(reason)"
        case .authorizationDenied:
            return "Administrator authorization was denied."
        case .chmodFailed(let reason):
            return "Failed to set executable permission: \(reason)"
        }
    }
}

// MARK: - System Permission Helpers

enum Permissions {

    /// Path to the embedded mihomo binary inside the app bundle.
    static var mihomoBinaryPath: String {
        Bundle.main.path(forResource: "mihomo", ofType: nil)
            ?? Bundle.main.bundlePath + "/Contents/Resources/mihomo"
    }

    // MARK: - TUN Permission

    /// Check if mihomo can create a TUN device (requires root/admin privileges).
    ///
    /// For V1, this simply checks whether we've previously installed a
    /// privileged helper script that runs mihomo with elevated permissions.
    static func hasTUNPermission() -> Bool {
        let helperPath = helperScriptPath()
        return FileManager.default.isExecutableFile(atPath: helperPath)
    }

    /// Request TUN permission by prompting for admin password via AppleScript.
    ///
    /// Creates a helper shell script that uses `sudo` to run mihomo.
    /// The user is prompted via macOS system dialog for their password.
    ///
    /// - Returns: `true` if authorization was granted and helper installed.
    static func requestTUNPermission() async -> Bool {
        let helperPath = helperScriptPath()
        let mihomoPath = mihomoBinaryPath

        // AppleScript to create helper with admin privileges
        let script = """
            do shell script "mkdir -p '\(helperDirectory())' && \
            echo '#!/bin/bash\\nexec sudo \\\"$@\\\"' > '\(helperPath)' && \
            chmod +x '\(helperPath)' && \
            chmod +x '\(mihomoPath)'" \
            with administrator privileges
            """

        return await runAppleScript(script)
    }

    // MARK: - Helper Tool

    /// Install the privileged helper for TUN access.
    ///
    /// For V1, this creates a simple shell wrapper that elevates mihomo via `sudo`.
    /// Future versions can use SMAppService for a proper launchd-based helper.
    static func installHelperTool() async throws {
        let success = await requestTUNPermission()
        if !success {
            throw PermissionError.authorizationDenied
        }
    }

    // MARK: - Mihomo Binary

    /// Ensure the embedded mihomo binary has executable permissions.
    ///
    /// App bundles may strip execute bits during code signing or download.
    /// This restores `+x` on the binary.
    static func ensureMihomoExecutable() throws {
        let path = mihomoBinaryPath

        guard FileManager.default.fileExists(atPath: path) else {
            throw PermissionError.mihomoNotFound
        }

        // Check if already executable
        if FileManager.default.isExecutableFile(atPath: path) {
            return
        }

        // Set executable permission
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", path]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PermissionError.chmodFailed(errorMessage)
        }
    }

    // MARK: - Private

    /// Directory for FreeNet helper scripts in Application Support.
    private static func helperDirectory() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.path ?? NSHomeDirectory()
        return "\(appSupport)/FreeNet"
    }

    /// Path to the helper launcher script.
    private static func helperScriptPath() -> String {
        "\(helperDirectory())/freenet-helper"
    }

    /// Run an AppleScript string and return whether it succeeded.
    private static func runAppleScript(_ source: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]

                let errorPipe = Pipe()
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
