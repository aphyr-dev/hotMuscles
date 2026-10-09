class_name HeatEngine
extends RefCounted
## what this offers - the heat maths, all static, no state, no autoload needed
## an ENTRY is {exerciseId: String, sets: int, grips: bool}
## a WORKOUT is {id, startedAt, endedAt, entries: [entry...]} (unix seconds; endedAt 0 = still running)
## `exerciseById` is AppData.exerciseById (id -> exercise dict with targets [{region, share}], forearmKind)
## - effectiveSets(entries, exerciseById)            regionId -> effective sets (sum of sets x share)
## - entryHeat(entry, exerciseById)                   the same for one entry
## - workoutsInWindow(workouts, nowUnix, days = 7)    submitted workouts inside the rolling window
## - weekEntries(workouts) / weekHeat(workouts, exerciseById, nowUnix, days = 7)
## - periodWorkouts(workouts, period, nowUnix, biasMinutes)  a home period's workouts (day/week/month/year)
## - periodWeeks(workouts, period, nowUnix)           what its heat divides by to read "per week"
## - dayStart(nowUnix, biasMinutes) local midnight;   scaleHeat(heat, factor)
## - targetStatus(sets, band) -> "missed" / "under" / "ok" / "over"; allStatuses(heat, regions)
## - offTarget(sets, band) signed distance from the band (- under, + over, 0 inside)
## - rankRegions(heat, regions)                       regions sorted by how far off target
## - contributions(regionId, entries, exerciseById)   which exercises gave a region how much
## - recommend(regionId, exercises, options)          exercise picker order for "tap a muscle"
## - unusedRegions(heat, regionIds)                   regionId -> true for every muscle at 0 sets
## - unusedFirst(exercises, unused)                   picker order for "filter by unused": the most
##                                                    share on unused muscles first, the rest after in
##                                                    their old order; [{exercise, share}]

### /// TUNING ///

# effective sets below this count as "missed" (not trained at all this week)
const missedBelow: float = 0.5
# seconds in a day, for the rolling window
const daySeconds: float = 86400.0
# recommendation score: weight of the share on the tapped muscle
const recommendShareWeight: float = 1.0
# recommendation score: weight of "hits this muscle without loading much else" (share / total shares)
const recommendFocusWeight: float = 0.5
# recommendation score: bonus for a starred exercise
const recommendFavouriteBonus: float = 0.15
# recommendation score: bonus for an exercise used before
const recommendUsedBonus: float = 0.05
# recommendation score: bonus for curated (hand-checked) data
const recommendCuratedBonus: float = 0.03
# effective sets below this count as "unused" (0% worked) for the picker's filter by unused
const unusedBelow: float = 0.01

# the home page's periods and how many days each looks back (day = since local midnight)
const periodIds: Array = ["day", "week", "month", "year"]
const periodDays: Dictionary = {"day": 1.0, "week": 7.0, "month": 30.0, "year": 365.0}

const statusMissed: String = "missed"
const statusUnder: String = "under"
const statusOk: String = "ok"
const statusOver: String = "over"


### /// EFFECTIVE SETS ///

static func entryHeat(entry: Dictionary, exerciseById: Dictionary) -> Dictionary:
	### WHAT THIS DOES
	# sets x share per region for one logged exercise; a grips-on entry drops its forearm share

	var heat: Dictionary = {}
	var exerciseId: String = str(entry.get("exerciseId", ""))
	var sets: float = maxf(float(entry.get("sets", 0)), 0.0)
	var grips: bool = bool(entry.get("grips", false))

	if sets <= 0.0 or not exerciseById.has(exerciseId):
		return heat
	var exercise: Dictionary = exerciseById[exerciseId]
	var dropForearms: bool = false
	if grips and exercise.get("forearmKind", "none") == "grip":
		dropForearms = true
	for target in exercise.get("targets", []):
		var regionId: String = target["region"]
		if dropForearms and regionId == "forearms":
			continue
		heat[regionId] = float(heat.get(regionId, 0.0)) + sets * float(target["share"])
	return heat


static func effectiveSets(entries: Array, exerciseById: Dictionary) -> Dictionary:
	# sum of entryHeat over a list of entries
	var heat: Dictionary = {}
	for entry in entries:
		var one: Dictionary = entryHeat(entry, exerciseById)
		for regionId in one:
			heat[regionId] = float(heat.get(regionId, 0.0)) + float(one[regionId])
	return heat


### /// THE WEEK ///

static func workoutTime(workout: Dictionary) -> float:
	# when a workout counts as done - its end, or its start if it has no end
	var ended: float = float(workout.get("endedAt", 0.0))
	if ended > 0.0:
		return ended
	return float(workout.get("startedAt", 0.0))


