# Application Support Config Plan

## Context

The live LaunchAgent-backed service now starts from a copied config alias at
`~/Library/SpeakSwiftlyServer/launch-agent-server.yaml` when the canonical config path contains
spaces. That alias is a patch-level durability fix: it moved the copied config out of
`~/Library/Caches`, which macOS and maintenance tools can remove independently of the installed
LaunchAgent plist.

The cleaner target is simpler: the installed service should derive its durable config root from
Foundation's standard Application Support URL, read the active config directly from
`~/Library/Application Support/SpeakSwiftlyServer/server.yaml`, and use the package bundle only for
shipped read-only defaults, templates, and resources.

## Current Failure Mode

The original alias existed because LaunchAgent installs that pointed `APP_CONFIG_FILE` directly at
`~/Library/Application Support/SpeakSwiftlyServer/server.yaml` failed while loading YAML config
through the current `swift-configuration` file-provider path. The practical symptom was that a
canonical config path containing `Application Support` was not safe enough for service startup.

The `v4.3.4` alias path avoids the immediate failure, but it still leaves two config files with
different jobs:

- the canonical operator-owned config in Application Support
- the copied LaunchAgent startup config outside Application Support

That duplication is useful only as a temporary compatibility surface. It should disappear once the
server can load the canonical path directly and reliably.

## Target Layout

Use the package bundle for shipped read-only inputs:

- default config templates
- schemas or documented example config files
- package resources such as `default.metallib`
- seed data that should be copied into user state before mutation

Use Application Support for durable per-user service state:

- `server.yaml`
- `runtime/configuration.json`
- `runtime/text-profiles.json`
- voice profile state
- any generated or user-edited runtime files that must survive restarts and cache cleanup

Use Caches only for rebuildable disposable data:

- temporary derived files
- short-lived diagnostics that can be regenerated
- noncritical indexes or scratch state

No LaunchAgent-critical config should live in Caches.

Resolve the Application Support root through Foundation URL APIs instead of hand-assembling or
escaping the path string. The space in `Application Support` is normal filesystem state, not a
special case the package should work around with alternate active config paths.

## Implementation Plan

### 1. Prove the path-with-spaces failure locally

Add a focused test or small diagnostic that asks the current config loader to read a YAML file at an
`Application Support` path with spaces. This should use the same `ConfigStore` path as service
startup instead of a different YAML parser path.

Expected result before the fix:

- the test reproduces the failure that originally forced the alias
- or the test proves the failure has already been removed upstream, in which case the remaining work
  can be a cleanup without a parser fix

### 2. Fix canonical config loading

Make `ConfigStore` load `APP_CONFIG_FILE` paths with spaces directly. Prefer a fix that keeps the
current `ReloadingFileProvider<YAMLSnapshot>` behavior if the provider can support it cleanly.

If the provider cannot support that path shape reliably, split the behavior deliberately:

- startup reads the YAML config through a direct Foundation-backed file read
- optional reload watching is layered on top only after direct startup loading is proven reliable

Do not preserve a stringly fallback that silently swaps to the alias after a failed direct open. If
the canonical path is invalid or missing, startup should fail with an explicit path-specific error.

### 3. Seed the canonical config during install and refresh

Add a package-bundled default config template and have install-style commands seed
`~/Library/Application Support/SpeakSwiftlyServer/server.yaml` when it is missing.

The install/update/refresh policy is:

- `install` seeds the default config when the canonical config file is missing
- refresh/update flows also seed the default config when the canonical config file is missing
- startup fails loudly when the resolved `APP_CONFIG_FILE` path is missing
- explicit user-provided config paths still fail loudly when missing instead of being replaced with
  bundled defaults

The default seed is a first-run convenience, not a runtime fallback. Once the LaunchAgent is pointed
at a canonical config path, the service should either load that file or report a clear missing-config
failure.

### 4. Change LaunchAgent environment shaping

Update `ServerInstallLayout.launchAgentEnvironmentVariables(...)` so `APP_CONFIG_FILE` points to the
canonical config path, including when that path contains spaces.

After this change:

- `launchAgentConfigPath(for:)` should either return the canonical standardized path unconditionally
  or be removed
- `launchAgentConfigAliasURL` should be removed from the public install layout unless a separate
  migration step still needs to delete old aliases
- `stageLaunchAgentConfigAliasIfNeeded(...)` should be removed from the install path

### 5. Clean up old alias state

Keep uninstall cleanup for both historical alias locations during the migration:

- `~/Library/Caches/SpeakSwiftlyServer/launch-agent-server.yaml`
- `~/Library/SpeakSwiftlyServer/launch-agent-server.yaml`

This cleanup should be explicit legacy removal code, not a continuing part of the active install
layout.

Once enough releases have passed, decide whether to delete the legacy cleanup or keep it as harmless
operator hygiene.

### 6. Add bundle-backed defaults only where they help

Add package-bundled resources only for read-only shipped data. A good first slice is a template or
default config resource that app/bootstrap code can copy into Application Support when no canonical
`server.yaml` exists.

Do not make the package bundle the active config store. Active config is user and operator state,
and it needs to remain writable outside the package artifact.

### 7. Update docs and release notes

Refresh the operator-facing docs that currently mention alias behavior:

- `README.md`
- `Sources/SpeakSwiftlyServer/SpeakSwiftlyServer.docc/Articles/LaunchAgent-Workflow.md`
- `docs/maintainers/live-service-reliability-follow-ups.md`
- release checklist or release notes for the patch that removes active alias use

The docs should say that Application Support owns durable config and runtime state, the package
bundle owns shipped read-only defaults, and Caches is not part of the LaunchAgent startup contract.

## Validation

Run the normal package and maintainer checks:

- `xcrun swift build`
- `xcrun swift test`
- `scripts/repo-maintenance/validate-all.sh`

Then run the live-service proof serially:

1. publish the patch release through `scripts/repo-maintenance/release-prepare.sh`
2. after merge, publish through `scripts/repo-maintenance/release-publish.sh --refresh-live-service`
3. verify the LaunchAgent environment shows `APP_CONFIG_FILE` pointing directly at
   `~/Library/Application Support/SpeakSwiftlyServer/server.yaml`
4. run `.release-artifacts/current/SpeakSwiftlyServerTool healthcheck --base-url http://127.0.0.1:7337`
5. confirm HTTP and MCP are both listening and MCP initialize succeeds
6. remove or temporarily rename the canonical config, rerun install or refresh, and confirm the
   bundled default is seeded back into Application Support before bootstrapping
7. remove or temporarily rename the canonical config after install, start the service without the
   install/refresh seeding path, and confirm startup fails loudly with the missing config path

## Open Questions

- Was the original path-with-spaces failure inside `swift-configuration`, this package's
  `FilePath(configFilePath)` handoff, or an earlier release's command/property-list construction?
- Should the app-managed install layout expose a public method for seeding the default config from
  bundle resources, or should seeding stay inside the command/app install path?
