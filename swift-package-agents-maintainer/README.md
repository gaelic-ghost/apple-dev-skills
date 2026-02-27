# Customizing `swift-package-agents-maintainer`

This skill syncs a canonical `AGENTS.md` across Swift package repositories. Customize it to match your workspace layout and automation policy.

## What To Customize

- Default discovery root when no `--repo`/`--root` is passed
- Directory exclusion rules during recursive scans
- Default mode preference (`--check` for drift vs apply mode)
- Canonical AGENTS source file path and governance workflow
- Verbosity and reporting format for automation logs

## How To Customize With Codex

Use Codex to edit both:

- `SKILL.md` and `references/automation-usage.md` (policy and operator guidance)
- `scripts/sync_agents_md.sh` (actual scanning and sync behavior)

Keep script usage text and behavior in sync.

## Example Prompts

- "Update `swift-package-agents-maintainer` so default root is `~/Code` instead of `~/Workspace`, and update docs accordingly."
- "Add a configurable exclusion flag to `sync_agents_md.sh` so I can skip multiple custom directories at runtime."
- "Change this skill so apply mode requires an explicit `--apply` flag and defaults to check mode when no mode is provided."
- "Modify the summary output format in `sync_agents_md.sh` to emit JSON for automation pipelines."

## Validation Checklist

- Run `scripts/sync_agents_md.sh --help` and verify usage text is correct.
- Run one `--check` execution and one apply execution against a test repo.
- Confirm reported counts (`scanned`, `unchanged`, `drift`, `updated`) are accurate.
