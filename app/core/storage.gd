extends Node
## Storage (autoload) - everything the user makes, saved as JSON under user:// on every change
## what this offers
## sections (read them, change them only through the functions below so they save):
## - profile       {name, body "male"/"female", gradient, theme, setupDone}
## - settings      {hideUntouched, newExerciseSets 0/1,
##                  defaultView "front"/"back"/"both", rangeWeek, rangeWorkout}
## - workouts      {submitted: [workout], current: workout or null}
##                  workout = {id, startedAt, endedAt, entries: [{exerciseId, sets, grips}]} (unix seconds)
## - templates     [{id, name, entries: [{exerciseId, sets, grips}]}]
## - exercisePrefs exerciseId -> {favourite, hidden, grips, lastUsed}
## workout in progress: startWorkout, addEntry, setEntrySets, setEntryGrips, removeEntry/insertEntry,
##   finishWorkout, discardWorkout/resumeWorkout (undo); submitted: updateWorkout, deleteWorkout/
##   restoreWorkout; templates: saveTemplate, renameTemplate, deleteTemplate/restoreTemplate;
##   prefs: setFavourite, setHidden, setGripsMemory, getPref, usedExercises
## signal changed(section) after every save ("profile", "settings", "workouts", "templates",
## "exercisePrefs", or "all" after an import)
## each file is {"version": formatVersion, "data": ...}; a broken file is kept as <name>.bad and
## the section starts from defaults (loudly)
## backup: exportBackupText() / exportBackup() (file under user://backups + clipboard) /
## importBackupText(text) -> {ok, error}

signal changed(section: String)

### /// TUNING ///

# save format version - bump only when the file layout changes, and add a migration below
const formatVersion: int = 1
# backup format version - written into every backup
const backupVersion: int = 1
# app name stamped in new backups - for people reading the file only, import checks the
# sections instead (isBackup), so backups stamped with an older name still import
const backupAppName: String = "hotMuscles"
# folder for exported backups, inside the storage folder
const backupFolderName: String = "backups"
# smallest and largest heat range (the 0-N slider)
const rangeMinValue: int = 1
const rangeMaxValue: int = 20

const sectionNames: Array = ["profile", "settings", "workouts", "templates", "exercisePrefs"]

### /// STATE ///

# where the files live - tests point this at a throwaway folder before loadAll
var folder: String = "user://"
var loaded: bool = false
var profile: Dictionary = {}
var settings: Dictionary = {}
var workouts: Dictionary = {}
var templates: Array = []
var exercisePrefs: Dictionary = {}


func _enter_tree() -> void:
	if not loaded:
		loadAll(folder)


### /// DEFAULTS ///

func defaultProfile() -> Dictionary:
	return {"name": "", "body": "male", "gradient": "infrared", "theme": "ember", "setupDone": false}


func defaultSettings() -> Dictionary:
	return {
		"hideUntouched": false,
		"newExerciseSets": 1,
		"defaultView": "both",
		"rangeWeek": 12,
		"rangeWorkout": 5,
	}


func defaultWorkouts() -> Dictionary:
	return {"submitted": [], "current": null}


func defaultPref() -> Dictionary:
	return {"favourite": false, "hidden": false, "grips": false, "lastUsed": 0.0}


### /// LOAD AND SAVE ///

func loadAll(storageFolder: String) -> void:
	### WHAT THIS DOES
	# reads every section, fills missing keys from defaults, cleans up types (json gives floats)

	folder = storageFolder
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)

	profile = _mergeDefaults(_readSection("profile", {}), defaultProfile())
	settings = _mergeDefaults(_readSection("settings", {}), defaultSettings())
	workouts = _mergeDefaults(_readSection("workouts", {}), defaultWorkouts())
	templates = _readSection("templates", [])
	exercisePrefs = _readSection("exercisePrefs", {})
	_cleanAll()
	loaded = true


func _sectionPath(section: String) -> String:
	return folder.path_join(section + ".json")


