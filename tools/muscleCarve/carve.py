########################################################################
### /// CARVE MUSCLEMAP INTO OUR REGIONS ///
########################################################################
# reads data/muscleShapes/sourceShapes.json (made by extractShapes.py) - decides which region
# every source piece belongs to - cuts the pieces that hold more than one region - writes
# data/muscleShapes/muscleShapes.json plus a labelled preview png
#
# cut zones are drawn in each piece's own box: u runs 0 at the outer (lateral) edge to 1 at
# the inner (medial) edge - v runs 0 at the top to 1 at the bottom - so one zone fits the
# left and the right side and both bodies - zones may poke outside 0..1 so they cover the edge
# zones are applied in order - each takes what is still left inside it - the rest goes to the
# rule's remainder region

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extractShapes import outDir, polygonArea, polygonCentroid   # noqa: E402
from renderPreview import render   # noqa: E402

### /// TUNING ///
godotExe = r"C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
projectRoot = Path(__file__).resolve().parents[2]
minPieceArea = 4.0         # cut slivers smaller than this (square units) are thrown away
fuseRadius = 4.0           # gaps up to twice this wide close when pieces are fused into one shape
cutGap = 5.0              # width of the dark seam opened along every cut - matches musclemap's own gaps
labelFontPx = 8.5          # preview label size in body units
closeupLabelScale = 0.028  # close-up label size as a fraction of the crop width

# every region - id - display name - preview colour (unique within a view)
regions = [
    ["neck", "Neck", "#469990"],
    ["upperTraps", "Upper traps", "#e6194b"],
    ["midTraps", "Mid traps", "#f58231"],
    ["lowerTraps", "Lower traps", "#ffe119"],
    ["rhomboids", "Rhomboids", "#bfef45"],
    ["frontDelt", "Front delt", "#42d4f4"],
    ["sideDelt", "Side delt", "#f032e6"],
    ["rearDelt", "Rear delt", "#4363d8"],
    ["rotatorCuff", "Rotator cuff", "#3cb44b"],
    ["lats", "Lats", "#911eb4"],
    ["upperChest", "Upper chest", "#ffe119"],
    ["lowerChest", "Mid/lower chest", "#f58231"],
    ["serratus", "Serratus", "#bfef45"],
    ["biceps", "Biceps", "#3cb44b"],
    ["triceps", "Triceps", "#dcbeff"],
    ["forearms", "Forearms", "#9a6324"],
    ["upperAbs", "Upper abs", "#4363d8"],
    ["lowerAbs", "Lower abs", "#911eb4"],
    ["obliques", "Obliques", "#808000"],
    ["lowerBack", "Lower back", "#42d4f4"],
    ["hipFlexors", "Hip flexors", "#fabed4"],
    ["glutes", "Glutes", "#fabed4"],
    ["gluteMed", "Glute med", "#ffd8b1"],
    ["outerQuad", "Outer quad", "#ff6f61"],
    ["midQuad", "Mid quad", "#ffd8b1"],
    ["innerQuad", "Inner quad", "#aaffc3"],
    ["adductors", "Adductors", "#fffac8"],
    ["hamstrings", "Hamstrings", "#aaffc3"],
    ["calves", "Calves", "#c77dff"],
    ["tibialis", "Tibialis", "#ffb000"],
]

# body parts that are drawn but never trained - shown plain
cosmeticSlugs = ["head", "hair", "hands", "feet", "ankles", "knees"]

# musclemap's front "sub-groups" are blobs stamped on top of the real muscle - not real
# splits - our carved regions replace them so they are dropped
droppedSlugs = ["frontDeltoid", "upperChest", "lowerChest", "upperAbs", "lowerAbs", "innerQuad", "outerQuad", "hipFlexors"]

# source muscles that become exactly one of our regions
directSlugs = {
    "neck": "neck",
    "biceps": "biceps",
    "triceps": "triceps",
    "forearm": "forearms",
    "obliques": "obliques",
    "serratus": "serratus",
    "calves": "calves",
    "tibialis": "tibialis",
    "hamstring": "hamstrings",
}

### /// CUT ZONES (u lateral 0 -> medial 1, v top 0 -> bottom 1) ///
# chest - upper chest is everything above a line rising toward the shoulder
chestUpperZone = [[-0.3, -0.3], [1.3, -0.3], [1.3, 0.42], [0.5, 0.36], [-0.3, 0.26]]

# front deltoid (one piece bodies only) - the outer strip is the side delt
frontSideDeltZone = [[-0.3, -0.3], [0.44, -0.3], [0.40, 0.5], [0.30, 1.3], [-0.3, 1.3]]

