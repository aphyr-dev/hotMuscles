extends SceneTree
## testStorage.gd - headless check of the save files and the backup format
## what this offers: python tests/runGodot.py script res://tests/testStorage.gd
## works in its own throwaway folders under user:// (unique per run, deleted at the end) and
## never touches the clipboard or the real save files

### /// TUNING ///

# throwaway folder name prefix inside user://
const folderPrefix: String = "_testPhase1Storage_"

var failures: int = 0
var checks: int = 0
var storageScript: GDScript = null
var folderA: String = ""
var folderB: String = ""
var folderC: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stamp: String = "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	folderA = "user://" + folderPrefix + stamp + "_a"
	folderB = "user://" + folderPrefix + stamp + "_b"
	folderC = "user://" + folderPrefix + stamp + "_c"
	storageScript = load("res://app/core/storage.gd")

	_checkDefaultsAndRoundTrip()
	_checkWorkoutFlow()
	_checkBackup()
	_checkBrokenFile()

	_removeFolder(folderA)
	_removeFolder(folderB)
	_removeFolder(folderC)
	if failures == 0:
		print("ALL PASS (%d checks)" % checks)
	else:
		print("%d FAILURE(S) of %d checks" % [failures, checks])
	quit(mini(failures, 1))


### /// HELPERS ///

func _expectEqual(label: String, got: Variant, want: Variant) -> void:
	checks += 1
	if got == want:
		print("PASS  %s = %s" % [label, str(got)])
	else:
		failures += 1
		print("FAIL  %s = %s, want %s" % [label, str(got), str(want)])