func _readSection(section: String, fallback: Variant) -> Variant:
	### WHAT THIS DOES
	# one section from disk; missing = fallback, broken = kept aside as .bad + fallback + error

	var path: String = _sectionPath(section)

	if not FileAccess.file_exists(path):
		return fallback
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var valid: bool = typeof(parsed) == TYPE_DICTIONARY and parsed.has("version") and parsed.has("data")
	if valid and typeof(parsed["data"]) != typeof(fallback):
		valid = false
	if not valid:
		push_error("Storage: %s is broken - kept as %s.bad, starting this section fresh" % [path, path])
		DirAccess.rename_absolute(path, path + ".bad")
		return fallback
	var version: int = int(parsed["version"])
	return _migrate(section, version, parsed["data"])


func _migrate(_section: String, _version: int, data: Variant) -> Variant:
	# format migrations go here (version 1 is the first, nothing to do yet)
	return data


func _writeSection(section: String) -> void:
	### WHAT THIS DOES
	# writes one section to a temp file then swaps it in, so a crash mid-write keeps the old file

	var path: String = _sectionPath(section)
	var tempPath: String = path + ".tmp"
	var wrapper: Dictionary = {"version": formatVersion, "data": _sectionData(section)}

	var file: FileAccess = FileAccess.open(tempPath, FileAccess.WRITE)
	if file == null:
		push_error("Storage: cannot write %s (error %d)" % [tempPath, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(wrapper))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tempPath, path)


func _sectionData(section: String) -> Variant:
	if section == "profile":
		return profile
	if section == "settings":
		return settings
	if section == "workouts":
		return workouts
	if section == "templates":
		return templates
	return exercisePrefs


func save(section: String) -> void:
	# write one section and tell listeners
	_writeSection(section)
	changed.emit(section)


func saveAll() -> void:
	for section in sectionNames:
		_writeSection(section)
	changed.emit("all")


### /// CLEANING ///

func _mergeDefaults(data: Variant, defaults: Dictionary) -> Dictionary:
	# keeps stored values, adds keys new in this version
	var merged: Dictionary = defaults.duplicate(true)
	if typeof(data) != TYPE_DICTIONARY:
		return merged
	for key in data:
		merged[key] = data[key]
	return merged


func _cleanAll() -> void:
	### WHAT THIS DOES
	# json hands every number back as a float and old files may lack keys - normalise both

	_cleanSettings()
	profile["setupDone"] = bool(profile["setupDone"])

	var cleanSubmitted: Array = []
	for workout in workouts.get("submitted", []):
		if typeof(workout) == TYPE_DICTIONARY:
			cleanSubmitted.append(_cleanWorkout(workout))
	workouts["submitted"] = cleanSubmitted
	if typeof(workouts.get("current")) == TYPE_DICTIONARY:
		workouts["current"] = _cleanWorkout(workouts["current"])
	else:
		workouts["current"] = null

	var cleanTemplates: Array = []
	for template in templates:
		if typeof(template) == TYPE_DICTIONARY:
			cleanTemplates.append({
				"id": str(template.get("id", _newId("t"))),
				"name": str(template.get("name", "Template")),
				"entries": _cleanEntries(template.get("entries", [])),
			})
	templates = cleanTemplates

	for exerciseId in exercisePrefs.keys():
		exercisePrefs[exerciseId] = _mergeDefaults(exercisePrefs[exerciseId], defaultPref())


func _cleanSettings() -> void:
	# the week used to have its own target colouring - saves from then still carry its key
	settings.erase("colourMode")
	settings["newExerciseSets"] = clampi(int(settings["newExerciseSets"]), 0, 1)
	settings["rangeWeek"] = clampi(int(settings["rangeWeek"]), rangeMinValue, rangeMaxValue)
	settings["rangeWorkout"] = clampi(int(settings["rangeWorkout"]), rangeMinValue, rangeMaxValue)
	settings["hideUntouched"] = bool(settings["hideUntouched"])


func _cleanWorkout(workout: Dictionary) -> Dictionary:
	return {
		"id": str(workout.get("id", _newId("w"))),
		"startedAt": float(workout.get("startedAt", 0.0)),
		"endedAt": float(workout.get("endedAt", 0.0)),
		"entries": _cleanEntries(workout.get("entries", [])),
	}


