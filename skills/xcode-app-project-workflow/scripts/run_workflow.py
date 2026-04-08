#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "PyYAML>=6.0.2,<7",
# ]
# ///
"""Runtime workflow policy engine for xcode-app-project-workflow."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import customization_config


VALID_OPERATION_TYPES = {
    "workspace-inspection",
    "session-inspection",
    "read-search-diagnostics",
    "build",
    "test",
    "run",
    "package-toolchain-management",
    "mutation",
}


def normalize_request_text(text: str | None) -> str:
    return " ".join((text or "").strip().lower().split())


def infer_operation_type_from_request(request: str | None) -> str | None:
    text = normalize_request_text(request)
    if not text:
        return None

    checks: list[tuple[str, tuple[str, ...]]] = [
        ("test", (" test", " tests", "testing", "xctest", "xcuitest", "ui test", "ui tests", "xctestplan")),
        ("run", (" run", "launch", "open simulator", "simulator", "device", "preview")),
        ("build", ("build", "compile", "archive", "release build", "debug build", "artifact")),
        ("package-toolchain-management", ("toolchain", "xcode-select", "swift version", "xcrun", "metal toolchain", "sdk", "package resolve", "dependency update")),
        ("read-search-diagnostics", ("diagnostic", "diagnostics", "error", "warning", "issue", "issues", "grep", "search", "find", "read", "navigator")),
        ("workspace-inspection", ("workspace", "scheme list", "inspect project", "inspect workspace", "session")),
        ("mutation", ("edit", "change", "modify", "rewrite", "refactor", "rename", "move file", "add file", "target membership", "pbxproj")),
    ]

    padded = f" {text} "
    for operation_type, needles in checks:
        if any(needle in padded for needle in needles):
            return operation_type
    return None


def load_effective_config() -> dict:
    return customization_config.merge_configs(
        customization_config.load_template(),
        customization_config.load_durable(),
    )


def detect_managed_scope(workspace_path: str | None) -> dict:
    if not workspace_path:
        return {"managed": False, "path": None, "markers": [], "reason": "workspace-path-missing"}

    script_path = Path(__file__).with_name("detect_xcode_managed_scope.sh")
    proc = subprocess.run(
        [str(script_path), workspace_path],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        payload = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError:
        payload = {
            "managed": False,
            "path": workspace_path,
            "markers": [],
            "reason": "scope-detection-json-error",
        }
    if proc.returncode != 0 and "reason" not in payload:
        payload["reason"] = "scope-detection-failed"
    return payload


def recommended_skill(operation_type: str) -> str:
    if operation_type == "test":
        return "xcode-testing-workflow"
    return "xcode-build-run-workflow"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operation-type", choices=sorted(VALID_OPERATION_TYPES))
    parser.add_argument("--request")
    parser.add_argument("--workspace-path")
    parser.add_argument("--tab-identifier")
    parser.add_argument("--mcp-failure-reason")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--direct-pbxproj-edit", action="store_true")
    parser.add_argument("--direct-pbxproj-edit-opt-in", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    load_effective_config()
    inferred_operation_type = infer_operation_type_from_request(args.request)
    operation_type = args.operation_type or inferred_operation_type

    if operation_type is None:
        payload = {
            "status": "blocked",
            "path_type": "primary",
            "output": {
                "operation_type": None,
                "operation_type_source": "missing",
                "workspace_path": args.workspace_path,
                "tab_identifier": args.tab_identifier,
                "mcp_failure_reason": args.mcp_failure_reason,
                "guard_result": {
                    "applied": False,
                    "managed_scope": False,
                    "reason": "not-applicable",
                },
                "fallback_commands": [],
                "recommended_skill": None,
                "next_step": "Pass --operation-type explicitly or provide --request text that makes the intended Xcode workflow obvious.",
            },
        }
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 1

    guard_result = {
        "applied": False,
        "managed_scope": False,
        "direct_edits_allowed": True,
        "direct_pbxproj_edit_warning_required": False,
        "reason": "not-applicable",
    }
    status = "handoff"
    recommended = recommended_skill(operation_type)
    next_step = f"Use {recommended} because the Xcode execution surface is now split by build-run versus testing."

    if operation_type == "mutation":
        scope = detect_managed_scope(args.workspace_path)
        markers = scope.get("markers", [])
        has_pbxproj_marker = any(str(marker).endswith(".pbxproj") for marker in markers)
        guard_result = {
            "applied": True,
            "managed_scope": bool(scope.get("managed")),
            "direct_edits_allowed": True,
            "direct_pbxproj_edit_warning_required": False,
            "reason": "ordinary-direct-edits-allowed",
            "markers": markers,
        }
        if args.direct_pbxproj_edit or has_pbxproj_marker:
            guard_result["direct_pbxproj_edit_warning_required"] = True
            guard_result["reason"] = "direct-pbxproj-edit-warning-required"
            if args.direct_pbxproj_edit and not args.direct_pbxproj_edit_opt_in:
                status = "blocked"
                recommended = None
                next_step = "Warn the user about direct .pbxproj edit risks and rerun with --direct-pbxproj-edit-opt-in only if they explicitly approve that path."

    payload = {
        "status": status,
        "path_type": "primary",
        "output": {
            "operation_type": operation_type,
            "operation_type_source": "explicit" if args.operation_type else "inferred",
            "workspace_path": args.workspace_path,
            "tab_identifier": args.tab_identifier,
            "mcp_failure_reason": args.mcp_failure_reason,
            "guard_result": guard_result,
            "fallback_commands": [],
            "recommended_skill": recommended,
            "next_step": next_step,
        },
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if status != "blocked" else 1


if __name__ == "__main__":
    sys.exit(main())
