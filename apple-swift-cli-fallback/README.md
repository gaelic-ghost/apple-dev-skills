# Customizing `apple-swift-cli-fallback`

This skill handles automatic fallback to official Apple and Swift CLI tooling when MCP-first execution cannot complete the task. Customize it to fit your command policies and fallback ergonomics.

## What To Customize

- CLI fallback command mapping by intent category
- Command verbosity and reproducibility defaults in examples
- Allowlist remediation guidance for blocked commands
- Toolchain preference policy (`swiftly` vs Xcode/CLT guidance)
- Advisory cooldown behavior for MCP setup reminders

## How To Customize With Codex

Edit:

- `SKILL.md` for high-level fallback policy and sequence
- `references/cli-fallback-matrix.md` for command selection rules
- `references/toolchain-management.md` and `references/allowlist-guidance.md` for setup/remediation guidance
- `scripts/advisory_cooldown.py` for advisory emission timing

## Example Prompts

- "Update `apple-swift-cli-fallback` so build/test fallback prefers `xcodebuild` over `swift test` for app projects."
- "Tighten fallback policy to always include a copy-paste-safe command block with explicit working directory assumptions."
- "Modify allowlist guidance to show `~/.codex/rules` examples for `xcodebuild` and `swift` together."
- "Reduce advisory chatter by increasing cooldown to 30 days."

## Validation Checklist

- Cross-check `references/cli-fallback-matrix.md` decisions against actual fallback examples in `SKILL.md`.
- Validate toolchain guidance remains consistent between references and policy text.
- Run `scripts/advisory_cooldown.py` to verify cooldown logic after policy changes.