func _cleanEntries(entries: Variant) -> Array:
	var clean: Array = []
	if typeof(entries) != TYPE_ARRAY:
		return clean
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		clean.append({
			"exerciseId": str(entry.get("exerciseId", "")),
			"sets": maxi(int(entry.get("sets", 0)), 0),
			"grips": bool(entry.get("grips", false)),
		})
	return clean


func _newId(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, int(Time.get_unix_time_from_system()), randi() % 1000000]


func _now() -> float:
	return Time.get_unix_time_from_system()


### /// PROFILE AND SETTINGS ///

func setProfile(key: String, value: Variant) -> void:
	profile[key] = value
	save("profile")


func setProfileValues(values: Dictionary) -> void:
	# several profile values in one write (each write costs a few ms)
	for key in values:
		profile[key] = values[key]
	save("profile")


func setSetting(key: String, value: Variant) -> void:
	settings[key] = value
	_cleanSettings()
	save("settings")


### /// THE WORKOUT IN PROGRESS ///

func hasCurrentWorkout() -> bool:
	return typeof(workouts["current"]) == TYPE_DICTIONARY


func currentWorkout() -> Dictionary:
	if hasCurrentWorkout():
		return workouts["current"]
	return {}


func startWorkout(nowUnix: float = -1.0) -> Dictionary:
	# starts a new workout (or returns the running one)
	if hasCurrentWorkout():
		return workouts["current"]
	_newCurrentWorkout(nowUnix)
	save("workouts")
	return workouts["current"]


func _newCurrentWorkout(nowUnix: float) -> void:
	var started: float = nowUnix
	if started < 0.0:
		started = _now()
	workouts["current"] = {"id": _newId("w"), "startedAt": started, "endedAt": 0.0, "entries": []}


func addEntry(exerciseId: String, sets: int = -1, grips: Variant = null) -> int:
	### WHAT THIS DOES
	# adds an exercise to the running workout; sets -1 = the "new exercises start at" setting,
	# grips null = what this exercise used last time; returns the entry index

	if not hasCurrentWorkout():
		startWorkout()
	var useSets: int = sets
	if useSets < 0:
		useSets = int(settings["newExerciseSets"])
	var useGrips: bool = bool(getPref(exerciseId)["grips"])
	if grips != null:
		useGrips = bool(grips)
	var entries: Array = workouts["current"]["entries"]
	entries.append({"exerciseId": exerciseId, "sets": maxi(useSets, 0), "grips": useGrips})
	save("workouts")
	return entries.size() - 1


func addEntries(list: Array) -> void:
	### WHAT THIS DOES
	# several entries ({exerciseId, sets, grips}) in one write, starting a workout if none runs

	if not hasCurrentWorkout():
		_newCurrentWorkout(-1.0)
	var entries: Array = workouts["current"]["entries"]
	for entry in list:
		entries.append({"exerciseId": str(entry["exerciseId"]), "sets": maxi(int(entry["sets"]), 0), "grips": bool(entry["grips"])})
	save("workouts")


func setEntrySets(index: int, sets: int) -> void:
	var entries: Array = currentWorkout().get("entries", [])
	if index < 0 or index >= entries.size():
		return
	entries[index]["sets"] = maxi(sets, 0)
	save("workouts")


func setEntryGrips(index: int, grips: bool) -> void:
	# also remembered per exercise for next time
	var entries: Array = currentWorkout().get("entries", [])
	if index < 0 or index >= entries.size():
		return
	entries[index]["grips"] = grips
	_setPrefValue(entries[index]["exerciseId"], "grips", grips)
	save("exercisePrefs")
	save("workouts")


func removeEntry(index: int) -> Dictionary:
	# returns the removed entry (for undo)
	var entries: Array = currentWorkout().get("entries", [])
	if index < 0 or index >= entries.size():
		return {}
	var removed: Dictionary = entries[index]
	entries.remove_at(index)
	save("workouts")
	return removed


func insertEntry(index: int, entry: Dictionary) -> void:
	# puts an entry back (undo of removeEntry)
	if not hasCurrentWorkout():
		startWorkout()
	var entries: Array = workouts["current"]["entries"]
	entries.insert(clampi(index, 0, entries.size()), _cleanEntries([entry])[0])
	save("workouts")


