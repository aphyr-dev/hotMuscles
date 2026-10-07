### /// EXTRACT MUSCLEMAP SHAPES ///
# reads the svg path strings out of the musclemap swift files - writes them as json
# plus flattened polygons - plus a labelled preview page so every piece can be inspected

import json
import math
import re
from pathlib import Path

### /// TUNING ///
projectRoot = Path(__file__).resolve().parents[2]
sourceDir = projectRoot / "models" / "muscleMap" / "source"
outDir = projectRoot / "data" / "muscleShapes"
curveStepPx = 3.0          # target length of one straight segment when flattening curves
minCurveSegments = 3       # never flatten a curve into fewer pieces than this
labelFontPx = 9            # label size in the inspection preview

# which swift file holds which body and view - plus the viewbox musclemap uses for it
sourceFiles = [
    {"gender": "male", "view": "front", "file": "MaleFrontPaths.swift", "viewBox": [0, 95, 727, 1280]},
    {"gender": "male", "view": "back", "file": "MaleBackPaths.swift", "viewBox": [718, 95, 727, 1280]},
    {"gender": "female", "view": "front", "file": "FemaleFrontPaths.swift", "viewBox": [0, 0, 650, 1450]},
    {"gender": "female", "view": "back", "file": "FemaleBackPaths.swift", "viewBox": [823, 0, 650, 1450]},
]


### /// SWIFT PARSING ///
def readSwiftParts(text):
    ### SPLIT A PATHS FILE INTO BODY PARTS

    parts = []
    blocks = re.split(r"BodyPartPathData\(", text)[1:]

    # each block holds one slug and up to three lists of path strings
    for block in blocks:
        slug = re.search(r"slug:\s*\.(\w+)", block).group(1)
        for sideName in ["common", "left", "right"]:
            listMatch = re.search(sideName + r":\s*\[(.*?)\]", block, re.S)
            if listMatch is None:
                continue
            strings = re.findall(r'"([^"]*)"', listMatch.group(1))
            for index, d in enumerate(strings):
                parts.append({"slug": slug, "side": sideName, "index": index, "d": d})
    return parts


### /// SVG PATH PARSER ///
commandLetters = "MmLlHhVvCcSsQqTtAaZz"
numberPattern = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


class PathReader:
    # walks a path string one token at a time - arc flags can be glued together like "01-.36"

    def __init__(self, d):
        self.d = d
        self.pos = 0

    def skipSeparators(self):
        while self.pos < len(self.d) and self.d[self.pos] in " ,\t\n\r":
            self.pos += 1

    def atEnd(self):
        self.skipSeparators()
        return self.pos >= len(self.d)

    def peekIsNumber(self):
        self.skipSeparators()
        if self.pos >= len(self.d):
            return False
        return self.d[self.pos] not in commandLetters

    def readCommand(self):
        self.skipSeparators()
        letter = self.d[self.pos]
        self.pos += 1
        return letter

    def readNumber(self):
        self.skipSeparators()
        match = numberPattern.match(self.d, self.pos)
        if match is None:
            raise ValueError("bad number at " + str(self.pos) + ": " + self.d[self.pos:self.pos + 20])
        self.pos = match.end()
        return float(match.group(0))

    def readFlag(self):
        self.skipSeparators()
        letter = self.d[self.pos]
        self.pos += 1
        if letter not in "01":
            raise ValueError("bad arc flag at " + str(self.pos))
        return letter == "1"


def cubicPoints(p0, p1, p2, p3):
    # flatten one cubic bezier - endpoint included - start point excluded
    roughLength = math.dist(p0, p1) + math.dist(p1, p2) + math.dist(p2, p3)
    steps = max(minCurveSegments, int(math.ceil(roughLength / curveStepPx)))
    points = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1.0 - t
        x = u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0]
        y = u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]
        points.append((x, y))
    return points


def quadPoints(p0, p1, p2):
    # flatten one quadratic bezier by raising it to a cubic
    c1 = (p0[0] + 2.0 / 3.0 * (p1[0] - p0[0]), p0[1] + 2.0 / 3.0 * (p1[1] - p0[1]))
    c2 = (p2[0] + 2.0 / 3.0 * (p1[0] - p2[0]), p2[1] + 2.0 / 3.0 * (p1[1] - p2[1]))
    return cubicPoints(p0, c1, c2, p2)