# back deltoid - the outer strip is the side delt - the rest is rear delt
backSideDeltZone = [[-0.3, -0.3], [0.36, -0.3], [0.32, 0.5], [0.22, 1.3], [-0.3, 1.3]]

# big quad piece - the outer strip along the thigh is the outer quad - the rest is mid quad
quadOuterZone = [[-0.3, -0.3], [0.30, -0.3], [0.30, 0.0], [0.60, 1.0], [0.60, 1.3], [-0.3, 1.3]]

# back trapezius - upper band - then the lower tip - then the rhomboid strip by the spine
trapUpperZone = [[-0.3, -0.3], [1.3, -0.3], [1.3, 0.13], [0.5, 0.21], [-0.3, 0.34]]
trapLowerZone = [[-0.3, 0.44], [1.3, 0.62], [1.3, 1.3], [-0.3, 1.3]]
trapRhomboidZone = [[0.62, 0.10], [1.3, 0.10], [1.3, 0.60], [0.80, 0.57], [0.56, 0.26]]


### /// PIECE HELPERS ///
def makePiece(part, polygon, viewCentreX):
    ### ONE SOURCE POLYGON WITH THE NUMBERS THE RULES NEED

    xs = [p[0] for p in polygon]
    ys = [p[1] for p in polygon]
    cx, cy = polygonCentroid(polygon)

    # which way is lateral - pieces left of the body centre open to the left
    lateralIsLeft = True
    if cx > viewCentreX:
        lateralIsLeft = False

    return {
        "slug": part["slug"],
        "sourceSide": part["side"],
        "sourceIndex": part["index"],
        "points": polygon,
        "area": abs(polygonArea(polygon)),
        "cx": cx,
        "cy": cy,
        "minX": min(xs),
        "maxX": max(xs),
        "minY": min(ys),
        "maxY": max(ys),
        "lateralIsLeft": lateralIsLeft,
        "medialness": abs(cx - viewCentreX),
    }


def zoneToBody(zone, piece):
    # normalised zone points to body units inside this piece's box
    width = piece["maxX"] - piece["minX"]
    height = piece["maxY"] - piece["minY"]
    points = []
    for u, v in zone:
        y = piece["minY"] + v * height
        if piece["lateralIsLeft"]:
            x = piece["minX"] + u * width
        else:
            x = piece["maxX"] - u * width
        points.append([round(x, 2), round(y, 2)])
    return points


