# Customizing `bootstrap-swift-package`

This skill ships with strong defaults for fast, repeatable Swift package setup. Customize it when your team has different package conventions.

## What To Customize

- Default package type (`library`, `executable`, `tool`)
- Default platform profile (`mac`, `mobile`, `multiplatform`)
- Default version profile (`latest-major`, `current-minus-one`, `current-minus-two`)
- Git initialization behavior
- Whether `AGENTS.md` should always be copied in new repos
- Naming constraints and org naming patterns

## How To Customize With Codex

Use Codex to edit both:

- `SKILL.md` (human instructions and defaults)
- `scripts/bootstrap_swift_package.sh` (enforced runtime behavior)

Keep those two files aligned so docs match execution.

## Example Prompts

- "Update `bootstrap-swift-package` so default type is `executable` and default platform is `mac` instead of `multiplatform`."
- "Modify `bootstrap-swift-package` to skip `git init` unless I pass an explicit `--init-git` flag."
- "Change `bootstrap-swift-package` so it does not copy `AGENTS.md` by default; add an opt-in flag for that behavior."
- "Adjust the version profile defaults in `bootstrap-swift-package` to always use `latest-major` and update docs/tests accordingly."

## Validation Checklist

- Run the script once with defaults and once with explicit flags.
- Confirm resulting `Package.swift` platform targets match expected profiles.
- Verify docs in `SKILL.md` still describe actual script behavior.
