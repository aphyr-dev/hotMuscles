# App spec - hotMuscles v1

Everything the owner agreed in the planning chat (2026-10-04). Where this says "default", the owner
did not pick and a sensible default was stated to them; keep it unless they say otherwise.

## What it is

A phone app (Android first, plus a Windows exe of the same app) for logging gym workouts and seeing
which muscles got worked as a heatmap on a flat 2D body, front and back. The goal is balance: spot
muscles that are overloaded or missed across the week.

Portrait phone layout only. Touch-first: everything must feel good with a finger, and still work with
a mouse on the Windows build.

---

## 1. Data

### Muscles (`appData/muscles.json`)
30 regions, each with: `id`, `name`, `group`, `views` (front/back), weekly target band `[low, high]`
in effective sets, and per body (male/female) x view (front/back): a baked region map
(`appData/bodyMaps/`) and simplified tap shapes per side (l/r), all made from
`data/muscleShapes/muscleShapes.json` at build time. Cosmetic parts (head, hair, hands, feet, ankles,
knees) are drawn plain and never heat up.

Region ids: neck, upperTraps, midTraps, lowerTraps, rhomboids, frontDelt, sideDelt, rearDelt,
rotatorCuff, lats, upperChest, lowerChest, serratus, biceps, triceps, forearms, upperAbs, lowerAbs,
obliques, lowerBack, hipFlexors, glutes, gluteMed, outerQuad, midQuad, innerQuad, adductors,
hamstrings, calves, tibialis.

Default weekly target bands: big muscles (chest halves, lats, quads parts, hamstrings, glutes) ~10-20
total per muscle group, split sensibly across sub-regions; small muscles (delts, arms, calves, abs
parts, traps parts) ~6-12; minor ones (neck, tibialis, serratus, rotator cuff, hip flexors) ~3-8.
All in one table at the top of the builder script so the owner can tune them.

### Exercises (`appData/exercises.json`)
Built from `data/freeExerciseDb/dist/exercises.json` (876 exercises: name, equipment, category,
level, mechanic, force, primary + secondary muscles from 17 coarse groups). Each becomes:
`id`, `name`, `equipment`, `category`, `targets: [{region, share}]`, `forearmKind` (none / grip /
direct), `curated` (bool).

- `share` = how many sets one set of this exercise counts as for that region (1.0 = a full set).
- **Auto conversion** (all exercises): primary group weight 1.0, secondary 0.5, spread over regions
  by a default table (tuning values at the top), e.g. shoulders -> frontDelt 0.5 / sideDelt 0.3 /
  rearDelt 0.2; chest -> lowerChest 0.7 / upperChest 0.3; middle back -> midTraps 0.5 / rhomboids 0.5;
  traps -> upperTraps 0.7 / midTraps 0.3; quadriceps -> midQuad 0.4 / outerQuad 0.35 / innerQuad 0.25;
  abdominals -> upperAbs 0.6 / lowerAbs 0.4; abductors -> gluteMed; lats -> lats; lower back -> lowerBack.
- **Curated** (`tools/appData/curatedExercises.json`): ~40 common gym lifts with hand-set shares that
  override the auto conversion (bench, incline press, flyes, push-ups, dips, OHP, DB press, lateral
  raise, face pull, reverse fly, rows, pulldown, pull-up, shrug, curls, hammer curl, pushdown,
  skullcrusher, squat, front squat, deadlift, RDL, lunges, leg press, leg curl, leg extension, hip
  thrust, abductor/adductor machine, back extension, calf raises, crunches, plank, hanging leg raise,
  Russian twist, side bend, ...). It may also ADD exercises the database lacks (at least a tibialis
  raise, a Y-raise for lower traps). Regions the auto table cannot reach (rotatorCuff, serratus,
  obliques, hipFlexors, lowerTraps, tibialis) must be reachable through curated ones.
