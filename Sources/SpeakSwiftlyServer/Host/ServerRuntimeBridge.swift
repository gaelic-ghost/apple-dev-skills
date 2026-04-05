import Foundation
import SpeakSwiftlyCore
import TextForSpeech

typealias SpeechNormalizationContext = TextForSpeech.Context

// MARK: - Runtime Bridge

struct RuntimeRequestHandle: Sendable {
    let id: String
    let operationName: String
    let profileName: String?
    let events: AsyncThrowingStream<SpeakSwiftly.RequestEvent, Error>

    // MARK: - Initialization

    init(
        id: String,
        operationName: String,
        profileName: String?,
        events: AsyncThrowingStream<SpeakSwiftly.RequestEvent, Error>
    ) {
        self.id = id
        self.operationName = operationName
        self.profileName = profileName
        self.events = events
    }

    init(_ handle: SpeakSwiftly.RequestHandle) {
        self.id = handle.id
        self.operationName = handle.operation
        self.profileName = handle.profileName
        self.events = handle.events
    }
}

// MARK: - Runtime Protocol

protocol ServerRuntimeProtocol: Actor {
    func start()
    func shutdown() async
    func statusEvents() -> AsyncStream<SpeakSwiftly.StatusEvent>
    func queueSpeechHandle(
        text: String,
        profileName: String,
        textProfileName: String?,
        normalizationContext: SpeechNormalizationContext?,
        as jobType: SpeakSwiftly.Job,
        id: String
    ) async -> RuntimeRequestHandle
    func createProfileHandle(
        profileName: String,
        text: String,
        voiceDescription: String,
        outputPath: String?,
        id: String
    ) async -> RuntimeRequestHandle
    func createCloneHandle(
        profileName: String,
        referenceAudioPath: String,
        transcript: String?,
        id: String
    ) async -> RuntimeRequestHandle
    func listProfilesHandle(id: String) async -> RuntimeRequestHandle
    func removeProfileHandle(profileName: String, id: String) async -> RuntimeRequestHandle
    func listQueueHandle(_ queueType: SpeakSwiftly.Queue, id requestID: String) async -> RuntimeRequestHandle
    func playbackHandle(_ action: SpeakSwiftly.PlaybackAction, id requestID: String) async -> RuntimeRequestHandle
    func clearQueueHandle(id requestID: String) async -> RuntimeRequestHandle
    func cancelRequestHandle(with id: String, requestID: String) async -> RuntimeRequestHandle
    func activeTextProfile() async -> TextForSpeech.Profile
    func baseTextProfile() async -> TextForSpeech.Profile
    func textProfile(named profileID: String) async -> TextForSpeech.Profile?
    func textProfiles() async -> [TextForSpeech.Profile]
    func effectiveTextProfile(named profileID: String?) async -> TextForSpeech.Profile
    func textProfilePersistenceURL() async -> URL?
    func createTextProfile(id: String, named name: String, replacements: [TextForSpeech.Replacement]) async throws -> TextForSpeech.Profile
    func storeTextProfile(_ profile: TextForSpeech.Profile) async throws
    func useTextProfile(_ profile: TextForSpeech.Profile) async throws
    func removeTextProfile(named profileID: String) async throws
    func resetTextProfile() async throws
    func addTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile
    func addTextReplacement(_ replacement: TextForSpeech.Replacement, toStoredTextProfileNamed profileID: String) async throws -> TextForSpeech.Profile
    func replaceTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile
    func replaceTextReplacement(_ replacement: TextForSpeech.Replacement, inStoredTextProfileNamed profileID: String) async throws -> TextForSpeech.Profile
    func removeTextReplacement(id replacementID: String) async throws -> TextForSpeech.Profile
    func removeTextReplacement(id replacementID: String, fromStoredTextProfileNamed profileID: String) async throws -> TextForSpeech.Profile
}

// MARK: - Runtime Adapter

