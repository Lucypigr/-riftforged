from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

FONT_URL = "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Regular.otf"
FONT_NAME = "NotoSansCJKtc-Regular.otf"


def prepare_font(project_root: Path) -> Path:
    output = project_root / "fonts" / FONT_NAME
    output.parent.mkdir(parents=True, exist_ok=True)

    if output.exists():
        data = output.read_bytes()
        if len(data) > 10_000_000 and data[:4] == b"OTTO":
            return output
        output.unlink()

    request = urllib.request.Request(
        FONT_URL,
        headers={"User-Agent": "Riftforged-v2-font-builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        data = response.read()

    if len(data) < 10_000_000:
        raise RuntimeError(f"Downloaded font is unexpectedly small: {len(data)} bytes")
    if data[:4] != b"OTTO":
        raise RuntimeError(f"Downloaded file is not an OpenType CFF font: magic={data[:4]!r}")

    output.write_bytes(data)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="godot_v2")
    args = parser.parse_args()

    project_root = Path(args.project).resolve()
    output = prepare_font(project_root)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    print(f"Prepared {output} ({output.stat().st_size} bytes, sha256={digest})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
