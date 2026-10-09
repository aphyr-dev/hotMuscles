extends SceneTree
## testHeatEngine.gd - headless check of the heat maths against hand-computed numbers
## what this offers: python tests/runGodot.py script res://tests/testHeatEngine.gd
## prints PASS/FAIL per check and "ALL PASS" or "N FAILURE(S)", exits 0 / 1
## shares used (from tools/appData/curatedExercises.json):
##   bench   lowerChest 1.0, upperChest 0.5, frontDelt 0.5, triceps 0.5, serratus 0.2
##   pullups lats 1.0, biceps 0.5, rhomboids 0.4, lowerTraps 0.4, rearDelt 0.3, midTraps 0.2, forearms 0.4 (grip)
##   hammer  forearms 1.0, biceps 0.7 (direct)

### /// TUNING ///

# how close a float must be to count as equal
const tolerance: float = 0.0001
# a fixed "now" so the window checks do not depend on the clock
const nowUnix: float = 1000000000.0
const day: float = 86400.0

const bench: String = "Barbell_Bench_Press_-_Medium_Grip"
const pullups: String = "Pullups"
const hammer: String = "Hammer_Curls"

var failures: int = 0
var checks: int = 0
var engine: GDScript = null
var data: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	engine = load("res://app/core/heatEngine.gd")
	data = load("res://app/core/appData.gd").new()
	var ok: bool = data.loadAll("res://appData")
	_expectTrue("app data loads", ok)
	_expectTrue("30 regions", data.regions.size() == 30)
	_expectTrue("927 exercises (12 of them the added cardio activities)", data.exercises.size() == 927)
	_expectTrue("11 target presets", data.presets.size() == 11)

	_checkShares()
	_checkEffectiveSets()
	_checkGrips()
	_checkWindow()
	_checkStatuses()
	_checkContributions()
	_checkRecommend()
	_checkUnused()
	_checkTargets()
	_checkCardio()
	_checkSearch()

	if failures == 0:
		print("ALL PASS (%d checks)" % checks)
	else:
		print("%d FAILURE(S) of %d checks" % [failures, checks])
	data.free()
	quit(mini(failures, 1))


### /// HELPERS ///

