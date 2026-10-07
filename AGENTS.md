# hotMuscles - gym heatmap app

The app is called **hotMuscles** everywhere: launcher label, window title, build files, the project
folder, the GitHub repo and the Android package id `com.aphyr.hotmuscles`. The package id changed
from builds v001-v003, so v004+ installs as a separate app on the phone (move saves with a backup).
Backup import checks a file's sections, not the app name stamped in it, so older backups still import.
No older name of the app appears anywhere in the project; keep it that way.

A personal phone app (Godot 4.3): log the exercises of a workout, see a heatmap of which muscles
got worked, balance the week. The owner is not a programmer: report in plain words (global
CLAUDE.md "How to talk to me" and "Working together").

This file is canonical. `CLAUDE.md` only points here.

## Map

| Path | What |
|---|---|
| `docs/appSpec.md` | **the full app spec** - every agreed feature, screen and rule. Read before building anything |
| `docs/hotMusclesArchitecture_v3.pdf` | illustrated architecture guide, naming the real file and function behind every part; source `docs/architecture/architectureV3.html` + `img/` (reprint command in its header) - update it when the app's shape changes or a quoted file or function is renamed |
| `app/` | the Godot app (each file opens with what it offers): `core/` = autoloads AppData, Storage, AppTheme + static HeatEngine, HeatGradients; `components/` = BodyView, KineticScroll, HeatRangeSlider |
| `app/main.gd` | AppRoot: screen stack + slides, bottom sheets, toast, Android back / Escape, safe area |
| `app/screens/` | WeekScreen (home), WorkoutScreen (live + editor), PickerScreen, SettingsScreen, ProfileSetup; all extend AppScreen |
| `app/ui/` | shared widgets: Ui (static builders + text formats), TapRow, BottomSheet, Toast, BodyCard, Segmented, HScrollStrip, BalanceBar, GradientBar, AppIcon |
| `appData/` | runtime data the app loads (built by `tools/appData/`, do not hand-edit): `exercises.json`, `muscles.json` (regions, tap shapes, centres) and `bodyMaps/<body>_<view>.png` - the baked body pictures the app draws (one region id per texel, so they ship byte for byte: `importer="keep"`, never a texture import) |
| `tests/` | checks and screenshot drivers, all run through `tests/runGodot.py` (see Checks) - never exported |
| `tools/muscleCarve/` | turns MuscleMap's drawings into our 30 muscle regions -> `data/muscleShapes/muscleShapes.json` (own README) |
| `tools/appData/` | builds `appData/` from the carved shapes + the exercise database + our curated exercise shares |
| `data/` | source data and previews (ignored by Godot via `.gdignore`). `data/sources.md` lists upstream versions |
| `data/freeExerciseDb/` | third-party exercise database clone, NOT in our history - restore it with the steps in `data/sources.md` |
| `models/muscleMap/source/` | the body drawings' source files (MIT; true upstream in `data/sources.md`), ignored by Godot, never exported |
| `builds/` | finished exe + apk, not in history |
| `export_presets.cfg` | "Windows Desktop" (one-file exe) and "Android" (com.aphyr.hotmuscles, portrait, arm64, VIBRATE only, immersive); both ship `app/`, `appData/*.json`, `appData/bodyMaps/*.png` and `icon.svg` only |
| `tools/build/` | `buildAll.py` (next vNNN exe then apk) and `checkBuild.py` (opens a build and proves what is inside) |
| `tools/icon/`, `icons/` | `makeIcon.py` draws `icon.svg` from the carved muscle shapes (`data/muscleShapes`) and rasterizes the launcher / exe / adaptive pngs into `icons/` (build-time only, not shipped) |

## Hard rules

- Godot 4.3 at `C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe` (real engine; the
  `_console` exe is a wrapper). Read the `godot` skill index first, then only the module the task needs;
  `references/gdscript-language.md` before finishing any GDScript.
- Owner code style (global CLAUDE.md): camelCase everything, tuning values at the top of each file
  with a plain comment, no ternaries, one thing per line, `### /// SECTION ///` headers.
- Everything shown to the owner runs on a plain launch. No switched-off features, no hidden
  fallbacks to old code (global CLAUDE.md "No switched-off work").
- Commit with explicit file paths (never `git add -A` / `.`), small `wip <lane>:` checkpoints while
  working, the attribution line from the session. Identity is set per repo: aphyr with the GitHub
  no-reply email `338727094+aphyr-dev@users.noreply.github.com`. NEVER commit with the owner's real email, a real name or any handle but aphyr:
  check `git config user.email` before the first commit of a session.
- Builds: `builds/hotMuscles_vNNN.exe` and `builds/hotMuscles_vNNN.apk` (any older `*_vNNN` build
  still counts) share ONE version counter. List `builds/` first, always upversion, never overwrite. Export every exe BEFORE the apk
  from the same `.godot` cache (an apk export bloats the next exe - godot skill, android-export).
  Android: `--export-debug "Android"` (no release keystore on this box).
- Automated windowed runs: muted (`--audio-driver Dummy`) and parked far off to the side.
  Never kill a Godot process you did not start.

## Data flow

