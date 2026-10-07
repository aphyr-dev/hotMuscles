### /// BEFORE AND AFTER PICTURE ///
# one png per body - musclemap as drawn next to our carved regions - only what changed is coloured

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extractShapes import outDir, polygonArea, polygonCentroid   # noqa: E402
from carve import regions, polygonPath, cosmeticSlugs, droppedSlugs   # noqa: E402
from renderPreview import render   # noqa: E402

### /// TUNING ///
unchangedFill = "#3b3f4a"      # muscles that did not change - same grey before and after
cosmeticFill = "#24262d"       # head hands feet
blobFill = "rgba(255,255,255,0.22)"
cropPadding = 16               # body units around the changed area
labelScale = 0.034             # label size as a fraction of the crop width
labelOnRight = ["rhomboids"]   # regions named on the viewer's right so their label does not sit on a neighbour's
pageHeights = {"male": 1150, "female": 1330}   # screenshot height per body - the female crop is taller

# per view - which musclemap muscles changed (before) and which of our regions came from them (after)
changes = {
    "front": {
        "beforeSlugs": ["trapezius", "deltoids", "chest", "abs", "adductors", "quadriceps"],
        "afterRegions": ["upperTraps", "frontDelt", "sideDelt", "upperChest", "lowerChest", "upperAbs", "lowerAbs", "hipFlexors", "adductors", "outerQuad", "midQuad", "innerQuad"],
        "notes": [
            "chest → upper chest + mid/lower chest (cut)",
            {"male": "deltoids → front delt + side delt (cut)", "female": "deltoids → front delt + side delt (already 2 pieces)"},
            "abs → upper abs (top 3 rows) + lower abs (bottom box)",
            "biggest quad piece → outer quad + mid quad (cut)",
            "long teal strip (sartorius) → hip flexors",
            "dashed blobs → removed, the real cuts replace them",
        ],
    },
    "back": {
        "beforeSlugs": ["trapezius", "deltoids", "upperBack", "gluteal"],
        "afterRegions": ["upperTraps", "midTraps", "lowerTraps", "rhomboids", "rearDelt", "sideDelt", "rotatorCuff", "lats", "glutes", "gluteMed"],
        "notes": [
            "trapezius → upper + mid + lower traps + rhomboids (cut)",
            "deltoids → rear delt + side delt (cut)",
            {"male": "upperBack → lats + rotator cuff (2 shoulder blade pieces fused into 1, to match the female drawing)", "female": "upperBack → lats + rotator cuff"},
            "gluteal → glutes + glute med",
        ],
    },
}

# one colour per musclemap name for the before panels
slugColours = {
    "trapezius": "#e6194b",
    "deltoids": "#f032e6",
    "chest": "#f58231",
    "abs": "#4363d8",
    "adductors": "#fffac8",
    "quadriceps": "#ff6f61",
    "upperBack": "#911eb4",
    "gluteal": "#fabed4",
}


def textTag(x, y, text, size):
    # outlined label
    return '<text x="' + str(round(x, 1)) + '" y="' + str(round(y + size * 0.35, 1)) + '" font-size="' + str(round(size, 2)) + '" font-family="Segoe UI, sans-serif" font-weight="600" fill="#fff" stroke="#000" stroke-width="' + str(round(size * 0.28, 2)) + '" paint-order="stroke" text-anchor="middle">' + text + '</text>'


def cropFor(carvedView, regionIds):
    # box around the changed regions - shared by the before and after panels of one view
    xs = []
    ys = []
    for shape in carvedView["shapes"]:
        if shape["region"] in regionIds:
            for polygon in shape["polygons"]:
                for x, y in polygon:
                    xs.append(x)
                    ys.append(y)
    return [min(xs) - cropPadding, min(ys) - cropPadding, max(xs) - min(xs) + 2 * cropPadding, max(ys) - min(ys) + 2 * cropPadding]


def isLeftOfCentre(polygon, viewBox):
    # labels go on the viewer's left half only
    cx, cy = polygonCentroid(polygon)
    return cx < viewBox[0] + viewBox[2] / 2.0


