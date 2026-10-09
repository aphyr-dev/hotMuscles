"""testBuildAppData.py - proves buildAppData.py refuses broken curated data, presets and cardio model

what this offers
- feeds the builder deliberately broken copies of curatedExercises.json (and of researchedExercises.json,
  targetPresets.json, cardio.json where a case needs it; all written to a temp folder) and checks each
  one exits non-zero with the expected complaint
- never writes appData/: every case is broken, and the builder only writes on success

run:  python tests/testBuildAppData.py
"""

import copy
import importlib.util
import io
import json
import sys
import tempfile
from contextlib import redirect_stdout
from pathlib import Path

### /// PATHS ///

testDir = Path(__file__).resolve().parent
builderPath = testDir.parent / "tools" / "appData" / "buildAppData.py"


def loadBuilder():
    # a fresh module each time so the collected problems list starts empty
    spec = importlib.util.spec_from_file_location("buildAppData", builderPath)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def runCase(curatedData, rawText, outFolder, overrides=None):
    ### WHAT THIS DOES
    # runs the builder against a temp curated file and a temp out folder, returns (code, output);
    # overrides = {builder path name: data} replaces other source files (researchedPath, targetPresetsPath,
    # cardioPath) with temp copies

    builder = loadBuilder()
    tempCurated = Path(outFolder) / "curated.json"
    if rawText is None:
        tempCurated.write_text(json.dumps(curatedData), encoding="utf-8")
    else:
        tempCurated.write_text(rawText, encoding="utf-8")
    builder.curatedPath = tempCurated
    if overrides is not None:
        for pathName, data in overrides.items():
            tempFile = Path(outFolder) / ("%s.json" % pathName)
            tempFile.write_text(json.dumps(data), encoding="utf-8")
            setattr(builder, pathName, tempFile)
    builder.outDir = Path(outFolder) / "out"
    captured = io.StringIO()
    with redirect_stdout(captured):
        code = builder.main()
    return code, captured.getvalue(), builder.outDir


def main():
    ### WHAT THIS DOES
    # one broken case per rule, each must fail with its message

    base = json.loads((builderPath.parent / "curatedExercises.json").read_text(encoding="utf-8"))
    cases = []
    failures = 0

    # unknown curated id
    broken = copy.deepcopy(base)
    broken["exercises"]["Not_A_Real_Lift"] = {"forearmKind": "none", "targets": {"biceps": 1.0}}
    cases.append(("unknown curated id", broken, None, "not in the exercise database"))

    # unknown region
    broken = copy.deepcopy(base)
    broken["exercises"]["Barbell_Curl"]["targets"]["bicepz"] = 0.5
    cases.append(("unknown region", broken, None, "unknown region 'bicepz'"))

    # share above 1
    broken = copy.deepcopy(base)
    broken["exercises"]["Barbell_Curl"]["targets"]["biceps"] = 1.5
    cases.append(("share above 1", broken, None, "outside 0..1"))

    # negative share
    broken = copy.deepcopy(base)
    broken["added"]["Y_Raise"]["targets"]["lowerTraps"] = -0.2
    cases.append(("negative share", broken, None, "outside 0..1"))

    # unreachable region - with no researched rows, tibialis is only reached by the added tibialis raise
    broken = copy.deepcopy(base)
    del broken["added"]["Tibialis_Raise"]
    noResearched = {"exercises": {}, "added": {}, "aliases": {}}
    cases.append(("unreachable region", broken, None, "region 'tibialis' is not reached", {"researchedPath": noResearched}))

    # target presets: an offset out of range, a missing region, an unknown key exercise
    presets = json.loads((builderPath.parent / "targetPresets.json").read_text(encoding="utf-8"))
    brokenPresets = copy.deepcopy(presets)
    brokenPresets["presets"]["marathon"]["offsets"]["calves"] = 15
    cases.append(("preset offset out of range", base, None, "offset 15 on 'calves'", {"targetPresetsPath": brokenPresets}))
    brokenPresets = copy.deepcopy(presets)
    del brokenPresets["presets"]["mew2"]["offsets"]["neck"]
    cases.append(("preset missing a region", base, None, "preset 'mew2' has no offset for 'neck'", {"targetPresetsPath": brokenPresets}))
    brokenPresets = copy.deepcopy(presets)
    brokenPresets["presets"]["climbing"]["keyExercises"].append("Not_A_Real_Lift")
    cases.append(("unknown key exercise", base, None, "key exercise 'Not_A_Real_Lift'", {"targetPresetsPath": brokenPresets}))

    # cardio: an exercise without a default effort, an effort that does not exist
    cardio = json.loads((builderPath.parent / "cardio.json").read_text(encoding="utf-8"))
    brokenCardio = copy.deepcopy(cardio)
    del brokenCardio["activities"]["Rope_Jumping"]
    cases.append(("cardio exercise without an effort", base, None, "'Rope_Jumping' has no default effort", {"cardioPath": brokenCardio}))
    brokenCardio = copy.deepcopy(cardio)
    brokenCardio["added"]["Hiking"]["effort"] = "medium"
    cases.append(("unknown effort", base, None, "has the effort 'medium'", {"cardioPath": brokenCardio}))

    # grip exercise without a forearm share
    broken = copy.deepcopy(base)
    broken["exercises"]["Pullups"]["targets"].pop("forearms")
    cases.append(("grip without forearm share", broken, None, "no forearms share"))

    # duplicate key in the json text
    rawText = json.dumps(base).replace('"Barbell_Curl":', '"Hammer_Curls": {"forearmKind": "direct", "targets": {"forearms": 1.0}}, "Barbell_Curl":', 1)
    cases.append(("duplicate key", None, rawText, "appears twice"))

    # added id that already exists in the database
    broken = copy.deepcopy(base)
    broken["added"]["Barbell_Curl"] = {"name": "x", "equipment": "barbell", "category": "strength", "forearmKind": "none", "targets": {"biceps": 1.0}}
    cases.append(("added id already in database", broken, None, "already exists in the database"))

    for case in cases:
        label, data, rawText, expected = case[0:4]
        researched = None
        if len(case) > 4:
            researched = case[4]
        with tempfile.TemporaryDirectory() as folder:
            code, output, outDir = runCase(data, rawText, folder, researched)
            wrote = outDir.exists()
        ok = code != 0 and expected in output and not wrote
        if ok:
            print("PASS  %s  (exit %d)" % (label, code))
        else:
            failures += 1
            print("FAIL  %s  exit=%s wroteFiles=%s expected '%s' in:\n%s" % (label, code, wrote, expected, output))

    if failures == 0:
        print("ALL PASS (%d cases)" % len(cases))
        return 0
    print("%d FAILURE(S)" % failures)
    return 1


if __name__ == "__main__":
    sys.exit(main())