func _expectTrue(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


func _indexOfId(rows: Array, exerciseId: String) -> int:
	# where an exercise sits in a recommend list (-1 = not there)
	for index in range(rows.size()):
		if rows[index]["exercise"]["id"] == exerciseId:
			return index
	return -1


func _expectNear(label: String, got: float, want: float) -> void:
	checks += 1
	if absf(got - want) <= tolerance:
		print("PASS  %s = %.4f" % [label, got])
	else:
		failures += 1
		print("FAIL  %s = %.4f, want %.4f" % [label, got, want])


func _expectEqual(label: String, got: Variant, want: Variant) -> void:
	checks += 1
	if got == want:
		print("PASS  %s = %s" % [label, str(got)])
	else:
		failures += 1
		print("FAIL  %s = %s, want %s" % [label, str(got), str(want)])


func _entry(exerciseId: String, sets: int, grips: bool) -> Dictionary:
	return {"exerciseId": exerciseId, "sets": sets, "grips": grips}


func _workout(id: String, endedAt: float, entries: Array) -> Dictionary:
	return {"id": id, "startedAt": endedAt - 3600.0, "endedAt": endedAt, "entries": entries}


### /// CHECKS ///

func _checkShares() -> void:
	_expectNear("bench share lowerChest", data.exerciseShare(bench, "lowerChest"), 1.0)
	_expectNear("pullups share forearms", data.exerciseShare(pullups, "forearms"), 0.4)
	_expectEqual("pullups forearmKind", data.getExercise(pullups)["forearmKind"], "grip")
	_expectEqual("hammer forearmKind", data.getExercise(hammer)["forearmKind"], "direct")
	_expectTrue("stretch gives no heat", data.getExercise("Chin_To_Chest_Stretch")["targets"].size() == 0)
	_expectTrue("added tibialis raise exists", data.exerciseShare("Tibialis_Raise", "tibialis") == 1.0)


func _checkEffectiveSets() -> void:
	### WHAT THIS DOES
	# bench 3 + pullups 4 + hammer 2 (grips on, but hammer is direct so it keeps forearms)

	var entries: Array = [_entry(bench, 3, false), _entry(pullups, 4, false), _entry(hammer, 2, true)]
	var heat: Dictionary = engine.effectiveSets(entries, data.exerciseById)

	_expectNear("lowerChest 3 x 1.0", heat.get("lowerChest", 0.0), 3.0)
	_expectNear("upperChest 3 x 0.5", heat.get("upperChest", 0.0), 1.5)
	_expectNear("serratus 3 x 0.2", heat.get("serratus", 0.0), 0.6)
	_expectNear("lats 4 x 1.0", heat.get("lats", 0.0), 4.0)
	_expectNear("biceps 4 x 0.5 + 2 x 0.7", heat.get("biceps", 0.0), 3.4)
	_expectNear("forearms 4 x 0.4 + 2 x 1.0", heat.get("forearms", 0.0), 3.6)
	_expectNear("rhomboids 4 x 0.4", heat.get("rhomboids", 0.0), 1.6)
	_expectTrue("untouched region absent", not heat.has("calves"))

	# zero sets, negative sets, unknown id, stretching
	var junk: Array = [_entry(bench, 0, false), _entry(bench, -2, false), _entry("No_Such_Lift", 5, false), _entry("Chin_To_Chest_Stretch", 4, false)]
	_expectEqual("junk entries give nothing", engine.effectiveSets(junk, data.exerciseById).size(), 0)


func _checkGrips() -> void:
	# grips on a grip exercise drops only its forearm share
	var heat: Dictionary = engine.effectiveSets([_entry(pullups, 4, true), _entry(hammer, 2, true)], data.exerciseById)
	_expectNear("grips on: forearms only from hammer", heat.get("forearms", 0.0), 2.0)
	_expectNear("grips on: biceps unchanged", heat.get("biceps", 0.0), 3.4)
	var gripsOnly: Dictionary = engine.effectiveSets([_entry(pullups, 3, true)], data.exerciseById)
	_expectTrue("grips on: no forearms key at all", not gripsOnly.has("forearms"))
	_expectNear("grips on: lats still 3", gripsOnly.get("lats", 0.0), 3.0)


func _checkWindow() -> void:
	### WHAT THIS DOES
	# rolling 7 days: 1 day old in, exactly 7 days out, 7 days minus a minute in, 8 days out

	var workouts: Array = [
		_workout("a", nowUnix - 1.0 * day, [_entry(bench, 3, false)]),
		_workout("b", nowUnix - 7.0 * day, [_entry(bench, 10, false)]),
		_workout("c", nowUnix - 7.0 * day + 60.0, [_entry(pullups, 4, false)]),
		_workout("d", nowUnix - 8.0 * day, [_entry(pullups, 10, false)]),
	]
	var inside: Array = engine.workoutsInWindow(workouts, nowUnix)
	var ids: Array = []
	for workout in inside:
		ids.append(workout["id"])
	_expectEqual("window keeps a and c", ids, ["a", "c"])
	var heat: Dictionary = engine.weekHeat(workouts, data.exerciseById, nowUnix)
	_expectNear("week lowerChest only from a", heat.get("lowerChest", 0.0), 3.0)
	_expectNear("week lats only from c", heat.get("lats", 0.0), 4.0)
	_expectNear("running workout counts from its start", engine.workoutTime({"startedAt": 50.0, "endedAt": 0.0}), 50.0)
	var shortWindow: Array = engine.workoutsInWindow(workouts, nowUnix, 2.0)
	_expectEqual("2-day window keeps only a", shortWindow.size(), 1)


func _checkStatuses() -> void:
	var band: Array = [8, 16]
	_expectEqual("0.3 sets = missed", engine.targetStatus(0.3, band), "missed")
	_expectEqual("0.49 sets = missed", engine.targetStatus(0.49, band), "missed")
	_expectEqual("0.5 sets = under", engine.targetStatus(0.5, band), "under")
	_expectEqual("5 sets = under", engine.targetStatus(5.0, band), "under")
	_expectEqual("8 sets (band low) = ok", engine.targetStatus(8.0, band), "ok")
	_expectEqual("16 sets (band high) = ok", engine.targetStatus(16.0, band), "ok")
	_expectEqual("16.5 sets = over", engine.targetStatus(16.5, band), "over")
	_expectNear("offTarget 4 of [8,16]", engine.offTarget(4.0, band), -0.5)
	_expectNear("offTarget 24 of [8,16]", engine.offTarget(24.0, band), 0.5)
	_expectNear("offTarget 10 of [8,16]", engine.offTarget(10.0, band), 0.0)
	var statuses: Dictionary = engine.allStatuses({"lowerChest": 10.0}, data.regions)
	_expectEqual("allStatuses covers 30 regions", statuses.size(), 30)
	_expectEqual("allStatuses lowerChest ok", statuses["lowerChest"], "ok")
	var ranked: Array = engine.rankRegions({"lowerChest": 3.0, "lats": 50.0}, data.regions)
	_expectEqual("rank: lats 50 of [10,20] is the worst (+1.5)", ranked[0]["region"], "lats")
	_expectEqual("rank row has a status", ranked[0]["status"], "over")


func _checkContributions() -> void:
	var entries: Array = [
		_entry(bench, 3, false),
		_entry("Dumbbell_Bench_Press", 2, false),
		_entry("Pushups", 2, false),
		_entry(bench, 1, false),
		_entry(pullups, 4, false),
	]
	var rows: Array = engine.contributions("lowerChest", entries, data.exerciseById)
	_expectEqual("contributions: 3 exercises fed lowerChest", rows.size(), 3)
	_expectEqual("contributions: bench first", rows[0]["exerciseId"], bench)
	_expectEqual("contributions: bench sets summed", rows[0]["sets"], 4)
	_expectNear("contributions: bench effective", rows[0]["effective"], 4.0)
	_expectEqual("contributions: tie broken by name", rows[1]["exerciseId"], "Dumbbell_Bench_Press")
	var upper: Array = engine.contributions("upperChest", entries, data.exerciseById)
	_expectNear("contributions: pushups upperChest share", upper[upper.size() - 1]["share"], 0.4)


func _checkRecommend() -> void:
	### WHAT THIS DOES
	# rear delt: the top three are full-share rear delt lifts, the most focused first; favourite boost; filters

	var plain: Array = engine.recommend(["rearDelt"], data.exercises)
	for index in range(3):
		_expectNear("recommend rearDelt #%d is a full rear delt set" % (index + 1), data.exerciseShare(plain[index]["exercise"]["id"], "rearDelt"), 1.0)
	_expectTrue("recommend rearDelt: most focused first", plain[0]["score"] >= plain[1]["score"] and plain[1]["score"] >= plain[2]["score"])
	_expectTrue("recommend rearDelt: face pull (less focused) below the flyes", _indexOfId(plain, "Face_Pull") > _indexOfId(plain, "Reverse_Machine_Flyes"))
	var prefs: Dictionary = {"Face_Pull": {"favourite": true, "hidden": false}}
	var boosted: Array = engine.recommend(["rearDelt"], data.exercises, {"prefs": prefs})
	_expectEqual("favourite face pull jumps to #1", boosted[0]["exercise"]["id"], "Face_Pull")
	var cable: Array = engine.recommend(["rearDelt"], data.exercises, {"equipment": ["cable"], "limit": 3})
	var cableOnly: bool = true
	for row in cable:
		if row["exercise"]["equipment"] != "cable":
			cableOnly = false
	_expectTrue("cable filter: cable lifts only", cableOnly)
	_expectNear("cable filter: #1 is a full rear delt set", data.exerciseShare(cable[0]["exercise"]["id"], "rearDelt"), 1.0)
	_expectEqual("limit 3", cable.size(), 3)
	var hiddenPrefs: Dictionary = {"Face_Pull": {"favourite": false, "hidden": true}}
	var hidden: Array = engine.recommend(["rearDelt"], data.exercises, {"prefs": hiddenPrefs})
	var hiddenIds: Array = []
	for row in hidden:
		hiddenIds.append(row["exercise"]["id"])
	_expectTrue("hidden face pull left out", not hiddenIds.has("Face_Pull"))
	var shown: Array = engine.recommend(["rearDelt"], data.exercises, {"prefs": hiddenPrefs, "showHidden": true})
	_expectEqual("showHidden brings it back", shown.size(), hidden.size() + 1)
	var tibialis: Array = engine.recommend(["tibialis"], data.exercises)
	_expectEqual("tibialis: the added raise", tibialis[0]["exercise"]["id"], "Tibialis_Raise")
	var several: Array = engine.recommend(["lats", "rearDelt"], data.exercises)
	var pullupRow: int = _indexOfId(several, pullups)
	_expectTrue("several muscles: pull-ups listed", pullupRow >= 0)
	if pullupRow >= 0:
		_expectNear("several muscles: pull-ups share summed (lats 1.0 + rear delt 0.3)", float(several[pullupRow]["share"]), 1.3)


func _checkUnused() -> void:
	# the picker's "filter by unused": bench worked chest / front delt / triceps / serratus, so pull-ups
	# (lats, biceps, back) and hammer curls (forearms, biceps) are the ones for unused muscles
	var heat: Dictionary = engine.effectiveSets([_entry(bench, 3, false)], data.exerciseById)
	var unused: Dictionary = engine.unusedRegions(heat, Array(data.regionIds))
	_expectEqual("bench leaves 25 muscles unused", unused.size(), 25)
	_expectTrue("lower chest not unused", not unused.has("lowerChest"))
	var list: Array = [data.getExercise(bench), data.getExercise(hammer), data.getExercise(pullups)]
	var ordered: Array = engine.weightedFirst(list, unused)
	_expectEqual("nothing dropped", ordered.size(), 3)
	_expectEqual("pull-ups first (most share on unused)", ordered[0]["exercise"]["id"], pullups)
	_expectNear("pull-ups share on unused", float(ordered[0]["share"]), 3.2)
	_expectEqual("hammer curls second", ordered[1]["exercise"]["id"], hammer)
	_expectEqual("bench last, nothing on unused", ordered[2]["exercise"]["id"], bench)
	_expectNear("bench share on unused", float(ordered[2]["share"]), 0.0)
	var none: Array = engine.weightedFirst([data.getExercise(bench), data.getExercise(hammer)], {})
	_expectEqual("no unused muscles: order kept", none[0]["exercise"]["id"], bench)
	var halfLats: Array = engine.weightedFirst([data.getExercise(bench), data.getExercise(pullups)], {"lats": 0.5})
	_expectNear("weighted: pull-ups lats 1.0 x weight 0.5", float(halfLats[0]["share"]), 0.5)


func _checkTargets() -> void:
	### WHAT THIS DOES
	# presets: baseline + offset, never below 0, the highest preset wins; the overlay heat, on target,
	# below target - hand-computed at baseline 12

	var presetA: Dictionary = {"offsets": {"calves": 6, "neck": -14}}
	var presetB: Dictionary = {"offsets": {"calves": 2, "lats": 4}}
	var targets: Dictionary = engine.regionTargets([presetA, presetB], 12.0)
	_expectNear("targets: calves the higher of 18 and 14", float(targets["calves"]), 18.0)
	_expectNear("targets: neck 12 - 14 stops at 0", float(targets["neck"]), 0.0)
	_expectNear("targets: lats 16", float(targets["lats"]), 16.0)
	_expectEqual("targets: nothing on = no targets", engine.regionTargets([], 12.0), {})
	var marathon: Dictionary = engine.regionTargets([data.presetById["marathon"]], 12.0)
	_expectNear("marathon: calves 12 + 6", float(marathon["calves"]), 18.0)
	_expectEqual("marathon: a target for all 30 muscles", marathon.size(), 30)

	var heat: Dictionary = {"calves": 9.0, "lats": 8.0}
	var shown: Dictionary = engine.targetHeat(heat, targets, 12.0)
	_expectNear("overlay: calves 9 of 18 = half of 0-12", float(shown["calves"]), 6.0)
	_expectTrue("overlay: neck (target 0) left plain", not shown.has("neck"))
	var done: Dictionary = {"calves": 18.0, "lats": 8.0}
	_expectEqual("on target: calves only", engine.onTarget(done, targets), ["calves"])
	var below: Dictionary = engine.belowTarget(done, targets)
	_expectNear("below target: lats half missing", float(below["lats"]), 0.5)
	_expectTrue("below target: calves met, neck has none", not below.has("calves") and not below.has("neck"))


func _checkCardio() -> void:
	### WHAT THIS DOES
	# minutes per light by effort zone (easy -> easy cardio, hard and very hard -> hard cardio), the
	# health line, the targets (the default is the floor), and what counts as logged

	var entries: Array = [
		{"exerciseId": "Hiking", "sets": 0, "grips": false, "minutes": 30, "effort": "easy"},
		{"exerciseId": "Sprint_Intervals", "sets": 0, "grips": false, "minutes": 20, "effort": "veryHard"},
		{"exerciseId": "Rope_Jumping", "sets": 0, "grips": false, "minutes": 10, "effort": "hard"},
		{"exerciseId": "Hiking", "sets": 0, "grips": false, "minutes": 0, "effort": "easy"},
		_entry(bench, 3, false),
	]
	var minutes: Dictionary = engine.cardioMinutes(entries, data.effortById, data.cardioLights)
	_expectNear("cardio: easy minutes", float(minutes["easyCardio"]), 30.0)
	_expectNear("cardio: hard + very hard minutes", float(minutes["hardCardio"]), 30.0)
	_expectNear("cardio: health = 30 + 2 x 30", engine.healthMinutes(minutes), 90.0)
	var plain: Dictionary = engine.cardioTargets([], data.cardioDefaultTarget)
	_expectNear("cardio target default: easy 90", float(plain["easyCardio"]), 90.0)
	_expectNear("cardio target default: hard 30", float(plain["hardCardio"]), 30.0)
	_expectNear("cardio default meets the WHO 150", engine.healthMinutes(plain), 150.0)
	var withMarathon: Dictionary = engine.cardioTargets([data.presetById["marathon"]], data.cardioDefaultTarget)
	_expectNear("cardio target marathon: easy 260", float(withMarathon["easyCardio"]), 260.0)
	var small: Dictionary = engine.cardioTargets([{"cardio": {"easyCardio": 10}}], data.cardioDefaultTarget)
	_expectNear("cardio target: the default is the floor", float(small["easyCardio"]), 90.0)
	_expectTrue("logged: minutes only", engine.isLogged({"sets": 0, "minutes": 5}))
	_expectTrue("not logged: 0 sets 0 minutes", not engine.isLogged({"sets": 0, "minutes": 0}))
	_expectTrue("every cardio exercise has a default effort", _allCardioHaveEffort())


func _allCardioHaveEffort() -> bool:
	for exercise in data.exercises:
		if exercise["category"] == "cardio" and not data.effortById.has(str(exercise.get("cardioEffort", ""))):
			return false
	return true


func _checkSearch() -> void:
	var found: Array = data.search("bench press")
	_expectTrue("search finds bench presses", found.size() >= 10)
	_expectTrue("search: curated bench near the top", found.slice(0, 5).has(data.getExercise(bench)))
	var dumbbells: Array = data.search("curl", ["dumbbell"])
	var allDumbbell: bool = true
	for exercise in dumbbells:
		if exercise["equipment"] != "dumbbell":
			allDumbbell = false
	_expectTrue("equipment filter holds", allDumbbell and dumbbells.size() > 0)
	_expectEqual("nonsense finds nothing", data.search("zzqqxx").size(), 0)
	var tibialisIds: Array = []
	for exercise in data.exercisesForRegion("tibialis"):
		tibialisIds.append(exercise["id"])
	_expectTrue("exercisesForRegion tibialis: the raise and the researched calf/balance moves", tibialisIds.size() == 4 and tibialisIds.has("Tibialis_Raise"))
