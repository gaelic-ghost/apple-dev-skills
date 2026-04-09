import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Transport Waiters

func waitUntilWorkerReady(
    using client: E2EHTTPClient,
    timeout: Duration,
    server: ServerProcess,
    expectPlaybackEngine: Bool = false
) async throws {
    let _: Bool = try await e2eWaitUntil(timeout: timeout, pollInterval: .seconds(1)) {
        guard server.isStillRunning else {
            throw E2ETransportError(
                "The live SpeakSwiftlyServer process exited before `/readyz` reported readiness.\n\(server.combinedOutput)"
            )
        }

        let response: E2EHTTPResponse
        do {
            response = try await client.request(path: "/readyz", method: "GET")
        } catch {
            guard isRetryableConnectionDuringStartup(error) else {
                throw error
            }
            return nil
        }
        guard response.statusCode == 200 else { return nil }
        let readiness = try decode(E2EReadinessSnapshot.self, from: response.data)
        return readiness.workerReady ? true : nil
    }

    guard expectPlaybackEngine else { return }

    _ = try await server.waitForStderrJSONObject(timeout: timeout) {
        guard
            $0["event"] as? String == "playback_engine_ready",
            let details = $0["details"] as? [String: Any]
        else {
            return false
        }

        return details["process_phys_footprint_bytes"] as? Int != nil
            && details["mlx_active_memory_bytes"] as? Int != nil
    }
}

func waitUntilWorkerReady(
    using client: E2EMCPClient,
    timeout: Duration,
    server: ServerProcess,
    expectPlaybackEngine: Bool = false
) async throws {
    let _: Bool = try await e2eWaitUntil(timeout: timeout, pollInterval: .seconds(1)) {
        guard server.isStillRunning else {
            throw E2ETransportError(
                "The live SpeakSwiftlyServer process exited before the MCP status tool reported readiness.\n\(server.combinedOutput)"
            )
        }

        let payload = try await client.callTool(name: "get_runtime_overview", arguments: [:])
        guard payload["worker_mode"] as? String == "ready" else { return nil }
        return true
    }

    guard expectPlaybackEngine else { return }

    _ = try await server.waitForStderrJSONObject(timeout: timeout) {
        guard
            $0["event"] as? String == "playback_engine_ready",
            let details = $0["details"] as? [String: Any]
        else {
            return false
        }

        return details["process_phys_footprint_bytes"] as? Int != nil
            && details["mlx_active_memory_bytes"] as? Int != nil
    }
}

func waitForTerminalJob(
    id requestID: String,
    using client: E2EHTTPClient,
    timeout: Duration,
    server: ServerProcess
) async throws -> E2EJobSnapshot {
    try await e2eWaitUntil(timeout: timeout, pollInterval: .seconds(1)) {
        guard server.isStillRunning else {
            throw E2ETransportError(
                "The live SpeakSwiftlyServer process exited before request '\(requestID)' reached a terminal state.\n\(server.combinedOutput)"
            )
        }

        let response = try await client.request(path: "/requests/\(requestID)", method: "GET")
        guard response.statusCode == 200 else { return nil }
        let snapshot = try decode(E2EJobSnapshot.self, from: response.data)
        return snapshot.terminalEvent == nil ? nil : snapshot
    }
}

func waitForTerminalJob(
    id requestID: String,
    using client: E2EMCPClient,
    timeout: Duration,
    server: ServerProcess
) async throws -> E2EJobSnapshot {
    try await e2eWaitUntil(timeout: timeout, pollInterval: .seconds(1)) {
        guard server.isStillRunning else {
            throw E2ETransportError(
                "The live SpeakSwiftlyServer process exited before MCP request resource '\(requestID)' reached a terminal state.\n\(server.combinedOutput)"
            )
        }

        let text = try await client.readResourceText(uri: "speak://requests/\(requestID)")
        let snapshot = try decode(E2EJobSnapshot.self, from: Data(text.utf8))
        return snapshot.terminalEvent == nil ? nil : snapshot
    }
}

