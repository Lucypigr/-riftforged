# Riftforged Godot V2

This directory is a clean Godot 4.7.2 rebuild of the mobile ARPG prototype.

The old `godot/` prototype remains intact only as a behavioral reference while V2 is validated. V2 does not reuse its font runtime, bitmap/SVG fallback, autoload patches, or monolithic gameplay script.

## First acceptance gate

Before more gameplay systems are ported, the Web/iPhone build must pass these checks:

- Traditional Chinese text is readable in the HUD, buttons, gem panel, and `Label3D` enemy names.
- Text does not flicker or change after loading.
- Portrait orthographic camera, touch joystick, attack button, enemy chase, HP and respawn work.
- Godot headless import, smoke test, and Web export all pass in CI.

## Font path

V2 uses the static `NotoSansCJKtc-Regular.otf` from the Noto CJK project. CI and Pages run `tools/prepare_font.py` before Godot import/export. The generated OTF is intentionally ignored by Git and packaged into Web export via `export_presets.cfg`.

This is intentionally different from the previous variable-TTF workaround.