- Non-curated exercises show a small "rough data" marker in lists.
- Stretching and cardio categories: kept, but contribute zero muscle heat. Cardio is logged in
  minutes and an effort instead of sets (see Cardio below); `tools/appData/cardio.json` gives every
  cardio exercise its default effort and adds 12 common activities (outdoor run, brisk walk, hike,
  sprint intervals, laps, HIIT circuit, air bike, spin class, team game, racket sport, dance class,
  boxing bag).
- Sport exercises the preset research named that the database lacked were added too (Nordic curl,
  Copenhagen plank, hangboard hang, dead hang, single-leg RDL, clamshell, rotational med-ball throw,
  single-leg calf raise, prone Y-T-W).
- `forearmKind`: `grip` where the forearm work is holding on (deadlifts, rows, pulldowns, pull-ups,
  shrugs, carries...), `direct` where it is wrist/elbow work (wrist curls, hammer/reverse curls),
  `none` otherwise. Drives the grips checkbox (below).
- Left/right are counted together (a single-arm row is just sets of rows).

### Heat maths
Effective sets per region = sum over logged exercises of `sets x share`. A grips-on entry drops its
forearm share. Week = rolling last 7 days of submitted workouts (not Monday-Sunday).

---

## 2. Screens

### First launch: profile setup
Shown once, before anything else (and editable later from Settings):
- name
- body: male / female (which drawing is used everywhere)
- preferred heat gradient (see 3)
- app colour theme (see 3)
Big, friendly, few steps, a live preview of the body in the chosen gradient and theme.

### Home = the week
- **Day | Week | Month | Year** chips under the header (owner, 2026-10-10; remembered). Day = since
  local midnight, raw sets; Week = the rolling 7 days; Month (30 days) and Year (365 days) show the
  AVERAGE sets per week (over the weeks since the first workout ever, at most the whole period), so the
  0-N slider is always the weekly scale. Every switch replays the light-up over exactly 3 s. The day
  view lists only the muscles worked today with "% of week"; the year view's Workouts tab has one row
  per month with its average week on a small body.
- Header: "This week" / greeting with the name, date range, number of workouts, total sets (and cardio
  minutes when there are any).
- **Body card**: front / back / both toggle, the heat for the last 7 days in the heat gradient, and
  the same 0-N slider as the workout card (it is the legend; the week remembers its own N). No
  separate target colouring: the map just runs min to max.
  Tap a muscle -> region sheet.
- **One-tap overlays** under the body (owner, 2026-10-10), each chip shown only when it has something
  to show, both remembered, both can be on together:
  - **Targets** (a target preset is on): each muscle drawn as its share of its target (at target = the
    hot end; muscles without a target stay plain), title "Sets vs your targets", the hint counts the
    muscles on target, the balance rows use the targets (over = more than 2x), the region sheet shows
    "your target".
  - **Cardio** (once any cardio was logged, per the research): red (hard cardio) and blue (easy cardio)
    vessel networks over the body, each as bright as its minutes are of the weekly target (capped at
    full), a pulse running along each lit one and a beating heart on the front; the figure dims a
    little under them. The hint gives "Easy x/y min · Hard x/y min"; the Balance tab gets a cardio panel
    with both bars, the health line (easy + 2 x hard against the WHO 150, extra benefit at 300) and the
    note "Colours are a code, not anatomy". Month / year average the minutes per week like the sets.
- Tabs under it: **Balance | Workouts** (the Balance tab starts with a targets line: which presets
  are on and a button to the Targets screen)
  - **Balance**: regions ranked by how far off target, each with a bar showing effective sets vs its
    target band and an under / ok / over / missed tag. Tap -> region sheet.
  - **Workouts**: the workouts in the week (date, length, sets, a tiny body thumbnail with its own
    heat). Tap -> open it in the workout editor to change it (Save changes). Delete with an undo
    toast, not an "are you sure" box. "Save as template" on each.
- **Region sheet** (bottom sheet): sets this week, target band, how far short/over, which exercises
  contributed how much, and a "Find exercises" button that opens the exercise picker filtered to that
  muscle.
