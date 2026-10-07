"""makeIcon.py - draws the app icon from our own muscle shapes and writes every size the builds need

what this offers
  python tools/icon/makeIcon.py
    1. reads the male front body from data/muscleShapes/muscleShapes.json (the carved outlines -
       the app itself only ships baked maps since v002)
    2. writes icon.svg (the project icon, a dark rounded square with the upper body in heat colours)
       and icons/androidForeground.svg (the same body on a clear background, sized for Android's
       adaptive-icon safe circle)
    3. runs Godot headless with tools/icon/rasterizeIcons.gd to turn them into the PNGs the
       export presets point at: icons/icon192.png (Android launcher), icons/icon256.png (Windows
       exe), icons/androidForeground432.png + icons/androidBackground432.png (Android adaptive)
  re-run after changing a colour or the crop below; the outputs are committed
"""

import json
import os
import subprocess
import sys
from pathlib import Path

### /// TUNING ///

# which body and view the icon shows
iconBody = "male"
iconView = "front"
# the part of the body drawing that fills the icon (body drawing units: left, top, right, bottom) -
# head to hips, so the muscles stay readable at launcher size
cropBox = [100.0, 86.0, 628.0, 724.0]
# icon canvas size in svg units
canvasSize = 512.0
# corner rounding of the dark square, in svg units
cornerRadius = 112.0
# how much of the canvas the body crop fills (the rest is margin)
bodyFill = 0.86
# same, for the Android adaptive foreground (Android crops it to a circle of ~61% of the canvas)
adaptiveFill = 0.58
# dark square colours, top and bottom of its soft vertical gradient
backTop = "#1d2026"
backBottom = "#0b0c0f"
# colour of the untouched body and of the head / hands / feet
bodyPlain = "#454a55"
bodyCosmetic = "#333740"
# the thin gaps between muscles (drawn as an outline in the background colour)
gapColour = "#101115"
gapWidth = 5.0
# muscles in heat colours (the Infrared ramp, the app's default gradient) - region id -> colour
heatColours = {
    "upperChest": "#ff2214",
    "lowerChest": "#ff4a1a",
    "frontDelt": "#ffe626",
    "sideDelt": "#ffbf22",
    "biceps": "#ffe626",
    "upperAbs": "#26e64d",
    "lowerAbs": "#26e64d",
    "obliques": "#00e0ff",
    "serratus": "#00e0ff",
    "forearms": "#1f40ff",
    "hipFlexors": "#6b1f9e",
    "upperTraps": "#00e0ff",
}
# Godot binary (same default as tests/runGodot.py) - override with the GODOT4 environment variable
defaultGodot = r"C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"

### /// PATHS ///

projectDir = Path(__file__).resolve().parent.parent.parent
iconsDir = projectDir / "icons"


def compactNumber(value):
    # rounded to 0.1 drawing units, whole numbers as ints (as the outlines were stored before v002)
    rounded = round(float(value), 1)
    if rounded == int(rounded):
        return int(rounded)
    return rounded


def flatPoints(points):
    # [[x, y], ...] -> [x, y, x, y, ...] rounded
    flat = []
    for point in points:
        flat.append(compactNumber(point[0]))
        flat.append(compactNumber(point[1]))
    return flat


def loadView():
    ### WHAT THIS DOES
    # the icon body and view from the carved shapes, outlines flattened like the drawing code wants

    shapesPath = projectDir / "data" / "muscleShapes" / "muscleShapes.json"
    data = json.loads(shapesPath.read_text(encoding="utf-8"))
    for view in data["views"]:
        if view["gender"] != iconBody or view["view"] != iconView:
            continue
        shapes = []
        for shape in view["shapes"]:
            polygons = []
            for polygon in shape["polygons"]:
                polygons.append(flatPoints(polygon))
            shapes.append({"region": shape["region"], "polygons": polygons})
        cosmetic = []
        for part in view["cosmetic"]:
            cosmetic.append({"points": flatPoints(part["points"])})
        return {"shapes": shapes, "cosmetic": cosmetic}
    raise SystemExit("no %s %s view in %s" % (iconBody, iconView, shapesPath))


