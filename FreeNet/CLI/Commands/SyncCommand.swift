import ArgumentParser
import Foundation

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync crowd intelligence blocklist."
    )

    func run() async throws {
        let state = try CLIState()

        let beforeCount = try state.domainStore.allDomains().count
        print("Syncing crowd intelligence...")

        try await state.crowdClient.sync(into: state.domainStore)

        let afterCount = try state.domainStore.allDomains().count
        let delta = afterCount - beforeCount
        if delta > 0 {
            print("Synced. \(delta) new domain(s) imported (\(afterCount) total).")
        } else {
            print("Synced. No new domains (\(afterCount) total).")
        }
    }
}