- Big "Start workout" button (reads "Resume workout - mm:ss" while one is running).
- **Week replay on start** (owner, 2026-10-09): opening the app (no workout running) empties the body,
  then replays the week workout by workout (oldest first), muscle by muscle from the top of the body
  down; each muscle flashes as its heat lands and each workout pulses as a whole at its end. The card
  title names the workout ("Wed 7 Oct · 2/3"). Fits in ~4.5 s; a tap on the body skips it.

### Workout mode
- Timer, back to the week, the body card showing ONLY this workout's heat (its own 0-N).
- A **"+ Week" chip** on the body card (owner, 2026-10-07) adds the last 7 days of finished workouts
  to the body, on the week's own 0-N; remembered between workouts.
- The exercise list shows the **newest exercise on top** (owner, 2026-10-07); older ones move down.
- Exercise list: each row has a sets stepper (- n +), remove, and a **grips** checkbox on exercises
  with `forearmKind == grip` (ticked = this entry gives no forearm heat; remembered per exercise for
  next time, and stored in templates).
- "Add exercise" -> picker. "Finish workout" -> confirm -> optional "Save as template" (name it) ->
  the workout is added to the week and you land on the week with the change visibly animated.
- An exercise at **0 sets is "planned"**: shown as the ghost outline on the body, turns into real heat
  as sets are added. Whether newly added exercises start at 0 or 1 set is a setting (default: 1).
- A running workout survives closing the app.
- **Cardio rows** (owner, 2026-10-10, model from the research): a cardio exercise logs minutes (a
  stepper in steps of 5, starting at 20 or 0 by the "new exercises start at" setting) and how hard it
  felt: **Easy** (could chat in full sentences, zone 1), **Hard** (short phrases, zone 2), **Very hard**
  (a word or two, zone 3), each with its talk-test hint under the chips; the effort is remembered per
  exercise. Easy minutes light the blue (easy cardio), hard and very hard the red (hard cardio).
  Cardio gives no muscle heat; strength sets never count as cardio. Minutes alone are enough to finish
  a workout; an entry with 0 sets and 0 minutes is planned and dropped on finish.

### Exercise picker (from a workout, or from "Find exercises")
- Search box, equipment filter chips, a "show hidden" chip.
- **"Filter by unused" chip** (owner, 2026-10-09): exercises for the muscles still at 0 sets (last 7
  days + this workout) go first, the most share on them first; nothing is dropped. It and a tapped
  muscle both set the order, so turning one on clears the other.
- **Favourites** (star) always listed first; **hidden** exercises never listed (unless "show hidden"),
  but still work in templates and old workouts. Star / hide via long-press or swipe on a row.
- **Multi-select**: tick several, one "Add N exercises" button.
- **Ghost preview**: the body shows the combined heat of everything ticked, as a pulsing outline
  clearly different from real heat, before anything is added.
- **Tap a muscle on the body** -> the list re-sorts to recommended exercises for that muscle (biggest
  share first, then ones that hit it without loading much else; favourites and previously used get a
  small boost; equipment chips still apply). A "for: Rear delt x" chip shows and clears the filter.
- **Several muscles** (owner, 2026-10-10): hold a muscle on the body to start picking several; then
  a tap or a hold adds or drops more ("for: lats + biceps x", 3+ = "for: N muscles"); the order is
  the share on all of them summed. A plain tap with nothing held still picks just that one.
- **"Below target" chip** (shown while a target preset is on): exercises for the muscles furthest
  below their target (last 7 days + this workout) first. It, Filter by unused and picked muscles all
  set the order, so turning one on clears the others.
- **Preset tags**: an exercise the research names as key for a switched-on preset carries that
  preset's name as a tag (e.g. "Basketball" and "mew2" together).
- **Templates tab**: saved templates (rename / delete), apply one -> its exercises (with their sets
  and grips settings, or at 0 sets if that setting is on) drop into the current workout.
