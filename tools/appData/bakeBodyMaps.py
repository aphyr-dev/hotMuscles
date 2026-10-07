"""bakeBodyMaps.py - bakes the body pictures and tap shapes the app draws with (called by buildAppData.py)

what this offers
- bakeView(view, regionIds, mapFolder, mapName) -> the app's entry for one body + view:
    a REGION MAP png in mapFolder: every texel says what is there -
      red   = 0 outside the body, 1 the dark seam (the gaps between muscles and the thin border round
              the figure), 2 head / hair / hands / feet / knees / ankles, 3 + n region number n
      green = where along its own outline a texel near a muscle's edge sits, as a fraction of one
              ghost dash period (the app draws the ghost preview's dashed outline from it)
      blue  = how far the texel's centre is from the edge of whatever it belongs to, in 1/64 texel
              (capped at 255 = ~4 texels) - the app blends these across texels to put each edge
              exactly where the outline runs, so edges stay smooth when zoomed far in
    tap shapes: every muscle piece simplified to at most maxTapPoints corners (hit testing only)
    centres: per region, the most inside point of its biggest piece (zoom / test targets)
- nothing geometric is left for the app to do: it draws the png through a shader and hit tests the
  tap shapes
- needs Pillow, numpy and scipy (build time only, never shipped)
"""

import math

import numpy
from PIL import Image, ImageDraw
from scipy import ndimage

### /// TUNING ///

# map texels per drawing unit - the female figure (~1430 units tall) comes out ~2000 texels tall,
# crisp at the largest body card on a phone, and the app's sharpened edge keeps it clean when zoomed
texelsPerUnit = 1.4
# empty texels kept round the figure so the edge blend never reads past the picture
mapPadTexels = 4
# tap-shape and dash masks: polygons rasterized this many times finer, a texel = covered at least half
superSample = 4
# the id map itself is drawn this many times finer (odd, so a texel's centre is a fine pixel's centre);
# each texel takes the id at its centre and its distance to the nearest edge
fineSample = 3
# edge distance steps per texel stored in blue
edgeSteps = 64.0
# the dark layer under the body: seams wider than seamClose x 2 drawing units get filled in, and the
# outer border sticks out seamGrow drawing units past the shapes (same numbers the app used to use)
seamGrow = 2.6
seamClose = 9.0
# ghost preview dashes, in drawing units along each outline: drawn part + gap = one period
ghostDash = 9.0
ghostDashGap = 6.0
# how deep inside each piece (texels) the dash position is written - the app reads it right at the edge
dashBandTexels = 5.0
# tap shapes: start at tapPointsStart corners and add tapPointsStep until the shape covers the same
# texels as the real piece to at least tapMinOverlap (shared / combined area), never past maxTapPoints
tapPointsStart = 16
tapPointsStep = 2
maxTapPoints = 32
tapMinOverlap = 0.9
# decimals kept on tap shape points and centres
pointDecimals = 1

# map ids
outsideId = 0
gapId = 1
cosmeticId = 2
firstRegionId = 3


### /// SMALL GEOMETRY ///

def polygonArea(points):
    # signed area (shoelace)
    area = 0.0
    count = len(points)
    for index in range(count):
        ax, ay = points[index]
        bx, by = points[(index + 1) % count]
        area += ax * by - bx * ay
    return area * 0.5


def cleanPoints(points):
    # drops repeated points and a closing point equal to the first
    clean = []
    for point in points:
        if len(clean) == 0 or math.dist(clean[-1], point) > 0.01:
            clean.append((float(point[0]), float(point[1])))
    if len(clean) > 1 and math.dist(clean[0], clean[-1]) <= 0.01:
        clean.pop()
    return clean


def segmentsCross(a, b, c, d):
    # true when segment ab properly crosses segment cd
    def side(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    d1 = side(c, d, a)
    d2 = side(c, d, b)
    d3 = side(a, b, c)
    d4 = side(a, b, d)
    return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)) and d1 != 0 and d2 != 0 and d3 != 0 and d4 != 0


