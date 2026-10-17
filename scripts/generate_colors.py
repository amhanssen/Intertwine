#!/usr/bin/env python3
"""Rebuild the color sets in Assets.xcassets from design-tokens.json.

Run from the repo root:  python3 scripts/generate_colors.py
Each token becomes a color set with a light and a dark appearance, named exactly
like the Figma variable's iOS code syntax (for example colorBgCanvas).
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = json.loads((ROOT / "design-tokens.json").read_text())
OUT = ROOT / "Intertwine" / "Assets.xcassets" / "Colors"


def components(hex_value):
    hex_value = hex_value.lstrip("#")
    r, g, b = (int(hex_value[i:i + 2], 16) for i in (0, 2, 4))
    return {"alpha": "1.000", "blue": f"0x{b:02X}", "green": f"0x{g:02X}", "red": f"0x{r:02X}"}


def color_entry(hex_value, dark=False):
    entry = {"color": {"color-space": "srgb", "components": components(hex_value)}, "idiom": "universal"}
    if dark:
        entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
    return entry


if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)
(OUT / "Contents.json").write_text(json.dumps(
    {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}}, indent=2) + "\n")

for name, value in TOKENS["color"].items():
    folder = OUT / f"{name}.colorset"
    folder.mkdir()
    contents = {
        "colors": [color_entry(value["light"]), color_entry(value["dark"], dark=True)],
        "info": {"author": "xcode", "version": 1},
    }
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")

print(f"Wrote {len(TOKENS['color'])} color sets to {OUT.relative_to(ROOT)}")
