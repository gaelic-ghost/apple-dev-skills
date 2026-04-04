import Foundation

// MARK: - Host State Models

struct HostOverviewSnapshot: Codable, Sendable, Equatable {
    let service: String
    let environment: String
    let serverMode: String
    let workerMode: String
    let workerStage: String
    let workerReady: Bool
    let startupError: String?
    let profileCacheState: String
    let profileCacheWarning: String?
    let profileCount: Int
    let lastProfileRefreshAt: String?

    enum CodingKeys: String, CodingKey {
        case service
        case environment
        case serverMode = "server_mode"
        case workerMode = "worker_mode"
        case workerStage = "worker_stage"
        case workerReady = "worker_ready"
        case startupError = "startup_error"
        case profileCacheState = "profile_cache_state"
        case profileCacheWarning = "profile_cache_warning"
        case profileCount = "profile_count"
        case lastProfileRefreshAt = "last_profile_refresh_at"
    }
}

struct QueueStatusSnapshot: Codable, Sendable, Equatable {
    let queueType: String
    let activeCount: Int
    let queuedCount: Int
    let activeRequest: ActiveRequestSnapshot?

    enum CodingKeys: String, CodingKey {
        case queueType = "queue_type"
        case activeCount = "active_count"
        case queuedCount = "queued_count"
        case activeRequest = "active_request"
    }
}

struct PlaybackStatusSnapshot: Codable, Sendable, Equatable {
    let state: String
    let activeRequest: ActiveRequestSnapshot?

    enum CodingKeys: String, CodingKey {
        case state
        case activeRequest = "active_request"
    }
}

struct CurrentGenerationJobSnapshot: Codable, Sendable, Equatable {
    let jobID: String
    let op: String
    let profileName: String?
    let submittedAt: String
    let startedAt: String?
    let latestStage: String?
    let elapsedGenerationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case op
        case profileName = "profile_name"
        case submittedAt = "submitted_at"
        case startedAt = "started_at"
        case latestStage = "latest_stage"
        case elapsedGenerationSeconds = "elapsed_generation_seconds"
    }
}

struct TransportStatusSnapshot: Codable, Sendable, Equatable {
    let name: String
    let enabled: Bool
    let state: String
    let host: String?
    let port: Int?
    let path: String?
    let advertisedAddress: String?

    enum CodingKeys: String, CodingKey {
        case name
        case enabled
        case state
        case host
        case port
        case path
        case advertisedAddress = "advertised_address"
    }
}

struct RecentErrorSnapshot: Codable, Sendable, Equatable {
    let occurredAt: String
    let source: String
    let code: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case occurredAt = "occurred_at"
        case source
        case code
        case message
    }
}

struct HostStateSnapshot: Codable, Sendable, Equatable {
    let overview: HostOverviewSnapshot
    let generationQueue: QueueStatusSnapshot
    let playbackQueue: QueueStatusSnapshot
    let playback: PlaybackStatusSnapshot
    let currentGenerationJob: CurrentGenerationJobSnapshot?
    let transports: [TransportStatusSnapshot]
    let recentErrors: [RecentErrorSnapshot]
}
