# Customizing `xcode-mcp-first-executor`

This skill executes Apple and Swift tasks through Xcode MCP tools first and emits structured fallback handoff only when MCP cannot satisfy the request. Customize it to match your workspace resolution and retry/handoff expectations.

## What To Customize

- Workspace tab resolution policy using `workspacePath`
- MCP tool mapping for task categories
- Retry criteria and maximum retry count for transient MCP failures
- Structured handoff payload shape for CLI fallback
- Mutation routing behavior for Xcode-managed scope requests

## How To Customize With Codex

Edit:

- `SKILL.md` for core MCP-first policy and handoff format
- `references/mcp-tool-matrix.md` for task-to-tool routing
- `references/mcp-failure-handoff.md` for fallback payload contract
- `references/mutation-via-mcp.md` for mutation routing constraints

## Example Prompts

- "Update `xcode-mcp-first-executor` to require explicit workspacePath confirmation before any build/test action."
- "Expand `mcp-tool-matrix.md` to include a dedicated lane for preview rendering workflows."
- "Change retry policy to two retries for timeout errors but zero retries for capability-missing errors."
- "Modify fallback handoff to always include one preferred command and one conservative alternative."

## Validation Checklist

- Validate workspace selection flow against real `XcodeListWindows` output patterns.
- Test one successful MCP path and one forced MCP failure path to verify handoff payload quality.
- Confirm mutation routing references remain aligned with the hard-safety expectations in dependent skills.
