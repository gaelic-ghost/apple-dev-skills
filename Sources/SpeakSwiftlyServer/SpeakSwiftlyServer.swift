import Foundation

// MARK: - Server Runtime Entrypoint

/// Starts the standalone SpeakSwiftly server runtime using the package's default embedded bootstrap path.
public enum ServerRuntimeEntrypoint {
    /// Builds and runs an embedded session, then waits until that session stops.
    public static func run() async throws {
        let session = try await EmbeddedServerSession.start(
            environment: ProcessInfo.processInfo.environment,
            options: .init(),
            defaultProfile: .standaloneExecutable,
            bootstrap: EmbeddedServerSession.liveBootstrap
        )
        try await session.waitUntilStopped()
    }
}