func e2eWaitUntil<T>(
    timeout: Duration,
    pollInterval: Duration,
    condition: @escaping () async throws -> T?
) async throws -> T {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if let value = try await condition() {
            return value
        }
        try await Task.sleep(for: pollInterval)
    }
    throw E2ETimeoutError()
}

// MARK: - Stored Profile Helpers

struct StoredProfileManifest: Decodable, Sendable {
    let sourceText: String
}

func loadStoredProfileManifest(named profileName: String, from rootURL: URL) throws -> StoredProfileManifest {
    let manifestURL = rootURL
        .appendingPathComponent(profileName, isDirectory: true)
        .appendingPathComponent("profile.json", isDirectory: false)
    let data = try Data(contentsOf: manifestURL)
    let manifest = try JSONSerialization.jsonObject(with: data)
    guard let object = manifest as? [String: Any] else {
        throw E2ETransportError(
            "The stored profile manifest at '\(manifestURL.path)' did not decode into a JSON object."
        )
    }

    let sourceText =
        object["source_text"] as? String
        ?? object["sourceText"] as? String
        ?? object["transcript"] as? String

    guard let sourceText else {
        let availableKeys = object.keys.sorted().joined(separator: ", ")
        throw E2ETransportError(
            "The stored profile manifest at '\(manifestURL.path)' did not contain a usable source-text field. Available keys: [\(availableKeys)]."
        )
    }

    return .init(sourceText: sourceText)
}

// MARK: - JSON Helpers

func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
    do {
        return try JSONDecoder().decode(Value.self, from: data)
    } catch {
        let body = String(decoding: data, as: UTF8.self)
        let preview = body.isEmpty ? "<empty body>" : body
        throw E2ETransportError(
            "The live end-to-end helper could not decode \(Value.self) from the server response. Raw body preview: \(preview)"
        )
    }
}

func jsonObject(from data: Data) throws -> [String: Any] {
    let json = try JSONSerialization.jsonObject(with: data)
    if let dictionaries = json as? [[String: Any]] {
        guard let dictionary = dictionaries.first else {
            throw E2ETransportError("Expected at least one JSON object in the live end-to-end helper array payload, but the array was empty.")
        }
        return dictionary
    }
    guard let dictionary = json as? [String: Any] else {
        throw E2ETransportError("Expected a top-level JSON object in the live end-to-end helper, but received '\(type(of: json))'.")
    }
    return dictionary
}

func parseMCPEnvelope(from data: Data) throws -> [String: Any] {
    let body = String(decoding: data, as: UTF8.self)
    if let dataLine = body
        .split(separator: "\n")
        .reversed()
        .first(where: {
            $0.hasPrefix("data: ")
                && $0.dropFirst("data: ".count).isEmpty == false
        })
    {
        let payload = dataLine.dropFirst("data: ".count)
        guard payload.isEmpty == false else {
            throw E2ETransportError("The live MCP response contained an empty `data:` payload. Raw body: \(body)")
        }
        return try mcpEnvelope(from: Data(payload.utf8), rawBody: body)
    }
    return try mcpEnvelope(from: data, rawBody: body)
}

func mcpEnvelope(from data: Data, rawBody: String) throws -> [String: Any] {
    let json = try JSONSerialization.jsonObject(with: data)
    if let dictionary = json as? [String: Any] {
        return dictionary
    }

    if let dictionaries = json as? [[String: Any]] {
        if let envelope = dictionaries.first(where: { $0["result"] != nil || $0["error"] != nil }) {
            return envelope
        }
        if let first = dictionaries.first {
            return first
        }
        throw E2ETransportError("The live MCP response decoded to an empty envelope array. Raw body: \(rawBody)")
    }

    throw E2ETransportError("Expected the live MCP response to decode into a JSON-RPC object or array of objects, but received '\(type(of: json))'. Raw body: \(rawBody)")
}

