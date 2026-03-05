# Project Roadmap

## Current Milestone
- ID: M8
- Name: Canonical Skill v2.0.0 Consolidation
- Status: In Progress
- Target Version: v2.0.0
- Last Updated: 2026-03-05
- Summary: Consolidate and rename the Apple skills bundle into five canonical skills, add install-advisor routing, and extract shared AGENTS baseline snippets.

## Milestones
| ID | Name | Target Version | Status | Target Date | Notes |
| --- | --- | --- | --- | --- | --- |
| M1 | Initial Apple Skill Bundle | v1.0.0 | Completed | 2026-02-27 | Initial four-skill repository baseline. |
| M2 | Portability and Customization Docs | v1.1.x | Completed | 2026-02-27 | Portability cleanup and per-skill customization docs for the original bundle. |
| M3 | Automation Prompt Support | v1.2.0 | Completed | 2026-02-27 | Automation prompt templates added to the original four skills. |
| M4 | Hybrid Apple/Xcode Workflow Suite | v1.3.0 | Completed | 2026-02-28 | Added orchestrator, MCP-first executor, CLI fallback, and safety/docs skills. |
| M5 | Discovery and README Polish | v1.4.x | Completed | 2026-02-28 | README discoverability and link/wording cleanup through `v1.4.2`. |
| M6 | Readiness and Documentation Parity | v1.5.0 | Completed | 2026-03-01 | Roadmap established, docs parity merged, and CI validation guardrails merged. |
| M7 | Claude Code Compatibility Completion | v1.7.0 | Completed | 2026-03-01 | Added grouped nested plugin manifest support. |
| M8 | Canonical Skill v2.0.0 Consolidation | v2.0.0 | In Progress | 2026-03-05 | Reduce to five canonical skills with merge + rename migration and routing installer guidance. |

## Plan History
### 2026-03-05 - Accepted Plan (v2.0.0 / M8)
- Scope:
  - Consolidate 8 skills into 5 canonical skills.
  - Introduce install-advisor routing skill.
  - Extract shared AGENTS core snippet for reusable standards.
- Acceptance Criteria:
  - Exactly five `SKILL.md` skill directories remain active.
  - Root docs and plugin manifest match new names and paths.
  - Validation script passes with no stale old-skill references in active skill metadata.
- Risks/Dependencies:
  - Breaking rename requires migration guidance for existing users.
  - Merge quality depends on preserving prior safety/fallback behavior.

## Change Log
- 2026-02-28: Initialized roadmap for repository status and next-priority planning.
- 2026-02-28: Closed documentation parity follow-ups and added CI guardrail workflow.
- 2026-03-01: Completed M6 and added M7 for plugin compatibility work.
- 2026-03-05: Started M8 to deliver canonical v2.0.0 naming and consolidation.