```
MuscleMap swift ──muscleCarve──> data/muscleShapes/muscleShapes.json ─┐
freeExerciseDb dist/exercises.json ───────────────────────────────────┼─ tools/appData ─> appData/*.json ─────> app
tools/appData/curatedExercises.json (hand-tuned shares) ──────────────┘    └──> appData/bodyMaps/*.png ─> app
```

`tools/appData/bakeBodyMaps.py` (called by `buildAppData.py`) bakes each body x view into a lossless region
map png (R = region id, G = ghost dash position, B = distance to the region edge) plus tap shapes of at
most 32 corners; the app draws each figure as one rect through `app/components/bodyMap.gdshader` and
hit tests only the tap shapes. No outlines are built or triangulated in the app; a missing map is an error.

The app never reads `data/` (Godot ignores it). Rebuild `appData/` after changing any source.

## Checks

Python at `C:\Users\Aphyr\AppData\Local\Python\bin\python.exe`; Godot path from `GODOT4` or the
default at the top of `tests/runGodot.py`. Windowed runs are muted and parked by the runner.

```
python tools/appData/buildAppData.py        # rebuild appData/ (fails loudly on bad data)
python tests/testBuildAppData.py            # the builder's failure checks
python tests/runGodot.py import             # after adding files or class_names
python tests/runGodot.py parse              # every .gd compiles (autoload users compiled in a booted run)
python tests/runGodot.py script res://tests/testHeatEngine.gd
python tests/runGodot.py script res://tests/testStorage.gd
python tests/runGodot.py script res://tests/testKineticScroll.gd --window
python tests/runGodot.py script res://tests/testFlows.gd                 # every screen's flows, real numbers
python tests/runGodot.py script res://tests/testTouchUi.gd --window      # synthetic finger: tap/drag/swipe/sheets/back
python tests/runGodot.py script res://tests/testStartup.gd --window      # start time + worst frame of every everyday step
python tests/runGodot.py script res://tests/shotBodyView.gd --window --resolution 1290x930 -- <outFolder>
python tests/runGodot.py script res://tests/shotPhase2.gd --window -- <outFolder> [ember|light|ocean|setup]
```

App tests use a throwaway `user://_test...` folder (deleted at the end), never the real saves.

`testStartup.gd` boots the real `main.tscn` and fails when the app's own start (main scene entering
the tree -> first drawn frame) passes 500 ms, on a first launch or on a seeded week, or when any
everyday step (setup, week, start workout, picker open / filter / search / star, finish) has a frame
gap over 40 ms (the aim is 33 ms; v003 measured 27-32 ms worst). Frame times only mean something on
a quiet PC: check the CPU first, and run it again before believing one failed step. It prints the
whole launch and the script loading too (not checked: Godot opening its window takes ~2-2.5 s here,
compiling the app's scripts ~0.6 s from source, ~0.45 s in the exe).
Keeping frames short: a list builds the rows that fit on screen at once and the rest a few per frame
(picker, week balance), rows are updated or moved instead of made again, a new screen is built in one
frame and slides in from the next (`main.gd` push), and several values are saved in one write
(`Storage.setProfileValues`, `Storage.addEntries`) - each file write costs ~4 ms here.
In `--script` tests reach autoloads via `root.get_node("/root/Storage")` and check screen types by
`get_script().get_global_name()`: naming an app class_name in a test prints compile noise.

## Builds

```
python tools/build/buildAll.py                       # next vNNN: import, exe, then apk; never overwrites
python tools/build/checkBuild.py builds/hotMuscles_vNNN.exe builds/hotMuscles_vNNN.apk
python tools/icon/makeIcon.py                        # only after changing the icon look
```

`buildAll.py` prints the engine output - send it to the scratchpad, never into `builds/` (that folder holds
the exe and apk only; the script removes apksigner's `.idsig`). `checkBuild.py` fails on any file from
tests/tools/docs/data/models/renders/mockups/icons in a build, a missing `appData/*.json`, a body map that is
missing or not byte for byte the project's file (or ships as an imported texture), or this PC's user
name / "scratchpad" / "C:/" inside any shipped entry (scripts decompressed first), and runs `aapt2 dump
badging` (label must be hotMuscles, package id com.aphyr.hotmuscles) + `apksigner verify` on the apk. It also STARTS
the exe three times on a throwaway APPDATA (muted, parked, only its own process ever stopped): first
launch, second launch, a seeded week. It fails when the log's "main scene -> first frame" passes 2000 ms
on the first launch (the graphics driver prepares its shaders once, ~1.1 s here) or 500 ms after that,
when a run passes 30 s or logs an error, or when the window title is not `config/name`. Bump
`application/config/version` in project.godot together with
`version/name` + `version/code` (Android) and the two `application/*_version` (Windows) in the presets.

To look at the BUILT exe without touching the real saves: set `APPDATA` to an empty folder of your own in
the shell that launches it (the exe then keeps `user://` there), and record frames with Movie Maker:
`hotMuscles_vNNN.exe --audio-driver Dummy --position 5200,3600 --write-movie <folder>/frame.png
--fixed-fps 30 --quit-after 75` (writes frame00000000.png...). The log line `first frame drawn N ms after
launch: scripts loaded in N ms, main scene -> first frame N ms` (from `app/main.gd`) times the start.
Its log lands in `<that folder>/Godot/app_userdata/hotMuscles/logs/godot.log`.
