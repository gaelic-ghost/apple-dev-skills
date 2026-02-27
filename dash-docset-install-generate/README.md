# Customizing `dash-docset-install-generate`

This skill focuses on confirmation-first installation and hybrid generation workflows. Customize it for your preferred install safety and generation automation level.

## What To Customize

- Install source priority (built-in vs contributed vs cheatsheet)
- Confirmation policy (`--yes` handling and explicit approval requirements)
- Generation path policy (fully automated vs guide-heavy)
- Last-resort fallback behavior (GitHub/Stack Overflow generation guidance)
- Verification order after install (MCP vs HTTP vs manual UI confirmation)

## How To Customize With Codex

Edit:

- `SKILL.md` for policy and operator expectations
- `scripts/dash_url_install.py` for install confirmation logic
- `scripts/dash_catalog_match.py` for candidate resolution behavior
- `references/*.md` for fallback/guided flow consistency

## Example Prompts

- "Update `dash-docset-install-generate` to require a second confirmation before any install action, even with `--yes`."
- "Change installation priority so user-contributed docsets are preferred over built-in entries for specific categories."
- "Refactor this skill to favor guided generation steps and disable automated generation suggestions by default."
- "Adjust verification to always check local HTTP `/docsets/list` before using MCP tools."

## Validation Checklist

- Run `scripts/dash_catalog_match.py --query "xcode"` and verify candidate ordering.
- Test one install flow in dry-run/confirmation mode.
- Confirm docs and script behavior agree on approval and fallback rules.
