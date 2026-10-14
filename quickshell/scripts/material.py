#!/usr/bin/env python3
"""Material You colours from an image (ported from the Ignis MaterialService).

  material.py generate IMAGE [--light]   new palette from IMAGE
  material.py mode dark|light            regenerate from the saved seed colour
  material.py seed USER_OPTIONS_JSON     import an existing Ignis palette

Writes ~/.cache/quickshell/material/colors.json, which the shell's Theme
watches, plus the templates in ./templates (always rendered from the dark
scheme, as Ignis did for its dark_* files) for Hyprland and hyprlock.
Then reloads Hyprland so it picks the new colours up.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell" / "material"
COLORS_JSON = CACHE / "colors.json"
TEMPLATES = Path(__file__).resolve().parent / "templates"


def optimal_size(width: int, height: int, bitmap_size: int = 128) -> tuple[int, int]:
    area, target = width * height, bitmap_size**2
    scale = math.sqrt(target / area) if area > target else 1
    return max(1, round(width * scale)), max(1, round(height * scale))


def image_seed(image_path: str) -> str:
    """The dominant colour of an image, as #rrggbb."""
    from PIL import Image
    from materialyoucolor.quantize import QuantizeCelebi
    from materialyoucolor.score.score import Score

    image = Image.open(image_path).convert("RGBA")
    size = optimal_size(*image.size)
    if size != image.size:
        image = image.resize(size, Image.Resampling.BICUBIC)
    pixels = list(image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata())
    return "#{:06x}".format(Score.score(QuantizeCelebi(pixels, 128))[0] & 0xFFFFFF)


def scheme_colors(seed: str, dark: bool) -> dict[str, str]:
    from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
    from materialyoucolor.hct import Hct
    from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot

    # 2021 spec: what Ignis used, and what the existing palette was built with
    # (materialyoucolor 3 defaults to the darker 2025 spec).
    scheme = SchemeTonalSpot(Hct.from_int(0xFF000000 | int(seed[1:], 16)), dark, 0.0, "2021")

    colors = {}
    for name in vars(MaterialDynamicColors):
        color = getattr(MaterialDynamicColors, name)
        if hasattr(color, "get_hct"):
            colors[name] = "#{:02x}{:02x}{:02x}".format(*color.get_hct(scheme).to_rgba())
    return colors


def render_templates(dark_colors: dict[str, str]) -> None:
    from jinja2 import Template

    for template in TEMPLATES.iterdir():
        text = Template(template.read_text()).render({**dark_colors, "dark_mode": "true"})
        (CACHE / template.name).write_text(text)


def write(source: str, seed: str, dark_mode: bool, colors: dict, dark_colors: dict) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    render_templates(dark_colors)
    tmp = COLORS_JSON.with_suffix(".tmp")
    tmp.write_text(json.dumps({"source": source, "seed": seed, "darkMode": dark_mode, "colors": colors}, indent=2))
    tmp.replace(COLORS_JSON)  # atomic: the shell never reads a half-written file
    # Hyprland's colors.lua reads the new border colour.
    subprocess.run(["hyprctl", "reload"], check=False, capture_output=True)


def generate(source: str, seed: str, dark_mode: bool) -> None:
    dark_colors = scheme_colors(seed, True)
    colors = dark_colors if dark_mode else scheme_colors(seed, False)
    write(source, seed, dark_mode, colors, dark_colors)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("image")
    gen.add_argument("--light", action="store_true")
    mode = sub.add_parser("mode")
    mode.add_argument("mode", choices=["dark", "light"])
    seed = sub.add_parser("seed")
    seed.add_argument("user_options")
    args = parser.parse_args()

    if args.cmd == "generate":
        image = str(Path(args.image).expanduser().resolve())
        generate(image, image_seed(image), not args.light)
    elif args.cmd == "mode":
        saved = json.loads(COLORS_JSON.read_text()) if COLORS_JSON.exists() else {}
        # Palettes imported from Ignis have no seed; their primary key colour stands in.
        seed = saved.get("seed") or saved.get("colors", {}).get("primary_paletteKeyColor")
        if not seed:
            print("material.py: no palette yet; run `generate IMAGE` first", file=sys.stderr)
            return 2
        generate(saved.get("source", ""), seed, args.mode == "dark")
    elif args.cmd == "seed":
        material = json.loads(Path(args.user_options).expanduser().read_text())["material"]
        colors = material["colors"]
        write("", colors.get("primary_paletteKeyColor", ""), bool(material.get("dark_mode", True)), colors, colors)
    return 0


if __name__ == "__main__":
    sys.exit(main())