func _expectTrue(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


func _fresh(folder: String) -> Node:
	var storage: Node = storageScript.new()
	storage.loadAll(folder)
	return storage


func _removeFolder(folder: String) -> void:
	# deletes only this test's own folder, file by file
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	for sub in dir.get_directories():
		_removeFolder(folder.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


### /// CHECKS ///

func _checkDefaultsAndRoundTrip() -> void:
	var first: Node = _fresh(folderA)
	_expectEqual("default body", first.profile["body"], "male")
	_expectTrue("no colour mode setting", not first.settings.has("colourMode"))
	_expectEqual("default new sets", first.settings["newExerciseSets"], 1)
	first.setProfile("name", "Sam")
	first.setProfile("body", "female")
	first.setSetting("rangeWeek", 99)
	first.setFavourite("Face_Pull", true)
	first.free()

	var second: Node = _fresh(folderA)
	_expectEqual("name survives reload", second.profile["name"], "Sam")
	_expectEqual("body survives reload", second.profile["body"], "female")
	_expectEqual("range clamps to 20", second.settings["rangeWeek"], 20)
	_expectEqual("favourite survives reload", second.getPref("Face_Pull")["favourite"], true)
	_expectEqual("untouched pref is default", second.getPref("Pullups")["hidden"], false)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(folderA.path_join("profile.json")))
	_expectEqual("file carries version", int(raw["version"]), 1)
	second.free()


func _checkWorkoutFlow() -> void:
	### WHAT THIS DOES
	# start, add (planned 0 + real), grips memory, survive a "restart", finish, delete + undo, templates

	var storage: Node = _fresh(folderA)
	storage.startWorkout(1000.0)
	storage.addEntry("Pullups", 3, true)
	storage.addEntry("Barbell_Curl", 0)
	storage.addEntry("Barbell_Bench_Press_-_Medium_Grip")
	storage.free()

	var restarted: Node = _fresh(folderA)
	_expectTrue("running workout survives a restart", restarted.hasCurrentWorkout())
	var entries: Array = restarted.currentWorkout()["entries"]
	_expectEqual("3 entries kept", entries.size(), 3)
	_expectEqual("sets come back as int", typeof(entries[0]["sets"]), TYPE_INT)
	_expectEqual("default new sets used", entries[2]["sets"], 1)
	restarted.setEntryGrips(0, true)
	_expectEqual("grips remembered per exercise", restarted.getPref("Pullups")["grips"], true)
	var again: int = restarted.addEntry("Pullups", 2)
	_expectEqual("remembered grips applied to a new entry", restarted.currentWorkout()["entries"][again]["grips"], true)
	var removed: Dictionary = restarted.removeEntry(again)
	_expectEqual("removeEntry returns it", removed["exerciseId"], "Pullups")

	var done: Dictionary = restarted.finishWorkout(5000.0)
	_expectEqual("planned 0-set entry dropped on finish", done["entries"].size(), 2)
	_expectTrue("no running workout after finish", not restarted.hasCurrentWorkout())
	_expectEqual("one submitted workout", restarted.submittedWorkouts().size(), 1)
	_expectEqual("used exercise remembered", restarted.usedExercises().has("Pullups"), true)

	var gone: Dictionary = restarted.deleteWorkout(done["id"])
	_expectEqual("delete empties the week", restarted.submittedWorkouts().size(), 0)
	restarted.restoreWorkout(gone)
	_expectEqual("undo puts it back", restarted.submittedWorkouts().size(), 1)

	var edited: Dictionary = gone.duplicate(true)
	edited["entries"][0]["sets"] = 7
	restarted.updateWorkout(edited)
	_expectEqual("updateWorkout saves the edit", restarted.submittedWorkouts()[0]["entries"][0]["sets"], 7)

	var template: Dictionary = restarted.saveTemplate("Pull day", done["entries"])
	restarted.renameTemplate(template["id"], "Pull day B")
	restarted.free()
	var reloaded: Node = _fresh(folderA)
	_expectEqual("template survives reload", reloaded.templates[0]["name"], "Pull day B")
	_expectEqual("template keeps grips", reloaded.templates[0]["entries"][0]["grips"], true)
	reloaded.deleteTemplate(reloaded.templates[0]["id"])
	_expectEqual("template deleted", reloaded.templates.size(), 0)
	reloaded.free()


func _checkBackup() -> void:
	### WHAT THIS DOES
	# export from A, import into an empty B, compare; refuse junk without changing anything

	var source: Node = _fresh(folderA)
	var exported: Dictionary = source.exportBackup(false)
	_expectTrue("backup file written under backups/", FileAccess.file_exists(exported["path"]))
	var text: String = exported["text"]
	var parsed: Variant = JSON.parse_string(text)
	_expectEqual("backup names the app", parsed["app"], "hotMuscles")
	_expectEqual("backup version", int(parsed["backupVersion"]), 1)

	var target: Node = _fresh(folderB)
	var junk: Dictionary = target.importBackupText("{\"app\": \"somethingElse\"}")
	_expectEqual("foreign json refused", junk["ok"], false)
	var broken: Dictionary = target.importBackupText("not json at all")
	_expectEqual("non-json refused", broken["ok"], false)
	_expectEqual("refused import changed nothing", target.profile["name"], "")
	var restamped: Dictionary = parsed.duplicate(true)
	restamped["app"] = "olderAppName"
	var olderTarget: Node = _fresh(folderC)
	var olderResult: Dictionary = olderTarget.importBackupText(JSON.stringify(restamped))
	_expectEqual("backup stamped with an older app name imports", olderResult["ok"], true)
	_expectEqual("older stamp: name imported", olderTarget.profile["name"], "Sam")
	olderTarget.free()
	var result: Dictionary = target.importBackupText(text)
	_expectEqual("our backup imports", result["ok"], true)
	_expectEqual("imported name", target.profile["name"], "Sam")
	_expectEqual("imported workouts", target.submittedWorkouts().size(), source.submittedWorkouts().size())
	_expectEqual("imported prefs", target.getPref("Face_Pull")["favourite"], true)
	target.free()
	var targetReloaded: Node = _fresh(folderB)
	_expectEqual("import was saved to disk", targetReloaded.profile["body"], "female")
	targetReloaded.free()
	source.free()


func _checkBrokenFile() -> void:
	# a broken section is kept aside as .bad and starts fresh, other sections untouched
	var file: FileAccess = FileAccess.open(folderB.path_join("settings.json"), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var storage: Node = _fresh(folderB)
	_expectEqual("broken settings back to defaults", storage.settings["rangeWeek"], 12)
	_expectTrue("broken file kept as .bad", FileAccess.file_exists(folderB.path_join("settings.json.bad")))
	_expectEqual("other sections still load", storage.profile["name"], "Sam")
	storage.free()
