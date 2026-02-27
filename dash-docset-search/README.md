# Customizing `dash-docset-search`

This skill prioritizes Dash MCP tools, then local HTTP API, then URL/service fallbacks. Customize it to match your environment and preferred search flow.

## What To Customize

- Fallback order (MCP vs HTTP vs URL/service)
- Search result limits and snippet behavior defaults
- Docset recommendation ranking behavior in matcher scripts
- FTS enabling policy (automatic vs explicit user request)
- Preferred troubleshooting path when APIs are unavailable

## How To Customize With Codex

Edit:

- `SKILL.md` for workflow/policy guidance
- `scripts/dash_catalog_match.py` and related helpers for ranking/limits
- `references/*.md` for fallback and API usage guidance

## Example Prompts

- "Update `dash-docset-search` to prefer local HTTP API before MCP tools and adjust the workflow docs."
- "Change default match limit in `dash_catalog_match.py` from 20 to 50 and document why."
- "Modify this skill so FTS is enabled automatically when a docset is disabled, without asking again."
- "Add a stricter fallback policy to `dash-docset-search` that avoids URL-scheme guidance unless both MCP and HTTP fail."

## Validation Checklist

- Run `scripts/dash_api_probe.py` and confirm health-path logic still works.
- Run `scripts/dash_catalog_match.py --query "swift"` and verify output quality.
- Confirm `SKILL.md` fallback order matches actual expected operation.
