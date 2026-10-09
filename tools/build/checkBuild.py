"""checkBuild.py - opens a finished exe / apk and proves what is inside it

what this offers
  python tools/build/checkBuild.py builds/hotMuscles_v003.exe builds/hotMuscles_v003.apk
  for each file:
    - lists the app's own files inside it (the pack embedded in the exe, the assets/ folder of the apk)
    - FAILS if anything from a folder that must never ship is there (tests, tools, docs, data, models,
      renders, mockups, icons, builds) or if appData/exercises.json / muscles.json / targets.json is missing
    - FAILS unless every body map (appData/bodyMaps/*.png) ships byte for byte the same as the project's
      file - the maps hold region ids per texel, so any re-compression would break taps and colours -
      and if any imported texture copy of a body map ships
    - FAILS if a private string ships: this PC's user name, "scratchpad", "C:/" or "C:\\" - searched in
      every pack entry, with scripts decompressed first (they ship as zstd token streams, and names
      inside them are stored as utf-32 with every byte XOR 0xB6, so a plain grep finds nothing)
  for the exe also: it is STARTED three times on a throwaway user folder (muted, parked far off
  screen, its own APPDATA so the real saves are never touched; only this script's own process is
  ever stopped): a first launch, a second launch, and a launch on a seeded week. From the log line
  "first frame drawn ... main scene -> first frame N ms" it FAILS when the app's own share N passes
  coldShareLimitMs on the first launch (the graphics driver prepares its shaders once) or
  warmShareLimitMs after that, when a run takes longer than runLimitSeconds, exits with an error,
  logs an ERROR (the shader-cache "err != OK" lines every launch prints are left out), or when the
  window title is not the app name from project.godot
  for the apk also: aapt2 dump badging (package, label, version, target sdk, permissions, native code) -
  FAILS unless the launcher label is the app name below and the package id is unchanged -
  and apksigner verify, from the Android SDK build-tools
  prints CHECK PASS / CHECK FAIL at the end
"""

import ctypes
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zipfile
from compression import zstd
from pathlib import Path

### /// TUNING ///

# top folders that must never be inside a build
forbiddenFolders = ["tests", "tools", "docs", "data", "models", "renders", "mockups", "icons", "builds", "review"]
# files that must be inside every build
requiredFiles = ["appData/exercises.json", "appData/muscles.json", "appData/targets.json"]
# folder of files that must ship byte for byte identical to the project's copy (every png in it)
identicalFolder = "appData/bodyMaps"
# the name the phone shows under the icon, and the package id (unchanged since v001, so a new apk
# installs over the old one and keeps its saves)
appLabel = "hotMuscles"
packageId = "com.aphyr.hotmuscles"
# the exe start check: the app's own share (main scene -> first drawn frame) on a first launch and
# on later ones (ms), the longest one run may take (s), and the frames each run draws before it quits
coldShareLimitMs = 2000
warmShareLimitMs = 500
runLimitSeconds = 30
runFrames = 120
# where the exe runs while checked (far off screen, like every automated run on this PC)
parkedPosition = "5200,3600"
# private strings - this PC's user name is added at run time
privateStrings = ["scratchpad", "C:/", "C:\\"]
# Android SDK build-tools folder (aapt2, apksigner)
buildToolsDir = Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "build-tools" / "34.0.0"
# Java for apksigner
javaHome = Path(os.environ.get("LOCALAPPDATA", "")) / "Java" / "jdk-17.0.19+10"

### /// STATE ///

failures = []


def fail(message):
    failures.append(message)
    print("FAIL  " + message)


### /// READING THE PACKS ///

