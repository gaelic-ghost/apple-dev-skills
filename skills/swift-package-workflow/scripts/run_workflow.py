#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "PyYAML>=6.0.2,<7",
# ]
# ///
"""Runtime workflow policy engine for swift-package-workflow."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path

import customization_config


VALID_OPERATION_TYPES = {
    "package-inspection",
    "read-search",
    "manifest-dependencies",
    "build",
    "test",
    "run",
    "plugin",
    "toolchain-management",
    "mutation",
}


def load_effective_config() -> dict:
    return customization_config.merge_configs(
        customization_config.load_template(),
        customization_config.load_durable(),
    )


def shell_join(parts: list[str]) -> str:
    return " ".join(shlex.quote(part) for part in parts)


def discover_repo_shape(repo_root: str | None) -> dict:
    root = Path(repo_root or ".").expanduser().resolve()
    if not root.exists():
        return {
            "repo_root": str(root),
            "exists": False,
            "has_package": False,
            "xcode_markers": [],
            "mixed_root": False,
            "reason": "repo-root-missing",
        }

    has_package = (root / "Package.swift").exists()
    markers = []
    for suffix in ("*.xcodeproj", "*.xcworkspace", "*.pbxproj"):
        markers.extend(str(path) for path in root.glob(suffix))
    markers = sorted(markers)

    return {
        "repo_root": str(root),
        "exists": True,
        "has_package": has_package,
        "xcode_markers": markers,
        "mixed_root": has_package and bool(markers),
        "reason": "ok" if has_package else "package-swift-missing",
    }


def build_commands(operation_type: str) -> list[str]:
    if operation_type == "package-inspection":
        return ["swift package describe", "swift package dump-package"]
    if operation_type == "read-search":
        return ["swift package describe"]
    if operation_type == "manifest-dependencies":
        return [
            "swift package dump-package",
            "swift package add-dependency <url>",
            "swift package resolve",
            "swift package update",
        ]
    if operation_type == "build":
        return ["swift build"]
    if operation_type == "test":
        return ["swift test"]
    if operation_type == "run":
        return ["swift run <target>"]
    if operation_type == "plugin":
        return ["swift package plugin --list"]
    if operation_type == "toolchain-management":
        return ["swift --version", "swift package --help", "xcrun --find swift"]
    if operation_type == "mutation":
        return [
            "Edit package sources or Package.swift directly when the change stays inside SwiftPM-managed scope.",
            shell_join(["swift", "package", "dump-package"]),
        ]
    return []


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--operation-type", required=True, choices=sorted(VALID_OPERATION_TYPES))
    parser.add_argument("--repo-root")
    parser.add_argument("--mixed-root-opt-in", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    load_effective_config()

    repo_shape = discover_repo_shape(args.repo_root)
    status = "success"
    path_type = "primary"
    next_step = "Proceed with the SwiftPM-first path."

    if not repo_shape["exists"]:
        status = "blocked"
        next_step = "Resolve the repo root before continuing."
    elif not repo_shape["has_package"]:
        status = "blocked"
        next_step = "Use a Swift package repo with Package.swift at the selected root."
    elif repo_shape["mixed_root"] and not args.mixed_root_opt_in:
        status = "handoff"
        next_step = "Use xcode-app-project-workflow because this repo root is mixed and Xcode-managed behavior may matter."

    payload = {
        "status": status,
        "path_type": path_type,
        "output": {
            "operation_type": args.operation_type,
            "repo_shape": repo_shape,
            "planned_commands": build_commands(args.operation_type),
            "next_step": next_step,
        },
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if status != "blocked" else 1


if __name__ == "__main__":
    sys.exit(main())