static func workoutsInWindow(workouts: Array, nowUnix: float, days: float = 7.0) -> Array:
	### WHAT THIS DOES
	# the rolling window: workouts done less than `days` days before now (a workout exactly
	# `days` days old has dropped out); a clock set backwards does not hide a workout from "the future"

	var inside: Array = []
	var cutoff: float = nowUnix - days * daySeconds

	for workout in workouts:
		if workoutTime(workout) > cutoff:
			inside.append(workout)
	return inside


static func weekEntries(workouts: Array) -> Array:
	# every entry of a list of workouts, flattened
	var entries: Array = []
	for workout in workouts:
		entries.append_array(workout.get("entries", []))
	return entries


static func weekHeat(workouts: Array, exerciseById: Dictionary, nowUnix: float, days: float = 7.0) -> Dictionary:
	# effective sets of the rolling week
	return effectiveSets(weekEntries(workoutsInWindow(workouts, nowUnix, days)), exerciseById)


### /// PERIODS ///

static func dayStart(nowUnix: float, biasMinutes: float) -> float:
	# the local midnight before nowUnix (bias = minutes the local clock runs ahead of UTC)
	var local: float = nowUnix + biasMinutes * 60.0
	return nowUnix - fposmod(local, daySeconds)


static func periodWorkouts(workouts: Array, period: String, nowUnix: float, biasMinutes: float) -> Array:
	### WHAT THIS DOES
	# the workouts a home period shows: day = since local midnight, the others a rolling window

	var inside: Array = []

	if period == "day":
		var start: float = dayStart(nowUnix, biasMinutes)
		for workout in workouts:
			if workoutTime(workout) >= start:
				inside.append(workout)
		return inside
	return workoutsInWindow(workouts, nowUnix, float(periodDays.get(period, 7.0)))


static func periodWeeks(workouts: Array, period: String, nowUnix: float) -> float:
	### WHAT THIS DOES
	# what a period's heat is divided by to read "per week": 1 for day and week; for month and year
	# the weeks covered - from the first workout ever (so a new user is not averaged over empty
	# weeks), at least one week, at most the whole period

	var first: float = nowUnix

	if period == "day" or period == "week" or workouts.is_empty():
		return 1.0
	for workout in workouts:
		first = minf(first, workoutTime(workout))
	var days: float = clampf((nowUnix - first) / daySeconds, 7.0, float(periodDays.get(period, 7.0)))
	return days / 7.0


static func scaleHeat(heat: Dictionary, factor: float) -> Dictionary:
	# every region's sets times factor
	var scaled: Dictionary = {}
	for regionId in heat:
		scaled[regionId] = float(heat[regionId]) * factor
	return scaled


### /// TARGETS ///

static func targetStatus(sets: float, band: Array) -> String:
	# missed / under / ok / over against a [low, high] band
	if sets < missedBelow:
		return statusMissed
	if sets < float(band[0]):
		return statusUnder
	if sets > float(band[1]):
		return statusOver
	return statusOk


static func allStatuses(heat: Dictionary, regions: Array) -> Dictionary:
	# regionId -> status for every region (regions = AppData.regions)
	var statuses: Dictionary = {}
	for region in regions:
		statuses[region["id"]] = targetStatus(float(heat.get(region["id"], 0.0)), region["band"])
	return statuses


static func offTarget(sets: float, band: Array) -> float:
	### WHAT THIS DOES
	# signed distance from the band, relative to the band edge: -1 = nothing done,
	# 0 = inside the band, +1 = double the band top

	var low: float = float(band[0])
	var high: float = float(band[1])

	if sets < low:
		if low <= 0.0:
			return 0.0
		return (sets - low) / low
	if sets > high:
		if high <= 0.0:
			return 1.0
		return (sets - high) / high
	return 0.0


static func rankRegions(heat: Dictionary, regions: Array) -> Array:
	### WHAT THIS DOES
	# [{region, name, sets, band, status, off}] sorted by how far off target (worst first), then name

	var rows: Array = []

	for region in regions:
		var sets: float = float(heat.get(region["id"], 0.0))
		rows.append({
			"region": region["id"],
			"name": region["name"],
			"sets": sets,
			"band": region["band"],
			"status": targetStatus(sets, region["band"]),
			"off": offTarget(sets, region["band"]),
		})
	rows.sort_custom(_rankBefore)
	return rows


static func _rankBefore(a: Dictionary, b: Dictionary) -> bool:
	var diff: float = absf(a["off"]) - absf(b["off"])
	if absf(diff) > 0.0001:
		return diff > 0.0
	return a["name"] < b["name"]


### /// REGION SHEET ///