def isSimple(points):
    # no two non-neighbouring edges cross
    count = len(points)
    for i in range(count):
        a = points[i]
        b = points[(i + 1) % count]
        for j in range(i + 2, count):
            if i == 0 and j == count - 1:
                continue
            if segmentsCross(a, b, points[j], points[(j + 1) % count]):
                return False
    return True


def simplifyTo(points, target):
    ### WHAT THIS DOES
    # Visvalingam-Whyatt: keeps dropping the corner whose triangle with its neighbours has the
    # smallest area until `target` corners are left - keeps the overall area close to the real one

    kept = list(points)

    while len(kept) > target:
        count = len(kept)
        smallest = None
        smallestIndex = 0
        for index in range(count):
            ax, ay = kept[index - 1]
            bx, by = kept[index]
            cx, cy = kept[(index + 1) % count]
            area = abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay))
            if smallest is None or area < smallest:
                smallest = area
                smallestIndex = index
        kept.pop(smallestIndex)
    return kept


### /// RASTERIZING ///

class MapFrame:
    # where a view's drawing units land in its map: texel = (unit - origin) * texelsPerUnit

    def __init__(self, left, top, width, height):
        self.left = left
        self.top = top
        self.width = width
        self.height = height

    def toTexel(self, point):
        return ((point[0] - self.left) * texelsPerUnit, (point[1] - self.top) * texelsPerUnit)


def coverage(frame, points):
    ### WHAT THIS DOES
    # how much of each texel a polygon covers (0..1), as (x0, y0, array) over the polygon's box

    texelPoints = [frame.toTexel(point) for point in points]
    xs = [point[0] for point in texelPoints]
    ys = [point[1] for point in texelPoints]
    x0 = max(int(math.floor(min(xs))) - 1, 0)
    y0 = max(int(math.floor(min(ys))) - 1, 0)
    x1 = min(int(math.ceil(max(xs))) + 1, frame.width)
    y1 = min(int(math.ceil(max(ys))) + 1, frame.height)
    fine = Image.new("L", ((x1 - x0) * superSample, (y1 - y0) * superSample), 0)

    # fine texel (i, j) is the point (i + 0.5, j + 0.5) / superSample - PIL fills integer points
    finePoints = []
    for x, y in texelPoints:
        finePoints.append(((x - x0) * superSample - 0.5, (y - y0) * superSample - 0.5))
    ImageDraw.Draw(fine).polygon(finePoints, fill=1)
    fineArray = numpy.asarray(fine, dtype=numpy.float32)
    blocks = fineArray.reshape(y1 - y0, superSample, x1 - x0, superSample)
    return x0, y0, blocks.mean(axis=(1, 3))


def pieceMask(frame, points):
    # full-map boolean mask of the texels a polygon covers at least half of
    x0, y0, cover = coverage(frame, points)
    mask = numpy.zeros((frame.height, frame.width), dtype=bool)
    mask[y0:y0 + cover.shape[0], x0:x0 + cover.shape[1]] = cover >= 0.5
    return mask


def fineMask(frame, points):
    ### WHAT THIS DOES
    # the fine pixels (fineSample per texel) whose centre lies inside a polygon, as (x0, y0, array)

    finePoints = []
    for point in points:
        x, y = frame.toTexel(point)
        finePoints.append((x * fineSample - 0.5, y * fineSample - 0.5))
    xs = [point[0] for point in finePoints]
    ys = [point[1] for point in finePoints]
    x0 = max(int(math.floor(min(xs))) - 1, 0)
    y0 = max(int(math.floor(min(ys))) - 1, 0)
    x1 = min(int(math.ceil(max(xs))) + 2, frame.width * fineSample)
    y1 = min(int(math.ceil(max(ys))) + 2, frame.height * fineSample)
    picture = Image.new("L", (x1 - x0, y1 - y0), 0)
    shifted = [(x - x0, y - y0) for x, y in finePoints]
    ImageDraw.Draw(picture).polygon(shifted, fill=1)
    return x0, y0, numpy.asarray(picture, dtype=numpy.uint8) > 0