func finishWorkout(nowUnix: float = -1.0) -> Dictionary:
	### WHAT THIS DOES
	# moves the running workout into the week; planned entries (0 sets) are dropped;
	# marks every exercise as used; returns the submitted workout

	if not hasCurrentWorkout():
		return {}
	var ended: float = nowUnix
	if ended < 0.0:
		ended = _now()
	var workout: Dictionary = workouts["current"]
	var kept: Array = []
	for entry in workout["entries"]:
		if int(entry["sets"]) > 0:
			kept.append(entry)
			_setPrefValue(entry["exerciseId"], "lastUsed", ended)
	workout["entries"] = kept
	workout["endedAt"] = ended
	workouts["submitted"].append(workout)
	workouts["current"] = null
	save("exercisePrefs")
	save("workouts")
	return workout


func discardWorkout() -> Dictionary:
	# throws the running workout away, returns it (for undo)
	var dropped: Dictionary = currentWorkout()
	workouts["current"] = null
	save("workouts")
	return dropped


func resumeWorkout(workout: Dictionary) -> void:
	# undo of discardWorkout - puts it back as the running workout (only if none is running)
	if workout.is_empty() or hasCurrentWorkout():
		return
	workouts["current"] = _cleanWorkout(workout)
	save("workouts")


### /// SUBMITTED WORKOUTS ///

func submittedWorkouts() -> Array:
	return workouts["submitted"]


func findWorkoutIndex(workoutId: String) -> int:
	var list: Array = workouts["submitted"]
	for index in range(list.size()):
		if list[index]["id"] == workoutId:
			return index
	return -1


func updateWorkout(workout: Dictionary) -> bool:
	# replaces a submitted workout with the same id (the editor's Save changes)
	var index: int = findWorkoutIndex(str(workout.get("id", "")))
	if index < 0:
		return false
	workouts["submitted"][index] = _cleanWorkout(workout)
	save("workouts")
	return true


func deleteWorkout(workoutId: String) -> Dictionary:
	# returns the removed workout so an undo toast can put it back with restoreWorkout
	var index: int = findWorkoutIndex(workoutId)
	if index < 0:
		return {}
	var removed: Dictionary = workouts["submitted"][index]
	workouts["submitted"].remove_at(index)
	save("workouts")
	return removed


func restoreWorkout(workout: Dictionary) -> void:
	if workout.is_empty() or findWorkoutIndex(str(workout.get("id", ""))) >= 0:
		return
	workouts["submitted"].append(_cleanWorkout(workout))
	workouts["submitted"].sort_custom(_workoutBefore)
	save("workouts")


func _workoutBefore(a: Dictionary, b: Dictionary) -> bool:
	return float(a["startedAt"]) < float(b["startedAt"])


### /// TEMPLATES ///

func saveTemplate(templateName: String, entries: Array) -> Dictionary:
	var template: Dictionary = {"id": _newId("t"), "name": templateName, "entries": _cleanEntries(entries)}
	templates.append(template)
	save("templates")
	return template


func findTemplateIndex(templateId: String) -> int:
	for index in range(templates.size()):
		if templates[index]["id"] == templateId:
			return index
	return -1


func renameTemplate(templateId: String, templateName: String) -> void:
	var index: int = findTemplateIndex(templateId)
	if index < 0:
		return
	templates[index]["name"] = templateName
	save("templates")


func deleteTemplate(templateId: String) -> Dictionary:
	var index: int = findTemplateIndex(templateId)
	if index < 0:
		return {}
	var removed: Dictionary = templates[index]
	templates.remove_at(index)
	save("templates")
	return removed


func restoreTemplate(template: Dictionary) -> void:
	if template.is_empty() or findTemplateIndex(str(template.get("id", ""))) >= 0:
		return
	templates.append(template)
	save("templates")


### /// EXERCISE PREFS ///

func getPref(exerciseId: String) -> Dictionary:
	# always a full pref dict (defaults for exercises never touched)
	if exercisePrefs.has(exerciseId):
		return exercisePrefs[exerciseId]
	return defaultPref()