def beforeSvg(sourceView, crop, change):
    ### MUSCLEMAP AS DRAWN - CHANGED MUSCLES IN COLOUR UNDER THEIR MUSCLEMAP NAMES

    size = crop[2] * labelScale
    lines = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + " ".join(str(round(v, 1)) for v in crop) + '">']
    labels = []
    blobs = []

    for part in sourceView["parts"]:
        slug = part["slug"]
        if slug in droppedSlugs:
            blobs.append(part)
            continue
        fill = unchangedFill
        if slug in cosmeticSlugs:
            fill = cosmeticFill
        if slug in change["beforeSlugs"]:
            fill = slugColours[slug]
        lines.append('<path d="' + part["d"] + '" fill="' + fill + '" stroke="#101216" stroke-width="1"/>')
        if slug in change["beforeSlugs"]:
            for polygon in part["polygons"]:
                if abs(polygonArea(polygon)) > 300 and isLeftOfCentre(polygon, sourceView["viewBox"]):
                    cx, cy = polygonCentroid(polygon)
                    labels.append(textTag(cx, cy, slug, size))

    # the stamped-on sub-group blobs - drawn on top like musclemap does
    for part in blobs:
        lines.append('<path d="' + part["d"] + '" fill="' + blobFill + '" stroke="#fff" stroke-width="1.6" stroke-dasharray="4 3"/>')

    lines.extend(labels)
    lines.append("</svg>")
    return "\n".join(lines)


def afterSvg(carvedView, crop, change, regionLookup):
    ### OUR REGIONS - ONLY THE NEW ONES IN COLOUR

    size = crop[2] * labelScale
    lines = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + " ".join(str(round(v, 1)) for v in crop) + '">']
    labels = []

    for piece in carvedView["cosmetic"]:
        lines.append('<path d="' + polygonPath(piece["points"]) + '" fill="' + cosmeticFill + '"/>')
    for shape in carvedView["shapes"]:
        isNew = shape["region"] in change["afterRegions"]
        fill = unchangedFill
        if isNew:
            fill = regionLookup[shape["region"]][1]
        for polygon in shape["polygons"]:
            lines.append('<path d="' + polygonPath(polygon) + '" fill="' + fill + '" stroke="#101216" stroke-width="1"/>')
        labelSide = "l"
        if shape["region"] in labelOnRight:
            labelSide = "r"
        if isNew and shape["side"] == labelSide:
            biggest = max(shape["polygons"], key=lambda poly: abs(polygonArea(poly)))
            cx, cy = polygonCentroid(biggest)
            labels.append(textTag(cx, cy, regionLookup[shape["region"]][0], size))

    lines.extend(labels)
    lines.append("</svg>")
    return "\n".join(lines)


def main():
    ### ONE PAGE PER BODY

    source = json.loads((outDir / "sourceShapes.json").read_text(encoding="utf-8"))
    carved = json.loads((outDir / "muscleShapes.json").read_text(encoding="utf-8"))
    regionLookup = {}
    for regionId, name, colour in regions:
        regionLookup[regionId] = [name, colour]

    for gender in ["male", "female"]:
        columns = []
        for sourceView, carvedView in zip(source["views"], carved["views"]):
            if carvedView["gender"] != gender:
                continue
            change = changes[carvedView["view"]]
            crop = cropFor(carvedView, change["afterRegions"])
            # a note can differ per body
            noteItems = ""
            for note in change["notes"]:
                text = note
                if isinstance(note, dict):
                    text = note[gender]
                noteItems += "<li>" + text + "</li>"
            columns.append(
                '<div class="pair"><div class="panels">'
                + '<div class="panel"><h2>' + carvedView["view"] + ' · before <span>(MuscleMap)</span></h2>' + beforeSvg(sourceView, crop, change) + '</div>'
                + '<div class="panel"><h2>' + carvedView["view"] + ' · after <span>(ours)</span></h2>' + afterSvg(carvedView, crop, change, regionLookup) + '</div>'
                + '</div><ul>' + noteItems + '</ul></div>'
            )

        page = """<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:#0d0e12;color:#e8e8ea;font-family:Segoe UI,sans-serif}
h1{margin:18px 22px 0;font-size:26px}
h1 span{font-weight:400;color:#9a9ca4;font-size:18px}
.row{display:flex;gap:22px;padding:14px 22px 22px}
.pair{flex:1;background:#15171c;border-radius:14px;padding:12px}
.panels{display:flex;gap:10px}
.panel{flex:1}
h2{margin:0 0 6px;font-size:18px;text-transform:capitalize}
h2 span{font-weight:400;color:#9a9ca4;text-transform:none}
svg{width:100%;height:auto;display:block}
ul{margin:10px 0 0;padding-left:20px;font-size:15px;line-height:1.5;color:#cfd0d4}
</style></head><body><h1>""" + gender.capitalize() + """ body <span>— grey = unchanged, colour = what changed</span></h1><div class="row">""" + "".join(columns) + "</div></body></html>"
        pageFile = outDir / "preview" / ("beforeAfter_" + gender + ".html")
        pageFile.write_text(page, encoding="utf-8", newline="\n")
        render(str(pageFile), 2000, pageHeights[gender], "1")


if __name__ == "__main__":
    main()