def edgeDistance(fineIds):
    ### WHAT THIS DOES
    # for every texel centre: distance (texels) to the nearest edge between two different ids -
    # inside a region that is its own edge, in a seam the nearest muscle's edge

    boundary = numpy.zeros(fineIds.shape, dtype=bool)
    horizontal = fineIds[:, 1:] != fineIds[:, :-1]
    vertical = fineIds[1:, :] != fineIds[:-1, :]
    boundary[:, 1:] |= horizontal
    boundary[:, :-1] |= horizontal
    boundary[1:, :] |= vertical
    boundary[:-1, :] |= vertical
    centre = fineSample // 2
    distance = ndimage.distance_transform_edt(~boundary)[centre::fineSample, centre::fineSample]
    # the edge runs half a fine pixel past the boundary pixel's centre
    return (distance + 0.5) / fineSample


def seamLayer(bodyMask, scale):
    ### WHAT THIS DOES
    # grows the whole body by seamClose, fills every hole (interior seams become solid), then shrinks
    # back so the border sticks out only seamGrow past the shapes (scale = pixels per texel)

    growTexels = seamClose * texelsPerUnit * scale
    shrinkTexels = (seamClose - seamGrow) * texelsPerUnit * scale

    distanceOut = ndimage.distance_transform_edt(~bodyMask)
    grown = distanceOut <= growTexels
    filled = ndimage.binary_fill_holes(grown)
    distanceIn = ndimage.distance_transform_edt(filled)
    return distanceIn > shrinkTexels


def insideDepth(mask):
    # distance (texels) from every texel of a mask to its edge, worked out on the mask's own box only
    depth = numpy.zeros(mask.shape, dtype=numpy.float64)
    rows = numpy.nonzero(mask.any(axis=1))[0]
    cols = numpy.nonzero(mask.any(axis=0))[0]
    if rows.size == 0:
        return depth
    top = max(rows[0] - 1, 0)
    bottom = min(rows[-1] + 2, mask.shape[0])
    left = max(cols[0] - 1, 0)
    right = min(cols[-1] + 2, mask.shape[1])
    depth[top:bottom, left:right] = ndimage.distance_transform_edt(mask[top:bottom, left:right])
    return depth


def writeDashPhase(frame, points, insideMask, phase):
    ### WHAT THIS DOES
    # for the texels just inside one piece: the arc length of the nearest outline point, as a
    # fraction of one dash period (0..255) - measured along the real outline in drawing units

    period = ghostDash + ghostDashGap
    count = len(points)
    lengths = []
    starts = []
    travelled = 0.0

    # the band: inside the piece and within dashBandTexels of its edge
    depth = insideDepth(insideMask)
    band = insideMask & (depth <= dashBandTexels)
    rows, cols = numpy.nonzero(band)
    if rows.size == 0:
        return
    unitX = (cols + 0.5) / texelsPerUnit + frame.left
    unitY = (rows + 0.5) / texelsPerUnit + frame.top

    # nearest point on the outline for every band texel
    for index in range(count):
        a = points[index]
        b = points[(index + 1) % count]
        starts.append(travelled)
        lengths.append(math.dist(a, b))
        travelled += lengths[-1]
    best = numpy.full(rows.size, numpy.inf)
    bestArc = numpy.zeros(rows.size)
    for index in range(count):
        ax, ay = points[index]
        bx, by = points[(index + 1) % count]
        length = lengths[index]
        if length <= 0.0:
            continue
        along = ((unitX - ax) * (bx - ax) + (unitY - ay) * (by - ay)) / (length * length)
        along = numpy.clip(along, 0.0, 1.0)
        dx = unitX - (ax + along * (bx - ax))
        dy = unitY - (ay + along * (by - ay))
        distance = dx * dx + dy * dy
        closer = distance < best
        best = numpy.where(closer, distance, best)
        bestArc = numpy.where(closer, starts[index] + along * length, bestArc)
    fraction = numpy.mod(bestArc / period, 1.0)
    phase[rows, cols] = numpy.clip(numpy.floor(fraction * 256.0), 0, 255).astype(numpy.uint8)


### /// TAP SHAPES ///

