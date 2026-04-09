import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Live Server Process

final class ServerProcess: @unchecked Sendable {
    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private var stdoutTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?

    let baseURL: URL

    init(
        executableURL: URL,
        profileRootURL: URL,
        port: Int,
        silentPlayback: Bool,
        playbackTrace: Bool = false,
        mcpEnabled: Bool,
        speechBackend: String? = nil
    ) throws {
        guard let baseURL = URL(string: "http://127.0.0.1:\(port)") else {
            throw E2ETransportError("The live end-to-end suite could not construct a localhost base URL for port '\(port)'.")
        }
        self.baseURL = baseURL

        process.executableURL = executableURL
        process.currentDirectoryURL = executableURL.deletingLastPathComponent()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var environment = ProcessInfo.processInfo.environment
        environment["APP_PORT"] = String(port)
        environment["SPEAKSWIFTLY_PROFILE_ROOT"] = profileRootURL.path
        environment["APP_MCP_ENABLED"] = mcpEnabled ? "true" : "false"
        environment["APP_MCP_PATH"] = "/mcp"
        environment["APP_MCP_SERVER_NAME"] = "speak-swiftly-server-e2e"
        environment["APP_MCP_TITLE"] = "SpeakSwiftlyServer E2E MCP"
        if silentPlayback {
            environment["SPEAKSWIFTLY_SILENT_PLAYBACK"] = "1"
        } else {
            environment.removeValue(forKey: "SPEAKSWIFTLY_SILENT_PLAYBACK")
        }
        if playbackTrace {
            environment["SPEAKSWIFTLY_PLAYBACK_TRACE"] = "1"
        }
        if let speechBackend {
            environment["SPEAKSWIFTLY_SPEECH_BACKEND"] = speechBackend
        } else {
            environment.removeValue(forKey: "SPEAKSWIFTLY_SPEECH_BACKEND")
        }
        environment["DYLD_FRAMEWORK_PATH"] = executableURL.deletingLastPathComponent().path
        process.environment = environment
    }

    func start() throws {
        stdoutTask = captureLines(from: stdoutPipe.fileHandleForReading, recordingInto: stdoutRecorder)
        stderrTask = captureLines(from: stderrPipe.fileHandleForReading, recordingInto: stderrRecorder)
        try process.run()
    }

    func stop() {
        terminateProcessIfNeeded()
        stdoutTask?.cancel()
        stderrTask?.cancel()
    }

    var isStillRunning: Bool {
        process.isRunning
    }

    var combinedOutput: String {
        stdoutRecorder.contents + (stdoutRecorder.isEmpty || stderrRecorder.isEmpty ? "" : "\n") + stderrRecorder.contents
    }

    func stderrObjects() -> [[String: Any]] {
        stderrRecorder.snapshot.compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return json as? [String: Any]
        }
    }

    func waitForStderrJSONObject(
        timeout: Duration,
        matching predicate: @escaping @Sendable ([String: Any]) -> Bool
    ) async throws -> [String: Any] {
        try await e2eWaitUntil(timeout: timeout, pollInterval: .milliseconds(100)) {
            for line in self.stderrRecorder.snapshot {
                guard let data = line.data(using: .utf8) else { continue }
                guard let json = try? JSONSerialization.jsonObject(with: data) else { continue }
                guard let object = json as? [String: Any], predicate(object) else { continue }
                return object
            }

            guard self.isStillRunning else {
                throw E2ETransportError(
                    "The live SpeakSwiftlyServer process exited before the expected stderr JSON log was observed.\n\(self.combinedOutput)"
                )
            }
            return nil
        }
    }

    private func captureLines(
        from handle: FileHandle,
        recordingInto recorder: SynchronizedLogBuffer
    ) -> Task<Void, Never> {
        Task {
            do {
                for try await line in handle.bytes.lines {
                    recorder.append(line)
                }
            } catch is CancellationError {
                return
            } catch {
                recorder.append(
                    "Server process log capture stopped after an unexpected stream error: \(error.localizedDescription)"
                )
            }
        }
    }

    private let stdoutRecorder = SynchronizedLogBuffer()
    private let stderrRecorder = SynchronizedLogBuffer()

    private func terminateProcessIfNeeded() {
        guard process.isRunning else { return }

        if waitForExit(after: { process.interrupt() }, timeout: .seconds(5)) {
            return
        }
        if waitForExit(after: { process.terminate() }, timeout: .seconds(5)) {
            return
        }

        #if canImport(Darwin)
        kill(process.processIdentifier, SIGKILL)
        _ = waitForExit(timeout: .seconds(2))
        #endif
    }

    private func waitForExit(
        after action: () -> Void,
        timeout: Duration
    ) -> Bool {
        action()
        return waitForExit(timeout: timeout)
    }

    private func waitForExit(timeout: Duration) -> Bool {
        guard process.isRunning else { return true }

        let semaphore = DispatchSemaphore(value: 0)
        let originalHandler = process.terminationHandler
        process.terminationHandler = { completedProcess in
            originalHandler?(completedProcess)
            semaphore.signal()
        }
        defer {
            process.terminationHandler = originalHandler
        }

        guard process.isRunning else { return true }
        let timeoutInterval =
            Double(timeout.components.seconds)
            + Double(timeout.components.attoseconds) / 1_000_000_000_000_000_000
        return semaphore.wait(timeout: .now() + timeoutInterval) == .success
    }

    private final class SynchronizedLogBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var lines = [String]()

        func append(_ line: String) {
            lock.withLock {
                lines.append(line)
            }
        }

        var contents: String {
            lock.withLock {
                lines.joined(separator: "\n")
            }
        }

        var snapshot: [String] {
            lock.withLock {
                lines
            }
        }

        var isEmpty: Bool {
            lock.withLock {
                lines.isEmpty
            }
        }
    }
}