def arcPoints(p0, rx, ry, rotationDeg, largeArc, sweep, p1):
    ### FLATTEN AN SVG ELLIPTICAL ARC (endpoint form -> centre form, svg spec F.6.5)

    if rx == 0 or ry == 0 or p0 == p1:
        return [p1]
    rx = abs(rx)
    ry = abs(ry)
    phi = math.radians(rotationDeg)
    cosPhi = math.cos(phi)
    sinPhi = math.sin(phi)

    # step 1 - midpoint in the ellipse's own frame
    dx = (p0[0] - p1[0]) / 2.0
    dy = (p0[1] - p1[1]) / 2.0
    x1 = cosPhi * dx + sinPhi * dy
    y1 = -sinPhi * dx + cosPhi * dy

    # radii too small for the endpoints get scaled up as the spec says
    lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if lam > 1:
        rx *= math.sqrt(lam)
        ry *= math.sqrt(lam)

    # step 2 - centre in the ellipse frame
    num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    factor = math.sqrt(max(0.0, num / den))
    if largeArc == sweep:
        factor = -factor
    cx1 = factor * rx * y1 / ry
    cy1 = -factor * ry * x1 / rx

    # step 3 - centre in user space
    cx = cosPhi * cx1 - sinPhi * cy1 + (p0[0] + p1[0]) / 2.0
    cy = sinPhi * cx1 + cosPhi * cy1 + (p0[1] + p1[1]) / 2.0

    # step 4 - start angle and sweep
    startAngle = math.atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
    endAngle = math.atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx)
    delta = endAngle - startAngle
    if sweep and delta < 0:
        delta += 2 * math.pi
    if not sweep and delta > 0:
        delta -= 2 * math.pi

    # walk the arc
    arcLength = abs(delta) * max(rx, ry)
    steps = max(minCurveSegments, int(math.ceil(arcLength / curveStepPx)))
    points = []
    for i in range(1, steps + 1):
        angle = startAngle + delta * i / steps
        ex = rx * math.cos(angle)
        ey = ry * math.sin(angle)
        points.append((cosPhi * ex - sinPhi * ey + cx, sinPhi * ex + cosPhi * ey + cy))
    return points


def flattenPath(d):
    ### TURN ONE PATH STRING INTO A LIST OF CLOSED POLYGONS

    reader = PathReader(d)
    polygons = []
    current = []
    pen = (0.0, 0.0)
    subpathStart = (0.0, 0.0)
    lastControl = None
    lastCommand = ""
    command = ""

    while not reader.atEnd():
        # a number where a command should be repeats the previous command
        if reader.peekIsNumber():
            if command in "Mm":
                if command == "M":
                    command = "L"
                else:
                    command = "l"
        else:
            command = reader.readCommand()

        relative = command.islower()
        upper = command.upper()
        baseX = 0.0
        baseY = 0.0
        if relative:
            baseX = pen[0]
            baseY = pen[1]

        if upper == "M":
            if len(current) > 2:
                polygons.append(current)
            x = reader.readNumber() + baseX
            y = reader.readNumber() + baseY
            pen = (x, y)
            subpathStart = pen
            current = [pen]
            lastControl = None
        elif upper == "L":
            x = reader.readNumber() + baseX
            y = reader.readNumber() + baseY
            pen = (x, y)
            current.append(pen)
            lastControl = None
        elif upper == "H":
            x = reader.readNumber() + baseX
            pen = (x, pen[1])
            current.append(pen)
            lastControl = None
        elif upper == "V":
            y = reader.readNumber() + baseY
            pen = (pen[0], y)
            current.append(pen)
            lastControl = None
        elif upper == "C":
            c1 = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            c2 = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            end = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            current.extend(cubicPoints(pen, c1, c2, end))
            lastControl = c2
            pen = end
        elif upper == "S":
            c1 = pen
            if lastControl is not None and lastCommand.upper() in "CS":
                c1 = (2 * pen[0] - lastControl[0], 2 * pen[1] - lastControl[1])
            c2 = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            end = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            current.extend(cubicPoints(pen, c1, c2, end))
            lastControl = c2
            pen = end
        elif upper == "Q":
            c1 = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            end = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            current.extend(quadPoints(pen, c1, end))
            lastControl = c1
            pen = end
        elif upper == "T":
            c1 = pen
            if lastControl is not None and lastCommand.upper() in "QT":
                c1 = (2 * pen[0] - lastControl[0], 2 * pen[1] - lastControl[1])
            end = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            current.extend(quadPoints(pen, c1, end))
            lastControl = c1
            pen = end
        elif upper == "A":
            rx = reader.readNumber()
            ry = reader.readNumber()
            rotation = reader.readNumber()
            largeArc = reader.readFlag()
            sweep = reader.readFlag()
            end = (reader.readNumber() + baseX, reader.readNumber() + baseY)
            current.extend(arcPoints(pen, rx, ry, rotation, largeArc, sweep, end))
            lastControl = None
            pen = end
        elif upper == "Z":
            if len(current) > 2:
                polygons.append(current)
            current = []
            pen = subpathStart
            lastControl = None
        else:
            raise ValueError("unknown command " + command)
        lastCommand = command

    if len(current) > 2:
        polygons.append(current)

    # drop a duplicated closing point and round for a compact file
    cleaned = []
    for polygon in polygons:
        if math.dist(polygon[0], polygon[-1]) < 0.01:
            polygon = polygon[:-1]
        rounded = []
        for x, y in polygon:
            rounded.append([round(x, 2), round(y, 2)])
        cleaned.append(rounded)
    return cleaned


