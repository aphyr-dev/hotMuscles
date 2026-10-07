"""runGodot.py - runs the project's Godot checks the safe way (waits on the real engine, captures output)

what this offers
  python tests/runGodot.py import                  import pass (refreshes the class cache)
  python tests/runGodot.py parse                   --check-only on every .gd under app/ and tests/
  python tests/runGodot.py script <res path> [--window] [engine flags...] [-- user args...]
                                                    runs a --script driver; --window = a real window,
                                                    muted and parked off to the side; engine flags
                                                    (e.g. --resolution 1290x930) go to Godot as-is
the Godot binary comes from the GODOT4 environment variable, else the path in the tuning block
every run gets a time cap and prints its own exit code; nothing here kills a process it did not start
"""

import os
import subprocess
import sys
from pathlib import Path

### /// TUNING ///

# the engine (AGENTS.md) - override with the GODOT4 environment variable
defaultGodot = r"C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
# seconds before a run is given up on
timeLimit = 300
# where windowed runs open - far off to the side, never where the app normally opens
parkPosition = "5200,3600"

### /// PATHS ///

projectDir = Path(__file__).resolve().parent.parent


def godotPath():
    path = os.environ.get("GODOT4", defaultGodot)
    if not Path(path).exists():
        print("Godot not found at %s - set GODOT4" % path)
        sys.exit(2)
    return path


def run(arguments, label):
    ### WHAT THIS DOES
    # runs one engine call, streams its output, returns its exit code

    command = [godotPath()] + arguments
    try:
        result = subprocess.run(command, cwd=str(projectDir), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeLimit)
    except subprocess.TimeoutExpired as expired:
        output = expired.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", "replace")
        print(output)
        print("[%s] TIMED OUT after %d s (the engine process was ended by subprocess)" % (label, timeLimit))
        return 124
    print(result.stdout)
    print("[%s] exit %d" % (label, result.returncode))
    return result.returncode


def readAutoloadNames():
    # the [autoload] names from project.godot
    names = []
    inside = False
    for line in (projectDir / "project.godot").read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            inside = stripped == "[autoload]"
            continue
        if inside and "=" in stripped:
            names.append(stripped.split("=")[0].strip())
    return names


def onlyAutoloadComplaints(output, autoloadNames):
    ### WHAT THIS DOES
    # true when every compile error names an autoload (and there is at least one); a script that
    # only fails because a script it uses names an autoload prints an EMPTY "Compile Error:" - that
    # one is a follow-on of the first, not a problem of its own

    complaints = [line for line in output.splitlines() if "Compile Error" in line or "Parse Error" in line]
    namedAutoload = 0
    if len(complaints) == 0:
        return False
    for line in complaints:
        if any(("Identifier not found: %s" % name) in line for name in autoloadNames):
            namedAutoload += 1
            continue
        if line.strip().endswith("Compile Error:"):
            continue
        return False
    return namedAutoload > 0


def parseAll():
    ### WHAT THIS DOES
    # --check-only on every script we wrote; any parse error or SCRIPT ERROR fails the run

    failures = 0
    needsAutoloads = []
    autoloadNames = readAutoloadNames()
    scripts = sorted(list((projectDir / "app").rglob("*.gd")) + list((projectDir / "tests").rglob("*.gd")))
    for script in scripts:
        resPath = "res://" + script.relative_to(projectDir).as_posix()
        command = [godotPath(), "--headless", "--check-only", "--script", resPath, "--path", str(projectDir)]
        result = subprocess.run(command, cwd=str(projectDir), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeLimit)
        bad = result.returncode != 0 or "SCRIPT ERROR" in result.stdout or "Parse Error" in result.stdout or "ERROR" in result.stdout
        if bad and onlyAutoloadComplaints(result.stdout, autoloadNames):
            # --check-only runs before autoloads exist - compile these inside a booted project instead
            needsAutoloads.append(resPath)
            print("later %s  (uses autoload names, compiled in a booted project below)" % resPath)
        elif bad:
            failures += 1
            print("FAIL  %s  (exit %d)\n%s" % (resPath, result.returncode, result.stdout))
        else:
            print("ok    %s" % resPath)
    if len(needsAutoloads) > 0:
        command = [godotPath(), "--headless", "--path", str(projectDir), "--script", "res://tests/compileCheck.gd", "--"] + needsAutoloads
        result = subprocess.run(command, cwd=str(projectDir), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=timeLimit)
        print(result.stdout.strip())
        if result.returncode != 0 or "COMPILE ALL OK" not in result.stdout or "SCRIPT ERROR" in result.stdout:
            failures += 1
            print("FAIL  compile check of autoload users (exit %d)" % result.returncode)
    print("parse: %d script(s), %d failure(s)" % (len(scripts), failures))
    if failures > 0:
        return 1
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    mode = sys.argv[1]
    if mode == "import":
        return run(["--headless", "--import", "--path", str(projectDir)], "import")
    if mode == "parse":
        return parseAll()
    if mode == "script":
        rest = sys.argv[2:]
        userArgs = []
        if "--" in rest:
            cut = rest.index("--")
            userArgs = rest[cut + 1:]
            rest = rest[:cut]
        windowed = "--window" in rest
        others = [item for item in rest if item != "--window"]
        scriptPath = others[0]
        engineExtras = others[1:]
        arguments = []
        if windowed:
            arguments += ["--audio-driver", "Dummy", "--position", parkPosition]
        else:
            arguments += ["--headless"]
        arguments += engineExtras
        arguments += ["--path", str(projectDir), "--script", scriptPath]
        if len(userArgs) > 0:
            arguments += ["--"] + userArgs
        return run(arguments, scriptPath)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
