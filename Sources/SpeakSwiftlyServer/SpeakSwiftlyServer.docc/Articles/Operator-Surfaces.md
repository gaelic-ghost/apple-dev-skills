# Operator Surfaces

## Overview

The package exposes one shared host through three operator-oriented surfaces:

- the embedded Swift library surface in this DocC catalog
- the standalone `SpeakSwiftlyServerTool` executable
- the HTTP and MCP transports that the standalone server can publish

These surfaces share the same underlying host model, but they answer different ownership questions.

## Surface Roles

### Embedded Library

Use ``EmbeddedServerSession`` and ``ServerState`` when an app owns the process and wants direct state observation on the main actor.

### Command-Line Tool

`SpeakSwiftlyServerTool` is the operator entrypoint for starting the server directly or managing the LaunchAgent property list workflow. The main command types exposed by the package are:

- ``SpeakSwiftlyServerToolCommand``
- ``LaunchAgentCommand``
- ``SpeakSwiftlyServerToolCommandError``
- ``LaunchAgentCommandError``

The companion executable walkthrough starts at <doc:Using-The-Command-Line-Tool>.

### HTTP And MCP

The HTTP and MCP surfaces are transport adapters around the same host state and runtime operations. They are the right choice when another process, a local service manager, or an external client should own the session.

This DocC catalog intentionally stays library-first. For the transport inventory, request and response payloads, and command reference, use the repository docs:

- [README](https://github.com/gaelic-ghost/SpeakSwiftlyServer/blob/main/README.md)
- [API Reference](https://github.com/gaelic-ghost/SpeakSwiftlyServer/blob/main/API.md)

## Next Reading

If you are embedding the host in an app, continue with <doc:Embedding-The-Server>.

If you are staging a standalone install owned by an app, continue with <doc:App-Managed-Install-Layout>.

If you are operating the executable directly, continue with <doc:Using-The-Command-Line-Tool>.