func _setPrefValue(exerciseId: String, key: String, value: Variant) -> void:
	if not exercisePrefs.has(exerciseId):
		exercisePrefs[exerciseId] = defaultPref()
	exercisePrefs[exerciseId][key] = value


func setFavourite(exerciseId: String, favourite: bool) -> void:
	_setPrefValue(exerciseId, "favourite", favourite)
	save("exercisePrefs")


func setHidden(exerciseId: String, hidden: bool) -> void:
	_setPrefValue(exerciseId, "hidden", hidden)
	save("exercisePrefs")


func setGripsMemory(exerciseId: String, grips: bool) -> void:
	# remembers the grips choice for next time without a running workout (the past-workout editor)
	_setPrefValue(exerciseId, "grips", grips)
	save("exercisePrefs")


func usedExercises() -> Dictionary:
	# exerciseId -> lastUsed for everything ever finished in a workout
	var used: Dictionary = {}
	for exerciseId in exercisePrefs:
		if float(exercisePrefs[exerciseId]["lastUsed"]) > 0.0:
			used[exerciseId] = exercisePrefs[exerciseId]["lastUsed"]
	return used


### /// BACKUP ///

func exportBackupText() -> String:
	### WHAT THIS DOES
	# everything in one JSON text: {app, backupVersion, formatVersion, exportedAt, profile,
	# settings, workouts, templates, exercisePrefs}

	var backup: Dictionary = {
		"app": backupAppName,
		"backupVersion": backupVersion,
		"formatVersion": formatVersion,
		"exportedAt": Time.get_datetime_string_from_system(false, true),
		"profile": profile,
		"settings": settings,
		"workouts": workouts,
		"templates": templates,
		"exercisePrefs": exercisePrefs,
	}
	return JSON.stringify(backup, "  ")


func exportBackup(copyToClipboard: bool = true) -> Dictionary:
	# saves a backup file under user://backups and copies it to the clipboard; returns {text, path}
	var text: String = exportBackupText()
	var backupFolder: String = folder.path_join(backupFolderName)
	DirAccess.make_dir_recursive_absolute(backupFolder)
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	var path: String = backupFolder.path_join("backup_%s.json" % stamp)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Storage: cannot write backup %s" % path)
		path = ""
	else:
		file.store_string(text)
		file.close()
	if copyToClipboard:
		DisplayServer.clipboard_set(text)
	return {"text": text, "path": path}


func isBackup(parsed: Variant) -> bool:
	### WHAT THIS DOES
	# true when parsed JSON has the shape of one of our backups - a version number plus every
	# saved section with the right type; the app name stamped in it is not checked

	var expected: Dictionary = {
		"profile": TYPE_DICTIONARY,
		"settings": TYPE_DICTIONARY,
		"workouts": TYPE_DICTIONARY,
		"templates": TYPE_ARRAY,
		"exercisePrefs": TYPE_DICTIONARY,
	}

	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if not parsed.has("backupVersion"):
		return false
	for section in expected:
		if typeof(parsed.get(section)) != expected[section]:
			return false
	return true


func importBackupText(text: String) -> Dictionary:
	### WHAT THIS DOES
	# replaces everything with a backup's contents after checking it really is one of ours;
	# nothing changes unless the whole backup is valid

	var parsed: Variant = JSON.parse_string(text.strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "That is not a backup (not JSON)."}
	if int(parsed.get("backupVersion", 0)) > backupVersion:
		return {"ok": false, "error": "That backup comes from a newer version of the app."}
	if not isBackup(parsed):
		return {"ok": false, "error": "That JSON is not a hotMuscles backup."}

	profile = _mergeDefaults(parsed["profile"], defaultProfile())
	settings = _mergeDefaults(parsed["settings"], defaultSettings())
	workouts = _mergeDefaults(parsed["workouts"], defaultWorkouts())
	templates = parsed["templates"]
	exercisePrefs = parsed["exercisePrefs"]
	_cleanAll()
	saveAll()
	return {"ok": true, "error": ""}
