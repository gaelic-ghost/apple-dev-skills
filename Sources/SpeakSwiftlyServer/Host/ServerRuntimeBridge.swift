import Foundation
import SpeakSwiftlyCore
import TextForSpeech

typealias SpeechNormalizationContext = TextForSpeech.Context

// MARK: - Runtime Bridge

struct RuntimeRequestHandle: Sendable {
    let id: String
    let operation: String
    let profileName: String?
    let events: AsyncThrowingStream<SpeakSwiftly.RequestEvent, Error>

    // MARK: - Initialization

    init(
        id: String,
        operation: String,
        profileName: String?,
        events: AsyncThrowingStream<SpeakSwiftly.RequestEvent, Error>
    ) {
        self.id = id
        self.operation = operation
        self.profileName = profileName
        self.events = events
    }

    init(_ handle: SpeakSwiftly.RequestHandle) {
        self.id = handle.id
        self.operation = handle.operation
        self.profileName = handle.profileName
        self.events = handle.events
    }
}

enum RuntimeQueueType: Sendable {
    case generation
    case playback
}

enum RuntimePlaybackAction: Sendable {
    case pause
    case resume
    case state
}

// MARK: - Runtime Protocol

protocol ServerRuntimeProtocol: Actor {
    func start()
    func shutdown() async
    func statusEvents() async -> AsyncStream<SpeakSwiftly.StatusEvent>
    func speak(
        text: String,
        with profileName: String,
        textProfileName: String?,
        normalizationContext: SpeechNormalizationContext?,
        sourceFormat: TextForSpeech.SourceFormat?
    ) async -> RuntimeRequestHandle
    func createProfile(
        named profileName: String,
        vibe: SpeakSwiftly.Vibe,
        from text: String,
        voice voiceDescription: String,
        outputPath: String?,
        cwd: String?
    ) async -> RuntimeRequestHandle
    func createClone(
        named profileName: String,
        vibe: SpeakSwiftly.Vibe,
        from referenceAudioPath: String,
        transcript: String?,
        cwd: String?
    ) async -> RuntimeRequestHandle
    func profiles() async -> RuntimeRequestHandle
    func removeProfile(named profileName: String) async -> RuntimeRequestHandle
    func queue(_ queueType: RuntimeQueueType) async -> RuntimeRequestHandle
    func playback(_ action: RuntimePlaybackAction) async -> RuntimeRequestHandle
    func clearQueue() async -> RuntimeRequestHandle
    func cancelRequest(_ requestID: String) async -> RuntimeRequestHandle
    func activeTextProfile() async -> TextForSpeech.Profile
    func baseTextProfile() async -> TextForSpeech.Profile
    func textProfile(id profileID: String) async -> TextForSpeech.Profile?
    func textProfiles() async -> [TextForSpeech.Profile]
    func effectiveTextProfile(id profileID: String?) async -> TextForSpeech.Profile
    func textProfilePersistenceURL() async -> URL?
    func loadTextProfiles() async throws
    func saveTextProfiles() async throws
    func createTextProfile(id: String, named name: String, replacements: [TextForSpeech.Replacement]) async throws -> TextForSpeech.Profile
    func storeTextProfile(_ profile: TextForSpeech.Profile) async throws
    func useTextProfile(_ profile: TextForSpeech.Profile) async throws
    func removeTextProfile(id profileID: String) async throws
    func resetTextProfile() async throws
    func addTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile
    func addTextReplacement(_ replacement: TextForSpeech.Replacement, toStoredTextProfileID profileID: String) async throws -> TextForSpeech.Profile
    func replaceTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile
    func replaceTextReplacement(_ replacement: TextForSpeech.Replacement, inStoredTextProfileID profileID: String) async throws -> TextForSpeech.Profile
    func removeTextReplacement(id replacementID: String) async throws -> TextForSpeech.Profile
    func removeTextReplacement(id replacementID: String, fromStoredTextProfileID profileID: String) async throws -> TextForSpeech.Profile
}

// MARK: - Runtime Adapter