def tapShape(frame, points, realMask):
    ### WHAT THIS DOES
    # the fewest corners (from tapPointsStart, at most maxTapPoints) whose shape still covers the
    # real piece well; returns (corners, overlap)

    target = tapPointsStart
    best = None
    bestOverlap = 0.0
    realCount = realMask.sum()

    if len(points) <= tapPointsStart:
        return list(points), 1.0
    while target <= maxTapPoints:
        simple = simplifyTo(points, target)
        if isSimple(simple) and abs(polygonArea(simple)) > 0.0:
            simpleMask = pieceMask(frame, simple)
            shared = numpy.logical_and(simpleMask, realMask).sum()
            combined = numpy.logical_or(simpleMask, realMask).sum()
            overlap = 1.0
            if combined > 0:
                overlap = shared / combined
            if realCount == 0:
                overlap = 1.0
            if overlap > bestOverlap:
                best = simple
                bestOverlap = overlap
            if overlap >= tapMinOverlap:
                return simple, overlap
        target += tapPointsStep
    if best is None:
        raise ValueError("no simple tap shape of at most %d corners found" % maxTapPoints)
    return best, bestOverlap


def innermostPoint(frame, mask):
    # the texel deepest inside a mask, back in drawing units
    depth = insideDepth(mask)
    row, col = numpy.unravel_index(numpy.argmax(depth), depth.shape)
    return ((col + 0.5) / texelsPerUnit + frame.left, (row + 0.5) / texelsPerUnit + frame.top)


def rounded(value):
    result = round(float(value), pointDecimals)
    if result == int(result):
        return int(result)
    return result


### /// ONE VIEW ///

