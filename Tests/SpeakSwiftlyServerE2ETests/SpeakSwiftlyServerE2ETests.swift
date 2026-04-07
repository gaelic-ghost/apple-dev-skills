import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#endif

// MARK: - End-to-End Tests

/// Keep the suite type name stable so Xcode test plans can target it directly.
@Suite(
    .serialized,
    .enabled(
        if: ProcessInfo.processInfo.environment["SPEAKSWIFTLYSERVER_E2E"] == "1",
        "Set SPEAKSWIFTLYSERVER_E2E=1 to run live end-to-end coverage."
    )
)
struct SpeakSwiftlyServerE2ETests {
    // MARK: Test Fixtures

    private static let testingProfileText = "Hello there from SpeakSwiftlyServer end-to-end coverage."
    private static let testingProfileVoiceDescription = "A generic, warm, masculine, slow speaking voice."
    static let testingCloneSourceText = """
    This imported reference audio should let SpeakSwiftlyServer build a clone profile for end to end coverage with a clean transcript and steady speech.
    """
    private static let testingPlaybackText = """
    Hello from the real resident SpeakSwiftlyServer playback path. This end to end test uses a longer utterance so we can observe startup buffering, queue floor recovery, drain timing, and steady streaming behavior with enough generated audio to make the diagnostics useful instead of noisy.
    """

    // MARK: Sequential End-to-End Workflows

    @Test func httpVoiceDesignLaneRunsSequentialSilentAndAudibleCoverage() async throws {
        try await Self.runVoiceDesignLane(using: .http)
    }

    @Test func httpCloneLaneWithProvidedTranscriptRunsSequentialSilentAndAudibleCoverage() async throws {
        try await Self.runCloneLane(using: .http, transcriptMode: .provided)
    }

    @Test func httpCloneLaneWithInferredTranscriptRunsSequentialSilentAndAudibleCoverage() async throws {
        try await Self.runCloneLane(using: .http, transcriptMode: .inferred)
    }

    @Test func mcpVoiceDesignLaneRunsSequentialSilentAndAudibleCoverage() async throws {
        try await Self.runVoiceDesignLane(using: .mcp)
    }

    @Test func mcpCloneLaneWithProvidedTranscriptRunsSequentialSilentAndAudibleCoverage() async throws {
        try await Self.runCloneLane(using: .mcp, transcriptMode: .provided)
    }

    @Test func mcpCloneLaneWithInferredTranscriptRunsSequentialSilentAndAudibleCoverage() async throws {
        try await Self.runCloneLane(using: .mcp, transcriptMode: .inferred)
    }

    // MARK: Lane Workflows