actor ServerRuntimeAdapter: ServerRuntimeProtocol {
    private let runtime: SpeakSwiftly.Runtime

    init(runtime: SpeakSwiftly.Runtime) {
        self.runtime = runtime
    }

    func start() {
        Task {
            await runtime.start()
        }
    }

    func shutdown() async {
        await runtime.shutdown()
    }

    func statusEvents() async -> AsyncStream<SpeakSwiftly.StatusEvent> {
        await runtime.statusEvents()
    }

    func speak(
        text: String,
        with profileName: String,
        textProfileName: String?,
        normalizationContext: SpeechNormalizationContext?,
        sourceFormat: TextForSpeech.SourceFormat?
    ) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(
            await runtime.generate.speech(
                text: text,
                with: profileName,
                textProfileName: textProfileName,
                textContext: normalizationContext,
                sourceFormat: sourceFormat
            )
        )
    }

    func createProfile(
        named profileName: String,
        vibe: SpeakSwiftly.Vibe,
        from text: String,
        voice voiceDescription: String,
        outputPath: String?,
        cwd: String?
    ) async -> RuntimeRequestHandle {
        let currentDirectoryPath = FileManager.default.currentDirectoryPath
        let previousDirectoryPath = currentDirectoryPath
        if let cwd, !cwd.isEmpty {
            FileManager.default.changeCurrentDirectoryPath(cwd)
        }
        defer {
            FileManager.default.changeCurrentDirectoryPath(previousDirectoryPath)
        }
        return RuntimeRequestHandle(
            await runtime.voices.create(
                design: profileName,
                from: text,
                vibe: vibe,
                voice: voiceDescription,
                outputPath: outputPath
            )
        )
    }

    func createClone(
        named profileName: String,
        vibe: SpeakSwiftly.Vibe,
        from referenceAudioPath: String,
        transcript: String?,
        cwd: String?
    ) async -> RuntimeRequestHandle {
        let currentDirectoryPath = FileManager.default.currentDirectoryPath
        let previousDirectoryPath = currentDirectoryPath
        if let cwd, !cwd.isEmpty {
            FileManager.default.changeCurrentDirectoryPath(cwd)
        }
        defer {
            FileManager.default.changeCurrentDirectoryPath(previousDirectoryPath)
        }
        return RuntimeRequestHandle(
            await runtime.voices.create(
                clone: profileName,
                from: URL(fileURLWithPath: referenceAudioPath),
                vibe: vibe,
                transcript: transcript
            )
        )
    }

    func profiles() async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await runtime.voices.list())
    }

    func removeProfile(named profileName: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await runtime.voices.delete(named: profileName))
    }

    func queue(_ queueType: RuntimeQueueType) async -> RuntimeRequestHandle {
        switch queueType {
        case .generation:
            RuntimeRequestHandle(await runtime.jobs.generationQueue())
        case .playback:
            RuntimeRequestHandle(await runtime.player.list())
        }
    }

    func playback(_ action: RuntimePlaybackAction) async -> RuntimeRequestHandle {
        switch action {
        case .pause:
            RuntimeRequestHandle(await runtime.player.pause())
        case .resume:
            RuntimeRequestHandle(await runtime.player.resume())
        case .state:
            RuntimeRequestHandle(await runtime.player.state())
        }
    }

    func clearQueue() async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await runtime.player.clearQueue())
    }

    func cancelRequest(_ requestID: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await runtime.player.cancelRequest(requestID))
    }

    func activeTextProfile() async -> TextForSpeech.Profile {
        await runtime.normalizer.activeProfile()
    }

    func baseTextProfile() async -> TextForSpeech.Profile {
        await runtime.normalizer.baseProfile()
    }

    func textProfile(id profileID: String) async -> TextForSpeech.Profile? {
        await runtime.normalizer.profile(id: profileID)
    }

    func textProfiles() async -> [TextForSpeech.Profile] {
        await runtime.normalizer.profiles()
    }

    func effectiveTextProfile(id profileID: String?) async -> TextForSpeech.Profile {
        await runtime.normalizer.effectiveProfile(id: profileID)
    }

    func textProfilePersistenceURL() async -> URL? {
        nil
    }

    func loadTextProfiles() async throws {
        try await runtime.normalizer.loadProfiles()
    }

    func saveTextProfiles() async throws {
        try await runtime.normalizer.saveProfiles()
    }

    func createTextProfile(
        id: String,
        named name: String,
        replacements: [TextForSpeech.Replacement]
    ) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.createProfile(id: id, named: name, replacements: replacements)
    }

    func storeTextProfile(_ profile: TextForSpeech.Profile) async throws {
        try await runtime.normalizer.storeProfile(profile)
    }

    func useTextProfile(_ profile: TextForSpeech.Profile) async throws {
        try await runtime.normalizer.useProfile(profile)
    }

    func removeTextProfile(id profileID: String) async throws {
        try await runtime.normalizer.removeProfile(id: profileID)
    }

    func resetTextProfile() async throws {
        try await runtime.normalizer.reset()
    }

    func addTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.addReplacement(replacement)
    }

    func addTextReplacement(
        _ replacement: TextForSpeech.Replacement,
        toStoredTextProfileID profileID: String
    ) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.addReplacement(replacement, toStoredProfileID: profileID)
    }

    func replaceTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.replaceReplacement(replacement)
    }

    func replaceTextReplacement(
        _ replacement: TextForSpeech.Replacement,
        inStoredTextProfileID profileID: String
    ) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.replaceReplacement(replacement, inStoredProfileID: profileID)
    }

    func removeTextReplacement(id replacementID: String) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.removeReplacement(id: replacementID)
    }

    func removeTextReplacement(
        id replacementID: String,
        fromStoredTextProfileID profileID: String
    ) async throws -> TextForSpeech.Profile {
        try await runtime.normalizer.removeReplacement(id: replacementID, fromStoredProfileID: profileID)
    }
}
