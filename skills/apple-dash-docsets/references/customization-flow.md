# Dash Customization Contract

## Purpose

Tune the runtime-supported defaults for the unified Dash stage entrypoint without overstating what still remains guidance-only.

## Knobs

| Knob | Default | Status | Effect |
| --- | --- | --- | --- |
| `fallbackOrder` | `mcp,http,url-service` | `runtime-enforced` | Controls the search-stage access-path order used by `scripts/run_workflow.py`. |
| `defaultMaxResults` | `20` | `runtime-enforced` | Controls the default catalog-match limit used by `scripts/run_workflow.py`. |
| `defaultSearchSnippets` | `true` | `policy-only` | Still documents preferred snippet behavior; the runtime entrypoint does not yet shape snippet content. |
| `installSourcePriority` | `built-in,user-contributed,cheatsheet` | `runtime-enforced` | Controls source selection order for install-stage catalog matches. |
| `requireExplicitApprovalForYes` | `true` | `runtime-enforced` | Controls whether `scripts/run_workflow.py` blocks install side effects without explicit approval. |
| `generationPolicy` | `automate-stable` | `runtime-enforced` | Controls the structured guidance mode returned by the generate stage. |
| `troubleshootingPreference` | `api-first` | `policy-only` | Sets the documented troubleshooting emphasis when Dash access fails. |

## Runtime Behavior

- `scripts/customization_config.py` reads, writes, resets, and reports customization state.
- `scripts/run_workflow.py` loads the effective merged customization state at runtime.
- Helper scripts remain implementation details behind `scripts/run_workflow.py`.
- `defaultSearchSnippets` and `troubleshootingPreference` still remain guidance-only.

## Update Flow

1. Inspect current settings with `python3 scripts/customization_config.py effective`.
2. Update `SKILL.md`, `references/automation-prompts.md`, and the affected workflow references.
3. Persist the metadata change with `python3 scripts/customization_config.py apply --input <yaml-file>`.
4. Re-run `python3 scripts/customization_config.py effective` and confirm the stored values match the docs.
5. Verify the runtime output with `python3 scripts/run_workflow.py --stage search --query Swift --dry-run`.

## Validation

1. Run `python3 scripts/dash_api_probe.py`.
2. Run `python3 scripts/dash_catalog_match.py --query "swift"`.
3. Verify the docs still present `search`, `install`, and `generate` as separate stages in forward order.
4. Verify `scripts/run_workflow.py` reflects the runtime-enforced knobs above.