def pointsText(flat, scale, offsetX, offsetY):
    # "x,y x,y ..." from a flat [x, y, x, y, ...] list, moved into icon space
    pairs = []
    for index in range(0, len(flat) - 1, 2):
        x = (flat[index] - cropBox[0]) * scale + offsetX
        y = (flat[index + 1] - cropBox[1]) * scale + offsetY
        pairs.append("%.1f,%.1f" % (x, y))
    return " ".join(pairs)


def bodyGroup(view, fill):
    ### WHAT THIS DOES
    # the body as svg polygons, scaled so the crop box fills `fill` of the canvas, centred

    cropWidth = cropBox[2] - cropBox[0]
    cropHeight = cropBox[3] - cropBox[1]
    scale = canvasSize * fill / max(cropWidth, cropHeight)
    offsetX = (canvasSize - cropWidth * scale) * 0.5
    offsetY = (canvasSize - cropHeight * scale) * 0.5
    lines = []

    # a clip so the cut-off thighs end in a straight edge inside the crop
    clipLeft = offsetX
    clipTop = offsetY
    lines.append('<clipPath id="crop"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f"/></clipPath>' % (clipLeft, clipTop, cropWidth * scale, cropHeight * scale))
    lines.append('<g clip-path="url(#crop)" stroke="%s" stroke-width="%.1f" stroke-linejoin="round">' % (gapColour, gapWidth))

    # head, hands, feet first, then the muscles on top
    for part in view["cosmetic"]:
        lines.append('<polygon points="%s" fill="%s"/>' % (pointsText(part["points"], scale, offsetX, offsetY), bodyCosmetic))
    for shape in view["shapes"]:
        colour = heatColours.get(shape["region"], bodyPlain)
        for polygon in shape["polygons"]:
            lines.append('<polygon points="%s" fill="%s"/>' % (pointsText(polygon, scale, offsetX, offsetY), colour))
    lines.append("</g>")
    return "\n".join(lines)


def svgDocument(inner):
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (canvasSize, canvasSize, canvasSize, canvasSize)
    return head + "\n" + inner + "\n</svg>\n"


def squareBackground():
    # the dark rounded square with its soft gradient
    gradient = '<defs><linearGradient id="back" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % (backTop, backBottom)
    square = '<rect x="0" y="0" width="%d" height="%d" rx="%.1f" fill="url(#back)"/>' % (canvasSize, canvasSize, cornerRadius)
    return gradient + "\n" + square


def writeText(path, text):
    # lf line endings, utf-8, no bom
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("wrote %s (%d bytes)" % (path.relative_to(projectDir).as_posix(), path.stat().st_size))


def main():
    ### WHAT THIS DOES
    # svgs from the shapes, then pngs through Godot

    view = loadView()
    iconsDir.mkdir(exist_ok=True)

    # the svgs
    writeText(projectDir / "icon.svg", svgDocument(squareBackground() + "\n" + bodyGroup(view, bodyFill)))
    writeText(iconsDir / "androidForeground.svg", svgDocument(bodyGroup(view, adaptiveFill)))

    # the pngs
    godot = os.environ.get("GODOT4", defaultGodot)
    if not Path(godot).exists():
        print("Godot not found at %s - set GODOT4" % godot)
        return 2
    command = [godot, "--headless", "--path", str(projectDir), "--script", "res://tools/icon/rasterizeIcons.gd", "--", backBottom]
    result = subprocess.run(command, cwd=str(projectDir), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=300)
    print(result.stdout.strip())
    if result.returncode != 0 or "ICONS DONE" not in result.stdout:
        print("rasterize FAILED (exit %d)" % result.returncode)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