- "rough data" marker on non-curated exercises.

### Settings
- Profile: name, body, gradient, theme.
- Heat gradient preset.
- Untouched muscles: show / hide (hide = 0-set muscles stay plain body colour).
- New exercises start at: 0 sets (planned) / 1 set.
- Default body view: front / back / both.
- Look: **Style** (Modern | Frutiger) and **Colours** (10 palettes). Styles and palettes are modules
  in `app/looks/` (one file each, registered in `looks.gd`); a missing one falls back to Modern / Ember.
- Targets: which presets are on, and a button to the Targets screen.
- Backup: export everything as JSON (copied to clipboard + saved under user://backups) and import
  from clipboard. Works the same on Android and Windows.

### Targets screen (owner, 2026-10-10)
- **Target presets**, each researched by its own agent (sources in `data/sources.md`): sports
  Marathon, Sprinting, Basketball, Football (soccer), Swimming, Cycling, Climbing, Boxing / MMA, and
  physiques V-taper, mew2 (Mewtwo build), Hourglass. Each = a weekly sets offset per muscle (-12..+10)
  from the **baseline** (the home slider, default 12), weekly cardio minutes, and its key exercises.
- Any number on at once; per muscle the target is the **highest** of max(0, baseline + offset) over
  the presets that are on; cardio targets are the highest preset or the default (90 easy + 30 hard =
  the WHO 150), whichever is more.
- Sections Sports / Physique / Yours; tap toggles, a preview body shows the combined targets.
- **Your own**: "+ New target", or hold any preset to copy it; the editor has a stepper per muscle by
  group (showing the resulting sets a week), easy / hard cardio minutes, Save (a new one is switched
  on), Delete with undo.

---

## 3. Look and feel

- Flat MuscleMap-style body (`appData/muscles.json` shapes), dark-friendly.
- **Heat gradients** (each a list of colour stops, like a Blender colour ramp; adding one = adding a
  list): **Infrared** (black -> purple -> blue -> cyan -> green -> yellow -> red, the owner's ramp),
  **Scarlet** (nothing -> bright scarlet, single hue), **Ember** (dark ember -> orange -> yellow ->
  near white). Default: Infrared.
- **0-N range slider** on the body card: the gradient spans 0 to N effective sets, N from 1 to 20,
  remembered separately for the week view and the workout view. Above N clips to the top colour.
- **App colour themes**: a few (e.g. Ember - charcoal + orange, Ocean - navy + cyan, Forest -
  dark green + lime, Light - light grey + blue). One theme = background, surface, text, accent colours
  applied everywhere.
- Body view: front / back / both side by side; pinch-zoom and pan, double-tap to reset; tap a muscle.

### Touch
- **Kinetic (inertia) scrolling** on every list: drag with finger or mouse, the list keeps gliding
  and slows with friction, soft overscroll bounce at the ends, mouse wheel on desktop.
- A drag never triggers the button under the finger (tap vs drag threshold).
- Big hit targets (>= 48 px at phone scale), bottom sheets that swipe down to close, swipe actions on
  rows, long-press menus, small press feedback animations.

---

## 4. Persistence
JSON files under `user://`: profile, settings (incl. the home period, the presets that are on, your
own presets and the two overlays), workouts (submitted + the one in progress; cardio entries carry
minutes + effort), templates, exercise prefs (favourite / hidden / grips memory / last cardio effort).
Saved on every change, with a version number.

## 5. Builds
`builds/hotMuscles_vNNN.exe` (Windows, portrait window ~430x930, resizable) and
`builds/hotMuscles_vNNN.apk` (Android debug-signed, installable by copying to the phone). Every build
is a new version, and `builds/` keeps every apk there ever was (owner, 2026-10-10).
Only `app/`, `appData/` and the icon are exported - never `data/`, `models/`, `tools/`.

## Not in v1
3D body, rendered (3D) body pictures, per-side (left/right) tracking, reps/weight logging, online sync.
