---
name: apple-dash-docsets
description: Deprecated compatibility skill. `apple-dash-docsets` has been replaced by `explore-apple-swift-docs`, which now handles Apple and Swift docs exploration across Xcode MCP docs, Dash, and official web docs while still supporting Dash compatibility and optional Dash install follow-up.
---

# Apple Dash Docsets

## Purpose

This skill is deprecated. Its only purpose is to redirect agents and users to `explore-apple-swift-docs`, which now owns Apple and Swift docs exploration and still includes Dash compatibility as a subordinate capability.

## When To Use

- Use this skill only when an older workflow, install note, or user memory still points at `apple-dash-docsets`.
- Tell the user this skill has been deprecated and replaced by `explore-apple-swift-docs`.
- Let the user know the new skill still supports Dash-compatible lookup, install follow-up, and generation guidance when needed.
- Mention the current repo and plugin install path on Gale's GitHub when the user wants the new skill directly.
- Recommend `explore-apple-swift-docs` immediately instead of continuing with this deprecated skill.

## Single-Path Workflow

1. State plainly that `apple-dash-docsets` is deprecated.
2. Recommend `explore-apple-swift-docs` as the replacement skill.
3. Tell the user that Dash compatibility still exists inside the new skill.
4. If install guidance is useful, mention the current install path:
   - `npx skills add gaelic-ghost/apple-dev-skills --skill explore-apple-swift-docs`
   - or install the full bundle from Gale's GitHub repo when the user wants the full Apple skill set
5. Stop there and do not continue old Dash-specific workflow guidance from this skill.

## Inputs

- historical skill name reference
- user request context that still mentions Dash or this deprecated skill
- Defaults:
  - replacement skill: `explore-apple-swift-docs`
  - install example: `npx skills add gaelic-ghost/apple-dev-skills --skill explore-apple-swift-docs`

## Outputs

- `status`
  - `handoff`: the deprecated skill redirected the agent to the replacement skill
- `path_type`
  - `primary`: deprecation redirect completed normally
- `output`
  - replacement skill name
  - short deprecation note
  - install hint when useful

## Guards and Stop Conditions

- Do not continue the old active Dash workflow from this deprecated skill.
- Do not claim Dash support was removed; it now lives inside `explore-apple-swift-docs`.
- Do not hide the deprecation. State it plainly.

## Fallbacks and Handoffs

- Hand off directly to `explore-apple-swift-docs`.
- Recommend `apple-xcode-workflow` only if the task is actually execution or mutation work inside an Apple project rather than docs exploration.

## Customization

- No new customization work should be added here.
- Historical helper files remain only for compatibility and source migration reference.

## References

### Workflow References

- `../explore-apple-swift-docs/SKILL.md`

### Contract References

- `../explore-apple-swift-docs/references/customization-flow.md`

### Support References

- `https://github.com/gaelic-ghost/apple-dev-skills`

### Script Inventory

- Deprecated compatibility surface only. Use `explore-apple-swift-docs` for active runtime behavior.
