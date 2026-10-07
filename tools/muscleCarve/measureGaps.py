### /// MEASURE SOURCE GAPS ///
# prints the narrowest gap between neighbouring source pieces - used to pick cutGap in carve.py

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extractShapes import outDir   # noqa: E402

### /// TUNING ///
pairsToMeasure = [
    ["male", "front", "abs", "l", 2, "abs", "l", 0],
    ["male", "front", "abs", "l", 0, "abs", "l", 1],
    ["male", "front", "abs", "l", 2, "abs", "r", 0],
    ["male", "back", "upperBack", "l", 0, "upperBack", "l", 2],
    ["male", "back", "trapezius", "l", 0, "upperBack", "l", 1],
    ["female", "back", "gluteal", "l", 0, "gluteal", "l", 1],
    ["female", "front", "deltoids", "l", 0, "deltoids", "l", 1],
]


def segmentDistance(p, a, b):
    # distance from point p to segment ab
    abx = b[0] - a[0]
    aby = b[1] - a[1]
    lengthSq = abx * abx + aby * aby
    t = 0.0
    if lengthSq > 0:
        t = max(0.0, min(1.0, ((p[0] - a[0]) * abx + (p[1] - a[1]) * aby) / lengthSq))
    return math.dist(p, (a[0] + t * abx, a[1] + t * aby))


def polygonGap(polyA, polyB):
    # narrowest distance between two polygon outlines
    best = 1e9
    for p in polyA:
        for i in range(len(polyB)):
            best = min(best, segmentDistance(p, polyB[i], polyB[(i + 1) % len(polyB)]))
    return best


def main():
    data = json.loads((outDir / "sourceShapes.json").read_text(encoding="utf-8"))
    sideNames = {"l": "left", "r": "right"}
    for gender, view, slugA, sideA, indexA, slugB, sideB, indexB in pairsToMeasure:
        for entry in data["views"]:
            if entry["gender"] != gender or entry["view"] != view:
                continue
            found = {}
            for part in entry["parts"]:
                if part["slug"] == slugA and part["side"] == sideNames[sideA] and part["index"] == indexA:
                    found["a"] = part["polygons"][0]
                if part["slug"] == slugB and part["side"] == sideNames[sideB] and part["index"] == indexB:
                    found["b"] = part["polygons"][0]
            gap = polygonGap(found["a"], found["b"])
            print(gender, view, slugA + sideA + str(indexA), "<->", slugB + sideB + str(indexB), "gap", round(gap, 2))


if __name__ == "__main__":
    main()
