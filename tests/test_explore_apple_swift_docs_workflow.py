from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills/explore-apple-swift-docs/scripts/run_workflow.py"


def write_config(tmpdir: str, skill: str, settings: dict) -> None:
    target = Path(tmpdir) / skill / "customization.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = ["schemaVersion: 1", "isCustomized: true", "settings:"]
    for key, value in settings.items():
        if isinstance(value, bool):
            raw = "true" if value else "false"
        elif isinstance(value, int):
            raw = str(value)
        else:
            raw = f'"{value}"'
        lines.append(f"  {key}: {raw}")
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


class ExploreAppleSwiftDocsWorkflowTests(unittest.TestCase):
    def run_script(self, *args: str, env: dict | None = None) -> tuple[int, dict]:
        command_env = dict(env or os.environ)
        command_env.setdefault("UV_CACHE_DIR", str(Path(tempfile.gettempdir()) / "apple-dev-skills-uv-cache"))
        proc = subprocess.run(
            [str(SCRIPT), *args],
            cwd="/tmp",
            env=command_env,
            capture_output=True,
            text=True,
            check=False,
        )
        return proc.returncode, json.loads(proc.stdout)

    def test_explore_uses_xcode_mcp_by_default(self) -> None:
        code, payload = self.run_script("--mode", "explore", "--query", "SwiftUI", "--dry-run")
        self.assertEqual(code, 0)
        self.assertEqual(payload["source_used"], "xcode-mcp-docs")
        self.assertEqual(payload["path_type"], "primary")

    def test_explore_obeys_preferred_source_override(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            status_file = Path(tmpdir) / "dash-status.json"
            status_file.write_text('{"health_ok": true, "schema_ok": true}\n', encoding="utf-8")
            code, payload = self.run_script(
                "--mode",
                "explore",
                "--query",
                "Swift",
                "--preferred-source",
                "dash",
                "--status-file",
                str(status_file),
                "--dry-run",
            )
            self.assertEqual(code, 0)
            self.assertEqual(payload["source_used"], "dash")

    def test_explore_falls_back_to_official_web_when_xcode_and_dash_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            write_config(tmpdir, "explore-apple-swift-docs", {"defaultSourceOrder": "xcode-mcp-docs,dash,official-web"})
            code, payload = self.run_script(
                "--mode",
                "explore",
                "--query",
                "Foundation",
                "--mcp-failure-reason",
                "session-missing",
                "--status-file",
                str(Path(tmpdir) / "missing-status.json"),
                "--dry-run",
                env=env,
            )
            self.assertEqual(code, 0)
            self.assertEqual(payload["source_used"], "official-web")
            self.assertEqual(payload["path_type"], "fallback")

    def test_explore_search_snippets_can_be_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(tmpdir, "explore-apple-swift-docs", {"defaultSearchSnippets": False})
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script("--mode", "explore", "--query", "Swift", "--dry-run", env=env)
            self.assertEqual(code, 0)
            self.assertFalse(payload["search_snippets_enabled"])
            self.assertEqual(sorted(payload["matches"][0].keys()), ["name", "slug", "source"])

    def test_dash_install_obeys_source_priority(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(
                tmpdir,
                "explore-apple-swift-docs",
                {"dashInstallSourcePriority": "cheatsheet,built-in,user-contributed"},
            )
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script(
                "--mode",
                "dash-install",
                "--docset-request",
                "Swift",
                "--dry-run",
                env=env,
            )
            self.assertEqual(code, 0)
            self.assertEqual(payload["selected_match"]["source"], "cheatsheet")

    def test_dash_install_requires_explicit_approval(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(tmpdir, "explore-apple-swift-docs", {"requireExplicitApprovalForDashInstallYes": True})
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script("--mode", "dash-install", "--docset-request", "Swift", env=env)
            self.assertEqual(code, 1)
            self.assertEqual(payload["status"], "blocked")

    def test_dash_generate_returns_structured_guidance(self) -> None:
        code, payload = self.run_script("--mode", "dash-generate", "--docset-request", "Swift", "--dry-run")
        self.assertEqual(code, 0)
        self.assertEqual(payload["status"], "success")
        self.assertIn("guidance", payload)
        self.assertEqual(payload["source_path"], "automation-guidance")


if __name__ == "__main__":
    unittest.main()
