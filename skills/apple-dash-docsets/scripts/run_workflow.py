#!/usr/bin/env python3
"""Unified runtime entrypoint for apple-dash-docsets."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import customization_config


VALID_STAGES = {"search", "install", "generate"}
INSTALL_REPO_NAME = {
    "built_in": "Main Docsets",
    "user_contributed": "User Contributed Docsets",
    "cheatsheet": "Cheat Sheets",
}


def load_effective_config() -> dict:
    return customization_config.merge_configs(
        customization_config.load_template(),
        customization_config.load_durable(),
    )


def split_csv(raw: str) -> list[str]:
    return [item.strip() for item in raw.split(",") if item.strip()]


def run_json_script(script_name: str, args: list[str]) -> dict:
    script_path = Path(__file__).with_name(script_name)
    proc = subprocess.run(
        [sys.executable, str(script_path), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        payload = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        payload = {}
    payload["_returncode"] = proc.returncode
    payload["_stderr"] = proc.stderr
    return payload


def select_search_access_path(order: list[str], status_file: str | None) -> tuple[str | None, list[str], dict | None]:
    probe_result: dict | None = None
    for item in order:
        if item == "mcp":
            return "mcp", order, probe_result
        if item == "http":
            probe_args: list[str] = []
            if status_file:
                probe_args.extend(["--status-file", status_file])
            probe_result = run_json_script("dash_api_probe.py", probe_args)
            if probe_result.get("health_ok") and probe_result.get("schema_ok"):
                return "http", order, probe_result
            continue
        if item == "url-service":
            return "url-service", order, probe_result
    return None, order, probe_result


def load_matches(query: str, limit: int) -> list[dict]:
    payload = run_json_script("dash_catalog_match.py", ["--query", query, "--limit", str(limit)])
    return payload.get("matches", []) if isinstance(payload.get("matches"), list) else []


def shape_matches(matches: list[dict], include_snippets: bool) -> list[dict]:
    if include_snippets:
        return matches
    trimmed: list[dict] = []
    for match in matches:
        trimmed.append(
            {
                "name": match.get("name"),
                "slug": match.get("slug"),
                "source": match.get("source"),
            }
        )
    return trimmed


def choose_match(matches: list[dict], source_priority: list[str]) -> dict | None:
    for source in source_priority:
        for match in matches:
            if match.get("source") == source:
                return match
    return matches[0] if matches else None


def search_stage(args: argparse.Namespace, settings: dict) -> tuple[int, dict]:
    if not args.query:
        return 1, {
            "status": "blocked",
            "path_type": "primary",
            "stage": "search",
            "access_path": None,
            "source_path": None,
            "matches": [],
            "next_step": "Provide --query for the search stage.",
        }

    order = split_csv(str(settings.get("fallbackOrder", "mcp,http,url-service")))
    access_path, applied_order, probe = select_search_access_path(order, args.status_file)
    include_snippets = bool(settings.get("defaultSearchSnippets", True))
    raw_matches = load_matches(args.query, int(settings.get("defaultMaxResults", 20)))
    matches = shape_matches(raw_matches, include_snippets)
    if not access_path:
        troubleshooting_preference = str(settings.get("troubleshootingPreference", "api-first"))
        if troubleshooting_preference == "url-service-first":
            next_step = "No usable Dash search path is available. Check URL or Service integration first, then verify the local Dash API."
        else:
            next_step = "No usable Dash search path is available. Check the local Dash API first, then verify URL or Service integration."
        return 1, {
            "status": "blocked",
            "path_type": "fallback",
            "stage": "search",
            "access_path": None,
            "source_path": None,
            "matches": matches,
            "probe": probe,
            "next_step": next_step,
            "search_snippets_enabled": include_snippets,
            "troubleshooting_preference": troubleshooting_preference,
        }

    return 0, {
        "status": "success",
        "path_type": "primary" if access_path == applied_order[0] else "fallback",
        "stage": "search",
        "access_path": access_path,
        "source_path": None,
        "matches": matches,
        "probe": probe,
        "search_snippets_enabled": include_snippets,
        "next_step": (
            "If the docset is missing, rerun with --stage install."
            if matches
            else "If the query maps to a missing docset, rerun with --stage install and --docset-request."
        ),
    }


def install_stage(args: argparse.Namespace, settings: dict) -> tuple[int, dict]:
    if not args.docset_request:
        return 1, {
            "status": "blocked",
            "path_type": "primary",
            "stage": "install",
            "access_path": None,
            "source_path": None,
            "matches": [],
            "next_step": "Provide --docset-request for the install stage.",
        }

    matches = load_matches(args.docset_request, 20)
    source_priority = split_csv(str(settings.get("installSourcePriority", "built-in,user-contributed,cheatsheet")))
    normalized_priority = [item.replace("-", "_") for item in source_priority]
    selected = choose_match(matches, normalized_priority)
    if not selected:
        return 0, {
            "status": "handoff",
            "path_type": "primary",
            "stage": "install",
            "access_path": None,
            "source_path": None,
            "matches": matches,
            "next_step": "No installable catalog match was found. Hand off to the generate stage.",
        }

    approval_required = bool(settings.get("requireExplicitApprovalForYes", True))
    approved = bool(args.yes) or not approval_required or args.dry_run
    source = str(selected.get("source", "built_in"))
    repo_name = INSTALL_REPO_NAME.get(source, "Main Docsets")
    install_result = run_json_script(
        "dash_url_install.py",
        [
            "--repo-name",
            repo_name,
            "--entry-name",
            str(selected.get("name", args.docset_request)),
            *(["--yes"] if approved and not args.dry_run else []),
            *(["--dry-run"] if args.dry_run else []),
        ],
    )

    if approval_required and not args.dry_run and not args.yes:
        return 1, {
            "status": "blocked",
            "path_type": "primary",
            "stage": "install",
            "access_path": "dash-install-url",
            "source_path": source,
            "matches": matches,
            "selected_match": selected,
            "next_step": "Rerun with --yes to allow install side effects.",
        }

    return 0, {
        "status": "success",
        "path_type": "primary",
        "stage": "install",
        "access_path": "dash-install-url",
        "source_path": source,
        "matches": matches,
        "selected_match": selected,
        "install_result": install_result,
        "next_step": "Run the search stage again after installation if you need lookup results.",
    }


def generate_stage(args: argparse.Namespace, settings: dict) -> tuple[int, dict]:
    if not args.docset_request:
        return 1, {
            "status": "blocked",
            "path_type": "primary",
            "stage": "generate",
            "access_path": None,
            "source_path": None,
            "matches": [],
            "next_step": "Provide --docset-request for the generate stage.",
        }

    matches = load_matches(args.docset_request, 20)
    generation_policy = str(settings.get("generationPolicy", "automate-stable"))
    guidance = {
        "policy": generation_policy,
        "automation_first": generation_policy == "automate-stable",
        "request": args.docset_request,
        "steps": [
            "Gather the upstream docs source and confirm the scope of the docset.",
            "Prefer stable automation or generator tooling before manual packaging.",
            "If automation is unavailable, produce deterministic manual generation guidance instead of mixing workflows.",
        ],
    }
    return 0, {
        "status": "success",
        "path_type": "primary",
        "stage": "generate",
        "access_path": None,
        "source_path": "automation-guidance" if guidance["automation_first"] else "manual-guidance",
        "matches": matches,
        "guidance": guidance,
        "next_step": "Use the generation guidance to create or update the missing Dash resource.",
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=sorted(VALID_STAGES))
    parser.add_argument("--query")
    parser.add_argument("--docset-identifiers")
    parser.add_argument("--docset-request")
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--status-file")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    config = load_effective_config()
    settings = config["settings"]
    stage = args.stage or "search"

    if stage == "search":
        code, payload = search_stage(args, settings)
    elif stage == "install":
        code, payload = install_stage(args, settings)
    else:
        code, payload = generate_stage(args, settings)

    payload["configured_stage"] = stage
    payload["docset_identifiers"] = args.docset_identifiers
    print(json.dumps(payload, indent=2, sort_keys=True))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
