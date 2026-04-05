import Foundation
import Testing
@testable import SpeakSwiftlyServer

// MARK: - CLI Tests

@Test func cliParsesLaunchAgentInstallAndDefaultsToSiblingServerExecutable() throws {
    let tempDirectory = try makeTemporaryDirectory()
    let currentDirectory = tempDirectory.path
    let debugDirectory = tempDirectory.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: debugDirectory, withIntermediateDirectories: true)

    let serverURL = debugDirectory.appendingPathComponent("SpeakSwiftlyServer")
    let cliURL = debugDirectory.appendingPathComponent("SpeakSwiftlyServerCli")
    try "#!/bin/sh\nexit 0\n".write(to: serverURL, atomically: true, encoding: .utf8)
    try "#!/bin/sh\nexit 0\n".write(to: cliURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: serverURL.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cliURL.path)

    let command = try SpeakSwiftlyServerCliCommand.parse(
        arguments: [
            "launch-agent",
            "install",
            "--config-file", "./server.yaml",
            "--reload-interval-seconds", "2",
        ],
        currentDirectoryPath: currentDirectory,
        currentExecutablePath: cliURL.path
    )

    guard case .launchAgent(let launchAgentCommand) = command,
          case .install(let options) = launchAgentCommand.action else {
        Issue.record("Expected the CLI parser to produce a launch-agent install command.")
        return
    }

    #expect(options.serverExecutablePath == serverURL.path)
    #expect(options.configFilePath == tempDirectory.appendingPathComponent("server.yaml").path)
    #expect(options.reloadIntervalSeconds == "2")
}

@Test func launchAgentPropertyListIncludesServerExecutableAndEnvironmentOverrides() throws {
    let tempDirectory = try makeTemporaryDirectory()
    let executableURL = tempDirectory.appendingPathComponent("SpeakSwiftlyServer")
    try "#!/bin/sh\nexit 0\n".write(to: executableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

    let options = try LaunchAgentOptions(
        serverExecutablePath: executableURL.path,
        plistPath: tempDirectory.appendingPathComponent("agent.plist").path,
        configFilePath: tempDirectory.appendingPathComponent("config/server.yaml").path,
        reloadIntervalSeconds: "0.5",
        workingDirectory: tempDirectory.path,
        standardOutPath: tempDirectory.appendingPathComponent("logs/stdout.log").path,
        standardErrorPath: tempDirectory.appendingPathComponent("logs/stderr.log").path
    )

    let propertyList = options.propertyList()
    let arguments = try #require(propertyList["ProgramArguments"] as? [String])
    let environment = try #require(propertyList["EnvironmentVariables"] as? [String: String])

    #expect(arguments == [executableURL.path])
    #expect(propertyList["RunAtLoad"] as? Bool == true)
    #expect(propertyList["KeepAlive"] as? Bool == true)
    #expect(environment["APP_CONFIG_FILE"] == tempDirectory.appendingPathComponent("config/server.yaml").path)
    #expect(environment["APP_CONFIG_RELOAD_INTERVAL_SECONDS"] == "0.5")
}

@Test func launchAgentInstallWritesPlistAndBootstrapsService() throws {
    let tempDirectory = try makeTemporaryDirectory()
    let executableURL = tempDirectory.appendingPathComponent("SpeakSwiftlyServer")
    let plistURL = tempDirectory.appendingPathComponent("LaunchAgents/com.example.test.plist")
    let logURL = tempDirectory.appendingPathComponent("launchctl.log")
    let stateURL = tempDirectory.appendingPathComponent("launchctl.state")
    let fakeLaunchctlURL = tempDirectory.appendingPathComponent("launchctl")

    try "#!/bin/sh\nexit 0\n".write(to: executableURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

    let fakeLaunchctlScript = """
    #!/bin/sh
    set -eu
    printf '%s\\n' "$*" >> "\(logURL.path)"
    command="$1"
    shift
    case "$command" in
      print)
        if [ -f "\(stateURL.path)" ]; then
          printf 'loaded\\n'
          exit 0
        fi
        printf 'not loaded\\n' >&2
        exit 113
        ;;
      bootstrap)
        : > "\(stateURL.path)"
        exit 0
        ;;
      bootout)
        rm -f "\(stateURL.path)"
        exit 0
        ;;
    esac
    """
    try fakeLaunchctlScript.write(to: fakeLaunchctlURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeLaunchctlURL.path)

    let options = try LaunchAgentOptions(
        label: "com.example.test",
        serverExecutablePath: executableURL.path,
        plistPath: plistURL.path,
        workingDirectory: tempDirectory.path,
        standardOutPath: tempDirectory.appendingPathComponent("logs/stdout.log").path,
        standardErrorPath: tempDirectory.appendingPathComponent("logs/stderr.log").path,
        launchctlPath: fakeLaunchctlURL.path,
        userDomain: "gui/501"
    )

    try options.install()

    #expect(FileManager.default.fileExists(atPath: plistURL.path))
    let launchctlLog = try String(contentsOf: logURL, encoding: .utf8)
    #expect(launchctlLog.contains("print gui/501/com.example.test"))
    #expect(launchctlLog.contains("bootstrap gui/501 \(plistURL.path)"))
}

@Test func launchAgentUninstallBootsOutLoadedServiceAndRemovesPlist() throws {
    let tempDirectory = try makeTemporaryDirectory()
    let plistURL = tempDirectory.appendingPathComponent("LaunchAgents/com.example.test.plist")
    let logURL = tempDirectory.appendingPathComponent("launchctl.log")
    let stateURL = tempDirectory.appendingPathComponent("launchctl.state")
    let fakeLaunchctlURL = tempDirectory.appendingPathComponent("launchctl")

    try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "plist".write(to: plistURL, atomically: true, encoding: .utf8)
    try Data().write(to: stateURL)

    let fakeLaunchctlScript = """
    #!/bin/sh
    set -eu
    printf '%s\\n' "$*" >> "\(logURL.path)"
    command="$1"
    shift
    case "$command" in
      print)
        if [ -f "\(stateURL.path)" ]; then
          printf 'loaded\\n'
          exit 0
        fi
        printf 'not loaded\\n' >&2
        exit 113
        ;;
      bootout)
        rm -f "\(stateURL.path)"
        exit 0
        ;;
    esac
    """
    try fakeLaunchctlScript.write(to: fakeLaunchctlURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeLaunchctlURL.path)

    let options = LaunchAgentStatusOptions(
        label: "com.example.test",
        plistPath: plistURL.path,
        launchctlPath: fakeLaunchctlURL.path,
        userDomain: "gui/501"
    )

    try options.uninstall()

    #expect(!FileManager.default.fileExists(atPath: plistURL.path))
    let launchctlLog = try String(contentsOf: logURL, encoding: .utf8)
    #expect(launchctlLog.contains("print gui/501/com.example.test"))
    #expect(launchctlLog.contains("bootout gui/501/com.example.test"))
}

// MARK: - Helpers

private func makeTemporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
