import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#endif

// MARK: - HTTP Client

struct E2EHTTPClient {
    let baseURL: URL

    func request(
        path: String,
        method: String,
        jsonBody: [String: Any]? = nil
    ) async throws -> E2EHTTPResponse {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let jsonBody {
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw E2ETransportError("The live HTTP request to '\(path)' did not return an HTTPURLResponse.")
        }
        return E2EHTTPResponse(statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields, data: data)
    }
}

struct E2EHTTPResponse {
    let statusCode: Int
    let headers: [AnyHashable: Any]
    let data: Data

    var text: String {
        String(decoding: data, as: UTF8.self)
    }
}

// MARK: - MCP Client

struct E2EMCPClient {
    let baseURL: URL
    let path: String
    let sessionID: String

    static func connect(
        baseURL: URL,
        path: String,
        timeout: Duration,
        server: ServerProcess
    ) async throws -> E2EMCPClient {
        try await e2eWaitUntil(timeout: timeout, pollInterval: .seconds(1)) {
            guard server.isStillRunning else {
                throw E2ETransportError(
                    "The live SpeakSwiftlyServer process exited before the MCP transport became available.\n\(server.combinedOutput)"
                )
            }

            do {
                return try await connectNow(baseURL: baseURL, path: path)
            } catch {
                if isRetryableConnectionDuringStartup(error) {
                    return nil
                }
                return nil
            }
        }
    }

    private static func connectNow(baseURL: URL, path: String) async throws -> E2EMCPClient {
        let initializeBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "initialize-1",
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-11-25",
                "capabilities": [:],
                "clientInfo": [
                    "name": "SpeakSwiftlyServerE2ETests",
                    "version": "1.0",
                ],
            ],
        ]

        let initializeResponse = try await post(
            baseURL: baseURL,
            path: path,
            jsonBody: initializeBody,
            sessionID: nil
        )
        let sessionID = try requireMCPHeader("Mcp-Session-Id", in: initializeResponse.headers)
        _ = try parseMCPEnvelope(from: initializeResponse.data)

        let initializedBody: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
        ]
        let initializedResponse = try await post(
            baseURL: baseURL,
            path: path,
            jsonBody: initializedBody,
            sessionID: sessionID
        )
        #expect((200...299).contains(initializedResponse.statusCode))

        return .init(baseURL: baseURL, path: path, sessionID: sessionID)
    }

    func callTool(name: String, arguments: [String: String]) async throws -> [String: Any] {
        try await callTool(name: name, arguments: arguments as [String: Any])
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> [String: Any] {
        let payload = try await callToolJSON(name: name, arguments: arguments)
        guard let object = payload as? [String: Any] else {
            throw E2ETransportError(
                "The live end-to-end helper expected the '\(name)' MCP tool to return a top-level JSON object, but received '\(type(of: payload))'."
            )
        }
        return object
    }

    func callToolJSON(name: String, arguments: [String: String]) async throws -> Any {
        try await callToolJSON(name: name, arguments: arguments as [String: Any])
    }

    func callToolJSON(name: String, arguments: [String: Any]) async throws -> Any {
        let envelope = try await callMethod(
            "tools/call",
            params: [
                "name": name,
                "arguments": arguments,
            ]
        )
        if let error = envelope["error"] as? [String: Any] {
            throw E2ETransportError("The live MCP tools/call request for '\(name)' failed with payload: \(error)")
        }
        let result = try requireDictionary("result", in: envelope)
        let content = try requireArray("content", in: result)
        let first = try requireFirstDictionary(in: content)
        let text = try requireString("text", in: first)
        return try JSONSerialization.jsonObject(with: Data(text.utf8))
    }

    func readResourceText(uri: String) async throws -> String {
        let envelope = try await callMethod("resources/read", params: ["uri": uri])
        if let error = envelope["error"] as? [String: Any] {
            throw E2ETransportError("The live MCP resources/read request for '\(uri)' failed with payload: \(error)")
        }
        let result = try requireDictionary("result", in: envelope)
        let contents = try requireArray("contents", in: result)
        let first = try requireFirstDictionary(in: contents)
        return try requireString("text", in: first)
    }

    func readResourceJSON(uri: String) async throws -> Any {
        try JSONSerialization.jsonObject(with: Data(try await readResourceText(uri: uri).utf8))
    }

    func listResources() async throws -> [[String: Any]] {
        let envelope = try await callMethod("resources/list", params: [:])
        let result = try requireDictionary("result", in: envelope)
        return try requireArray("resources", in: result)
    }

    func listResourceTemplates() async throws -> [[String: Any]] {
        let envelope = try await callMethod("resources/templates/list", params: [:])
        let result = try requireDictionary("result", in: envelope)
        return try requireArray("resourceTemplates", in: result)
    }

    func listPrompts() async throws -> [[String: Any]] {
        let envelope = try await callMethod("prompts/list", params: [:])
        let result = try requireDictionary("result", in: envelope)
        return try requireArray("prompts", in: result)
    }

    func getPrompt(name: String, arguments: [String: String]) async throws -> [String: Any] {
        let envelope = try await callMethod(
            "prompts/get",
            params: [
                "name": name,
                "arguments": arguments,
            ]
        )
        return try requireDictionary("result", in: envelope)
    }

    func subscribe(to uri: String) async throws {
        _ = try await callMethod("resources/subscribe", params: ["uri": uri])
    }

    func unsubscribe(from uri: String) async throws {
        _ = try await callMethod("resources/unsubscribe", params: ["uri": uri])
    }

    func callMethod(_ method: String, params: [String: Any]) async throws -> [String: Any] {
        let response = try await Self.post(
            baseURL: baseURL,
            path: path,
            jsonBody: [
                "jsonrpc": "2.0",
                "id": UUID().uuidString,
                "method": method,
                "params": params,
            ],
            sessionID: sessionID
        )
        return try parseMCPEnvelope(from: response.data)
    }

    func openEventStream() -> E2EMCPEventStream {
        .init(baseURL: baseURL, path: path, sessionID: sessionID)
    }

    private static func post(
        baseURL: URL,
        path: String,
        jsonBody: [String: Any],
        sessionID: String?
    ) async throws -> E2EHTTPResponse {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw E2ETransportError("The live MCP transport did not return an HTTPURLResponse.")
        }
        return E2EHTTPResponse(statusCode: httpResponse.statusCode, headers: httpResponse.allHeaderFields, data: data)
    }
}

