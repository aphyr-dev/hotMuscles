"""buildAll.py - builds the next version of the app: the Windows exe, then the Android apk

what this offers
  python tools/build/buildAll.py
    1. lists builds/ and picks the next free version (the exe and apk share ONE counter, never overwrites)
    2. refreshes the import cache (headless --import)
    3. exports builds/hotMuscles_vNNN.exe (preset "Windows Desktop", one file with the pack inside)
    4. exports builds/hotMuscles_vNNN.apk (preset "Android", debug-signed - no release key on this box)
    5. prints both sizes
  the exe goes FIRST: an apk export leaves phone textures in the import cache that the next exe would pack
  a failed export whose output mentions packtmp / PCK Embedding (another Godot export, or an antivirus
  scan, holding Godot's shared temp pack) is retried after clearing its stray .tmp
  nothing but the exe and the apk is written to builds/ - the engine output goes to this script's output
"""

import os
import re
import subprocess
import sys
import time
from pathlib import Path

### /// TUNING ///

# Godot binary (same default as tests/runGodot.py) - override with the GODOT4 environment variable
defaultGodot = r"C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
# file name start of every new build
# (any older build ending _vNNN.exe / .apk still counts toward the shared version number)
buildPrefix = "hotMuscles_v"
# export preset names (export_presets.cfg)
windowsPreset = "Windows Desktop"
androidPreset = "Android"
# tries per export, and seconds to wait between them
exportTries = 3
retryWaitSeconds = 20
# seconds before one engine call is given up on
timeLimit = 900
# output lines that mean the shared temp pack was held - worth a retry
retryPattern = re.compile(r"packtmp|PCK Embedding|Safe save failed", re.IGNORECASE)

### /// PATHS ///

projectDir = Path(__file__).resolve().parent.parent.parent
buildsDir = projectDir / "builds"


def godotPath():
    path = os.environ.get("GODOT4", defaultGodot)
    if not Path(path).exists():
        print("Godot not found at %s - set GODOT4" % path)
        sys.exit(2)
    return path


def runEngine(arguments, label):
    ### WHAT THIS DOES
    # one headless engine call; prints its output; returns (exit code, output)

    command = [godotPath(), "--headless", "--path", str(projectDir)] + arguments
    print("[%s] %s" % (label, " ".join(arguments)))
    started = time.time()
    try:
        result = subprocess.run(command, cwd=str(projectDir), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeLimit)
    except subprocess.TimeoutExpired:
        print("[%s] TIMED OUT after %d s" % (label, timeLimit))
        return 124, ""
    print(result.stdout.strip())
    print("[%s] exit %d after %.0f s" % (label, result.returncode, time.time() - started))
    return result.returncode, result.stdout


def nextVersion():
    ### WHAT THIS DOES
    # highest vNNN of any exe or apk in builds/ plus one (v001 for an empty folder)

    highest = 0

    buildsDir.mkdir(exist_ok=True)
    print("builds/ holds:")
    for item in sorted(buildsDir.iterdir()):
        print("  %s  %d bytes" % (item.name, item.stat().st_size))
        found = re.search(r"_v(\d+)\.(exe|apk)$", item.name)
        if found:
            highest = max(highest, int(found.group(1)))
    return highest + 1


def otherGodotCount():
    # how many Godot processes are already running (a slow or retried export is explicable then)
    try:
        listing = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Godot*"], stdout=subprocess.PIPE, text=True, errors="replace").stdout
    except OSError:
        return -1
    return len([line for line in listing.splitlines() if line.lower().startswith("godot")])


def clearStrayTmp(outPath):
    # an interrupted embed leaves <out>.tmp (and sometimes <out>.tmp.*) next to the output - only ours
    for stray in buildsDir.glob(outPath.name + ".tmp*"):
        print("clearing stray %s" % stray.name)
        stray.unlink()


def exportOne(mode, preset, outPath):
    ### WHAT THIS DOES
    # exports one preset to outPath, retrying when the shared temp pack was held; true when the file is there

    for attempt in range(1, exportTries + 1):
        clearStrayTmp(outPath)
        code, output = runEngine([mode, preset, str(outPath)], "%s try %d" % (preset, attempt))
        produced = outPath.exists() and outPath.stat().st_size > 0
        if code == 0 and produced:
            return True
        if attempt < exportTries and retryPattern.search(output):
            print("held temp pack - retrying in %d s" % retryWaitSeconds)
            time.sleep(retryWaitSeconds)
            continue
        if produced:
            # a failed export must not leave a half-made build behind under a real version name
            print("export failed - removing the incomplete %s" % outPath.name)
            outPath.unlink()
        clearStrayTmp(outPath)
        return False
    return False


def main():
    ### WHAT THIS DOES
    # version, import, exe, apk, sizes

    version = nextVersion()
    exePath = buildsDir / ("%s%03d.exe" % (buildPrefix, version))
    apkPath = buildsDir / ("%s%03d.apk" % (buildPrefix, version))

    # never overwrite
    for target in (exePath, apkPath):
        if target.exists():
            print("REFUSING: %s already exists" % target)
            return 2
    print("building v%03d (other Godot processes running: %d)" % (version, otherGodotCount()))

    # import pass, its errors counted on their own
    code, output = runEngine(["--import"], "import")
    importErrors = len([line for line in output.splitlines() if "ERROR" in line])
    print("import: exit %d, %d ERROR line(s)" % (code, importErrors))
    if code != 0:
        print("BUILD FAILED at import")
        return 1

    # the exe first, then the apk
    if not exportOne("--export-release", windowsPreset, exePath):
        print("BUILD FAILED at the Windows export")
        return 1
    if not exportOne("--export-debug", androidPreset, apkPath):
        print("BUILD FAILED at the Android export (the exe is built: %s)" % exePath)
        return 1

    # apksigner also writes <apk>.idsig (only for adb's streamed install) - builds/ holds the exe and apk only
    signatureSidecar = buildsDir / (apkPath.name + ".idsig")
    if signatureSidecar.exists():
        print("removing apksigner's %s" % signatureSidecar.name)
        signatureSidecar.unlink()

    print("BUILD DONE v%03d" % version)
    for target in (exePath, apkPath):
        print("  %s  %.1f MB (%d bytes)" % (target, target.stat().st_size / 1048576.0, target.stat().st_size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
