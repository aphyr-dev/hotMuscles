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
	_expectTrue("884 exercises", data.exercises.size() == 884)

	_checkShares()
	_checkEffectiveSets()
	_checkGrips()
	_checkWindow()
	_checkStatuses()
	_checkContributions()
	_checkRecommend()
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
	# rear delt: three 1.0-share curated lifts, the most focused first; favourite boost; filters

	var plain: Array = engine.recommend("rearDelt", data.exercises)
	_expectEqual("recommend rearDelt #1 (most focused)", plain[0]["exercise"]["id"], "Reverse_Machine_Flyes")
	_expectEqual("recommend rearDelt #2", plain[1]["exercise"]["id"], "Reverse_Flyes")
	_expectEqual("recommend rearDelt #3", plain[2]["exercise"]["id"], "Face_Pull")
	var prefs: Dictionary = {"Face_Pull": {"favourite": true, "hidden": false}}
	var boosted: Array = engine.recommend("rearDelt", data.exercises, {"prefs": prefs})
	_expectEqual("favourite face pull jumps to #1", boosted[0]["exercise"]["id"], "Face_Pull")
	var cable: Array = engine.recommend("rearDelt", data.exercises, {"equipment": ["cable"], "limit": 3})
	_expectEqual("cable filter: face pull first", cable[0]["exercise"]["id"], "Face_Pull")
	_expectEqual("limit 3", cable.size(), 3)
	var hiddenPrefs: Dictionary = {"Face_Pull": {"favourite": false, "hidden": true}}
	var hidden: Array = engine.recommend("rearDelt", data.exercises, {"prefs": hiddenPrefs})
	var hiddenIds: Array = []
	for row in hidden:
		hiddenIds.append(row["exercise"]["id"])
	_expectTrue("hidden face pull left out", not hiddenIds.has("Face_Pull"))
	var shown: Array = engine.recommend("rearDelt", data.exercises, {"prefs": hiddenPrefs, "showHidden": true})
	_expectEqual("showHidden brings it back", shown.size(), hidden.size() + 1)
	var tibialis: Array = engine.recommend("tibialis", data.exercises)
	_expectEqual("tibialis: the added raise", tibialis[0]["exercise"]["id"], "Tibialis_Raise")


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
	_expectTrue("exercisesForRegion tibialis", data.exercisesForRegion("tibialis").size() == 1)