extension SpeakSwiftly.Runtime: ServerRuntimeProtocol {
    func queueSpeechHandle(
        text: String,
        profileName: String,
        textProfileName: String?,
        normalizationContext: SpeechNormalizationContext?,
        as jobType: SpeakSwiftly.Job,
        id: String
    ) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(
            await self.speak(
                text: text,
                with: profileName,
                as: jobType,
                textProfileName: textProfileName,
                textContext: normalizationContext,
                id: id
            )
        )
    }

    func createProfileHandle(
        profileName: String,
        text: String,
        voiceDescription: String,
        outputPath: String?,
        id: String
    ) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(
            await self.createProfile(
                named: profileName,
                from: text,
                voice: voiceDescription,
                outputPath: outputPath,
                id: id
            )
        )
    }

    func createCloneHandle(
        profileName: String,
        referenceAudioPath: String,
        transcript: String?,
        id: String
    ) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(
            await self.createClone(
                named: profileName,
                from: URL(fileURLWithPath: referenceAudioPath),
                transcript: transcript,
                id: id
            )
        )
    }

    func listProfilesHandle(id: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await self.profiles(id: id))
    }

    func removeProfileHandle(profileName: String, id: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await self.removeProfile(named: profileName, id: id))
    }

    func listQueueHandle(_ queueType: SpeakSwiftly.Queue, id requestID: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await self.queue(queueType, id: requestID))
    }

    func playbackHandle(_ action: SpeakSwiftly.PlaybackAction, id requestID: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await self.playback(action, id: requestID))
    }

    func clearQueueHandle(id requestID: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await self.clearQueue(id: requestID))
    }

    func cancelRequestHandle(with id: String, requestID: String) async -> RuntimeRequestHandle {
        RuntimeRequestHandle(await self.cancelRequest(id, requestID: requestID))
    }

    func activeTextProfile() async -> TextForSpeech.Profile {
        await normalizer.activeProfile()
    }

    func baseTextProfile() async -> TextForSpeech.Profile {
        await normalizer.baseProfile()
    }

    func textProfile(named profileID: String) async -> TextForSpeech.Profile? {
        await normalizer.profile(named: profileID)
    }

    func textProfiles() async -> [TextForSpeech.Profile] {
        await normalizer.profiles()
    }

    func effectiveTextProfile(named profileID: String?) async -> TextForSpeech.Profile {
        await normalizer.effectiveProfile(named: profileID)
    }

    func textProfilePersistenceURL() async -> URL? {
        await normalizer.persistenceURL()
    }

    func createTextProfile(
        id: String,
        named name: String,
        replacements: [TextForSpeech.Replacement]
    ) async throws -> TextForSpeech.Profile {
        try await normalizer.createProfile(id: id, named: name, replacements: replacements)
    }

    func storeTextProfile(_ profile: TextForSpeech.Profile) async throws {
        try await normalizer.storeProfile(profile)
    }

    func useTextProfile(_ profile: TextForSpeech.Profile) async throws {
        try await normalizer.useProfile(profile)
    }

    func removeTextProfile(named profileID: String) async throws {
        try await normalizer.removeProfile(named: profileID)
    }

    func resetTextProfile() async throws {
        try await normalizer.reset()
    }

    func addTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile {
        try await normalizer.addReplacement(replacement)
    }

    func addTextReplacement(
        _ replacement: TextForSpeech.Replacement,
        toStoredTextProfileNamed profileID: String
    ) async throws -> TextForSpeech.Profile {
        try await normalizer.addReplacement(replacement, toStoredProfileNamed: profileID)
    }

    func replaceTextReplacement(_ replacement: TextForSpeech.Replacement) async throws -> TextForSpeech.Profile {
        try await normalizer.replaceReplacement(replacement)
    }

    func replaceTextReplacement(
        _ replacement: TextForSpeech.Replacement,
        inStoredTextProfileNamed profileID: String
    ) async throws -> TextForSpeech.Profile {
        try await normalizer.replaceReplacement(replacement, inStoredProfileNamed: profileID)
    }

    func removeTextReplacement(id replacementID: String) async throws -> TextForSpeech.Profile {
        try await normalizer.removeReplacement(id: replacementID)
    }

    func removeTextReplacement(
        id replacementID: String,
        fromStoredTextProfileNamed profileID: String
    ) async throws -> TextForSpeech.Profile {
        try await normalizer.removeReplacement(id: replacementID, fromStoredProfileNamed: profileID)
    }
}
