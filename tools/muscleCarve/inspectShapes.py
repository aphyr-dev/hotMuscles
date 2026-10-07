### /// INSPECT SOURCE SHAPES ///
# writes a zoomed labelled svg of one view so individual pieces can be identified
# usage: inspectShapes.py gender view x y w h [slugsToHide comma separated]

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extractShapes import outDir, polygonArea, polygonCentroid, slugColour   # noqa: E402

### /// TUNING ///
labelScale = 0.022     # label size as a fraction of the crop width


def main():
    # crop one view and label every piece with slug side and index

    gender = sys.argv[1]
    view = sys.argv[2]
    x, y, w, h = (float(v) for v in sys.argv[3:7])
    hidden = set()
    if len(sys.argv) > 7:
        hidden = set(sys.argv[7].split(","))
    data = json.loads((outDir / "sourceShapes.json").read_text(encoding="utf-8"))
    fontPx = w * labelScale

    for entry in data["views"]:
        if entry["gender"] != gender or entry["view"] != view:
            continue
        lines = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + " ".join(str(v) for v in [x, y, w, h]) + '">']
        lines.append('<rect x="' + str(x) + '" y="' + str(y) + '" width="' + str(w) + '" height="' + str(h) + '" fill="#15171c"/>')
        for part in entry["parts"]:
            if part["slug"] in hidden:
                continue
            # a slug listed with a ! prefix gets one colour per piece so its pieces can be told apart
            fill = slugColour(part["slug"])
            if ("!" + part["slug"]) in hidden:
                fill = "hsl(" + str((part["index"] * 97 + 20) % 360) + ", 80%, 55%)"
            lines.append('<path d="' + part["d"] + '" fill="' + fill + '" fill-opacity="0.8" stroke="#fff" stroke-width="' + str(w / 600) + '"/>')
        for part in entry["parts"]:
            if part["slug"] in hidden:
                continue
            for polygon in part["polygons"]:
                if abs(polygonArea(polygon)) < 40:
                    continue
                cx, cy = polygonCentroid(polygon)
                label = part["slug"] + " " + part["side"][0] + str(part["index"])
                lines.append('<text x="' + str(round(cx, 1)) + '" y="' + str(round(cy, 1)) + '" font-size="' + str(round(fontPx, 2)) + '" font-family="Consolas, monospace" fill="#fff" stroke="#000" stroke-width="' + str(round(fontPx * 0.25, 2)) + '" paint-order="stroke" text-anchor="middle">' + label + '</text>')
        lines.append("</svg>")
        outFile = outDir / "preview" / ("inspect_" + gender + "_" + view + ".svg")
        outFile.write_text("\n".join(lines), encoding="utf-8", newline="\n")
        print("wrote", outFile)


if __name__ == "__main__":
    main()
