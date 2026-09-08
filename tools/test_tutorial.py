#!/usr/bin/env python3
"""Run the real tutorial LocalScript with a deterministic, isolated Roblox mock.

Only temporary test code is generated. Does not contact Roblox or change a place.
Usage: python3 tools/test_tutorial.py --luau /path/to/luau
"""
import argparse
import subprocess
import tempfile
from pathlib import Path


def literal(source):
    equals = "="
    while "]" + equals + "]" in source:
        equals += "="
    return "[" + equals + "[" + source + "]" + equals + "]"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    client_dir = root / "src/StarterPlayer/StarterPlayerScripts"
    sources = [
        client_dir / "TutorialMenuClient_V2.client.lua",
        client_dir / "TutorialPresentation.lua",
        root / "tests/tutorial_client_harness.luau",
    ]
    client, presentation, harness = [literal(p.read_text(encoding="utf-8")) for p in sources]
    driver = f"local P = assert(loadstring({presentation}))()\n"
    driver += f"local test = assert(loadstring({harness}))()\n"
    driver += f"test({client}, P)\n"
    with tempfile.TemporaryDirectory(prefix="retroverse-tutorial-test-") as temp:
        path = Path(temp) / "driver.luau"
        path.write_text(driver, encoding="utf-8")
        subprocess.run([args.luau, str(path)], check=True, cwd=root)


if __name__ == "__main__":
    main()