final class E2EMCPEventStream: @unchecked Sendable {
    private let baseURL: URL
    private let path: String
    private let sessionID: String
    private let buffer = E2ENotificationBuffer()
    private let connectionState = E2EMCPEventStreamConnectionState()
    private let urlSession: URLSession
    private var task: Task<Void, Never>?

    init(baseURL: URL, path: String, sessionID: String) {
        self.baseURL = baseURL
        self.path = path
        self.sessionID = sessionID
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: configuration)
    }

    func start() async throws {
        guard task == nil else { return }

        task = Task {
            var request = URLRequest(url: baseURL.appending(path: path))
            request.httpMethod = "GET"
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")

            do {
                let (bytes, response) = try await urlSession.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await connectionState.finish(
                        with: E2ETransportError(
                            "The live MCP event stream did not open successfully for session '\(sessionID)'."
                        )
                    )
                    await buffer.finish(
                        with: E2ETransportError(
                            "The live MCP event stream did not open successfully for session '\(sessionID)'."
                        )
                    )
                    return
                }
                await connectionState.markConnected()

                for try await line in bytes.lines {
                    if Task.isCancelled {
                        return
                    }

                    if line.hasPrefix("data: ") {
                        let payload = String(line.dropFirst(6))
                        guard payload.isEmpty == false, let data = payload.data(using: .utf8) else {
                            continue
                        }
                        await buffer.append(data)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await connectionState.finish(with: error)
                await buffer.finish(with: error)
            }
        }

        let _: Bool = try await e2eWaitUntil(timeout: .seconds(10), pollInterval: .milliseconds(100)) {
            try await self.connectionState.streamReady()
        }
        try await Task.sleep(for: .milliseconds(100))
    }

    func stop() {
        task?.cancel()
        task = nil
        urlSession.invalidateAndCancel()
    }

    func waitForNotification(
        timeout: Duration,
        matching predicate: @escaping @Sendable ([String: Any]) -> Bool
    ) async throws -> [String: Any] {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let data = try await self.buffer.takeMatching(predicate) {
                let json = try JSONSerialization.jsonObject(with: data)
                guard let object = json as? [String: Any] else {
                    throw E2ETransportError(
                        "The live MCP event stream produced a notification payload that was not a JSON object."
                    )
                }
                return object
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let observedPayloads = await self.buffer.recentPayloads(limit: 12)
        let preview = observedPayloads.isEmpty
            ? "none"
            : observedPayloads.joined(separator: "\n")
        throw E2ETransportError(
            "The live MCP event stream timed out after waiting \(timeout) for a matching notification. The GET SSE stream stayed connected, but no matching notification arrived. Recent raw notification payloads seen before timeout:\n\(preview)"
        )
    }
}

private actor E2EMCPEventStreamConnectionState {
    private var isConnected = false
    private var terminalError: Error?

    func markConnected() {
        isConnected = true
    }

    func finish(with error: Error) {
        terminalError = error
    }

    func streamReady() throws -> Bool? {
        if let terminalError {
            throw terminalError
        }
        return isConnected ? true : nil
    }
}

private actor E2ENotificationBuffer {
    private var notifications = [Data]()
    private var terminalError: Error?
    private var payloadHistory = [String]()
    private static let payloadHistoryLimit = 48

    func append(_ notification: Data) {
        notifications.append(notification)
        payloadHistory.append(String(decoding: notification, as: UTF8.self))
        if payloadHistory.count > Self.payloadHistoryLimit {
            payloadHistory.removeFirst(payloadHistory.count - Self.payloadHistoryLimit)
        }
    }

    func finish(with error: Error) {
        terminalError = error
    }

    func takeMatching(_ predicate: @escaping @Sendable ([String: Any]) -> Bool) throws -> Data? {
        if let terminalError {
            throw terminalError
        }

        for (index, notification) in notifications.enumerated() {
            let json = try JSONSerialization.jsonObject(with: notification)
            guard let object = json as? [String: Any] else {
                continue
            }
            if predicate(object) {
                return notifications.remove(at: index)
            }
        }
        return nil
    }

    func recentPayloads(limit: Int) -> [String] {
        Array(payloadHistory.suffix(limit))
    }
}

