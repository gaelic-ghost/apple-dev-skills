# ROADMAP

## Milestone 1: Bootstrap And Repo Hygiene

- [x] Scaffold the Swift executable package.
- [x] Add project-level guidance in `AGENTS.md`.
- [x] Write an initial `README.md` that reflects the real current state.
- [ ] Add a project license.
- [ ] Replace the placeholder executable body with the first real server startup path.
- [ ] Add package formatting and linting tooling.

## Milestone 2: Hummingbird HTTP Server

- [ ] Add Hummingbird as the HTTP server dependency.
- [ ] Implement a localhost server configuration model for host, port, and runtime settings.
- [ ] Implement `GET /healthz`.
- [ ] Implement `GET /readyz`.
- [ ] Implement `GET /status`.
- [ ] Implement `GET /profiles`.
- [ ] Implement `POST /profiles`.
- [ ] Implement `DELETE /profiles/{profile_name}`.
- [ ] Implement `POST /speak`.
- [ ] Implement `GET /jobs/{job_id}`.
- [ ] Implement `GET /jobs/{job_id}/events`.
- [ ] Implement SSE heartbeats and replay behavior compatible with the existing Python server contract.

## Milestone 3: SpeakSwiftly Integration

- [ ] Decide and implement the first integration path to `SpeakSwiftly`.
- [ ] If the first pass is subprocess-backed, mirror the existing worker JSONL contract cleanly in Swift.
- [ ] Surface operator-facing startup, readiness, and worker failure details clearly.
- [ ] Support profile cache refresh and reconciliation behavior after profile mutations.

## Milestone 4: Testing And Verification

- [ ] Replace the generated placeholder test with real package coverage.
- [ ] Add unit tests for configuration and settings loading.
- [ ] Add unit tests for in-memory job retention and pruning.
- [ ] Add route tests for health, readiness, profile, and job endpoints.
- [ ] Add SSE tests for initial worker status replay, progress history, and keep-alive behavior.
- [ ] Add failure-path tests for worker startup failure, runtime degradation, and expired jobs.
- [ ] Add end-to-end verification against a real or controlled `SpeakSwiftly` runtime.

## Milestone 5: Direct Library Import Migration

- [ ] Split `../SpeakSwiftly` so it vends a reusable library product alongside its executable product.
- [ ] Switch this package from subprocess-style integration to direct `SpeakSwiftly` package import when that library product exists.
- [ ] Collapse any temporary integration-only code that becomes unnecessary after direct import.
- [ ] Re-verify that the public HTTP API surface still matches `../speak-to-user-server`.

## Milestone 6: App And LaunchAgent Handoff

- [ ] Document the server configuration contract the forthcoming macOS app will need.
- [ ] Add any server-side hooks needed for LaunchAgent-friendly lifecycle management.
- [ ] Decide how logs, profile roots, and cache paths should be configured for app-managed installs.
- [ ] Prepare an initial tagged release once the service is meaningfully usable.
