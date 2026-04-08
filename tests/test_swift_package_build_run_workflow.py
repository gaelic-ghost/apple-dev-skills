from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills/swift-package-build-run-workflow/scripts/run_workflow.py"


class SwiftPackageBuildRunWorkflowTests(unittest.TestCase):
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

    def test_succeeds_for_plain_package_build(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            Path(tmpdir, "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")
            code, payload = self.run_script("--operation-type", "build", "--repo-root", tmpdir)
            self.assertEqual(code, 0)
            self.assertEqual(payload["status"], "success")
            self.assertEqual(payload["output"]["planned_commands"], ["swift build"])

    def test_handoffs_test_requests_to_testing_skill(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            Path(tmpdir, "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")
            code, payload = self.run_script("--request", "run the package tests", "--repo-root", tmpdir)
            self.assertEqual(code, 0)
            self.assertEqual(payload["status"], "handoff")
            self.assertIn("swift-package-testing-workflow", payload["output"]["next_step"])

    def test_handoffs_mixed_root_without_opt_in(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            Path(tmpdir, "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")
            Path(tmpdir, "Demo.xcodeproj").mkdir()
            code, payload = self.run_script("--operation-type", "build", "--repo-root", tmpdir)
            self.assertEqual(code, 0)
            self.assertEqual(payload["status"], "handoff")
            self.assertIn("xcode-build-run-workflow", payload["output"]["next_step"])

    def test_blocks_when_no_operation_or_request_is_provided(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            Path(tmpdir, "Package.swift").write_text("// swift-tools-version: 6.0\n", encoding="utf-8")
            code, payload = self.run_script("--repo-root", tmpdir)
            self.assertEqual(code, 1)
            self.assertEqual(payload["status"], "blocked")


if __name__ == "__main__":
    unittest.main()