def readPck(blob, start):
    ### WHAT THIS DOES
    # Godot 4 pck (format 2) starting at `start` in blob -> {res path: entry bytes}

    entries = {}

    magic, formatVersion, major, minor, patch, flags, fileBase = struct.unpack_from("<4sIIIIIQ", blob, start)
    if magic != b"GDPC":
        raise ValueError("no GDPC header at %d" % start)
    print("pack: format %d, made by Godot %d.%d.%d, flags %d" % (formatVersion, major, minor, patch, flags))
    if flags & 1:
        raise ValueError("encrypted pack directory - cannot check")
    cursor = start + 4 + 4 * 5 + 8 + 16 * 4
    count = struct.unpack_from("<I", blob, cursor)[0]
    cursor += 4

    # the directory, then each file's bytes
    for _ in range(count):
        nameLength = struct.unpack_from("<I", blob, cursor)[0]
        cursor += 4
        name = blob[cursor:cursor + nameLength].rstrip(b"\0").decode("utf-8")
        cursor += nameLength
        offset, size = struct.unpack_from("<QQ", blob, cursor)
        cursor += 16 + 16
        entryFlags = struct.unpack_from("<I", blob, cursor)[0]
        cursor += 4
        base = 0
        if flags & 2:
            base = start + fileBase
        if entryFlags & 1:
            fail("%s is encrypted - cannot check" % name)
            continue
        entries[name] = blob[base + offset:base + offset + size]
    return entries


def exeEntries(path):
    # the pack glued to the end of the exe: ... pack, its size (8 bytes), "GDPC"
    blob = path.read_bytes()
    if blob[-4:] != b"GDPC":
        raise ValueError("no embedded pack at the end of %s" % path.name)
    packSize = struct.unpack_from("<Q", blob, len(blob) - 12)[0]
    return readPck(blob, len(blob) - 12 - packSize)


def apkEntries(path):
    # the apk keeps the app's files as zip entries under assets/
    entries = {}
    with zipfile.ZipFile(path) as archive:
        for info in archive.infolist():
            if info.filename.startswith("assets/"):
                entries["res://" + info.filename[len("assets/"):]] = archive.read(info)
    return entries


### /// CHECKS ///

def scriptBody(data):
    # a compiled script: "GDSC", version, decompressed size (0 = not compressed), then the body
    if data[:4] != b"GDSC":
        return data
    size = struct.unpack_from("<I", data, 8)[0]
    if size == 0:
        return data[12:]
    return zstd.decompress(data[12:])


def checkEntries(label, entries):
    ### WHAT THIS DOES
    # forbidden folders, required files, private strings, and a calibration that the decoding works

    names = sorted(entries.keys())
    userName = os.environ.get("USERNAME", "")
    needles = list(privateStrings)
    scripts = 0

    if userName != "":
        needles.append(userName)
    print("%s: %d entries" % (label, len(names)))
    for name in names:
        print("  %8d  %s" % (len(entries[name]), name))

    # forbidden folders and required files
    for name in names:
        top = name[len("res://"):].split("/")[0]
        if top in forbiddenFolders:
            fail("%s ships %s" % (label, name))
    for required in requiredFiles:
        if ("res://" + required) not in entries:
            fail("%s is missing %s" % (label, required))

    # body maps: present, byte for byte, and never as an imported (re-encoded) texture
    projectDir = Path(__file__).resolve().parent.parent.parent
    sources = sorted((projectDir / identicalFolder).glob("*.png"))
    if len(sources) == 0:
        fail("no pngs in %s - nothing to compare" % identicalFolder)
    for source in sources:
        resName = "res://%s/%s" % (identicalFolder, source.name)
        if resName not in entries:
            fail("%s is missing %s" % (label, resName))
        elif entries[resName] != source.read_bytes():
            fail("%s: %s differs from the project's file" % (label, resName))
        else:
            print("%s: %s identical to the project's file (%d bytes)" % (label, resName, source.stat().st_size))
    for name in names:
        if name.startswith("res://.godot/imported/") and importedCopyOf(name, sources):
            fail("%s ships an imported copy of a body map: %s" % (label, name))

    # private strings, plain, utf-16 and the xor'd utf-32 of script identifiers
    calibrated = False
    for name in names:
        body = entries[name]
        if name.endswith(".gdc"):
            body = scriptBody(body)
            scripts += 1
            if xorName("loadAll") in body:
                calibrated = True
        for needle in needles:
            forms = [needle.encode("utf-8"), needle.encode("utf-16-le"), xorName(needle)]
            if any(form in body for form in forms):
                fail("%s: %s carries %r" % (label, name, needle))
    print("%s: %d compiled scripts searched for %s" % (label, scripts, ", ".join(repr(needle) for needle in needles)))
    if scripts == 0:
        fail("%s: no compiled scripts found - is the pack read right?" % label)
    elif not calibrated:
        fail("%s: the known name 'loadAll' was not found in any script - the decoding is wrong" % label)