def polygonArea(points):
    # signed shoelace area
    total = 0.0
    for i in range(len(points)):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % len(points)]
        total += x0 * y1 - x1 * y0
    return total / 2.0


def polygonCentroid(points):
    # area-weighted centre - falls back to the vertex mean for slivers
    area = polygonArea(points)
    if abs(area) < 1e-6:
        sx = sum(p[0] for p in points) / len(points)
        sy = sum(p[1] for p in points) / len(points)
        return (sx, sy)
    cx = 0.0
    cy = 0.0
    for i in range(len(points)):
        x0, y0 = points[i]
        x1, y1 = points[(i + 1) % len(points)]
        cross = x0 * y1 - x1 * y0
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross
    return (cx / (6 * area), cy / (6 * area))


### /// PREVIEW ///
def slugColour(slug):
    # stable distinct-ish colour per slug
    value = 0
    for ch in slug:
        value = (value * 131 + ord(ch)) % 360
    return "hsl(" + str(value) + ", 70%, 55%)"


def previewSvg(viewEntry, parts):
    ### ONE LABELLED SVG PER VIEW

    vb = viewEntry["viewBox"]
    lines = []
    lines.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + " ".join(str(v) for v in vb) + '">')
    lines.append('<rect x="' + str(vb[0]) + '" y="' + str(vb[1]) + '" width="' + str(vb[2]) + '" height="' + str(vb[3]) + '" fill="#15171c"/>')

    # shapes in file order - the same order musclemap draws them
    for part in parts:
        fill = slugColour(part["slug"])
        if part["slug"] in ("head", "hair"):
            fill = "#3a3d45"
        lines.append('<path d="' + part["d"] + '" fill="' + fill + '" fill-opacity="0.85" stroke="#000" stroke-width="0.8"/>')

    # labels on the biggest polygon of each piece
    for part in parts:
        if part["slug"] in ("head", "hair"):
            continue
        biggest = None
        for polygon in part["polygons"]:
            if biggest is None or abs(polygonArea(polygon)) > abs(polygonArea(biggest)):
                biggest = polygon
        if biggest is None:
            continue
        cx, cy = polygonCentroid(biggest)
        label = part["slug"] + " " + part["side"][0] + str(part["index"])
        lines.append('<text x="' + str(round(cx, 1)) + '" y="' + str(round(cy, 1)) + '" font-size="' + str(labelFontPx) + '" font-family="Consolas, monospace" fill="#fff" stroke="#000" stroke-width="2.2" paint-order="stroke" text-anchor="middle">' + label + '</text>')
    lines.append("</svg>")
    return "\n".join(lines)


### /// MAIN ///
def main():
    ### EXTRACT EVERYTHING AND WRITE THE FILES

    outDir.mkdir(parents=True, exist_ok=True)
    previewDir = outDir / "preview"
    previewDir.mkdir(parents=True, exist_ok=True)
    allViews = []

    for entry in sourceFiles:
        text = (sourceDir / entry["file"]).read_text(encoding="utf-8")
        parts = readSwiftParts(text)
        for part in parts:
            part["polygons"] = flattenPath(part["d"])
        allViews.append({"gender": entry["gender"], "view": entry["view"], "viewBox": entry["viewBox"], "parts": parts})

        # per view preview
        svgText = previewSvg(entry, parts)
        svgName = "source_" + entry["gender"] + "_" + entry["view"] + ".svg"
        (previewDir / svgName).write_text(svgText, encoding="utf-8", newline="\n")

        polygonCount = sum(len(p["polygons"]) for p in parts)
        print(entry["gender"], entry["view"], len(parts), "paths", polygonCount, "polygons")

    sourceJson = json.dumps({"source": "melihcolpan/MuscleMap 7dc0307", "views": allViews}, separators=(",", ":"))
    (outDir / "sourceShapes.json").write_text(sourceJson, encoding="utf-8", newline="\n")
    print("wrote", outDir / "sourceShapes.json")


if __name__ == "__main__":
    main()