    private static func runVoiceDesignLane(using transport: E2ETransport) async throws {
        let sandbox = try ServerE2ESandbox()
        defer { sandbox.cleanup() }

        let profileName = "\(transport.profilePrefix)-voice-design-profile"

        do {
            let server = try makeServer(
                port: randomPort(in: 59_000..<59_200),
                profileRootURL: sandbox.profileRootURL,
                silentPlayback: true,
                mcpEnabled: transport == .mcp
            )
            try server.start()
            defer { server.stop() }

            switch transport {
            case .http:
                let client = E2EHTTPClient(baseURL: server.baseURL)
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: profileName,
                    text: testingProfileText,
                    voiceDescription: testingProfileVoiceDescription
                )
                try await assertProfileIsVisible(using: client, profileName: profileName)
                try await runSilentSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: profileName
                )

            case .mcp:
                let client = try await E2EMCPClient.connect(
                    baseURL: server.baseURL,
                    path: "/mcp",
                    timeout: e2eTimeout,
                    server: server
                )
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: profileName,
                    text: testingProfileText,
                    voiceDescription: testingProfileVoiceDescription
                )
                try await assertProfileIsVisible(using: client, profileName: profileName)
                try await runSilentSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: profileName
                )
            }
        }

        do {
            let server = try makeServer(
                port: randomPort(in: 59_200..<59_400),
                profileRootURL: sandbox.profileRootURL,
                silentPlayback: false,
                playbackTrace: isPlaybackTraceEnabled,
                mcpEnabled: transport == .mcp
            )
            try server.start()
            defer { server.stop() }

            switch transport {
            case .http:
                let client = E2EHTTPClient(baseURL: server.baseURL)
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)

                try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: profileName
                )

            case .mcp:
                let client = try await E2EMCPClient.connect(
                    baseURL: server.baseURL,
                    path: "/mcp",
                    timeout: e2eTimeout,
                    server: server
                )
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)

                try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: profileName
                )
            }
        }
    }

    private static func runCloneLane(
        using transport: E2ETransport,
        transcriptMode: CloneTranscriptMode
    ) async throws {
        let sandbox = try ServerE2ESandbox()
        defer { sandbox.cleanup() }

        let fixtureProfileName = "\(transport.profilePrefix)-\(transcriptMode.slug)-clone-source-profile"
        let cloneProfileName = "\(transport.profilePrefix)-\(transcriptMode.slug)-clone-profile"
        let referenceAudioURL = sandbox.rootURL.appendingPathComponent("\(transport.profilePrefix)-\(transcriptMode.slug)-reference.wav")

        do {
            let server = try makeServer(
                port: randomPort(in: 59_400..<59_600),
                profileRootURL: sandbox.profileRootURL,
                silentPlayback: true,
                mcpEnabled: transport == .mcp
            )
            try server.start()
            defer { server.stop() }

            switch transport {
            case .http:
                let client = E2EHTTPClient(baseURL: server.baseURL)
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: fixtureProfileName,
                    text: testingCloneSourceText,
                    voiceDescription: testingProfileVoiceDescription,
                    outputPath: referenceAudioURL.path
                )
                #expect(FileManager.default.fileExists(atPath: referenceAudioURL.path))

                try await createCloneProfile(
                    using: client,
                    server: server,
                    profileName: cloneProfileName,
                    referenceAudioPath: referenceAudioURL.path,
                    transcript: transcriptMode.providedTranscript,
                    expectTranscription: transcriptMode.expectTranscription
                )
                try await assertProfileIsVisible(using: client, profileName: cloneProfileName)

            case .mcp:
                let client = try await E2EMCPClient.connect(
                    baseURL: server.baseURL,
                    path: "/mcp",
                    timeout: e2eTimeout,
                    server: server
                )
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: fixtureProfileName,
                    text: testingCloneSourceText,
                    voiceDescription: testingProfileVoiceDescription,
                    outputPath: referenceAudioURL.path
                )
                #expect(FileManager.default.fileExists(atPath: referenceAudioURL.path))

                try await createCloneProfile(
                    using: client,
                    server: server,
                    profileName: cloneProfileName,
                    referenceAudioPath: referenceAudioURL.path,
                    transcript: transcriptMode.providedTranscript,
                    expectTranscription: transcriptMode.expectTranscription
                )
                try await assertProfileIsVisible(using: client, profileName: cloneProfileName)
            }

            let storedProfile = try loadStoredProfileManifest(
                named: cloneProfileName,
                from: sandbox.profileRootURL
            )
            switch transcriptMode {
            case .provided:
                #expect(storedProfile.sourceText == testingCloneSourceText)
            case .inferred:
                let inferredTranscript = storedProfile.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                #expect(!inferredTranscript.isEmpty)
                #expect(transcriptLooksCloseToCloneSource(inferredTranscript))
            }

            switch transport {
            case .http:
                let client = E2EHTTPClient(baseURL: server.baseURL)
                try await runSilentSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: cloneProfileName
                )

            case .mcp:
                let client = try await E2EMCPClient.connect(
                    baseURL: server.baseURL,
                    path: "/mcp",
                    timeout: e2eTimeout,
                    server: server
                )
                try await runSilentSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: cloneProfileName
                )
            }
        }

        do {
            let server = try makeServer(
                port: randomPort(in: 59_600..<59_800),
                profileRootURL: sandbox.profileRootURL,
                silentPlayback: false,
                playbackTrace: isPlaybackTraceEnabled,
                mcpEnabled: transport == .mcp
            )
            try server.start()
            defer { server.stop() }

            switch transport {
            case .http:
                let client = E2EHTTPClient(baseURL: server.baseURL)
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)
                try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: cloneProfileName
                )

            case .mcp:
                let client = try await E2EMCPClient.connect(
                    baseURL: server.baseURL,
                    path: "/mcp",
                    timeout: e2eTimeout,
                    server: server
                )
                try await waitUntilWorkerReady(using: client, timeout: e2eTimeout, server: server)
                try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: cloneProfileName
                )
            }
        }
    }

    // MARK: HTTP Lane Helpers

    private static func createVoiceDesignProfile(
        using client: E2EHTTPClient,
        server: ServerProcess,
        profileName: String,
        vibe: String = "femme",
        text: String,
        voiceDescription: String,
        outputPath: String? = nil
    ) async throws {
        var body: [String: Any] = [
            "profile_name": profileName,
            "vibe": vibe,
            "text": text,
            "voice_description": voiceDescription,
        ]
        if let outputPath {
            body["output_path"] = outputPath
        }

        let response = try await client.request(path: "/profiles", method: "POST", jsonBody: body)
        #expect(response.statusCode == 202)

        let createJobID = try decode(E2EJobCreatedResponse.self, from: response.data).jobID
        let snapshot = try await waitForTerminalJob(
            id: createJobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )
        #expect(snapshot.status == "completed")
        #expect(snapshot.terminalEvent?.ok == true)
        #expect(snapshot.terminalEvent?.profileName == profileName)
        if outputPath != nil {
            #expect(snapshot.terminalEvent?.profilePath?.isEmpty == false)
        }
    }

    private static func createCloneProfile(
        using client: E2EHTTPClient,
        server: ServerProcess,
        profileName: String,
        vibe: String = "femme",
        referenceAudioPath: String,
        transcript: String?,
        expectTranscription: Bool
    ) async throws {
        var body: [String: Any] = [
            "profile_name": profileName,
            "vibe": vibe,
            "reference_audio_path": referenceAudioPath,
        ]
        if let transcript {
            body["transcript"] = transcript
        }

        let response = try await client.request(path: "/profiles/clone", method: "POST", jsonBody: body)
        #expect(response.statusCode == 202)

        let cloneJobID = try decode(E2EJobCreatedResponse.self, from: response.data).jobID
        let snapshot = try await waitForTerminalJob(
            id: cloneJobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )
        #expect(snapshot.status == "completed")
        #expect(snapshot.terminalEvent?.ok == true)
        #expect(snapshot.terminalEvent?.profileName == profileName)

        assertCloneTranscriptionStages(
            in: snapshot,
            expectTranscription: expectTranscription
        )
    }

    private static func assertProfileIsVisible(
        using client: E2EHTTPClient,
        profileName: String
    ) async throws {
        let profilesResponse = try await client.request(path: "/profiles", method: "GET")
        #expect(profilesResponse.statusCode == 200)
        let profiles = try decode(E2EProfileListResponse.self, from: profilesResponse.data).profiles
        #expect(profiles.contains { $0.profileName == profileName })
    }

    private static func runSilentSpeech(
        using client: E2EHTTPClient,
        server: ServerProcess,
        text: String,
        profileName: String
    ) async throws {
        let response = try await client.request(
            path: "/speak",
            method: "POST",
            jsonBody: [
                "text": text,
                "profile_name": profileName,
            ]
        )
        #expect(response.statusCode == 202)

        let jobID = try decode(E2EJobCreatedResponse.self, from: response.data).jobID
        let snapshot = try await waitForTerminalJob(
            id: jobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )

        assertSpeechJobCompleted(snapshot, expectedJobID: jobID)
        #expect(snapshot.history.contains { $0.event == "started" && $0.op == "queue_speech_live" })
        #expect(snapshot.history.contains { $0.event == "progress" && $0.stage == "playback_finished" })
        #expect(!snapshot.history.contains { $0.event == "queued" })

        let eventsResponse = try await client.request(path: "/jobs/\(jobID)/events", method: "GET")
        #expect(eventsResponse.statusCode == 200)
        #expect(eventsResponse.text.contains("event: worker_status"))
        #expect(eventsResponse.text.contains(#""event":"started""#))
        #expect(eventsResponse.text.contains(#""ok":true"#))
        #expect(!eventsResponse.text.contains(#""event":"queued""#))
    }

    private static func runAudibleSpeech(
        using client: E2EHTTPClient,
        server: ServerProcess,
        text: String,
        profileName: String
    ) async throws {
        let engineReadyLog = try await server.waitForStderrJSONObject(timeout: .seconds(120)) {
            guard
                $0["event"] as? String == "playback_engine_ready",
                let details = $0["details"] as? [String: Any]
            else {
                return false
            }

            return details["process_phys_footprint_bytes"] as? Int != nil
                && details["mlx_active_memory_bytes"] as? Int != nil
        }
        #expect(engineReadyLog["event"] as? String == "playback_engine_ready")

        let response = try await client.request(
            path: "/speak",
            method: "POST",
            jsonBody: [
                "text": text,
                "profile_name": profileName,
            ]
        )
        #expect(response.statusCode == 202)

        let jobID = try decode(E2EJobCreatedResponse.self, from: response.data).jobID

        _ = try await server.waitForStderrJSONObject(timeout: e2eTimeout) {
            guard
                $0["event"] as? String == "playback_started",
                $0["request_id"] as? String == jobID,
                let details = $0["details"] as? [String: Any]
            else {
                return false
            }

            let textComplexityClass = details["text_complexity_class"] as? String
            return ["compact", "balanced", "extended"].contains(textComplexityClass)
                && details["startup_buffer_target_ms"] as? Int != nil
                && details["startup_buffered_audio_ms"] as? Int != nil
                && details["process_phys_footprint_bytes"] as? Int != nil
                && details["mlx_active_memory_bytes"] as? Int != nil
        }

        _ = try await server.waitForStderrJSONObject(timeout: e2eTimeout) {
            guard
                $0["event"] as? String == "playback_finished",
                $0["request_id"] as? String == jobID,
                let details = $0["details"] as? [String: Any]
            else {
                return false
            }

            let textComplexityClass = details["text_complexity_class"] as? String
            return ["compact", "balanced", "extended"].contains(textComplexityClass)
                && details["time_to_first_chunk_ms"] as? Int != nil
                && details["played_back_callback_count"] as? Int != nil
                && details["startup_buffer_target_ms"] as? Int != nil
                && details["low_water_target_ms"] as? Int != nil
                && details["process_phys_footprint_bytes"] as? Int != nil
                && details["mlx_active_memory_bytes"] as? Int != nil
        }

        let snapshot = try await waitForTerminalJob(
            id: jobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )

        assertSpeechJobCompleted(snapshot, expectedJobID: jobID)
        #expect(snapshot.history.contains { $0.event == "progress" && $0.stage == "preroll_ready" })
        #expect(snapshot.history.contains { $0.event == "progress" && $0.stage == "playback_finished" })
    }

    // MARK: MCP Lane Helpers

    private static func createVoiceDesignProfile(
        using client: E2EMCPClient,
        server: ServerProcess,
        profileName: String,
        vibe: String = "femme",
        text: String,
        voiceDescription: String,
        outputPath: String? = nil
    ) async throws {
        var arguments = [
            "profile_name": profileName,
            "vibe": vibe,
            "text": text,
            "voice_description": voiceDescription,
        ]
        if let outputPath {
            arguments["output_path"] = outputPath
        }

        let payload = try await client.callTool(name: "create_profile", arguments: arguments)
        let jobID = try requireString("job_id", in: payload)
        #expect(payload["job_resource_uri"] as? String == "speak://jobs/\(jobID)")

        let snapshot = try await waitForTerminalJob(
            id: jobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )
        #expect(snapshot.status == "completed")
        #expect(snapshot.terminalEvent?.ok == true)
        #expect(snapshot.terminalEvent?.profileName == profileName)
        if outputPath != nil {
            #expect(snapshot.terminalEvent?.profilePath?.isEmpty == false)
        }
    }

    private static func createCloneProfile(
        using client: E2EMCPClient,
        server: ServerProcess,
        profileName: String,
        vibe: String = "femme",
        referenceAudioPath: String,
        transcript: String?,
        expectTranscription: Bool
    ) async throws {
        var arguments = [
            "profile_name": profileName,
            "vibe": vibe,
            "reference_audio_path": referenceAudioPath,
        ]
        if let transcript {
            arguments["transcript"] = transcript
        }

        let payload = try await client.callTool(name: "create_clone", arguments: arguments)
        let jobID = try requireString("job_id", in: payload)
        #expect(payload["job_resource_uri"] as? String == "speak://jobs/\(jobID)")

        let snapshot = try await waitForTerminalJob(
            id: jobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )
        #expect(snapshot.status == "completed")
        #expect(snapshot.terminalEvent?.ok == true)
        #expect(snapshot.terminalEvent?.profileName == profileName)

        assertCloneTranscriptionStages(
            in: snapshot,
            expectTranscription: expectTranscription
        )
    }

    private static func assertProfileIsVisible(
        using client: E2EMCPClient,
        profileName: String
    ) async throws {
        let payload = try await client.callToolJSON(name: "list_profiles", arguments: [:])
        let profiles = try requireProfiles(from: payload)
        #expect(profiles.contains { $0.profileName == profileName })
    }

    private static func runSilentSpeech(
        using client: E2EMCPClient,
        server: ServerProcess,
        text: String,
        profileName: String
    ) async throws {
        let payload = try await client.callTool(
            name: "queue_speech_live",
            arguments: [
                "text": text,
                "profile_name": profileName,
            ]
        )
        let jobID = try requireString("job_id", in: payload)
        #expect(payload["job_resource_uri"] as? String == "speak://jobs/\(jobID)")

        let snapshot = try await waitForTerminalJob(
            id: jobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )

        assertSpeechJobCompleted(snapshot, expectedJobID: jobID)
        #expect(snapshot.history.contains { $0.event == "started" && $0.op == "queue_speech_live" })
        #expect(snapshot.history.contains { $0.event == "progress" && $0.stage == "playback_finished" })
        #expect(!snapshot.history.contains { $0.event == "queued" })
    }

    private static func runAudibleSpeech(
        using client: E2EMCPClient,
        server: ServerProcess,
        text: String,
        profileName: String
    ) async throws {
        let engineReadyLog = try await server.waitForStderrJSONObject(timeout: .seconds(120)) {
            guard
                $0["event"] as? String == "playback_engine_ready",
                let details = $0["details"] as? [String: Any]
            else {
                return false
            }

            return details["process_phys_footprint_bytes"] as? Int != nil
                && details["mlx_active_memory_bytes"] as? Int != nil
        }
        #expect(engineReadyLog["event"] as? String == "playback_engine_ready")

        let payload = try await client.callTool(
            name: "queue_speech_live",
            arguments: [
                "text": text,
                "profile_name": profileName,
            ]
        )
        let jobID = try requireString("job_id", in: payload)
        #expect(payload["job_resource_uri"] as? String == "speak://jobs/\(jobID)")

        _ = try await server.waitForStderrJSONObject(timeout: e2eTimeout) {
            guard
                $0["event"] as? String == "playback_started",
                $0["request_id"] as? String == jobID,
                let details = $0["details"] as? [String: Any]
            else {
                return false
            }

            let textComplexityClass = details["text_complexity_class"] as? String
            return ["compact", "balanced", "extended"].contains(textComplexityClass)
                && details["startup_buffer_target_ms"] as? Int != nil
                && details["startup_buffered_audio_ms"] as? Int != nil
                && details["process_phys_footprint_bytes"] as? Int != nil
                && details["mlx_active_memory_bytes"] as? Int != nil
        }

        _ = try await server.waitForStderrJSONObject(timeout: e2eTimeout) {
            guard
                $0["event"] as? String == "playback_finished",
                $0["request_id"] as? String == jobID,
                let details = $0["details"] as? [String: Any]
            else {
                return false
            }

            let textComplexityClass = details["text_complexity_class"] as? String
            return ["compact", "balanced", "extended"].contains(textComplexityClass)
                && details["time_to_first_chunk_ms"] as? Int != nil
                && details["played_back_callback_count"] as? Int != nil
                && details["startup_buffer_target_ms"] as? Int != nil
                && details["low_water_target_ms"] as? Int != nil
                && details["process_phys_footprint_bytes"] as? Int != nil
                && details["mlx_active_memory_bytes"] as? Int != nil
        }

        let snapshot = try await waitForTerminalJob(
            id: jobID,
            using: client,
            timeout: e2eTimeout,
            server: server
        )

        assertSpeechJobCompleted(snapshot, expectedJobID: jobID)
        #expect(snapshot.history.contains { $0.event == "progress" && $0.stage == "preroll_ready" })
        #expect(snapshot.history.contains { $0.event == "progress" && $0.stage == "playback_finished" })
    }

    // MARK: Shared Assertions

    private static func assertSpeechJobCompleted(_ snapshot: E2EJobSnapshot, expectedJobID jobID: String) {
        #expect(snapshot.status == "completed")
        #expect(snapshot.terminalEvent?.id == jobID)
        #expect(snapshot.terminalEvent?.ok == true)
        #expect(snapshot.history.contains { $0.ok == true })
    }

    private static func assertCloneTranscriptionStages(
        in snapshot: E2EJobSnapshot,
        expectTranscription: Bool
    ) {
        let sawLoading = snapshot.history.contains {
            $0.event == "progress" && $0.stage == "loading_clone_transcription_model"
        }
        let sawTranscribing = snapshot.history.contains {
            $0.event == "progress" && $0.stage == "transcribing_clone_audio"
        }

        if expectTranscription {
            #expect(sawLoading)
            #expect(sawTranscribing)
        } else {
            #expect(!sawLoading)
            #expect(!sawTranscribing)
        }
    }

    private static func transcriptLooksCloseToCloneSource(_ transcript: String) -> Bool {
        let expectedTokens = normalizedTranscriptTokens(from: testingCloneSourceText)
        let actualTokens = normalizedTranscriptTokens(from: transcript)

        guard !expectedTokens.isEmpty, !actualTokens.isEmpty else {
            return false
        }

        let sharedTokens = expectedTokens.intersection(actualTokens)
        let recall = Double(sharedTokens.count) / Double(expectedTokens.count)
        let precision = Double(sharedTokens.count) / Double(actualTokens.count)

        return recall >= 0.7 && precision >= 0.6
    }

    private static func normalizedTranscriptTokens(from text: String) -> Set<String> {
        let scalars = text.lowercased().unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }
        let normalized = String(scalars)
        return Set(
            normalized
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    // MARK: Build Artifacts

    private static func speakSwiftlyProductsURL() throws -> URL {
        let serverRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let productsURL = serverRootURL
            .deletingLastPathComponent()
            .appendingPathComponent("SpeakSwiftly/.derived/Build/Products/Debug", isDirectory: true)

        let metallibURL = productsURL
            .appendingPathComponent("mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib", isDirectory: false)
        guard FileManager.default.fileExists(atPath: metallibURL.path) else {
            throw SpeakSwiftlyBuildError(
                "The live SpeakSwiftlyServer end-to-end suite requires the Xcode-built SpeakSwiftly products at '\(productsURL.path)' so `default.metallib` is available at runtime. That local build is only an artifact source for the live suite, not this repository's SwiftPM dependency source."
            )
        }
        return productsURL
    }

    private static func serverToolExecutableURL() throws -> URL {
        let serverRootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let executableURL = serverRootURL
            .appendingPathComponent(".build/arm64-apple-macosx/debug/SpeakSwiftlyServerTool", isDirectory: false)

        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw SpeakSwiftlyBuildError(
                "The SpeakSwiftlyServerTool executable was expected at '\(executableURL.path)', but it was not present. Run `swift build` before the live end-to-end suite."
            )
        }
        return executableURL
    }

    private static func stageMetallibForServerBinary(
        from dependencyProductsURL: URL,
        serverExecutableURL: URL
    ) throws {
        let sourceURL = dependencyProductsURL
            .appendingPathComponent("mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib", isDirectory: false)
        let targetDirectoryURL = serverExecutableURL
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
        let targetURL = targetDirectoryURL.appendingPathComponent("default.metallib", isDirectory: false)

        try FileManager.default.createDirectory(at: targetDirectoryURL, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try? FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    }

    private static func makeServer(
        port: Int,
        profileRootURL: URL,
        silentPlayback: Bool,
        playbackTrace: Bool = false,
        mcpEnabled: Bool
    ) throws -> ServerProcess {
        let dependencyProductsURL = try speakSwiftlyProductsURL()
        let executableURL = try serverToolExecutableURL()
        try stageMetallibForServerBinary(
            from: dependencyProductsURL,
            serverExecutableURL: executableURL
        )

        return try ServerProcess(
            executableURL: executableURL,
            dependencyProductsURL: dependencyProductsURL,
            profileRootURL: profileRootURL,
            port: port,
            silentPlayback: silentPlayback,
            playbackTrace: playbackTrace,
            mcpEnabled: mcpEnabled
        )
    }

    private static func randomPort(in range: Range<Int>) -> Int {
        Int.random(in: range)
    }

    private static var isPlaybackTraceEnabled: Bool {
        ProcessInfo.processInfo.environment["SPEAKSWIFTLY_PLAYBACK_TRACE"] == "1"
    }

    private static var e2eTimeout: Duration {
        .seconds(1_200)
    }
}