### /// RULES ///
def assignView(view, pieces):
    ### DECIDE EVERY PIECE OF ONE VIEW - RETURNS (plain assignments, cut jobs, cosmetic)

    assigned = []      # [regionId, piece]
    cuts = []          # {"piece", "zones": [[regionId, zone], ...], "remainder": regionId}
    cosmetic = []
    groups = {}

    # sort into groups of one muscle on one side of the body
    for piece in pieces:
        side = "l"
        if not piece["lateralIsLeft"]:
            side = "r"
        if piece["sourceSide"] == "common":
            side = "c"
        key = (piece["slug"], side)
        if key not in groups:
            groups[key] = []
        groups[key].append(piece)

    for (slug, side), group in groups.items():
        # plain parts first
        if slug in cosmeticSlugs:
            cosmetic.extend(group)
            continue
        if slug in droppedSlugs:
            continue
        if slug in directSlugs:
            for piece in group:
                assigned.append([directSlugs[slug], piece])
            continue

        largestFirst = sorted(group, key=lambda p: -p["area"])

        # front view muscles
        if view == "front" and slug == "chest":
            for piece in group:
                cuts.append({"piece": piece, "zones": [["upperChest", chestUpperZone]], "remainder": "lowerChest"})
        elif view == "front" and slug == "deltoids":
            if len(group) == 1:
                cuts.append({"piece": group[0], "zones": [["sideDelt", frontSideDeltZone]], "remainder": "frontDelt"})
            else:
                # bodies drawn with two deltoid pieces - the outer one is the side delt
                byMedial = sorted(group, key=lambda p: p["medialness"])
                for piece in byMedial[:-1]:
                    assigned.append(["frontDelt", piece])
                assigned.append(["sideDelt", byMedial[-1]])
        elif view == "front" and slug == "trapezius":
            for piece in group:
                assigned.append(["upperTraps", piece])
        elif view == "front" and slug == "abs":
            # the lowest box is the lower abs - the boxes above are upper abs
            byHeight = sorted(group, key=lambda p: p["cy"])
            for piece in byHeight[:-1]:
                assigned.append(["upperAbs", piece])
            assigned.append(["lowerAbs", byHeight[-1]])
        elif view == "front" and slug == "adductors":
            # the tallest strip runs from the hip to the inner knee - that is the sartorius - a hip flexor
            byTall = sorted(group, key=lambda p: -(p["maxY"] - p["minY"]))
            assigned.append(["hipFlexors", byTall[0]])
            for piece in byTall[1:]:
                assigned.append(["adductors", piece])
        elif view == "front" and slug == "quadriceps":
            # biggest piece is rectus femoris merged with vastus lateralis - cut it
            cuts.append({"piece": largestFirst[0], "zones": [["outerQuad", quadOuterZone]], "remainder": "midQuad"})
            others = sorted(largestFirst[1:], key=lambda p: p["medialness"])
            for piece in others[:-1]:
                assigned.append(["innerQuad", piece])
            if len(others) > 0:
                assigned.append(["outerQuad", others[-1]])

        # back view muscles
        elif view == "back" and slug == "trapezius":
            for piece in group:
                zones = [["upperTraps", trapUpperZone], ["lowerTraps", trapLowerZone], ["rhomboids", trapRhomboidZone]]
                cuts.append({"piece": piece, "zones": zones, "remainder": "midTraps"})
        elif view == "back" and slug == "deltoids":
            for piece in group:
                cuts.append({"piece": piece, "zones": [["sideDelt", backSideDeltZone]], "remainder": "rearDelt"})
        elif view == "back" and slug == "upperBack":
            # biggest is the lat - the rest sit on the shoulder blade - the female drawing has one
            # shoulder blade piece - the male one is split in two (infraspinatus plus a teres half
            # moon) - so the male pieces are fused into one shape to match her
            assigned.append(["lats", largestFirst[0]])
            rest = largestFirst[1:]
            if len(rest) == 1:
                assigned.append(["rotatorCuff", rest[0]])
            if len(rest) > 1:
                cuts.append({"kind": "fuse", "piece": rest[0], "pieces": rest, "region": "rotatorCuff"})
        elif view == "back" and slug == "lowerBack":
            # the big inner piece is the spinal erectors - the small outer one is the oblique seen from behind
            assigned.append(["lowerBack", largestFirst[0]])
            for piece in largestFirst[1:]:
                assigned.append(["obliques", piece])
        elif view == "back" and slug == "gluteal":
            assigned.append(["glutes", largestFirst[0]])
            for piece in largestFirst[1:]:
                assigned.append(["gluteMed", piece])
        elif view == "back" and slug == "adductors":
            for piece in group:
                assigned.append(["adductors", piece])
        else:
            # fail loudly - a source piece nobody decided about must not vanish quietly
            raise SystemExit("no rule for " + view + " " + slug + " " + side)

    return assigned, cuts, cosmetic


### /// GODOT CUTTING ///
def runCuts(allCuts):
    ### SEND EVERY CUT TO GODOT AND READ THE PIECES BACK

    jobsFile = outDir / "cutJobs.json"
    resultsFile = outDir / "cutResults.json"
    jobs = []

    for index, cut in enumerate(allCuts):
        if cut.get("kind") == "fuse":
            subjects = [piece["points"] for piece in cut["pieces"]]
            jobs.append({"id": str(index), "kind": "fuse", "subjects": subjects, "radius": fuseRadius})
            continue
        zones = [zoneToBody(zone, cut["piece"]) for regionId, zone in cut["zones"]]
        jobs.append({"id": str(index), "kind": "cut", "subject": cut["piece"]["points"], "zones": zones, "gap": cutGap})
    jobsFile.write_text(json.dumps({"jobs": jobs}), encoding="utf-8", newline="\n")
    if resultsFile.exists():
        resultsFile.unlink()

    # the real engine exe so the run is waited on - headless means no window and no audio
    logFile = outDir / "cutLog.txt"
    with open(logFile, "w", encoding="utf-8") as log:
        result = subprocess.run([
            godotExe, "--headless", "--path", str(projectRoot),
            "--script", "res://tools/muscleCarve/polygonCut.gd", "--",
            str(jobsFile), str(resultsFile),
        ], stdout=log, stderr=subprocess.STDOUT, text=True, timeout=300)
    logText = logFile.read_text(encoding="utf-8")
    if result.returncode != 0 or not resultsFile.exists() or "SCRIPT ERROR" in logText:
        raise SystemExit("godot cut failed - see " + str(logFile))

    results = json.loads(resultsFile.read_text(encoding="utf-8"))["results"]
    jobsFile.unlink()
    resultsFile.unlink()
    logFile.unlink()
    return results


