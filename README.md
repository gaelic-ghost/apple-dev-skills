# SpeakSwiftlyServer

Swift executable package for a localhost HTTP server that will expose `SpeakSwiftly` over a small, app-friendly API.

## Overview

This repository is the Swift-native sibling to `../speak-to-user-server`. The goal is to replace that Python host with a Hummingbird-based macOS service that serves the same HTTP surface, including job-style request handling and SSE progress streaming, while staying tightly aligned with `SpeakSwiftly` as the source of truth for speech, profile management, and playback progress semantics.

### Motivation

The long-term target is a thin Swift server that a macOS app can install and manage as a LaunchAgent without needing a separate Python runtime. This package is intentionally starting as a small SwiftPM executable scaffold first so the repository, roadmap, and GitHub home are in place before the server implementation lands.

At the moment, the package is still in bootstrap state. The actual Hummingbird server, the matching HTTP routes, and the `SpeakSwiftly` integration are still ahead of us.

## Setup

Build the package with SwiftPM:

```bash
swift build
```

Run the test suite:

```bash
swift test
```

## Usage

The current executable is only a scaffold entrypoint. Running it today just exercises the placeholder binary:

```bash
swift run SpeakSwiftlyServer
```

The intended end state is a localhost HTTP service that mirrors the API shape of `../speak-to-user-server`, including:

- `GET /healthz`
- `GET /readyz`
- `GET /status`
- `GET /profiles`
- `POST /profiles`
- `DELETE /profiles/{profile_name}`
- `POST /speak`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/events`

Those routes are planned, not implemented yet.

## Development

The current package is a clean SwiftPM executable scaffold with generated test support and project guidance in [`AGENTS.md`](/Users/galew/Workspace/SpeakSwiftlyServer/AGENTS.md).

Near-term implementation work is expected to cover:

- adding Hummingbird as the HTTP server dependency
- modeling the Python host's in-memory job and SSE behavior in Swift
- deciding whether the first Swift server talks to `SpeakSwiftly` through a subprocess contract or through a future library product
- keeping the public HTTP contract aligned with `../speak-to-user-server`

Because `SpeakSwiftly` does not yet vend a library product, direct package import from this server is not available today. Until that changes, the integration strategy remains an explicit implementation milestone rather than a completed dependency.

## Verification

Current baseline checks:

```bash
swift build
swift test
```

Additional verification still needs to be added once the server implementation exists, especially for route behavior, SSE streaming, and `SpeakSwiftly` integration.

## Roadmap

Planned work is tracked in [`ROADMAP.md`](/Users/galew/Workspace/SpeakSwiftlyServer/ROADMAP.md).

## License

A project license has not been added yet.
