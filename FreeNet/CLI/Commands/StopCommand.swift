import ArgumentParser
import Foundation

struct StopCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the mihomo engine."
    )

    func run() async throws {
        // Try PID file first
        if let pid = CLIState.readPID() {
            kill(pid, SIGTERM)
            CLIState.removePIDFile()
            print("Mihomo stopped (PID \(pid))")
            return
        }

        // Fallback: find mihomo process via pkill
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        process.arguments = ["-f", "mihomo"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            CLIState.removePIDFile()
            print("Mihomo stopped via pkill")
        } else {
            throw CLIError.mihomoNotRunning
        }
    }
}
