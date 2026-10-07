### /// VERIFY CARVED SHAPES ///
# compares muscleShapes.json against the source - area kept per view and per carved muscle -
# which regions exist in which view - and that every region shape has both sides where expected

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extractShapes import outDir, polygonArea   # noqa: E402
from carve import cosmeticSlugs, droppedSlugs   # noqa: E402

### /// TUNING ///
maxAreaLossPercent = 4.0   # more area lost than this in a view means a cut went wrong - seams alone cost 1.5 to 3


def main():
    ### AREA BOOKKEEPING AND COVERAGE

    source = json.loads((outDir / "sourceShapes.json").read_text(encoding="utf-8"))
    carved = json.loads((outDir / "muscleShapes.json").read_text(encoding="utf-8"))
    failed = False
    coverage = {}

    for sourceView, carvedView in zip(source["views"], carved["views"]):
        label = carvedView["gender"] + " " + carvedView["view"]

        # muscle area in the source - cosmetic parts and the stamped blobs do not count
        sourceArea = 0.0
        for part in sourceView["parts"]:
            if part["slug"] in cosmeticSlugs or part["slug"] in droppedSlugs:
                continue
            for polygon in part["polygons"]:
                sourceArea += abs(polygonArea(polygon))

        # muscle area after carving
        carvedArea = 0.0
        sides = {}
        for shape in carvedView["shapes"]:
            for polygon in shape["polygons"]:
                carvedArea += abs(polygonArea(polygon))
            if shape["region"] not in sides:
                sides[shape["region"]] = []
            sides[shape["region"]].append(shape["side"])
            if shape["region"] not in coverage:
                coverage[shape["region"]] = []
            coverage[shape["region"]].append(label)

        lossPercent = 100.0 * (sourceArea - carvedArea) / sourceArea
        print(label, "source", round(sourceArea), "carved", round(carvedArea), "lost", str(round(lossPercent, 2)) + "%")
        if lossPercent < -0.01 or lossPercent > maxAreaLossPercent:
            print("  FAIL area out of range")
            failed = True

        # every region drawn on one side must be drawn on the other too
        for regionId, regionSides in sides.items():
            if "c" in regionSides:
                continue
            if "l" not in regionSides or "r" not in regionSides:
                print("  FAIL", regionId, "only on sides", regionSides)
                failed = True

    print("")
    for region in carved["regions"]:
        views = sorted(set(coverage.get(region["id"], [])))
        print(region["id"].ljust(12), ", ".join(sorted(set(v.split(" ")[1] for v in views))).ljust(11), len(views), "of 4 body views")
        if len(views) == 0:
            failed = True
            print("  FAIL region never drawn")

    if failed:
        raise SystemExit(1)
    print("\nall checks passed")


if __name__ == "__main__":
    main()
