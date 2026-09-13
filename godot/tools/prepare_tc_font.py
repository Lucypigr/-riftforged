from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf"
FONT_NAME = "NotoSansTC-Riftforged.ttf"


def prepare_font(project_root: Path) -> Path:
    output = project_root / "fonts" / FONT_NAME
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and output.stat().st_size > 1_000_000:
        return output

    request = urllib.request.Request(
        FONT_URL,
        headers={"User-Agent": "Riftforged-font-builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        data = response.read()

    if len(data) < 1_000_000:
        raise RuntimeError(f"Downloaded font is unexpectedly small: {len(data)} bytes")
    output.write_bytes(data)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="godot")
    args = parser.parse_args()

    project_root = Path(args.project).resolve()
    output = prepare_font(project_root)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"Prepared {output} ({output.stat().st_size} bytes, sha256={digest})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