def checkWinding(pieces, label):
    # every output piece must wind the same way - a flipped one would be a hole
    windings = set(p["clockwise"] for p in pieces)
    if len(windings) > 1:
        raise SystemExit("cut produced a hole in " + label)


### /// PREVIEW ///
def previewSvg(viewBox, shapes, cosmeticPieces, regionLookup, labelSide):
    ### ONE VIEW WITH EVERY REGION IN ITS COLOUR AND NAMED ON ONE SIDE

    vb = viewBox
    lines = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + " ".join(str(v) for v in vb) + '">']
    for piece in cosmeticPieces:
        lines.append('<path d="' + polygonPath(piece["points"]) + '" fill="#2b2e36"/>')
    for shape in shapes:
        colour = regionLookup[shape["region"]][1]
        for polygon in shape["polygons"]:
            lines.append('<path d="' + polygonPath(polygon) + '" fill="' + colour + '" stroke="#101216" stroke-width="1.2"/>')

    # names on the biggest polygon of each region on the chosen side
    for shape in shapes:
        if shape["side"] != labelSide and shape["side"] != "c":
            continue
        biggest = max(shape["polygons"], key=lambda poly: abs(polygonArea(poly)))
        cx, cy = polygonCentroid(biggest)
        name = regionLookup[shape["region"]][0]
        lines.append('<text x="' + str(round(cx, 1)) + '" y="' + str(round(cy + labelFontPx * 0.35, 1)) + '" font-size="' + str(labelFontPx) + '" font-family="Segoe UI, sans-serif" font-weight="600" fill="#fff" stroke="#000" stroke-width="2.4" paint-order="stroke" text-anchor="middle">' + name + '</text>')
    lines.append("</svg>")
    return "\n".join(lines)


def polygonPath(points):
    # polygon points to an svg path string
    parts = ["M" + str(points[0][0]) + " " + str(points[0][1])]
    for x, y in points[1:]:
        parts.append("L" + str(x) + " " + str(y))
    parts.append("Z")
    return "".join(parts)


def cropBox(entry, regionIds, padding):
    # the box around the listed regions in one view - used for close-ups
    xs = []
    ys = []
    for shape in entry["shapes"]:
        if shape["region"] not in regionIds:
            continue
        for polygon in shape["polygons"]:
            for x, y in polygon:
                xs.append(x)
                ys.append(y)
    return [min(xs) - padding, min(ys) - padding, max(xs) - min(xs) + 2 * padding, max(ys) - min(ys) + 2 * padding]


def writePreview(outputViews, regionLookup, fileStem, cropRegions, viewFilter, pageWidth, pageHeight):
    ### HTML PAGE WITH THE CHOSEN VIEWS PLUS A LEGEND PER VIEW - THEN A PNG OF IT

    cards = []
    global labelFontPx
    fullLabelPx = labelFontPx
    for entry in outputViews:
        if viewFilter is not None and entry["view"] != viewFilter:
            continue
        viewBox = entry["viewBox"]
        labelFontPx = fullLabelPx
        if cropRegions is not None:
            viewBox = cropBox(entry, cropRegions, 12)
            labelFontPx = viewBox[2] * closeupLabelScale
        svgText = previewSvg(viewBox, entry["shapes"], entry["cosmeticPieces"], regionLookup, "l")
        used = []
        for shape in entry["shapes"]:
            if shape["region"] not in used:
                used.append(shape["region"])
        legendItems = []
        for regionId, name, colour in regions:
            if regionId in used:
                legendItems.append('<span><i style="background:' + colour + '"></i>' + name + '</span>')
        title = entry["gender"] + " · " + entry["view"]
        cards.append('<div class="card"><h2>' + title + '</h2>' + svgText + '<div class="legend">' + "".join(legendItems) + '</div></div>')

    page = """<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:#0d0e12;color:#e8e8ea;font-family:Segoe UI,sans-serif}
.row{display:flex;gap:18px;padding:18px}
.card{flex:1;background:#15171c;border-radius:14px;padding:12px 12px 16px}
h2{margin:0 0 6px;font-size:18px;text-transform:capitalize;color:#bbb}
svg{width:100%;height:auto;display:block}
.legend{display:flex;flex-wrap:wrap;gap:4px 12px;font-size:13px;margin-top:8px}
.legend span{display:flex;align-items:center;gap:5px}
.legend i{width:12px;height:12px;border-radius:3px;display:inline-block}
</style></head><body><div class="row">""" + "".join(cards) + "</div></body></html>"
    labelFontPx = fullLabelPx
    previewFile = outDir / "preview" / (fileStem + ".html")
    previewFile.write_text(page, encoding="utf-8", newline="\n")
    render(str(previewFile), pageWidth, pageHeight, "1")


