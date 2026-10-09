"""buildAppData.py - builds the app's runtime data in appData/

what this offers
- appData/muscles.json   - the 30 muscle regions (name, group, views, weekly target band) plus, per
                           body (male/female) x view (front/back): the baked map's file and placement,
                           simplified tap shapes (at most 32 corners each, hit testing only), a centre
                           per region and the figure's layout box (no raw outlines - the app never
                           computes geometry)
- appData/bodyMaps/<body>_<view>.png - the baked region maps the app draws (tools/appData/bakeBodyMaps.py),
                           each with a .import that tells Godot to ship the png untouched ("keep")
- appData/exercises.json - every exercise of the free exercise database, each turned into
                           region shares: hand-tuned (curatedExercises.json) first, then researched
                           (researchedExercises.json), then the automatic guess; plus the added
                           exercises of both files and each exercise's search aliases; every cardio
                           exercise carries its default effort (cardio.json), plus the added cardio activities
- appData/targets.json   - the target presets (targetPresets.json: per-region offsets, cardio minutes per
                           light, key exercises) and the cardio model (cardio.json: efforts, lights, the
                           default weekly target)
- loud checks: exits non-zero on an unknown exercise or region id, a share outside 0..1, a
  region that no exercise can reach, a preset offset out of range or missing a region, an unknown
  key exercise or effort, or a cardio exercise without a default effort

run:  python tools/appData/buildAppData.py      (needs Pillow, numpy, scipy for the bake; paths found from this file)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bakeBodyMaps  # noqa: E402

### /// TUNING ///

# weekly target band per region, in effective sets [low, high] - the owner tunes these
# big muscles land near the full 10-20 of their group because one compound set credits every
# sub-region it really works (a squat set counts for outer AND inner quad), small ones 6-12,
# minor ones 3-8
targetBands = {
    "neck": [3, 8],
    "upperTraps": [6, 12],
    "midTraps": [6, 12],
    "lowerTraps": [5, 10],
    "rhomboids": [6, 12],
    "frontDelt": [6, 12],
    "sideDelt": [6, 12],
    "rearDelt": [6, 12],
    "rotatorCuff": [3, 8],
    "lats": [10, 20],
    "upperChest": [6, 12],
    "lowerChest": [8, 16],
    "serratus": [3, 8],
    "biceps": [6, 12],
    "triceps": [6, 12],
    "forearms": [6, 12],
    "upperAbs": [6, 12],
    "lowerAbs": [6, 12],
    "obliques": [6, 12],
    "lowerBack": [6, 12],
    "hipFlexors": [3, 8],
    "glutes": [10, 20],
    "gluteMed": [4, 10],
    "outerQuad": [8, 16],
    "midQuad": [6, 12],
    "innerQuad": [8, 16],
    "adductors": [4, 10],
    "hamstrings": [10, 20],
    "calves": [6, 12],
    "tibialis": [3, 8],
}

# which group each region belongs to - used for grouping in lists
regionGroups = {
    "neck": "neck",
    "upperTraps": "back",
    "midTraps": "back",
    "lowerTraps": "back",
    "rhomboids": "back",
    "lats": "back",
    "lowerBack": "back",
    "frontDelt": "shoulders",
    "sideDelt": "shoulders",
    "rearDelt": "shoulders",
    "rotatorCuff": "shoulders",
    "upperChest": "chest",
    "lowerChest": "chest",
    "serratus": "chest",
    "biceps": "arms",
    "triceps": "arms",
    "forearms": "arms",
    "upperAbs": "core",
    "lowerAbs": "core",
    "obliques": "core",
    "hipFlexors": "core",
    "glutes": "legs",
    "gluteMed": "legs",
    "outerQuad": "legs",
    "midQuad": "legs",
    "innerQuad": "legs",
    "adductors": "legs",
    "hamstrings": "legs",
    "calves": "legs",
    "tibialis": "legs",
}

# display names of the groups, in list order
groupNames = {
    "chest": "Chest",
    "shoulders": "Shoulders",
    "back": "Back",
    "arms": "Arms",
    "core": "Core",
    "legs": "Legs",
    "neck": "Neck",
}

# weight of a database exercise's primary and secondary muscle groups
primaryWeight = 1.0
secondaryWeight = 0.5

# how each of the database's 17 coarse muscle groups spreads over our regions (each row sums to 1)
defaultSpread = {
    "shoulders": {"frontDelt": 0.5, "sideDelt": 0.3, "rearDelt": 0.2},
    "chest": {"lowerChest": 0.7, "upperChest": 0.3},
    "middle back": {"midTraps": 0.5, "rhomboids": 0.5},
    "traps": {"upperTraps": 0.7, "midTraps": 0.3},
    "quadriceps": {"midQuad": 0.4, "outerQuad": 0.35, "innerQuad": 0.25},
    "abdominals": {"upperAbs": 0.6, "lowerAbs": 0.4},
    "abductors": {"gluteMed": 1.0},
    "adductors": {"adductors": 1.0},
    "lats": {"lats": 1.0},
    "lower back": {"lowerBack": 1.0},
    "hamstrings": {"hamstrings": 1.0},
    "glutes": {"glutes": 1.0},
    "calves": {"calves": 1.0},
    "biceps": {"biceps": 1.0},
    "triceps": {"triceps": 1.0},
    "forearms": {"forearms": 1.0},
    "neck": {"neck": 1.0},
}

# exercise categories that are kept in the list but give no heat
zeroHeatCategories = ["stretching", "cardio"]

# equipment name used when the database has none
missingEquipment = "other"

# name pieces that mark forearm work as wrist/elbow work (direct) rather than holding on (grip)
directForearmWords = ["wrist", "finger curl", "hammer", "reverse curl", "reverse barbell", "zottman", "reverse grip curl", "reverse cable curl", "reverse plate curl"]

# shares below this are dropped from the automatic conversion
minShare = 0.01

# decimals kept on shares
shareDecimals = 3

# version stamped into both files - bump when the format changes (2 = baked maps + tap shapes)
dataVersion = 2

# target presets: the range of a region offset, the longest summary line, the kinds
offsetMin = -12
offsetMax = 10
summaryMax = 90
presetKinds = ["sport", "physique"]
# the zones of the cardio model (z1 below the first threshold, z2 between, z3 above the second)
cardioZones = ["z1", "z2", "z3"]

### /// PATHS ///

toolDir = Path(__file__).resolve().parent
projectDir = toolDir.parent.parent
shapesPath = projectDir / "data" / "muscleShapes" / "muscleShapes.json"
exerciseDbPath = projectDir / "data" / "freeExerciseDb" / "dist" / "exercises.json"
curatedPath = toolDir / "curatedExercises.json"
researchedPath = toolDir / "researchedExercises.json"
targetPresetsPath = toolDir / "targetPresets.json"
cardioPath = toolDir / "cardio.json"
outDir = projectDir / "appData"

forearmKinds = ["none", "grip", "direct"]
# researched rows at these confidences count as checked data; the rest still show "rough data"
checkedConfidences = ["high", "medium"]

### /// HELPERS ///

problems = []


def fail(message):
    # collect a problem - every problem is printed before the script exits non-zero
    problems.append(message)


def rejectDuplicateKeys(pairs):
    # json hook - a repeated key in a hand-made data file is an error, never a silent overwrite
    result = {}
    for key, value in pairs:
        if key in result:
            fail("curated / researched exercises: key '%s' appears twice" % key)
        result[key] = value
    return result


def compactNumber(value, decimals):
    # rounds and turns whole numbers into ints so the json stays short
    rounded = round(float(value), decimals)
    if rounded == int(rounded):
        return int(rounded)
    return rounded


def writeJson(path, data):
    # compact json, utf-8, LF line ending
    text = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)
        handle.write("\n")


### /// MUSCLES ///

def buildMuscles(shapes):
    ### WHAT THIS DOES
    # turns the carved shapes into muscles.json: region table + outlines per body and view

    regionIds = []
    regionNames = {}
    regionViews = {}
    bodies = {}

    # the region list comes from the carved shapes - it must match our tables exactly
    for region in shapes["regions"]:
        regionIds.append(region["id"])
        regionNames[region["id"]] = region["name"]
        regionViews[region["id"]] = []
    for regionId in regionIds:
        if regionId not in targetBands:
            fail("region '%s' has no target band" % regionId)
        if regionId not in regionGroups:
            fail("region '%s' has no group" % regionId)
    for regionId in targetBands:
        if regionId not in regionNames:
            fail("targetBands names unknown region '%s'" % regionId)
    for regionId in regionGroups:
        if regionId not in regionNames:
            fail("regionGroups names unknown region '%s'" % regionId)
        elif regionGroups[regionId] not in groupNames:
            fail("region '%s' has unknown group '%s'" % (regionId, regionGroups[regionId]))
    for regionId, band in targetBands.items():
        if len(band) != 2 or band[0] < 0 or band[1] < band[0]:
            fail("target band of '%s' is not [low, high]: %s" % (regionId, band))

    # which views each region shows in; the views themselves are baked only once every check passed
    for view in shapes["views"]:
        gender = view["gender"]
        viewName = view["view"]
        for shape in view["shapes"]:
            regionId = shape["region"]
            if regionId not in regionNames:
                fail("shape in %s %s uses unknown region '%s'" % (gender, viewName, regionId))
                continue
            if viewName not in regionViews[regionId]:
                regionViews[regionId].append(viewName)
        if gender not in bodies:
            bodies[gender] = {}
        bodies[gender][viewName] = view

    # region table in the carved order
    regions = []
    for regionId in regionIds:
        views = []
        for viewName in ["front", "back"]:
            if viewName in regionViews[regionId]:
                views.append(viewName)
        if len(views) == 0:
            fail("region '%s' has no outline in any view" % regionId)
        regions.append({
            "id": regionId,
            "name": regionNames[regionId],
            "group": regionGroups.get(regionId, ""),
            "views": views,
            "band": list(targetBands.get(regionId, [0, 0])),
        })

    groups = []
    for groupId, groupName in groupNames.items():
        groups.append({"id": groupId, "name": groupName})

    muscles = {
        "version": dataVersion,
        "source": shapes.get("source", ""),
        "groups": groups,
        "regions": regions,
        "mapIds": bakeBodyMaps.mapIdTable(regionIds),
        "bodies": bodies,
    }
    return muscles, regionIds


def bakeBodies(muscles, regionIds):
    ### WHAT THIS DOES
    # swaps each raw view for its baked entry: writes appData/bodyMaps/<body>_<view>.png (+ its .import)
    # and prints the point counts before and after

    mapFolder = outDir / "bodyMaps"
    mapFolder.mkdir(parents=True, exist_ok=True)

    for gender in sorted(muscles["bodies"].keys()):
        for viewName in sorted(muscles["bodies"][gender].keys()):
            view = muscles["bodies"][gender][viewName]
            mapName = "%s_%s" % (gender, viewName)
            entry, stats = bakeBodyMaps.bakeView(view, regionIds, mapFolder, mapName)
            entry["map"]["file"] = "bodyMaps/" + entry["map"]["file"]
            writeKeepImport(mapFolder / (mapName + ".png.import"))
            muscles["bodies"][gender][viewName] = entry
            print("  baked %-13s map %4dx%-4d %6d bytes  outline points %5d -> tap points %4d (%d pieces, max %d per piece, worst overlap %.2f)" % (
                mapName, stats["mapSize"][0], stats["mapSize"][1], stats["mapBytes"], stats["sourcePoints"],
                stats["tapPoints"], stats["pieces"], stats["maxTapPoints"], stats["worstOverlap"]))


def writeKeepImport(path):
    # Godot ships the png byte for byte (importer "keep"): no texture import, no compression, no mipmaps
    text = '[remap]\n\nimporter="keep"\n'
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


### /// EXERCISES ///

def autoTargets(entry):
    ### WHAT THIS DOES
    # turns the database's coarse primary/secondary muscle groups into region shares

    shares = {}

    # primary groups count fully, secondary ones half, spread by the default table
    weighted = []
    for group in entry.get("primaryMuscles", []):
        weighted.append((group, primaryWeight))
    for group in entry.get("secondaryMuscles", []):
        weighted.append((group, secondaryWeight))
    for group, weight in weighted:
        if group not in defaultSpread:
            fail("exercise '%s' uses muscle group '%s' with no spread row" % (entry["id"], group))
            continue
        for regionId, part in defaultSpread[group].items():
            shares[regionId] = shares.get(regionId, 0.0) + weight * part

    # a region hit from two groups never counts more than one full set
    for regionId in list(shares.keys()):
        if shares[regionId] > 1.0:
            shares[regionId] = 1.0
        if shares[regionId] < minShare:
            del shares[regionId]
    return shares


def autoForearmKind(entry, shares):
    # direct for wrist/elbow work, grip for holding on, none when there is no forearm share
    if shares.get("forearms", 0.0) <= 0.0:
        return "none"
    lowerName = entry["name"].lower()
    for word in directForearmWords:
        if word in lowerName:
            return "direct"
    return "grip"


def targetList(shares):
    # {region: share} -> [{region, share}] biggest share first
    items = []
    for regionId, share in shares.items():
        items.append({"region": regionId, "share": compactNumber(share, shareDecimals)})
    items.sort(key=lambda item: (-item["share"], item["region"]))
    return items


def checkShares(owner, shares, regionSet):
    # every region known, every share inside 0..1
    for regionId, share in shares.items():
        if regionId not in regionSet:
            fail("%s: unknown region '%s'" % (owner, regionId))
        if not isinstance(share, (int, float)):
            fail("%s: share of '%s' is not a number" % (owner, regionId))
        elif share < 0.0 or share > 1.0:
            fail("%s: share of '%s' is %s, outside 0..1" % (owner, regionId, share))


def checkForearmKind(owner, kind, shares):
    # a grip or direct exercise must have a forearm share for the checkbox to mean anything
    if kind not in forearmKinds:
        fail("%s: forearmKind '%s' is not one of %s" % (owner, kind, forearmKinds))
        return
    if kind != "none" and shares.get("forearms", 0.0) <= 0.0:
        fail("%s: forearmKind '%s' but no forearms share" % (owner, kind))


def buildExercises(database, curated, researched, cardio, regionSet):
    ### WHAT THIS DOES
    # every database exercise: hand-tuned shares if curated, else researched, else auto-converted;
    # the added exercises of both files appended; every cardio exercise gets its default effort and
    # the added cardio activities join; aliases attached for search

    exercises = []
    databaseIds = set()
    curatedRows = curated.get("exercises", {})
    researchedRows = researched.get("exercises", {})
    aliasRows = researched.get("aliases", {})
    addedRows = dict(curated.get("added", {}))

    # researched added exercises join the curated ones (an id in both is an error)
    for exerciseId, row in researched.get("added", {}).items():
        if exerciseId in addedRows:
            fail("added '%s' is in both curatedExercises.json and researchedExercises.json" % exerciseId)
        addedRows[exerciseId] = row
    for exerciseId in researchedRows:
        if exerciseId not in curatedRows and exerciseId in addedRows:
            fail("researched '%s' is listed under exercises but is an added one" % exerciseId)

    # curated ids must exist in the database, added ids must not
    for entry in database:
        databaseIds.add(entry["id"])
    for exerciseId in curatedRows:
        if exerciseId not in databaseIds:
            if exerciseId in addedRows:
                fail("curated '%s' is listed under exercises but is an added one - move it" % exerciseId)
            else:
                fail("curated '%s' is not in the exercise database and not an added exercise" % exerciseId)
    for exerciseId in addedRows:
        if exerciseId in databaseIds:
            fail("added '%s' already exists in the database - curate it under exercises instead" % exerciseId)

    # database exercises
    for entry in database:
        exerciseId = entry["id"]
        category = entry.get("category") or "other"
        equipment = entry.get("equipment") or missingEquipment
        isCurated = exerciseId in curatedRows
        if isCurated or exerciseId in researchedRows:
            row = researchedRows.get(exerciseId)
            owner = "researched '%s'" % exerciseId
            if isCurated:
                row = curatedRows[exerciseId]
                owner = "curated '%s'" % exerciseId
            else:
                isCurated = row.get("confidence", "low") in checkedConfidences
            shares = dict(row.get("targets", {}))
            kind = row.get("forearmKind", "none")
            checkShares(owner, shares, regionSet)
            checkForearmKind(owner, kind, shares)
            if category in zeroHeatCategories:
                fail("%s is a %s exercise - those give no heat, do not curate it" % (owner, category))
        else:
            shares = autoTargets(entry)
            kind = autoForearmKind(entry, shares)
            checkShares("auto '%s'" % exerciseId, shares, regionSet)
        if category in zeroHeatCategories:
            shares = {}
            kind = "none"
        exercises.append({
            "id": exerciseId,
            "name": entry["name"],
            "equipment": equipment,
            "category": category,
            "targets": targetList(shares),
            "forearmKind": kind,
            "curated": isCurated,
        })

    # added exercises
    for exerciseId, row in addedRows.items():
        owner = "added '%s'" % exerciseId
        for field in ["name", "equipment", "category", "targets"]:
            if field not in row:
                fail("%s is missing '%s'" % (owner, field))
        shares = dict(row.get("targets", {}))
        kind = row.get("forearmKind", "none")
        checkShares(owner, shares, regionSet)
        checkForearmKind(owner, kind, shares)
        if row.get("category") in zeroHeatCategories:
            fail("%s is a %s exercise - those give no heat" % (owner, row.get("category")))
        exercises.append({
            "id": exerciseId,
            "name": row.get("name", exerciseId),
            "equipment": row.get("equipment", missingEquipment),
            "category": row.get("category", "strength"),
            "targets": targetList(shares),
            "forearmKind": kind,
            "curated": row.get("confidence", "high") in checkedConfidences,
        })

    # cardio: each one's default effort; the added activities (no heat - they light the cardio overlay)
    effortIds = set()
    for effort in cardio.get("efforts", []):
        effortIds.add(effort.get("id"))
    activityRows = cardio.get("activities", {})
    for exerciseId, row in cardio.get("added", {}).items():
        owner = "cardio added '%s'" % exerciseId
        if exerciseId in databaseIds or exerciseId in addedRows:
            fail("%s already exists - give it an effort under activities instead" % owner)
        for field in ["name", "equipment", "effort"]:
            if field not in row:
                fail("%s is missing '%s'" % (owner, field))
        exercises.append({
            "id": exerciseId,
            "name": row.get("name", exerciseId),
            "equipment": row.get("equipment", missingEquipment),
            "category": "cardio",
            "targets": [],
            "forearmKind": "none",
            "curated": True,
        })
        activityRows = dict(activityRows)
        activityRows[exerciseId] = row
    for exerciseId, row in activityRows.items():
        if row.get("effort") not in effortIds:
            fail("cardio '%s' has the effort '%s', which is not one of %s" % (exerciseId, row.get("effort"), sorted(effortIds)))
    for exercise in exercises:
        if exercise["category"] != "cardio":
            continue
        if exercise["id"] not in activityRows:
            fail("cardio exercise '%s' has no default effort in cardio.json" % exercise["id"])
            continue
        exercise["cardioEffort"] = activityRows[exercise["id"]]["effort"]
        exercise["cardioNote"] = activityRows[exercise["id"]].get("note", "")
    for exerciseId in activityRows:
        if exerciseId not in databaseIds and exerciseId not in cardio.get("added", {}):
            fail("cardio.json names '%s', which is not an exercise" % exerciseId)

    # search aliases (every id must exist)
    knownIds = set()
    for exercise in exercises:
        knownIds.add(exercise["id"])
    for exerciseId in aliasRows:
        if exerciseId not in knownIds:
            fail("aliases name '%s', which is not an exercise" % exerciseId)
    for exercise in exercises:
        words = aliasRows.get(exercise["id"], [])
        if len(words) > 0:
            exercise["aliases"] = list(words)

    exercises.sort(key=lambda item: item["name"].lower())
    return exercises


def buildTargets(presetData, cardio, regionIds, exerciseIds):
    ### WHAT THIS DOES
    # appData/targets.json: the cardio model and every preset with its offsets checked and its cardio
    # minutes turned from the three zones into the cardio lights

    lights = cardio.get("lights", [])
    efforts = cardio.get("efforts", [])
    lightIds = []
    presets = []

    # the cardio model
    for effort in efforts:
        if effort.get("zone") not in cardioZones:
            fail("effort '%s' has the zone '%s', not one of %s" % (effort.get("id"), effort.get("zone"), cardioZones))
    for light in lights:
        lightIds.append(light.get("id"))
        for zone in cardioZones:
            if zone not in light.get("zones", {}):
                fail("cardio light '%s' does not say how much %s lights it" % (light.get("id"), zone))
    for lightId in lightIds:
        if lightId not in cardio.get("defaultTarget", {}):
            fail("cardio defaultTarget has no minutes for '%s'" % lightId)

    # the presets
    for presetId, row in presetData.get("presets", {}).items():
        owner = "preset '%s'" % presetId
        offsets = row.get("offsets", {})
        for regionId in regionIds:
            if regionId not in offsets:
                fail("%s has no offset for '%s'" % (owner, regionId))
        for regionId, offset in offsets.items():
            if regionId not in regionIds:
                fail("%s names the unknown region '%s'" % (owner, regionId))
            elif not isinstance(offset, int) or offset < offsetMin or offset > offsetMax:
                fail("%s: offset %s on '%s' is not a whole number in %d..%d" % (owner, offset, regionId, offsetMin, offsetMax))
        if row.get("kind") not in presetKinds:
            fail("%s has the kind '%s', not one of %s" % (owner, row.get("kind"), presetKinds))
        if len(row.get("summary", "")) > summaryMax:
            fail("%s: summary longer than %d characters" % (owner, summaryMax))
        for exerciseId in row.get("keyExercises", []):
            if exerciseId not in exerciseIds:
                fail("%s: key exercise '%s' is not an exercise" % (owner, exerciseId))
        minutes = {}
        for light in lights:
            total = 0.0
            for zone in cardioZones:
                total += float(row.get("cardio", {}).get(zone, 0)) * float(light.get("zones", {}).get(zone, 0))
            minutes[light.get("id")] = int(round(total))
        presets.append({
            "id": presetId,
            "name": row.get("name", presetId),
            "kind": row.get("kind", "sport"),
            "summary": row.get("summary", ""),
            "offsets": dict(offsets),
            "cardio": minutes,
            "keyExercises": list(row.get("keyExercises", [])),
        })

    return {
        "version": dataVersion,
        "baseline": presetData.get("baseline", 12),
        "presets": presets,
        "cardio": {"efforts": efforts, "lights": lights, "defaultTarget": cardio.get("defaultTarget", {})},
    }


### /// MAIN ///

def main():
    ### WHAT THIS DOES
    # loads the three sources, builds both files, checks reachability, prints a summary

    reach = {}

    # sources
    for path in [shapesPath, exerciseDbPath, curatedPath, researchedPath, targetPresetsPath, cardioPath]:
        if not path.exists():
            print("MISSING source file: %s" % path)
            if path == exerciseDbPath:
                print("restore it with the steps in data/sources.md")
            return 2
    with open(shapesPath, encoding="utf-8") as handle:
        shapes = json.load(handle)
    with open(exerciseDbPath, encoding="utf-8") as handle:
        database = json.load(handle)
    with open(curatedPath, encoding="utf-8") as handle:
        curated = json.load(handle, object_pairs_hook=rejectDuplicateKeys)
    with open(researchedPath, encoding="utf-8") as handle:
        researched = json.load(handle, object_pairs_hook=rejectDuplicateKeys)
    with open(targetPresetsPath, encoding="utf-8") as handle:
        presetData = json.load(handle, object_pairs_hook=rejectDuplicateKeys)
    with open(cardioPath, encoding="utf-8") as handle:
        cardio = json.load(handle, object_pairs_hook=rejectDuplicateKeys)

    # build
    muscles, regionIds = buildMuscles(shapes)
    regionSet = set(regionIds)
    exercises = buildExercises(database, curated, researched, cardio, regionSet)
    exerciseIds = set()
    for exercise in exercises:
        exerciseIds.add(exercise["id"])
    targets = buildTargets(presetData, cardio, regionIds, exerciseIds)

    # every region must be reachable by at least one exercise
    for regionId in regionIds:
        reach[regionId] = 0
    for exercise in exercises:
        for target in exercise["targets"]:
            if target["share"] > 0 and target["region"] in reach:
                reach[target["region"]] += 1
    for regionId in regionIds:
        if reach[regionId] == 0:
            fail("region '%s' is not reached by any exercise - curate one that works it" % regionId)

    if len(problems) > 0:
        print("buildAppData FAILED - %d problem(s):" % len(problems))
        for problem in problems:
            print("  - " + problem)
        return 1

    # bake the body maps, then write
    outDir.mkdir(parents=True, exist_ok=True)
    bakeBodies(muscles, regionIds)
    musclesPath = outDir / "muscles.json"
    exercisesPath = outDir / "exercises.json"
    writeJson(musclesPath, muscles)
    writeJson(exercisesPath, {"version": dataVersion, "exercises": exercises})
    targetsPath = outDir / "targets.json"
    writeJson(targetsPath, targets)

    # summary
    curatedCount = 0
    zeroCount = 0
    for exercise in exercises:
        if exercise["curated"]:
            curatedCount += 1
        if len(exercise["targets"]) == 0:
            zeroCount += 1
    print("buildAppData OK")
    print("  regions: %d   bodies: %s" % (len(regionIds), ", ".join(sorted(muscles["bodies"].keys()))))
    addedCount = len(curated.get("added", {})) + len(researched.get("added", {})) + len(cardio.get("added", {}))
    print("  exercises: %d  (database %d + added %d)" % (len(exercises), len(database), addedCount))
    print("  checked data: %d   rough data: %d   zero-heat (stretching/cardio): %d" % (curatedCount, len(exercises) - curatedCount - zeroCount, zeroCount))
    print("  target presets: %d   cardio lights: %d   efforts: %d" % (len(targets["presets"]), len(targets["cardio"]["lights"]), len(targets["cardio"]["efforts"])))
    print("  muscles.json %d KB   exercises.json %d KB   targets.json %d KB" % (musclesPath.stat().st_size // 1024, exercisesPath.stat().st_size // 1024, targetsPath.stat().st_size // 1024))
    print("  exercises reaching each region:")
    line = "   "
    for index, regionId in enumerate(regionIds):
        line += " %-12s %4d" % (regionId, reach[regionId])
        if index % 4 == 3:
            print(line)
            line = "   "
    if line.strip() != "":
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