func requireMCPHeader(_ name: String, in headers: [AnyHashable: Any]) throws -> String {
    for (key, value) in headers {
        if String(describing: key).caseInsensitiveCompare(name) == .orderedSame,
           let stringValue = value as? String,
           stringValue.isEmpty == false
        {
            return stringValue
        }
    }
    throw E2ETransportError("The live MCP initialize response was missing the required '\(name)' header.")
}

func requireDictionary(_ key: String, in object: [String: Any]) throws -> [String: Any] {
    guard let value = object[key] as? [String: Any] else {
        throw E2ETransportError("The live end-to-end helper expected '\(key)' to be a JSON object.")
    }
    return value
}

func requireArray(_ key: String, in object: [String: Any]) throws -> [[String: Any]] {
    guard let value = object[key] as? [[String: Any]] else {
        throw E2ETransportError("The live end-to-end helper expected '\(key)' to be an array of JSON objects.")
    }
    return value
}

func requireFirstDictionary(in array: [[String: Any]]) throws -> [String: Any] {
    guard let first = array.first else {
        throw E2ETransportError("The live end-to-end helper expected at least one object in the MCP content array.")
    }
    return first
}

func requireString(_ key: String, in object: [String: Any]) throws -> String {
    guard let value = object[key] as? String, value.isEmpty == false else {
        throw E2ETransportError("The live end-to-end helper expected '\(key)' to be a non-empty string.")
    }
    return value
}

func requireProfiles(from payload: Any) throws -> [E2EProfileSnapshot] {
    if let profiles = payload as? [[String: Any]] {
        let data = try JSONSerialization.data(withJSONObject: ["profiles": profiles])
        return try decode(E2EProfileListResponse.self, from: data).profiles
    }

    if let profile = payload as? [String: Any], profile["profile_name"] != nil {
        let data = try JSONSerialization.data(withJSONObject: ["profiles": [profile]])
        return try decode(E2EProfileListResponse.self, from: data).profiles
    }

    guard let payload = payload as? [String: Any] else {
        throw E2ETransportError(
            "The live end-to-end helper expected the profile list payload to decode into a JSON object or array, but received '\(type(of: payload))'."
        )
    }

    if let profiles = payload["profiles"] as? [[String: Any]] {
        let data = try JSONSerialization.data(withJSONObject: ["profiles": profiles])
        return try decode(E2EProfileListResponse.self, from: data).profiles
    }

    if let wrappedProfiles = payload["profiles"] as? [String: Any] {
        if let profiles = wrappedProfiles["profiles"] as? [[String: Any]] {
            let data = try JSONSerialization.data(withJSONObject: ["profiles": profiles])
            return try decode(E2EProfileListResponse.self, from: data).profiles
        }
        if let items = wrappedProfiles["items"] as? [[String: Any]] {
            let data = try JSONSerialization.data(withJSONObject: ["profiles": items])
            return try decode(E2EProfileListResponse.self, from: data).profiles
        }
    }

    if let profiles = payload["items"] as? [[String: Any]] {
        let data = try JSONSerialization.data(withJSONObject: ["profiles": profiles])
        return try decode(E2EProfileListResponse.self, from: data).profiles
    }

    let availableKeys = payload.keys.sorted().joined(separator: ", ")
    throw E2ETransportError(
        "The live end-to-end helper could not find a decodable profile list in the MCP payload. Available top-level keys: [\(availableKeys)]."
    )
}

extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - Error Helpers

struct E2ETimeoutError: Error {}

struct E2ETransportError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

struct SpeakSwiftlyBuildError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

func isRetryableConnectionDuringStartup(_ error: Error) -> Bool {
    let nsError = error as NSError
    guard nsError.domain == NSURLErrorDomain else { return false }
    return nsError.code == NSURLErrorCannotConnectToHost || nsError.code == NSURLErrorNetworkConnectionLost
}