def importedCopyOf(name, sources):
    # true when an imported-file name belongs to one of the body map pngs
    for source in sources:
        if ("/" + source.name + "-") in name:
            return True
    return False


def xorName(text):
    # how an identifier sits inside a 4.3 token stream
    return bytes(byte ^ 0xB6 for byte in text.encode("utf-32-le"))


def runTool(command):
    env = dict(os.environ)
    env["JAVA_HOME"] = str(javaHome)
    env["PATH"] = str(javaHome / "bin") + os.pathsep + env.get("PATH", "")
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace", env=env, shell=False)
    return result.returncode, result.stdout


def checkApkTools(path):
    ### WHAT THIS DOES
    # badging (package, label, version, sdk, permissions, native code) and the signature

    code, output = runTool([str(buildToolsDir / "aapt2.exe"), "dump", "badging", str(path)])
    keep = [line for line in output.splitlines() if re.match(r"(package|sdkVersion|targetSdkVersion|application-label:|application:|uses-permission|native-code|launchable-activity)", line)]
    print("aapt2 dump badging (exit %d):" % code)
    for line in keep:
        print("  " + line)
    permissions = re.findall(r"uses-permission: name='([^']+)'", output)
    if permissions != ["android.permission.VIBRATE"]:
        fail("apk permissions are %s, want VIBRATE only" % permissions)
    if "native-code: 'arm64-v8a'" not in output:
        fail("apk native code is not arm64-v8a only")
    if ("application-label:'%s'" % appLabel) not in output:
        fail("apk launcher label is not %s" % appLabel)
    if ("package: name='%s'" % packageId) not in output:
        fail("apk package id is not %s" % packageId)

    code, output = runTool(["cmd", "/c", str(buildToolsDir / "apksigner.bat"), "verify", "--verbose", str(path)])
    print("apksigner verify (exit %d):" % code)
    for line in output.splitlines():
        if line.startswith("Verifie") or line.startswith("Number of signers") or "DOES NOT VERIFY" in line or line.startswith("ERROR"):
            print("  " + line)
    if code != 0:
        fail("apksigner verify failed")


### /// STARTING THE EXE ///

def appName():
    # the window title and user folder name: config/name in project.godot
    projectFile = Path(__file__).resolve().parent.parent.parent / "project.godot"
    found = re.search(r'^config/name="([^"]+)"', projectFile.read_text(encoding="utf-8"), re.MULTILINE)
    return found.group(1)


def windowTitlesOf(processId):
    # titles of the visible top-level windows owned by one process (Windows only)
    titles = []
    user32 = ctypes.windll.user32
    callbackType = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def collect(handle, _unused):
        owner = ctypes.c_ulong(0)
        user32.GetWindowThreadProcessId(ctypes.c_void_p(handle), ctypes.byref(owner))
        if owner.value == processId and user32.IsWindowVisible(ctypes.c_void_p(handle)):
            buffer = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(ctypes.c_void_p(handle), buffer, 256)
            if buffer.value != "":
                titles.append(buffer.value)
        return True

    user32.EnumWindows(callbackType(collect), None)
    return titles


def seedWeek(userFolder):
    # a profile and three workouts this week, in the app's own save format
    now = time.time()
    day = 86400.0
    plans = [
        (now - 5.2 * day, 3900.0, [["Barbell_Bench_Press_-_Medium_Grip", 4], ["Incline_Dumbbell_Press", 3], ["Standing_Military_Press", 3]]),
        (now - 3.1 * day, 3300.0, [["Bent_Over_Barbell_Row", 4], ["Wide-Grip_Lat_Pulldown", 3], ["Pullups", 3]]),
        (now - 1.05 * day, 4200.0, [["Barbell_Squat", 4], ["Romanian_Deadlift", 3], ["Leg_Press", 3]]),
    ]
    submitted = []
    for index, (start, length, rows) in enumerate(plans):
        entries = [{"exerciseId": row[0], "sets": row[1], "grips": False} for row in rows]
        submitted.append({"id": "w_check_%d" % index, "startedAt": start, "endedAt": start + length, "entries": entries})
    profile = {"name": "Check", "body": "male", "gradient": "infrared", "theme": "ember", "setupDone": True}
    sections = {"profile": profile, "workouts": {"submitted": submitted, "current": None}}
    userFolder.mkdir(parents=True, exist_ok=True)
    for name in sections:
        (userFolder / (name + ".json")).write_text(json.dumps({"version": 1, "data": sections[name]}), encoding="utf-8")


