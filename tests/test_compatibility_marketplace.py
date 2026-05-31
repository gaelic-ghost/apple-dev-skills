from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_standalone_marketplace_points_to_socket_payload() -> None:
    marketplace = json.loads((ROOT / ".agents/plugins/marketplace.json").read_text(encoding="utf-8"))
    plugin = marketplace["plugins"][0]

    assert marketplace["name"] == "apple-dev-skills"
    assert plugin["name"] == "apple-dev-skills"
    assert plugin["source"] == {
        "source": "git-subdir",
        "url": "https://github.com/gaelic-ghost/socket.git",
        "path": "./plugins/apple-dev-skills",
        "ref": "main",
    }
    assert plugin["policy"]["installation"] == "AVAILABLE"
