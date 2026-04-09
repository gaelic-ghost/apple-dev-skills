# E2E Investigation: Queued Marvis Live Playback Stall

## Context

- Date observed: `2026-04-08`
- Test suite command: `SPEAKSWIFTLYSERVER_E2E=1 swift test --filter SpeakSwiftlyServerE2ETests`
- Active failing lane: `httpMarvisQueuedLivePlaybackDrainsInOrder`

## Confirmed Runtime State

- The live E2E-owned server was running on `http://127.0.0.1:59123`.
- The process environment confirmed:
  - `APP_MCP_ENABLED=false`
  - `SPEAKSWIFTLY_SPEECH_BACKEND=marvis`
- Those settings narrow the stuck run to the HTTP queued-Marvis lane in `Tests/SpeakSwiftlyServerE2ETests/SpeakSwiftlyServerE2ETests.swift`.

## Confirmed Failure Signals

### 1. The first queued-live request never reached a terminal event

The first live request remained active in playback and never completed:

- request id: `70A26ACF-D15D-4F48-9CAD-5B7C27AA2438`
- profile: `http-marvis-queued-femme-profile`
- snapshot endpoint: `GET /requests/70A26ACF-D15D-4F48-9CAD-5B7C27AA2438`

Observed request history:

- `acknowledged`
- `started`
- `progress.loading_profile`
- `progress.starting_playback`
- `progress.buffering_audio`
- `progress.preroll_ready`

The request never emitted:

- `progress.playback_finished`
- a terminal success event
- a terminal failure event

That leaves the E2E helper blocked in `waitForTerminalJob(id:using:timeout:server:)` while the request snapshot still reports `status: "running"`.

### 2. Generation advanced while playback still held the first request open

While playback still reported the first request as active, the runtime host overview reported:

- playback queue active request:
  - `70A26ACF-D15D-4F48-9CAD-5B7C27AA2438`
- playback queue queued count:
  - `2`
- generation queue active request:
  - `333B6133-888F-4A48-A2FA-D3471A06F555`
- generation queue queued count:
  - `0`

The later queued requests had both advanced past queueing:

- second request:
  - `4D96E961-F15E-4D73-9A83-94EBDD2EA711`
  - queued at position `1`
  - later observed at `progress.starting_playback`
- third request:
  - `333B6133-888F-4A48-A2FA-D3471A06F555`
  - profile: `http-marvis-queued-androgenous-profile`
  - queued at position `2`
  - later observed at `progress.starting_playback`

At the time of inspection, all three retained request snapshots were still `running`:

- `70A26ACF-D15D-4F48-9CAD-5B7C27AA2438` at `progress.preroll_ready`
- `4D96E961-F15E-4D73-9A83-94EBDD2EA711` at `progress.starting_playback`
- `333B6133-888F-4A48-A2FA-D3471A06F555` at `progress.starting_playback`

This means the queued-live Marvis path allowed later work to start while the first playback-owned request never drained.

## Current Interpretation

There are two plausible explanations that still need to be separated:

1. The primary bug is playback completion.
   The first queued-live request never emits `playback_finished` or a terminal event, so the playback queue never drains.

2. The secondary bug is queue/lifecycle mismatch.
   Generation-side work may be allowed to advance independently of playback completion, which may be correct internally but still leaves the server-side retained request lifecycle inconsistent with the E2E expectation that a queued-live request becomes terminal after playback finishes.

## Focused Lane Rerun

A later focused rerun of only `httpMarvisQueuedLivePlaybackDrainsInOrder` produced a stronger signal:

- first request:
  - `53A3932B-0F18-435D-B449-F684B57712A0`
  - reached `progress.playback_finished`
  - reached a terminal success event
- second request:
  - `D68325FD-D4B8-4EE6-93F5-812CF48B4944`
  - advanced through `progress.preroll_ready`
  - remained `running`
- third request:
  - `60B73D71-3996-4C94-8BE5-4A319DF03D0B`
  - started after the first request completed
  - advanced to `progress.starting_playback` while the second request was still only at `preroll_ready`

That focused rerun shifts the problem statement:

- the failure is not strictly "the first queued-live request always stalls"
- the stronger invariant break is that a later queued-live request can begin advancing while an earlier playback-owned request is still non-terminal
- once that happens, the earlier request can remain parked at `preroll_ready` indefinitely

## Likely Next Checks

1. Trace where `generate_speech_live` is expected to emit `playback_finished` and `completed` for each queued-live request after `preroll_ready`.
2. Verify whether queued live speech is allowed to overlap generation progress for later requests before the active playback request becomes terminal.
3. Decide whether the server should continue treating queued-live request completion as a strict terminal playback boundary, or whether the retained-job model needs to distinguish generation completion from playback completion more explicitly.