def bakeView(view, regionIds, mapFolder, mapName):
    ### WHAT THIS DOES
    # region map png + tap shapes + centres + layout box for one body / view; returns the app entry
    # and a stats dict (point counts, overlaps)

    regionNumber = {}
    pieces = []
    regionOrder = []
    allPoints = []
    stats = {"sourcePoints": 0, "tapPoints": 0, "maxTapPoints": 0, "pieces": 0, "worstOverlap": 1.0}

    for index, regionId in enumerate(regionIds):
        regionNumber[regionId] = firstRegionId + index

    # every piece, cosmetic first (drawn underneath), then regions grouped in first-seen order
    for part in view["cosmetic"]:
        points = cleanPoints(part["points"])
        if len(points) >= 3:
            pieces.append({"kind": "cosmetic", "region": "", "side": "", "points": points})
    for shape in view["shapes"]:
        if shape["region"] not in regionOrder:
            regionOrder.append(shape["region"])
    for regionId in regionOrder:
        for shape in view["shapes"]:
            if shape["region"] != regionId:
                continue
            for polygon in shape["polygons"]:
                points = cleanPoints(polygon)
                if len(points) >= 3:
                    pieces.append({"kind": "region", "region": regionId, "side": shape["side"], "points": points})
    for piece in pieces:
        allPoints.extend(piece["points"])
        stats["sourcePoints"] += len(piece["points"])

    # the map frame: the figure plus its seam border plus a little empty padding
    left = min(point[0] for point in allPoints) - seamGrow
    top = min(point[1] for point in allPoints) - seamGrow
    right = max(point[0] for point in allPoints) + seamGrow
    bottom = max(point[1] for point in allPoints) + seamGrow
    pad = mapPadTexels / texelsPerUnit
    width = int(math.ceil((right - left + pad * 2.0) * texelsPerUnit))
    height = int(math.ceil((bottom - top + pad * 2.0) * texelsPerUnit))
    frame = MapFrame(left - pad, top - pad, width, height)

    # each piece's texels (tap shapes, dashes) and its fine pixels (the id map)
    fineIds = numpy.full((height * fineSample, width * fineSample), outsideId, dtype=numpy.uint8)
    fineBody = numpy.zeros(fineIds.shape, dtype=bool)
    for piece in pieces:
        piece["mask"] = pieceMask(frame, piece["points"])
        piece["fine"] = fineMask(frame, piece["points"])
        x0, y0, inside = piece["fine"]
        fineBody[y0:y0 + inside.shape[0], x0:x0 + inside.shape[1]] |= inside

    # ids: seam layer, cosmetic, regions (later pieces win where they overlap, as drawn before)
    fineIds[seamLayer(fineBody, fineSample)] = gapId
    for piece in pieces:
        x0, y0, inside = piece["fine"]
        window = fineIds[y0:y0 + inside.shape[0], x0:x0 + inside.shape[1]]
        if piece["kind"] == "cosmetic":
            window[inside] = cosmeticId
        else:
            window[inside] = regionNumber[piece["region"]]
    centre = fineSample // 2
    ids = numpy.ascontiguousarray(fineIds[centre::fineSample, centre::fineSample])
    edges = numpy.clip(numpy.round(edgeDistance(fineIds) * edgeSteps), 0, 255).astype(numpy.uint8)
    del fineIds
    del fineBody

    # dash phase just inside every region piece, on the texels that piece still owns
    phase = numpy.zeros((height, width), dtype=numpy.uint8)
    for piece in pieces:
        if piece["kind"] != "region":
            continue
        owned = piece["mask"] & (ids == regionNumber[piece["region"]])
        writeDashPhase(frame, piece["points"], owned, phase)

    # tap shapes and centres
    taps = []
    centres = {}
    biggest = {}
    for piece in pieces:
        if piece["kind"] != "region":
            continue
        owned = piece["mask"] & (ids == regionNumber[piece["region"]])
        corners, overlap = tapShape(frame, piece["points"], piece["mask"])
        flat = []
        for point in corners:
            flat.append(rounded(point[0]))
            flat.append(rounded(point[1]))
        xs = [point[0] for point in corners]
        ys = [point[1] for point in corners]
        box = [rounded(min(xs)), rounded(min(ys)), rounded(max(xs) - min(xs)), rounded(max(ys) - min(ys))]
        taps.append({"region": piece["region"], "side": piece["side"], "polygon": flat, "box": box})
        stats["tapPoints"] += len(corners)
        stats["maxTapPoints"] = max(stats["maxTapPoints"], len(corners))
        stats["worstOverlap"] = min(stats["worstOverlap"], overlap)
        stats["pieces"] += 1
        area = owned.sum()
        if piece["region"] not in biggest or area > biggest[piece["region"]][0]:
            biggest[piece["region"]] = (area, owned)
    for regionId in regionOrder:
        if biggest[regionId][0] == 0:
            raise ValueError("region '%s' has no texels left in %s - covered by other pieces" % (regionId, mapName))
        point = innermostPoint(frame, biggest[regionId][1])
        centres[regionId] = [rounded(point[0]), rounded(point[1])]

    # the png - lossless, red = id, green = dash phase
    rgb = numpy.zeros((height, width, 3), dtype=numpy.uint8)
    rgb[:, :, 0] = ids
    rgb[:, :, 1] = phase
    rgb[:, :, 2] = edges
    mapFolder.mkdir(parents=True, exist_ok=True)
    mapPath = mapFolder / (mapName + ".png")
    Image.fromarray(rgb, "RGB").save(mapPath, optimize=True)

    # layout box: the figure plus its seam border (what the app fits into its card)
    entry = {
        "viewBox": [rounded(value) for value in view["viewBox"]],
        "bounds": [rounded(left), rounded(top), rounded(right - left), rounded(bottom - top)],
        "map": {
            "file": mapName + ".png",
            "rect": [round(frame.left, 4), round(frame.top, 4), round(width / texelsPerUnit, 4), round(height / texelsPerUnit, 4)],
            "size": [width, height],
        },
        "taps": taps,
        "centres": centres,
    }
    stats["mapSize"] = [width, height]
    stats["mapBytes"] = mapPath.stat().st_size
    stats["ids"] = sorted(int(value) for value in numpy.unique(ids))
    return entry, stats


def mapIdTable(regionIds):
    # what the map's red values mean, stored in muscles.json for the app
    return {
        "outside": outsideId,
        "gap": gapId,
        "cosmetic": cosmeticId,
        "firstRegion": firstRegionId,
        "texelsPerUnit": texelsPerUnit,
        "dashShare": ghostDash / (ghostDash + ghostDashGap),
        "edgeSteps": edgeSteps,
        "regionCount": len(regionIds),
    }
