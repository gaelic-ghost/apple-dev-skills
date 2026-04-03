# Reality Audit Guide

Use this guide when reconciling repository documentation with the actual shipped skill surface, local scripts, and tests.

## Source-of-Truth Order

Use the highest-confidence artifact first and only fall back when the higher layer is silent.

1. Runtime behavior proven by tests under `tests/`
2. Active shipped skill assets under `skills/<skill>/`
   - `SKILL.md`
   - `agents/openai.yaml`
   - `references/`
   - `scripts/`
3. Plugin packaging metadata under `plugins/apple-dev-skills/` and `.agents/plugins/marketplace.json`
   - `.codex-plugin/plugin.json`
   - `.claude-plugin/plugin.json`
   - plugin-only packaging directories such as `hooks/`, `bin/`, and `assets/`
4. Repository validation rules in `.github/scripts/validate_repo_docs.sh`
5. Root maintainer and discoverability docs
   - `README.md`
   - `AGENTS.md`
   - `ROADMAP.md`
   - `docs/maintainers/`

Deprecated compatibility skills that remain on disk do not count as part of the active public skill surface unless the validator and root docs explicitly say otherwise.

## Audit Procedure

1. Confirm the active public skill surface from `.github/scripts/validate_repo_docs.sh` and the matching sections in `README.md` and `docs/maintainers/workflow-atlas.md`.
2. Check each active skill for the documented contract:
   - required headings in `SKILL.md`
   - `agents/openai.yaml`
   - `references/customization.template.yaml`
   - `references/`
   - the skill-appropriate local snippet copy under `references/snippets/`
3. Check plugin packaging metadata for drift:
   - root `skills/` still define the canonical workflow behavior
   - Codex plugin metadata does not claim unsupported plugin capabilities
   - Claude-only extras remain optional and clearly separated
4. Run `bash .github/scripts/validate_repo_docs.sh` and treat failures as documentation-contract drift unless code assets prove otherwise.
5. Run `uv run pytest` and treat failures as runtime drift.
6. Reconcile root docs to the tested, shipped state instead of preserving stale historical wording.
7. Update `ROADMAP.md` in the same change when milestone or status text is no longer truthful.

## Durable Review Criteria

- Root docs must describe the same active skill surface.
- Root docs must describe the current plugin packaging shape without treating plugin wrappers as the workflow source of truth.
- Maintainer-doc links in root docs must resolve on disk.
- Validation rules must check the canonical maintainer-doc paths, not legacy locations.
- Historical notes may mention retired or deprecated skills only in migration context.
- Maintainer docs must not imply that repo-root files are required when the canonical files live under `docs/maintainers/`.
- Plugin docs must keep the Codex common denominator and Claude-only extras explicit.

## Current Canonical Maintainer Docs

- Workflow diagrams and UX maps: `docs/maintainers/workflow-atlas.md`
- Audit procedure and source-of-truth order: `docs/maintainers/reality-audit.md`

## Reporting Shape

A maintainer audit report should summarize:

- documentation drift found
- validation health
- test health
- roadmap credibility or staleness
- remaining follow-up items
