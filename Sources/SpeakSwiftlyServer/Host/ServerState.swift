import Foundation
import Observation

// MARK: - Observable State

@Observable
@MainActor
final class ServerState {
    var overview = HostOverviewSnapshot(
        service: "speak-swiftly-server",
        environment: "development",
        serverMode: "degraded",
        workerMode: "starting",
        workerStage: "starting",
        workerReady: false,
        startupError: nil,
        profileCacheState: "uninitialized",
        profileCacheWarning: nil,
        profileCount: 0,
        lastProfileRefreshAt: nil
    )

    var generationQueue = QueueStatusSnapshot(
        queueType: "generation",
        activeCount: 0,
        queuedCount: 0,
        activeRequest: nil
    )

    var playbackQueue = QueueStatusSnapshot(
        queueType: "playback",
        activeCount: 0,
        queuedCount: 0,
        activeRequest: nil
    )

    var playback = PlaybackStatusSnapshot(
        state: "idle",
        activeRequest: nil
    )

    var currentGenerationJob: CurrentGenerationJobSnapshot?
    var transports = [TransportStatusSnapshot]()
    var recentErrors = [RecentErrorSnapshot]()
    var jobsByID: [String: JobSnapshot] = [:]

    init() {}
}