def runOnce(exePath, appDataFolder, label, shareLimitMs, title):
    ### WHAT THIS DOES
    # one muted, parked launch on the throwaway APPDATA; checks the time, the log and the window title

    environment = dict(os.environ)
    environment["APPDATA"] = str(appDataFolder)
    command = [str(exePath), "--audio-driver", "Dummy", "--position", parkedPosition, "--quit-after", str(runFrames)]
    logPath = appDataFolder / "Godot" / "app_userdata" / title / "logs" / "godot.log"
    titlesSeen = set()

    started = time.time()
    process = subprocess.Popen(command, env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    while process.poll() is None:
        if time.time() - started > runLimitSeconds:
            # only ever this script's own process, by its own handle
            process.kill()
            process.wait()
            fail("%s: still running after %d s - stopped" % (label, runLimitSeconds))
            return
        for windowTitle in windowTitlesOf(process.pid):
            titlesSeen.add(windowTitle)
        time.sleep(0.05)
    seconds = time.time() - started

    # the log: the timing line, and no errors besides the shader-cache noise
    if not logPath.exists():
        fail("%s: no log at %s" % (label, logPath))
        return
    logText = logPath.read_text(encoding="utf-8", errors="replace")
    timing = re.search(r"first frame drawn (\d+) ms after launch: scripts loaded in (\d+) ms, main scene -> first frame (\d+) ms", logText)
    errors = [line for line in logText.splitlines() if "ERROR" in line and 'Condition "err != OK" is true' not in line]
    print("%s: exit %d after %.1f s, window titles %s" % (label, process.returncode, seconds, sorted(titlesSeen)))
    if timing is None:
        fail("%s: no 'first frame drawn' line in the log" % label)
    else:
        whole = int(timing.group(1))
        scripts = int(timing.group(2))
        share = int(timing.group(3))
        print("%s: whole launch %d ms, scripts loaded in %d ms, main scene -> first frame %d ms (limit %d)" % (label, whole, scripts, share, shareLimitMs))
        if share > shareLimitMs:
            fail("%s: the app's own start took %d ms, limit %d" % (label, share, shareLimitMs))
    if process.returncode != 0:
        fail("%s: exit code %d" % (label, process.returncode))
    for line in errors:
        fail("%s: log error: %s" % (label, line.strip()))
    if title not in titlesSeen:
        fail("%s: window title %s is not %s" % (label, sorted(titlesSeen), title))


def checkExeStart(exePath):
    ### WHAT THIS DOES
    # first launch, second launch, seeded week - all on one throwaway APPDATA, deleted afterwards

    title = appName()
    appDataFolder = Path(tempfile.mkdtemp(prefix="hotMuscles_checkBuild_"))
    try:
        runOnce(exePath, appDataFolder, "start 1 (first launch)", coldShareLimitMs, title)
        runOnce(exePath, appDataFolder, "start 2 (second launch)", warmShareLimitMs, title)
        seedWeek(appDataFolder / "Godot" / "app_userdata" / title)
        runOnce(exePath, appDataFolder, "start 3 (a week of workouts)", warmShareLimitMs, title)
    finally:
        shutil.rmtree(appDataFolder, ignore_errors=True)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for argument in sys.argv[1:]:
        path = Path(argument).resolve()
        print("=== %s (%d bytes)" % (path, path.stat().st_size))
        if path.suffix.lower() == ".exe":
            checkEntries(path.name, exeEntries(path))
            checkExeStart(path)
        elif path.suffix.lower() == ".apk":
            checkEntries(path.name, apkEntries(path))
            checkApkTools(path)
        else:
            fail("do not know how to check %s" % path.name)
    if len(failures) > 0:
        print("CHECK FAIL (%d)" % len(failures))
        return 1
    print("CHECK PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
