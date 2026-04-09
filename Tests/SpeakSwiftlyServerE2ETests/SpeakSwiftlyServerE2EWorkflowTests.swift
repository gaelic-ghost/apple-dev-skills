import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Workflow End-to-End Tests

extension SpeakSwiftlyServerE2ETests {
    static func runVoiceDesignLane(using transport: E2ETransport) async throws {
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

                _ = try await runAudibleSpeech(
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

                _ = try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: profileName
                )
            }
        }
    }

    static func runCloneLane(
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
                _ = try await runAudibleSpeech(
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
                _ = try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: cloneProfileName
                )
            }
        }
    }

    static func runMarvisTripletLane(using transport: E2ETransport) async throws {
        struct MarvisProfileLane {
            let profileName: String
            let vibe: String
            let voiceDescription: String
            let expectedVoice: String
        }

        let sandbox = try ServerE2ESandbox()
        defer { sandbox.cleanup() }

        let prefix = transport.profilePrefix
        let lanes = [
            MarvisProfileLane(
                profileName: "\(prefix)-marvis-triplet-femme-profile",
                vibe: "femme",
                voiceDescription: "A warm, bright, feminine narrator voice.",
                expectedVoice: "conversational_a"
            ),
            MarvisProfileLane(
                profileName: "\(prefix)-marvis-triplet-masc-profile",
                vibe: "masc",
                voiceDescription: "A grounded, rich, masculine speaking voice.",
                expectedVoice: "conversational_b"
            ),
            MarvisProfileLane(
                profileName: "\(prefix)-marvis-triplet-androgenous-profile",
                vibe: "androgenous",
                voiceDescription: "A calm, balanced, and gentle speaking voice.",
                expectedVoice: "conversational_a"
            ),
        ]

        let server = try makeServer(
            port: randomPort(in: 58_800..<59_000),
            profileRootURL: sandbox.profileRootURL,
            silentPlayback: false,
            playbackTrace: isPlaybackTraceEnabled,
            mcpEnabled: transport == .mcp,
            speechBackend: "marvis"
        )
        try server.start()
        defer { server.stop() }

        switch transport {
        case .http:
            let client = E2EHTTPClient(baseURL: server.baseURL)
            try await waitUntilWorkerReady(
                using: client,
                timeout: e2eTimeout,
                server: server,
                expectPlaybackEngine: true
            )

            for lane in lanes {
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: lane.profileName,
                    vibe: lane.vibe,
                    text: testingProfileText,
                    voiceDescription: lane.voiceDescription
                )
            }

            let profilesResponse = try await client.request(path: "/voices", method: "GET")
            #expect(profilesResponse.statusCode == 200)
            let profiles = try decode(E2EProfileListResponse.self, from: profilesResponse.data).profiles
            for lane in lanes {
                #expect(profiles.contains {
                    $0.profileName == lane.profileName && $0.vibe == lane.vibe
                })
            }

            for lane in lanes {
                let jobID = try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: lane.profileName
                )
                try await expectMarvisVoiceSelection(
                    on: server,
                    requestID: jobID,
                    expectedVoice: lane.expectedVoice
                )
            }

        case .mcp:
            let client = try await E2EMCPClient.connect(
                baseURL: server.baseURL,
                path: "/mcp",
                timeout: e2eTimeout,
                server: server
            )
            try await waitUntilWorkerReady(
                using: client,
                timeout: e2eTimeout,
                server: server,
                expectPlaybackEngine: true
            )

            for lane in lanes {
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: lane.profileName,
                    vibe: lane.vibe,
                    text: testingProfileText,
                    voiceDescription: lane.voiceDescription
                )
            }

            let profilesPayload = try await client.callToolJSON(name: "list_voice_profiles", arguments: [:])
            let profiles = try requireProfiles(from: profilesPayload)
            for lane in lanes {
                #expect(profiles.contains {
                    $0.profileName == lane.profileName && $0.vibe == lane.vibe
                })
            }

            for lane in lanes {
                let jobID = try await runAudibleSpeech(
                    using: client,
                    server: server,
                    text: testingPlaybackText,
                    profileName: lane.profileName
                )
                try await expectMarvisVoiceSelection(
                    on: server,
                    requestID: jobID,
                    expectedVoice: lane.expectedVoice
                )
            }
        }
    }

    static func runRelativePathProfileAndCloneLane(using transport: E2ETransport) async throws {
        let sandbox = try ServerE2ESandbox()
        defer { sandbox.cleanup() }

        let callerWorkingDirectory = sandbox.rootURL.appendingPathComponent("\(transport.profilePrefix)-caller-cwd", isDirectory: true)
        try FileManager.default.createDirectory(at: callerWorkingDirectory, withIntermediateDirectories: true)

        let relativeReferencePath = "exports/reference.wav"
        let exportedReferenceURL = callerWorkingDirectory.appending(path: relativeReferencePath)
        let fixtureProfileName = "\(transport.profilePrefix)-relative-profile-source"
        let cloneProfileName = "\(transport.profilePrefix)-relative-profile-clone"

        let server = try makeServer(
            port: randomPort(in: 58_600..<58_800),
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
                outputPath: relativeReferencePath,
                cwd: callerWorkingDirectory.path
            )
            #expect(FileManager.default.fileExists(atPath: exportedReferenceURL.path))

            try await createCloneProfile(
                using: client,
                server: server,
                profileName: cloneProfileName,
                referenceAudioPath: relativeReferencePath,
                transcript: testingCloneSourceText,
                expectTranscription: false,
                cwd: callerWorkingDirectory.path
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
                outputPath: relativeReferencePath,
                cwd: callerWorkingDirectory.path
            )
            #expect(FileManager.default.fileExists(atPath: exportedReferenceURL.path))

            try await createCloneProfile(
                using: client,
                server: server,
                profileName: cloneProfileName,
                referenceAudioPath: relativeReferencePath,
                transcript: testingCloneSourceText,
                expectTranscription: false,
                cwd: callerWorkingDirectory.path
            )
            try await assertProfileIsVisible(using: client, profileName: cloneProfileName)
        }

        let storedProfile = try loadStoredProfileManifest(
            named: cloneProfileName,
            from: sandbox.profileRootURL
        )
        #expect(storedProfile.sourceText == testingCloneSourceText)
    }

    static func runQueuedMarvisTripletLane(using transport: E2ETransport) async throws {
        struct MarvisQueuedLane {
            let profileName: String
            let vibe: String
            let voiceDescription: String
            let expectedVoice: String
        }

        let sandbox = try ServerE2ESandbox()
        defer { sandbox.cleanup() }

        let prefix = transport.profilePrefix
        let lanes = [
            MarvisQueuedLane(
                profileName: "\(prefix)-marvis-queued-femme-profile",
                vibe: "femme",
                voiceDescription: "A warm, bright, feminine narrator voice.",
                expectedVoice: "conversational_a"
            ),
            MarvisQueuedLane(
                profileName: "\(prefix)-marvis-queued-masc-profile",
                vibe: "masc",
                voiceDescription: "A grounded, rich, masculine speaking voice.",
                expectedVoice: "conversational_b"
            ),
            MarvisQueuedLane(
                profileName: "\(prefix)-marvis-queued-androgenous-profile",
                vibe: "androgenous",
                voiceDescription: "A calm, balanced, and gentle speaking voice.",
                expectedVoice: "conversational_a"
            ),
        ]

        let server = try makeServer(
            port: randomPort(in: 59_000..<59_200),
            profileRootURL: sandbox.profileRootURL,
            silentPlayback: false,
            playbackTrace: isPlaybackTraceEnabled,
            mcpEnabled: transport == .mcp,
            speechBackend: "marvis"
        )
        try server.start()
        defer { server.stop() }

        switch transport {
        case .http:
            let client = E2EHTTPClient(baseURL: server.baseURL)
            try await waitUntilWorkerReady(
                using: client,
                timeout: e2eTimeout,
                server: server,
                expectPlaybackEngine: true
            )

            for lane in lanes {
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: lane.profileName,
                    vibe: lane.vibe,
                    text: testingProfileText,
                    voiceDescription: lane.voiceDescription
                )
            }

            var jobIDs = [String]()
            for lane in lanes {
                let jobID = try await submitSpeechJob(
                    using: client,
                    text: testingPlaybackText,
                    profileName: lane.profileName
                )
                jobIDs.append(jobID)
            }

            _ = try await waitForPlaybackState(
                using: client,
                timeout: .seconds(180),
                matching: { $0.state == "playing" && $0.activeRequest?.id == jobIDs[0] }
            )
            let queued = try await waitForGenerationQueue(
                using: client,
                timeout: .seconds(180),
                matching: { snapshot in
                    let ids = Set(snapshot.queue.map(\.id))
                    return ids.contains(jobIDs[1]) && ids.contains(jobIDs[2])
                }
            )
            #expect(queued.queueType == "generation")

            do {
                let firstSnapshot = try await waitForTerminalJob(
                    id: jobIDs[0],
                    using: client,
                    timeout: e2eTimeout,
                    server: server
                )
                assertSpeechJobCompleted(firstSnapshot, expectedJobID: jobIDs[0])
                #expect(!firstSnapshot.history.contains { $0.event == "queued" })

                let secondSnapshot = try await waitForTerminalJob(
                    id: jobIDs[1],
                    using: client,
                    timeout: e2eTimeout,
                    server: server
                )
                assertSpeechJobCompleted(secondSnapshot, expectedJobID: jobIDs[1])
                #expect(secondSnapshot.history.contains {
                    $0.event == "queued" && (
                        $0.reason == "waiting_for_marvis_generation_lane"
                            || $0.reason == "waiting_for_playback_stability"
                    )
                })

                let thirdSnapshot = try await waitForTerminalJob(
                    id: jobIDs[2],
                    using: client,
                    timeout: e2eTimeout,
                    server: server
                )
                assertSpeechJobCompleted(thirdSnapshot, expectedJobID: jobIDs[2])
                #expect(thirdSnapshot.history.contains {
                    $0.event == "queued" && (
                        $0.reason == "waiting_for_marvis_generation_lane"
                            || $0.reason == "waiting_for_playback_stability"
                    )
                })
            } catch {
                await recordQueuedMarvisHTTPDiagnostics(
                    using: client,
                    requestIDs: jobIDs,
                    expectedProfiles: lanes.map(\.profileName)
                )
                throw error
            }

            try await assertMarvisPlaybackStartedInOrder(on: server, requestIDs: jobIDs)

            for (jobID, lane) in zip(jobIDs, lanes) {
                try await expectMarvisVoiceSelection(
                    on: server,
                    requestID: jobID,
                    expectedVoice: lane.expectedVoice
                )
            }

        case .mcp:
            let client = try await E2EMCPClient.connect(
                baseURL: server.baseURL,
                path: "/mcp",
                timeout: e2eTimeout,
                server: server
            )
            try await waitUntilWorkerReady(
                using: client,
                timeout: e2eTimeout,
                server: server,
                expectPlaybackEngine: true
            )

            for lane in lanes {
                try await createVoiceDesignProfile(
                    using: client,
                    server: server,
                    profileName: lane.profileName,
                    vibe: lane.vibe,
                    text: testingProfileText,
                    voiceDescription: lane.voiceDescription
                )
            }

            var jobIDs = [String]()
            for lane in lanes {
                let payload = try await client.callTool(
                    name: "queue_speech_live",
                    arguments: [
                        "text": testingPlaybackText,
                        "profile_name": lane.profileName,
                    ]
                )
                let jobID = try requireString("request_id", in: payload)
                #expect(payload["request_resource_uri"] as? String == "speak://requests/\(jobID)")
                jobIDs.append(jobID)
            }

            let queued = try await waitForMCPGenerationQueue(
                using: client,
                timeout: .seconds(180),
                matching: { snapshot in
                    let ids = Set(snapshot.queue.map(\.id))
                    return ids.contains(jobIDs[1]) && ids.contains(jobIDs[2])
                }
            )
            #expect(queued.queueType == "generation")

            let firstSnapshot = try await waitForTerminalJob(
                id: jobIDs[0],
                using: client,
                timeout: e2eTimeout,
                server: server
            )
            assertSpeechJobCompleted(firstSnapshot, expectedJobID: jobIDs[0])
            #expect(!firstSnapshot.history.contains { $0.event == "queued" })

            let secondSnapshot = try await waitForTerminalJob(
                id: jobIDs[1],
                using: client,
                timeout: e2eTimeout,
                server: server
            )
            assertSpeechJobCompleted(secondSnapshot, expectedJobID: jobIDs[1])
            #expect(secondSnapshot.history.contains {
                $0.event == "queued" && (
                    $0.reason == "waiting_for_marvis_generation_lane"
                        || $0.reason == "waiting_for_playback_stability"
                )
            })

            let thirdSnapshot = try await waitForTerminalJob(
                id: jobIDs[2],
                using: client,
                timeout: e2eTimeout,
                server: server
            )
            assertSpeechJobCompleted(thirdSnapshot, expectedJobID: jobIDs[2])
            #expect(thirdSnapshot.history.contains {
                $0.event == "queued" && (
                    $0.reason == "waiting_for_marvis_generation_lane"
                        || $0.reason == "waiting_for_playback_stability"
                )
            })

            try await assertMarvisPlaybackStartedInOrder(on: server, requestIDs: jobIDs)

            for (jobID, lane) in zip(jobIDs, lanes) {
                try await expectMarvisVoiceSelection(
                    on: server,
                    requestID: jobID,
                    expectedVoice: lane.expectedVoice
                )
            }
        }
    }
}
