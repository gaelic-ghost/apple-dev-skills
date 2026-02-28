# apple-dev-skills

Codex skills for Apple development workflows focused on Swift, Xcode, and Apple tooling.

## Quick Add (Skills CLI)

```bash
npx skills add gaelic-ghost/apple-dev-skills
```

The CLI will prompt you to choose which skill(s) to install from this repo.

Additional examples:

```bash
# Target Codex explicitly
npx skills add gaelic-ghost/apple-dev-skills -a codex

# Install to global profile
npx skills add gaelic-ghost/apple-dev-skills -g

# Combine both
npx skills add gaelic-ghost/apple-dev-skills -a codex -g
```

Flag notes (see https://www.npmjs.com/package/skills):

- `-a` targets a specific agent (for example `codex`).
- `-g` installs to the global profile.

## Purpose

This repository packages a curated set of Apple-development Codex skills in a flat layout so they are easy to discover and install.

## Installing Skills (Vercel Skills CLI)

Use the Vercel Skills CLI against this repository to install any skill directory you want to use.

Example skill directories in this repo:

- `bootstrap-swift-package`
- `swift-package-agents-maintainer`
- `dash-docset-search`
- `dash-docset-install-generate`

## v1.0.0 Contents

Version `v1.0.0` includes the four skills above as the initial Apple-development bundle.

## v1.1.0 Highlights

Version `v1.1.0` focuses on public portability and customization:

- sanitizes user-specific path assumptions in skill content
- removes tracked Python cache artifacts
- adds per-skill customization guides:
  - `bootstrap-swift-package/README.md`
  - `swift-package-agents-maintainer/README.md`
  - `dash-docset-search/README.md`
  - `dash-docset-install-generate/README.md`

## v1.2.0 Highlights

Version `v1.2.0` adds automation prompt support across all bundled skills:

- adds `references/automation-prompts.md` to each skill with:
  - Codex App automation prompt templates
  - Codex CLI (`codex exec`) automation prompt templates
  - placeholder-driven customization knobs and guardrails
- adds `Automation Prompting` sections to each `SKILL.md` with App/CLI fit guidance (`Strong` or `Guarded`)
- updates each `agents/openai.yaml` `default_prompt` to explicitly route users to automation template usage

## Repository Layout

```text
.
├── README.md
├── LICENSE
├── bootstrap-swift-package/
├── swift-package-agents-maintainer/
├── dash-docset-search/
└── dash-docset-install-generate/
```

## Notes

- This repository intentionally includes only selected git-tracked skills from `~/.codex/skills`.
- The structure is intentionally flat at the repository root for now.
