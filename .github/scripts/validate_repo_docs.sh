#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "Missing required string in $file: $needle"
}

require_not_contains() {
  local file="$1"
  local needle="$2"
  ! grep -Fq -- "$needle" "$file" || fail "Unexpected stale string in $file: $needle"
}

echo "Validating root docs presence..."
[[ -f README.md ]] || fail "Missing README.md at repo root."
[[ -f AGENTS.md ]] || fail "Missing AGENTS.md at repo root."
[[ -f LICENSE ]] || fail "Missing PolyForm Noncommercial LICENSE."
[[ -f LICENSE-APACHE-2.0 ]] || fail "Missing historical Apache 2.0 license text."
[[ -f NOTICE ]] || fail "Missing NOTICE."
[[ -f COMMERCIAL-USE.md ]] || fail "Missing COMMERCIAL-USE.md."

echo "Validating compatibility pointer shape..."
[[ -f ".agents/plugins/marketplace.json" ]] || fail "Missing compatibility marketplace metadata."
[[ ! -e ".agents/skills" ]] || fail "Did not expect .agents/skills in the pointer repository."
[[ ! -e ".codex-plugin" ]] || fail "Did not expect .codex-plugin in the pointer repository."
[[ ! -e "skills" ]] || fail "Did not expect a local skills tree in the pointer repository."
[[ ! -e "plugins/apple-dev-skills" ]] || fail "Did not expect a nested plugins/apple-dev-skills tree."
require_contains ".agents/plugins/marketplace.json" '"source": "git-subdir"'
require_contains ".agents/plugins/marketplace.json" '"url": "https://github.com/gaelic-ghost/socket.git"'
require_contains ".agents/plugins/marketplace.json" '"path": "./plugins/apple-dev-skills"'
require_contains ".agents/plugins/marketplace.json" '"ref": "main"'

echo "Validating root README contract..."
require_contains "README.md" 'Apple Dev Skills has moved into the [Socket marketplace](https://github.com/gaelic-ghost/socket).'
require_contains "README.md" 'codex plugin marketplace add gaelic-ghost/socket'
require_contains "README.md" 'codex plugin marketplace upgrade socket'
require_contains "README.md" 'codex plugin marketplace add gaelic-ghost/apple-dev-skills'
require_contains "README.md" 'codex plugin marketplace upgrade apple-dev-skills'
require_contains "README.md" 'That compatibility marketplace points at the Socket-hosted plugin payload through `.agents/plugins/marketplace.json`.'
require_contains "README.md" 'prefer the Socket entry: `apple-dev-skills@socket`'
require_contains "README.md" 'PolyForm Noncommercial License 1.0.0'
require_contains "README.md" 'Commercial use requires a separate written commercial license from Gale.'
require_contains "README.md" 'mail@galewilliams.com'
require_contains "README.md" 'LICENSE-APACHE-2.0'
require_not_contains "README.md" 'install-plugin-to-socket'
require_not_contains "README.md" 'licensed under Apache 2.0'

echo "Validating AGENTS contract..."
require_contains "AGENTS.md" 'This repository is a compatibility marketplace and README pointer'
require_contains "AGENTS.md" 'The canonical authored Apple Dev Skills payload now lives in `gaelic-ghost/socket` under `plugins/apple-dev-skills`.'
require_contains "AGENTS.md" 'Treat `productivity-skills` as the default baseline maintainer layer'
require_contains "AGENTS.md" 'Preserve standalone-install guidance for public users who install only `apple-dev-skills`'
require_contains "AGENTS.md" 'Keep `.agents/plugins/marketplace.json` as the compatibility surface that redirects to the Socket subdirectory.'
require_contains "AGENTS.md" 'Do not add plugin payload, `.codex-plugin`, or `.agents/skills` surfaces back to this repository for new feature work; make payload changes in Socket.'
require_contains "AGENTS.md" 'require reading the relevant Apple documentation before proposing implementation changes.'
require_contains "AGENTS.md" 'Keep `explore-apple-swift-docs` as the canonical docs-routing surface'
require_contains "AGENTS.md" "This repository no longer carries skill behavior or pytest-backed payload tests."

echo "Validating commercial-use contract..."
require_contains "COMMERCIAL-USE.md" "Commercial use requires a separate written commercial license"
require_contains "COMMERCIAL-USE.md" "mail@galewilliams.com"
require_contains "COMMERCIAL-USE.md" "contractor, consultant, freelancer"
require_contains "COMMERCIAL-USE.md" "using Apple Dev Skills to do work for an employer"
require_contains "COMMERCIAL-USE.md" "startup using Apple Dev Skills"
require_contains "COMMERCIAL-USE.md" "organization using Apple Dev Skills to provide services"
require_contains "COMMERCIAL-USE.md" "train, evaluate, benchmark, design, or improve"

echo "Apple Dev Skills compatibility repository docs are internally consistent."