static func contributions(regionId: String, entries: Array, exerciseById: Dictionary) -> Array:
	### WHAT THIS DOES
	# which exercises fed a region: [{exerciseId, name, sets, share, effective}] biggest first,
	# the same exercise across several entries/workouts summed into one row

	var byExercise: Dictionary = {}
	var rows: Array = []

	for entry in entries:
		var heat: Dictionary = entryHeat(entry, exerciseById)
		if not heat.has(regionId):
			continue
		var exerciseId: String = entry["exerciseId"]
		if not byExercise.has(exerciseId):
			var exercise: Dictionary = exerciseById[exerciseId]
			byExercise[exerciseId] = {
				"exerciseId": exerciseId,
				"name": exercise["name"],
				"sets": 0,
				"share": 0.0,
				"effective": 0.0,
			}
		var row: Dictionary = byExercise[exerciseId]
		row["sets"] = int(row["sets"]) + int(entry.get("sets", 0))
		row["effective"] = float(row["effective"]) + float(heat[regionId])
	for exerciseId in byExercise:
		var row: Dictionary = byExercise[exerciseId]
		if int(row["sets"]) > 0:
			row["share"] = float(row["effective"]) / float(row["sets"])
		rows.append(row)
	rows.sort_custom(_contributionBefore)
	return rows


static func _contributionBefore(a: Dictionary, b: Dictionary) -> bool:
	if absf(a["effective"] - b["effective"]) > 0.0001:
		return a["effective"] > b["effective"]
	return a["name"] < b["name"]


### /// RECOMMENDATIONS ///

static func recommend(regionId: String, exercises: Array, options: Dictionary = {}) -> Array:
	### WHAT THIS DOES
	# picker order for a tapped muscle: biggest share first, then ones that hit it without loading
	# much else; favourites and previously used get a small boost
	# options (all optional):
	#   prefs: exerciseId -> {favourite, hidden}   (Storage.exercisePrefs)
	#   used: exerciseId -> anything                (ids used before)
	#   equipment: [names]                          (empty = all)
	#   showHidden: bool
	#   limit: int                                  (0 = all)
	# returns [{exercise, share, focus, score}]

	var prefs: Dictionary = options.get("prefs", {})
	var used: Dictionary = options.get("used", {})
	var equipment: Array = options.get("equipment", [])
	var showHidden: bool = bool(options.get("showHidden", false))
	var limit: int = int(options.get("limit", 0))
	var rows: Array = []

	for exercise in exercises:
		# filters
		if equipment.size() > 0 and not equipment.has(exercise.get("equipment", "")):
			continue
		var pref: Dictionary = prefs.get(exercise["id"], {})
		if bool(pref.get("hidden", false)) and not showHidden:
			continue

		# share on this muscle and focus (its part of everything the exercise loads)
		var share: float = 0.0
		var total: float = 0.0
		for target in exercise.get("targets", []):
			total += float(target["share"])
			if target["region"] == regionId:
				share = float(target["share"])
		if share <= 0.0:
			continue
		var focus: float = share / maxf(total, 0.0001)

		# score
		var score: float = share * recommendShareWeight + focus * recommendFocusWeight
		if bool(pref.get("favourite", false)):
			score += recommendFavouriteBonus
		if used.has(exercise["id"]):
			score += recommendUsedBonus
		if bool(exercise.get("curated", false)):
			score += recommendCuratedBonus
		rows.append({"exercise": exercise, "share": share, "focus": focus, "score": score})

	rows.sort_custom(_recommendBefore)
	if limit > 0 and rows.size() > limit:
		rows.resize(limit)
	return rows


static func _recommendBefore(a: Dictionary, b: Dictionary) -> bool:
	if absf(a["score"] - b["score"]) > 0.00001:
		return a["score"] > b["score"]
	return a["exercise"]["name"] < b["exercise"]["name"]


### /// UNUSED MUSCLES ///

static func unusedRegions(heat: Dictionary, regionIds: Array) -> Dictionary:
	# every muscle the heat leaves at 0
	var unused: Dictionary = {}
	for regionId in regionIds:
		if float(heat.get(regionId, 0.0)) < unusedBelow:
			unused[regionId] = true
	return unused


static func unusedFirst(exercises: Array, unused: Dictionary) -> Array:
	### WHAT THIS DOES
	# reorders a list (nothing is dropped): exercises with more share on unused muscles first; equal
	# ones, and every exercise that misses them all, keep the order they came in. Shares go into
	# buckets of 0.01 sets and only the bucket keys are sorted (a custom sort of ~880 rows cost a
	# whole frame)

	var buckets: Dictionary = {}
	var keys: PackedInt32Array = PackedInt32Array()
	var rows: Array = []

	for exercise in exercises:
		var share: float = 0.0
		for target in exercise.get("targets", []):
			if unused.has(target["region"]):
				share += float(target["share"])
		var key: int = roundi(share * 100.0)
		if not buckets.has(key):
			buckets[key] = []
			keys.append(key)
		buckets[key].append({"exercise": exercise, "share": share})
	keys.sort()
	for index in range(keys.size() - 1, -1, -1):
		rows.append_array(buckets[keys[index]])
	return rows