### /// MAIN ///
def main():
    ### CLASSIFY - CUT - ASSEMBLE - WRITE - PREVIEW

    source = json.loads((outDir / "sourceShapes.json").read_text(encoding="utf-8"))
    regionLookup = {}
    for regionId, name, colour in regions:
        regionLookup[regionId] = [name, colour]
    perView = []
    allCuts = []

    # rules per view
    for entry in source["views"]:
        vb = entry["viewBox"]
        centreX = vb[0] + vb[2] / 2.0
        pieces = []
        for part in entry["parts"]:
            for polygon in part["polygons"]:
                pieces.append(makePiece(part, polygon, centreX))
        assigned, cuts, cosmetic = assignView(entry["view"], pieces)
        perView.append({"entry": entry, "assigned": assigned, "cuts": cuts, "cosmetic": cosmetic})
        for cut in cuts:
            cut["viewIndex"] = len(perView) - 1
            allCuts.append(cut)

    results = runCuts(allCuts)

    # gather region polygons per view and side
    outputViews = []
    for viewIndex, item in enumerate(perView):
        bucket = {}

        def addPolygon(regionId, piece, points):
            # one polygon into its region and side bucket
            side = "l"
            if not piece["lateralIsLeft"]:
                side = "r"
            if piece["sourceSide"] == "common":
                side = "c"
            if regionId not in regionLookup:
                raise SystemExit("unknown region " + regionId)
            key = (regionId, side)
            if key not in bucket:
                bucket[key] = []
            bucket[key].append(points)

        for regionId, piece in item["assigned"]:
            addPolygon(regionId, piece, piece["points"])

        for cutIndex, cut in enumerate(allCuts):
            if cut["viewIndex"] != viewIndex:
                continue
            outputs = results[str(cutIndex)]
            if cut.get("kind") == "fuse":
                regionOrder = [cut["region"]]
                if len(outputs[0]) != 1:
                    raise SystemExit("fuse did not give exactly one shape for " + cut["region"])
            else:
                regionOrder = [regionId for regionId, zone in cut["zones"]] + [cut["remainder"]]
            for regionId, pieces in zip(regionOrder, outputs):
                label = item["entry"]["gender"] + " " + item["entry"]["view"] + " " + cut["piece"]["slug"] + " -> " + regionId
                checkWinding(pieces, label)
                for piece in pieces:
                    if abs(polygonArea(piece["points"])) < minPieceArea:
                        continue
                    addPolygon(regionId, cut["piece"], piece["points"])

        # stable order - region list order then side
        shapes = []
        for regionId, name, colour in regions:
            for side in ["l", "r", "c"]:
                if (regionId, side) in bucket:
                    shapes.append({"region": regionId, "side": side, "polygons": bucket[(regionId, side)]})
        cosmeticOut = []
        for piece in item["cosmetic"]:
            cosmeticOut.append({"part": piece["slug"], "points": piece["points"]})
        outputViews.append({
            "gender": item["entry"]["gender"],
            "view": item["entry"]["view"],
            "viewBox": item["entry"]["viewBox"],
            "shapes": shapes,
            "cosmeticPieces": cosmeticOut,
        })
        print(item["entry"]["gender"], item["entry"]["view"], len(shapes), "region shapes", len(item["cuts"]), "pieces cut")

    # the dataset
    dataset = {
        "source": source["source"],
        "generatedBy": "tools/muscleCarve/carve.py",
        "regions": [{"id": r[0], "name": r[1]} for r in regions],
        "views": [],
    }
    for view in outputViews:
        dataset["views"].append({
            "gender": view["gender"],
            "view": view["view"],
            "viewBox": view["viewBox"],
            "shapes": view["shapes"],
            "cosmetic": view["cosmeticPieces"],
        })
    (outDir / "muscleShapes.json").write_text(json.dumps(dataset, separators=(",", ":")), encoding="utf-8", newline="\n")
    print("wrote", outDir / "muscleShapes.json")

    # overview plus close-ups of every carved area
    writePreview(outputViews, regionLookup, "carvedRegions", None, None, 2200, 1400)
    torsoRegions = ["upperTraps", "frontDelt", "sideDelt", "rearDelt", "upperChest", "lowerChest", "lowerAbs", "lowerBack", "lats"]
    writePreview(outputViews, regionLookup, "carvedTorso", torsoRegions, None, 2200, 1100)
    thighRegions = ["outerQuad", "midQuad", "innerQuad", "hipFlexors", "adductors"]
    writePreview(outputViews, regionLookup, "carvedThighs", thighRegions, "front", 1400, 1300)


if __name__ == "__main__":
    main()
