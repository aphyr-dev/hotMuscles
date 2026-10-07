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
- Stretching and cardio categories: kept, but contribute zero heat.
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
- Header: "This week" / greeting with the name, date range, number of workouts, total sets.
- **Body card**: front / back / both toggle, the heat for the last 7 days in the heat gradient, and
  the same 0-N slider as the workout card (it is the legend; the week remembers its own N). No
  separate target colouring: the map just runs min to max.
  Tap a muscle -> region sheet.
- Tabs under it: **Balance | Workouts**
  - **Balance**: regions ranked by how far off target, each with a bar showing effective sets vs its
    target band and an under / ok / over / missed tag. Tap -> region sheet.
  - **Workouts**: the workouts in the week (date, length, sets, a tiny body thumbnail with its own
    heat). Tap -> open it in the workout editor to change it (Save changes). Delete with an undo
    toast, not an "are you sure" box. "Save as template" on each.
- **Region sheet** (bottom sheet): sets this week, target band, how far short/over, which exercises
  contributed how much, and a "Find exercises" button that opens the exercise picker filtered to that
  muscle.
- Big "Start workout" button (reads "Resume workout - mm:ss" while one is running).

### Workout mode
- Timer, back to the week, the body card showing ONLY this workout's heat (its own 0-N).
- Exercise list: each row has a sets stepper (- n +), remove, and a **grips** checkbox on exercises
  with `forearmKind == grip` (ticked = this entry gives no forearm heat; remembered per exercise for
  next time, and stored in templates).
- "Add exercise" -> picker. "Finish workout" -> confirm -> optional "Save as template" (name it) ->
  the workout is added to the week and you land on the week with the change visibly animated.
- An exercise at **0 sets is "planned"**: shown as the ghost outline on the body, turns into real heat
  as sets are added. Whether newly added exercises start at 0 or 1 set is a setting (default: 1).
- A running workout survives closing the app.

### Exercise picker (from a workout, or from "Find exercises")
- Search box, equipment filter chips, a "show hidden" chip.
- **Favourites** (star) always listed first; **hidden** exercises never listed (unless "show hidden"),
  but still work in templates and old workouts. Star / hide via long-press or swipe on a row.
- **Multi-select**: tick several, one "Add N exercises" button.
- **Ghost preview**: the body shows the combined heat of everything ticked, as a pulsing outline
  clearly different from real heat, before anything is added.
- **Tap a muscle on the body** -> the list re-sorts to recommended exercises for that muscle (biggest
  share first, then ones that hit it without loading much else; favourites and previously used get a
  small boost; equipment chips still apply). A "for: Rear delt x" chip shows and clears the filter.
- **Templates tab**: saved templates (rename / delete), apply one -> its exercises (with their sets
  and grips settings, or at 0 sets if that setting is on) drop into the current workout.
- "rough data" marker on non-curated exercises.

### Settings
- Profile: name, body, gradient, theme.
- Heat gradient preset.
- Untouched muscles: show / hide (hide = 0-set muscles stay plain body colour).
- New exercises start at: 0 sets (planned) / 1 set.
- Default body view: front / back / both.
- Backup: export everything as JSON (copied to clipboard + saved under user://backups) and import
  from clipboard. Works the same on Android and Windows.

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
JSON files under `user://`: profile, settings, workouts (submitted + the one in progress), templates,
exercise prefs (favourite / hidden / grips memory). Saved on every change, with a version number.

## 5. Builds
`builds/hotMuscles_vNNN.exe` (Windows, portrait window ~430x930, resizable) and
`builds/hotMuscles_vNNN.apk` (Android debug-signed, installable by copying to the phone).
Only `app/`, `appData/` and the icon are exported - never `data/`, `models/`, `tools/`.

## Not in v1
3D body, rendered (3D) body pictures, per-side (left/right) tracking, reps/weight logging, online sync.
