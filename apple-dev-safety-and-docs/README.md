# Customizing `apple-dev-safety-and-docs`

This skill enforces hard mutation safety gates for Xcode-managed scope and routes Apple/Swift docs through a Dash-first policy. Customize it to match your consent thresholds and local docs posture.

## What To Customize

- Mutation-risk triggers for Xcode-managed scope detection
- Consent-gate wording and escalation thresholds for direct edits
- Docs routing order (Dash MCP/local-first versus official web docs fallback)
- Advisory cooldown duration and reminder behavior
- Installation guidance messaging for missing Dash docsets

## How To Customize With Codex

Edit:

- `SKILL.md` for policy rules and operator-facing workflow
- `references/mutation-risk-policy.md` and `references/dash-docs-flow.md` for decision criteria
- `scripts/detect_xcode_managed_scope.sh` for scope-detection logic
- `scripts/advisory_cooldown.py` for advisory timing behavior

## Example Prompts

- "Update `apple-dev-safety-and-docs` so direct-edit fallback always requires an explicit typed confirmation."
- "Change advisory cooldown from 21 days to 14 days and update references to match."
- "Adjust docs flow so official Apple docs are used immediately when a required Dash docset is missing."
- "Expand Xcode-managed scope detection to include additional workspace patterns."

## Validation Checklist

- Run `scripts/detect_xcode_managed_scope.sh` against sample paths and verify expected scope classification.
- Run `scripts/advisory_cooldown.py` with representative inputs and confirm cooldown behavior.
- Confirm `SKILL.md` policy language still matches script and reference behavior.
