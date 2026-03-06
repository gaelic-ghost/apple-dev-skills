from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills/apple-dash-docsets/scripts/run_workflow.py"


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


class DashWorkflowTests(unittest.TestCase):
    def run_script(self, *args: str, env: dict | None = None) -> tuple[int, dict]:
        proc = subprocess.run(
            ["python3", str(SCRIPT), *args],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        return proc.returncode, json.loads(proc.stdout)

    def test_search_obeys_fallback_order(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(tmpdir, "apple-dash-docsets", {"fallbackOrder": "url-service,http,mcp"})
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script("--stage", "search", "--query", "Swift", "--dry-run", env=env)
            self.assertEqual(code, 0)
            self.assertEqual(payload["access_path"], "url-service")

    def test_search_snippets_can_be_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(tmpdir, "apple-dash-docsets", {"defaultSearchSnippets": False})
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script("--stage", "search", "--query", "Swift", "--dry-run", env=env)
            self.assertEqual(code, 0)
            self.assertFalse(payload["search_snippets_enabled"])
            self.assertEqual(sorted(payload["matches"][0].keys()), ["name", "slug", "source"])

    def test_search_falls_back_when_http_probe_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(tmpdir, "apple-dash-docsets", {"fallbackOrder": "http,url-service"})
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script(
                "--stage",
                "search",
                "--query",
                "Swift",
                "--dry-run",
                "--status-file",
                str(Path(tmpdir) / "missing-status.json"),
                env=env,
            )
            self.assertEqual(code, 0)
            self.assertEqual(payload["access_path"], "url-service")
            self.assertEqual(payload["path_type"], "fallback")

    def test_troubleshooting_preference_changes_blocked_guidance(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(
                tmpdir,
                "apple-dash-docsets",
                {
                    "fallbackOrder": "http",
                    "troubleshootingPreference": "url-service-first",
                },
            )
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script(
                "--stage",
                "search",
                "--query",
                "Swift",
                "--dry-run",
                "--status-file",
                str(Path(tmpdir) / "missing-status.json"),
                env=env,
            )
            self.assertEqual(code, 1)
            self.assertEqual(payload["status"], "blocked")
            self.assertEqual(payload["troubleshooting_preference"], "url-service-first")
            self.assertIn("URL or Service integration first", payload["next_step"])

    def test_install_obeys_source_priority(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(
                tmpdir,
                "apple-dash-docsets",
                {"installSourcePriority": "cheatsheet,built-in,user-contributed"},
            )
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script(
                "--stage",
                "install",
                "--docset-request",
                "Swift",
                "--dry-run",
                env=env,
            )
            self.assertEqual(code, 0)
            self.assertEqual(payload["selected_match"]["source"], "cheatsheet")

    def test_install_requires_explicit_approval(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            write_config(tmpdir, "apple-dash-docsets", {"requireExplicitApprovalForYes": True})
            env = dict(os.environ)
            env["APPLE_DEV_SKILLS_CONFIG_HOME"] = tmpdir
            code, payload = self.run_script("--stage", "install", "--docset-request", "Swift", env=env)
            self.assertEqual(code, 1)
            self.assertEqual(payload["status"], "blocked")

    def test_generate_returns_structured_guidance(self) -> None:
        code, payload = self.run_script("--stage", "generate", "--docset-request", "Swift", "--dry-run")
        self.assertEqual(code, 0)
        self.assertEqual(payload["status"], "success")
        self.assertIn("guidance", payload)
        self.assertEqual(payload["source_path"], "automation-guidance")


if __name__ == "__main__":
    unittest.main()
