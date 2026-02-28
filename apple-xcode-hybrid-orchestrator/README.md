# Customizing `apple-xcode-hybrid-orchestrator`

This skill is the Apple/Swift entrypoint that routes work across MCP-first execution, official CLI fallback, and safety/docs policy handoff. Customize it to reflect your preferred orchestration and guardrail strictness.

## What To Customize

- Intent classification buckets and routing rules
- MCP-first retry and fallback handoff thresholds
- Mutation-safety handoff requirements before direct filesystem fallback
- Docs-policy integration points with `apple-dev-safety-and-docs`
- Advisory wording and cooldown behavior for MCP setup guidance

## How To Customize With Codex

Edit:

- `SKILL.md` for orchestration policy and sequencing rules
- `references/workflow-policy.md` for routing and handoff decisions
- `references/mcp-setup-advisory.md` for advisory behavior
- `references/skills-discovery.md` for downstream skill invocation guidance
- `scripts/advisory_cooldown.py` for cooldown mechanics

## Example Prompts

- "Update `apple-xcode-hybrid-orchestrator` to classify profiling requests as a separate intent bucket."
- "Change fallback policy so MCP retry happens twice before handoff to CLI."
- "Tighten mutation handling so direct filesystem fallback is never suggested unless user explicitly asks for it."
- "Refine skill-discovery guidance so docs lookups always invoke `apple-dev-safety-and-docs` first."

## Validation Checklist

- Walk through one task in each intent category and confirm route outcomes are deterministic.
- Verify fallback and mutation references align with policy text in `SKILL.md`.
- Run `scripts/advisory_cooldown.py` and confirm advisory timing behavior still matches documented policy.
