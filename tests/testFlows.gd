extends SceneTree
## testFlows.gd - headless check of the whole app, driving the REAL screens (main.tscn) through their
## public functions, on a throwaway save folder (unique per run, deleted at the end)
## what this offers: python tests/runGodot.py script res://tests/testFlows.gd
## covers: first-launch profile; start a workout; multi-select add with the ghost preview; sets incl.
## 0 = planned; grips; finish -> save template -> the week; apply a template; start-at-0 setting;
## nothing-logged finish; discard + undo; edit a past workout; delete + undo; restart survival
## (storage reloaded from disk + a new app); settings take effect; region sheet -> picker filter;
## picker search / equipment / favourites / hidden / templates; back handling; backup round trip
## asserts real numbers (effective sets, counts), prints PASS/FAIL lines and ALL PASS / N FAILURE(S)
## never touches the clipboard or the real save files

### /// TUNING ///

# throwaway folder name prefix inside user://
const folderPrefix: String = "_testPhase2Flows_"
# seconds for slides / sheets to finish, and for a heat blend to land
const settleSeconds: float = 0.45
const blendSeconds: float = 2.3
# exercises used (curated, ids from appData)
const bench: String = "Barbell_Bench_Press_-_Medium_Grip"
const row: String = "Bent_Over_Barbell_Row"
const pulldown: String = "Wide-Grip_Lat_Pulldown"
const curl: String = "Barbell_Curl"
const pullups: String = "Pullups"

var storage: Node = null
var appTheme: Node = null
var appData: Node = null
var app: Node = null
var folder: String = ""
var failures: int = 0
var checks: int = 0
var firstTemplateId: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	storage = root.get_node("/root/Storage")
	appTheme = root.get_node("/root/AppTheme")
	appData = root.get_node("/root/AppData")
	folder = "user://%s%d_%d" % [folderPrefix, OS.get_process_id(), Time.get_ticks_usec()]
	storage.loadAll(folder)
	appTheme.apply(str(storage.profile["theme"]))
	await _openApp()

	await _checkProfileSetup()
	await _checkWorkoutFlow()
	await _checkTemplateApplyAndDiscard()
	await _checkStartAtZero()
	await _checkEditor()
	await _checkDeleteUndo()
	await _checkPeriods()
	await _checkRestart()
	await _checkSettings()
	await _checkRegionSheetToPicker()
	await _checkPickerFilters()
	await _checkBack()
	await _checkSeveralMuscles()
	await _checkCardio()
	await _checkTargets()
	await _checkBackup()

	_closeApp()
	await _wait(0.1)
	_removeFolder(folder)
	if failures == 0:
		print("ALL PASS (%d checks)" % checks)
	else:
		print("%d FAILURE(S) of %d checks" % [failures, checks])
	quit(mini(failures, 1))


### /// HELPERS ///

func _expectTrue(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


func _expectEqual(label: String, got: Variant, want: Variant) -> void:
	checks += 1
	if got == want:
		print("PASS  %s = %s" % [label, str(got)])
	else:
		failures += 1
		print("FAIL  %s = %s, want %s" % [label, str(got), str(want)])


func _expectNear(label: String, got: float, want: float, tolerance: float = 0.001) -> void:
	checks += 1
	if absf(got - want) <= tolerance:
		print("PASS  %s = %.3f" % [label, got])
	else:
		failures += 1
		print("FAIL  %s = %.3f, want %.3f" % [label, got, want])


func _share(exerciseId: String, regionId: String) -> float:
	return appData.exerciseShare(exerciseId, regionId)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _openApp() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await _wait(settleSeconds)


func _closeApp() -> void:
	if app != null and is_instance_valid(app):
		app.queue_free()
	app = null


func _isA(node: Variant, className: String) -> bool:
	# class check by script name - naming the app's classes here would compile them before the
	# autoloads exist and print noise
	if not (node is Object) or not is_instance_valid(node) or node.get_script() == null:
		return false
	return node.get_script().get_global_name() == className


func _setCount(entries: Array) -> int:
	var total: int = 0
	for entry in entries:
		total += int(entry["sets"])
	return total


func _formatSets(value: float) -> String:
	# same text the app shows (Ui.formatSets)
	if absf(value - roundf(value)) < 0.05:
		return "%d" % int(roundf(value))
	return "%.1f" % value


func _findText(node: Node, text: String) -> bool:
	# any Label / Button under node showing exactly this text
	if (node is Label or node is Button) and node.text == text:
		return true
	for child in node.get_children():
		if _findText(child, text):
			return true
	return false


func _removeFolder(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_removeFolder(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


### /// FIRST LAUNCH ///

func _checkProfileSetup() -> void:
	var setup: Node = app.top()
	_expectTrue("first launch opens the profile setup", _isA(setup, "ProfileSetup"))
	_expectTrue("Next is off until there is a name", setup.nextButton.disabled)
	setup.setNameText("Sam")
	_expectTrue("Next is on with a name", not setup.nextButton.disabled)
	setup.next()
	setup.chooseBody("female")
	_expectEqual("preview follows the body", setup.previewBody.body, "female")
	setup.next()
	setup.chooseGradient("ember")
	_expectEqual("preview follows the gradient", setup.previewBody.gradientId, "ember")
	setup.next()
	setup.chooseTheme("light")
	_expectTrue("the setup screen wears the chosen theme", setup.theme != null and setup.theme.get_color("accent", "App") == appTheme.paletteOf("light")["accent"])
	_expectEqual("still the old theme app-wide while picking", appTheme.currentId, "ember")
	setup.next()
	await _wait(settleSeconds)
	_expectEqual("profile name saved", storage.profile["name"], "Sam")
	_expectEqual("profile body saved", storage.profile["body"], "female")
	_expectEqual("profile gradient saved", storage.profile["gradient"], "ember")
	_expectEqual("profile theme saved", storage.profile["theme"], "light")
	_expectEqual("setup marked done", storage.profile["setupDone"], true)
	_expectEqual("theme applied app-wide", appTheme.currentId, "light")
	var week: Node = app.top()
	_expectTrue("the week opens after setup", _isA(week, "WeekScreen"))
	_expectTrue("greeting has the name", week.greetingLabel.text.ends_with("Sam"))
	_expectEqual("week body is the chosen one", week.bodyCard.bodyView.body, "female")
	_expectEqual("week gradient is the chosen one", week.bodyCard.bodyView.gradientId, "ember")
	_expectEqual("one screen in the stack", app.screens.size(), 1)


### /// A WORKOUT, START TO FINISH ///

func _checkWorkoutFlow() -> void:
	### WHAT THIS DOES
	# start, multi-select 4 then untick 1, sets incl. planned, grips, finish, template, the week

	var week: Node = app.weekScreen()
	var workout: Node = week.startWorkout()
	await _wait(settleSeconds)
	_expectTrue("Start opens the workout", app.top() == workout and workout.live)
	_expectTrue("a workout is running", storage.hasCurrentWorkout())

	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)
	_expectTrue("Add exercise opens the picker", app.top() == picker)
	for exerciseId in [bench, row, pulldown, curl]:
		picker.toggleExercise(exerciseId)
	_expectEqual("4 ticked", picker.selected.size(), 4)
	_expectEqual("button counts them", picker.addButton.text, "Add 4 exercises")
	picker.toggleExercise(curl)
	_expectEqual("untick leaves 3", picker.selected.size(), 3)
	var ghost: Dictionary = picker.bodyCard.bodyView.ghostHeat
	_expectNear("ghost chest = bench share x 1 set", float(ghost.get("lowerChest", 0.0)), _share(bench, "lowerChest"))
	_expectNear("ghost lats = row + pulldown shares", float(ghost.get("lats", 0.0)), _share(row, "lats") + _share(pulldown, "lats"))
	_expectNear("unticked curl gives no ghost biceps beyond the others", float(ghost.get("biceps", 0.0)), _share(row, "biceps") + _share(pulldown, "biceps") + _share(bench, "biceps"))
	picker.addSelected()
	await _wait(settleSeconds)
	_expectTrue("back on the workout after adding", app.top() == workout)
	_expectEqual("3 entries added", workout.entries().size(), 3)
	_expectEqual("new entries start at 1 set (default)", workout.entries()[0]["sets"], 1)

	# sets: bench 4, row 0 (planned), pulldown 3
	workout.setSets(0, 4)
	workout.setSets(1, 0)
	workout.changeSets(2, 2)
	_expectEqual("stepper + twice from 1 = 3", storage.currentWorkout()["entries"][2]["sets"], 3)
	var heat: Dictionary = workout.bodyCard.bodyView.toHeat
	_expectNear("workout chest = 4 x bench share", float(heat.get("lowerChest", 0.0)), 4.0 * _share(bench, "lowerChest"))
	_expectNear("planned row adds no lats heat", float(heat.get("lats", 0.0)), 3.0 * _share(pulldown, "lats"))
	_expectNear("planned row shows as ghost", float(workout.bodyCard.bodyView.ghostHeat.get("midTraps", 0.0)), _share(row, "midTraps"))
	_expectTrue("planned tag shown on the 0-set row", workout.rowParts[1]["plannedTag"].visible)
	_expectTrue("no planned tag on a logged row", not workout.rowParts[0]["plannedTag"].visible)

	# grips: only on forearmKind grip
	_expectTrue("no grips box on bench (forearmKind none)", workout.rowParts[0]["grips"] == null)
	_expectTrue("grips box on the row (grip)", workout.rowParts[1]["grips"] != null)
	_expectTrue("grips box on the pulldown (grip)", workout.rowParts[2]["grips"] != null)
	var forearmsBefore: float = float(workout.bodyCard.bodyView.toHeat.get("forearms", 0.0))
	_expectNear("forearms before grips", forearmsBefore, 4.0 * _share(bench, "forearms") + 3.0 * _share(pulldown, "forearms"))
	workout.setGrips(2, true)
	_expectNear("grips drop the pulldown's forearm heat", float(workout.bodyCard.bodyView.toHeat.get("forearms", 0.0)), 4.0 * _share(bench, "forearms"))
	_expectTrue("grips choice remembered for the exercise", bool(storage.getPref(pulldown)["grips"]))
	_expectTrue("grips box shows ticked", workout.rowParts[2]["grips"].button_pressed)

	# remove + undo
	workout.removeEntry(0)
	_expectEqual("remove takes it out", workout.entries().size(), 2)
	_expectTrue("remove shows an undo toast", app.toast.isShowing() and app.toast.messageText().begins_with("Removed"))
	app.toast.pressAction()
	_expectEqual("undo puts it back", workout.entries().size(), 3)
	_expectEqual("back in its place", workout.entries()[0]["exerciseId"], bench)

	# finish -> template -> week
	var confirm: Node = workout.requestFinish()
	await _wait(settleSeconds)
	_expectEqual("finish asks first", confirm.titleLabel.text, "Finish workout?")
	confirm.choose("finish")
	await _wait(settleSeconds)
	var templateSheet: Node = app.topSheet()
	_expectTrue("then offers save as template", templateSheet != null and templateSheet.lineEdit != null)
	templateSheet.setText("Push test")
	templateSheet.choose("ok")
	await _wait(settleSeconds)
	_expectEqual("one workout in the week", storage.submittedWorkouts().size(), 1)
	_expectEqual("planned entry dropped on finish", storage.submittedWorkouts()[0]["entries"].size(), 2)
	_expectEqual("template saved", storage.templates.size(), 1)
	_expectEqual("template name", storage.templates[0]["name"], "Push test")
	_expectEqual("template keeps the pulldown's grips", storage.templates[0]["entries"][1]["grips"], true)
	firstTemplateId = storage.templates[0]["id"]
	_expectTrue("landed on the week", _isA(app.top(), "WeekScreen"))
	_expectTrue("no workout running", not storage.hasCurrentWorkout())
	_expectNear("week heat: chest", float(week.shownHeat.get("lowerChest", 0.0)), 4.0 * _share(bench, "lowerChest"))
	_expectTrue("finish blend is the slow one", week.bodyCard.bodyView.transitionSeconds > 1.0)
	_expectTrue("the change is animating (not landed yet)", absf(float(week.bodyCard.bodyView.heatShown().get("lowerChest", 0.0)) - 4.0 * _share(bench, "lowerChest")) > 0.01)
	await _wait(blendSeconds)
	_expectNear("blend lands on the new week", float(week.bodyCard.bodyView.heatShown().get("lowerChest", 0.0)), 4.0 * _share(bench, "lowerChest"))
	_expectTrue("header counts 1 workout, 7 sets", week.statsLabel.text.contains("1 workout ·") and week.statsLabel.text.ends_with("7 sets"))
	_expectEqual("workouts tab lists it", week.workoutsBox.get_child_count(), 2)
	_expectEqual("start button back to Start", week.startButton.text, "Start workout")


func _checkTemplateApplyAndDiscard() -> void:
	var week: Node = app.weekScreen()

	# the start-up replay: empties the body, fills it back, lands on the real week; a body tap skips it
	week.startReplay()
	_expectTrue("replay runs", week.replaying())
	_expectTrue("replay starts from an empty body", week.bodyCard.bodyView.heatShown().is_empty())
	await _wait(week.replayMaxSeconds + 0.5)
	_expectTrue("replay ends by itself", not week.replaying())
	_expectNear("replay lands on the week", float(week.bodyCard.bodyView.heatShown().get("lowerChest", 0.0)), float(week.shownHeat.get("lowerChest", 0.0)))
	_expectEqual("replay gives the title back", week.bodyCard.titleLabel.text, week.cardTitle())
	week.startReplay()
	week._onBodyEmptyTapped()
	_expectTrue("a tap on the body skips the replay", not week.replaying())

	var workout: Node = week.startWorkout()
	await _wait(settleSeconds)
	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)
	picker.showTab("templates")
	picker.previewTemplate(firstTemplateId)
	_expectNear("template preview ghost", float(picker.ghost().get("lowerChest", 0.0)), 4.0 * _share(bench, "lowerChest"))
	picker.applyTemplate(firstTemplateId)
	await _wait(settleSeconds)
	_expectTrue("apply returns to the workout", app.top() == workout)
	var entries: Array = workout.entries()
	_expectEqual("template entries applied", entries.size(), 2)
	_expectEqual("with their sets", entries[0]["sets"], 4)
	_expectEqual("and grips", entries[1]["grips"], true)
	_expectTrue("newest exercise is the top row", workout.rowsBox.get_child(0) == workout.rowParts[1]["row"])

	# "+ Week" adds the finished workout (bench x4) to this one's bench x4, on the week's 0-N
	workout.setShowWeek(true)
	_expectNear("+ Week: chest = both workouts", float(workout.bodyCard.bodyView.toHeat.get("lowerChest", 0.0)), 8.0 * _share(bench, "lowerChest"))
	_expectEqual("+ Week: slider on the week's 0-N", workout.bodyCard.rangeKey, "rangeWeek")
	_expectTrue("+ Week remembered", bool(storage.settings["workoutShowWeek"]))
	workout.setShowWeek(false)
	_expectNear("week off: only this workout", float(workout.bodyCard.bodyView.toHeat.get("lowerChest", 0.0)), 4.0 * _share(bench, "lowerChest"))

	# "Filter by unused": exercises for muscles at 0 sets first, nothing dropped; a tapped muscle clears it
	var unusedPicker: Node = workout.openPicker()
	await _wait(settleSeconds)
	var allCount: int = unusedPicker.results.size()
	unusedPicker.setOrder("unused")
	_expectEqual("unused: nothing dropped", unusedPicker.results.size(), allCount)
	_expectTrue("unused: top row hits unused muscles", unusedPicker.orderShares.has(unusedPicker.results[0]["id"]))
	_expectTrue("unused: bench is not on top", unusedPicker.results[0]["id"] != bench)
	unusedPicker.setRegionFilter("lats")
	_expectTrue("a tapped muscle turns unused off", unusedPicker.orderMode == "" and not unusedPicker.unusedChip.button_pressed)
	app.goBack()
	await _wait(settleSeconds)

	# discard + undo, then discard for real
	workout.discard()
	await _wait(settleSeconds)
	_expectTrue("discard ends it", not storage.hasCurrentWorkout() and _isA(app.top(), "WeekScreen"))
	app.toast.pressAction()
	await _wait(0.1)
	_expectTrue("undo brings it back", storage.hasCurrentWorkout() and storage.currentWorkout()["entries"].size() == 2)
	_expectTrue("resume button shows the clock", week.startButton.text.begins_with("Resume workout · "))
	var again: Node = week.startWorkout()
	await _wait(settleSeconds)
	_expectEqual("resume opens the same workout", again.entries().size(), 2)
	again.discard()
	await _wait(settleSeconds)
	_expectTrue("discarded", not storage.hasCurrentWorkout())


func _checkStartAtZero() -> void:
	### WHAT THIS DOES
	# "new exercises start at 0" -> planned entries and templates at 0; finish with nothing logged

	var week: Node = app.weekScreen()
	var settings: Node = app.openSettings()
	await _wait(settleSeconds)
	settings.setNewExerciseSets(0)
	_expectEqual("setting saved", storage.settings["newExerciseSets"], 0)
	app.goBack()
	await _wait(settleSeconds)

	var workout: Node = week.startWorkout()
	await _wait(settleSeconds)
	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)
	picker.toggleExercise(curl)
	_expectNear("ghost still previews 1 set when starting at 0", float(picker.ghost().get("biceps", 0.0)), _share(curl, "biceps"))
	picker.addSelected()
	await _wait(settleSeconds)
	_expectEqual("added at 0 sets (planned)", workout.entries()[0]["sets"], 0)
	_expectNear("planned curl: no biceps heat", float(workout.bodyCard.bodyView.toHeat.get("biceps", 0.0)), 0.0)
	_expectNear("planned curl: ghost biceps", float(workout.bodyCard.bodyView.ghostHeat.get("biceps", 0.0)), _share(curl, "biceps"))
	picker = workout.openPicker()
	await _wait(settleSeconds)
	picker.showTab("templates")
	picker.applyTemplate(firstTemplateId)
	await _wait(settleSeconds)
	_expectEqual("template applied at 0 sets too", _setCount(workout.entries()), 0)
	_expectEqual("3 planned entries", workout.entries().size(), 3)

	var sheet: Node = workout.requestFinish()
	await _wait(settleSeconds)
	_expectEqual("nothing logged = no finish", sheet.titleLabel.text, "Nothing logged yet")
	sheet.choose("keep")
	await _wait(settleSeconds)
	_expectTrue("keep going keeps it", storage.hasCurrentWorkout())
	workout.setSets(0, 2)
	workout.requestFinish()
	await _wait(settleSeconds)
	app.topSheet().choose("finish")
	await _wait(settleSeconds)
	app.topSheet().choose("cancel")
	await _wait(settleSeconds)
	_expectEqual("Not now saves no template", storage.templates.size(), 1)
	_expectEqual("second workout in the week", storage.submittedWorkouts().size(), 2)
	_expectEqual("only the logged curl kept", storage.submittedWorkouts()[1]["entries"].size(), 1)
	storage.setSetting("newExerciseSets", 1)
	await _wait(blendSeconds)


### /// PAST WORKOUTS ///

func _checkEditor() -> void:
	var week: Node = app.weekScreen()
	var firstId: String = storage.submittedWorkouts()[0]["id"]
	week.showTab("workouts")
	var editor: Node = week.openEditor(firstId)
	await _wait(settleSeconds)
	_expectTrue("tap opens the editor", app.top() == editor and not editor.live)
	_expectTrue("Save is off until something changes", editor.mainButton.disabled)
	editor.setSets(0, 6)
	_expectTrue("Save turns on", not editor.mainButton.disabled)
	_expectEqual("nothing saved yet", storage.submittedWorkouts()[0]["entries"][0]["sets"], 4)

	# back with changes asks; discard keeps the old
	app.goBack()
	await _wait(settleSeconds)
	_expectEqual("back asks about the changes", app.topSheet().titleLabel.text, "Unsaved changes")
	app.topSheet().choose("discard")
	await _wait(settleSeconds)
	_expectEqual("discarded edit changed nothing", storage.submittedWorkouts()[0]["entries"][0]["sets"], 4)

	editor = week.openEditor(firstId)
	await _wait(settleSeconds)
	editor.setSets(0, 6)
	editor.addExercises([curl])
	editor.setSets(2, 0)
	editor.saveChanges()
	await _wait(settleSeconds)
	_expectEqual("saved sets", storage.submittedWorkouts()[0]["entries"][0]["sets"], 6)
	_expectEqual("0-set entry dropped on save", storage.submittedWorkouts()[0]["entries"].size(), 2)
	_expectTrue("back on the week", _isA(app.top(), "WeekScreen"))
	_expectNear("week heat follows the edit", float(week.shownHeat.get("lowerChest", 0.0)), 6.0 * _share(bench, "lowerChest"))


func _checkDeleteUndo() -> void:
	var week: Node = app.weekScreen()
	var before: int = storage.submittedWorkouts().size()
	var victim: String = storage.submittedWorkouts()[1]["id"]
	week.deleteWorkout(victim)
	await _wait(0.1)
	_expectEqual("delete removes it", storage.submittedWorkouts().size(), before - 1)
	_expectEqual("toast says so", app.toast.messageText(), "Workout deleted")
	_expectEqual("week rows follow", week.workoutsBox.get_child_count(), before)
	app.toast.pressAction()
	await _wait(0.1)
	_expectEqual("undo restores it", storage.submittedWorkouts().size(), before)
	_expectEqual("week rows back", week.workoutsBox.get_child_count(), before + 1)
	_expectTrue("toast gone after undo", not app.toast.isShowing())


### /// PERIODS ///

func _checkPeriods() -> void:
	### WHAT THIS DOES
	# day / week / month / year on the home page: an old workout (20 days back) joins the month and
	# year, which show sets PER WEEK (divided by the weeks since the first workout); each switch lights
	# the body up over exactly 3 s and lands on the shown heat; the pick is remembered

	var week: Node = app.weekScreen()
	var now: float = Time.get_unix_time_from_system()
	var oldTime: float = now - 20.0 * 86400.0
	var old: Dictionary = {"id": "wPeriodOld", "startedAt": oldTime, "endedAt": oldTime + 3600.0, "entries": [{"exerciseId": bench, "sets": 3, "grips": false}]}
	var recent: int = storage.submittedWorkouts().size()

	storage.restoreWorkout(old)
	await _wait(0.1)
	var weekChest: float = float(week.shownHeat.get("lowerChest", 0.0))
	_expectEqual("week leaves the old workout out", week.shownWorkouts.size(), recent)

	# month: the old workout counts, everything per week over the 20 days since the first workout
	week.setPeriod("month")
	_expectEqual("month: title", week.pageTitle.text, "This month")
	_expectEqual("month: the old workout is in", week.shownWorkouts.size(), recent + 1)
	var weeksExpected: float = (now - oldTime - 3600.0) / 86400.0 / 7.0
	_expectNear("month: weeks covered = since the old workout ended", week.weeksCovered, weeksExpected)
	_expectNear("month: chest per week", float(week.shownHeat.get("lowerChest", 0.0)), (weekChest + 3.0 * _share(bench, "lowerChest")) / weeksExpected)
	_expectTrue("switch lights the body up", week.replaying() and week.bodyCard.bodyView.heatShown().is_empty())
	_expectNear("the light-up takes exactly 3 s", week.replayLength(), 3.0, 0.01)
	_expectTrue("stats line reads per week", week.statsLabel.text.ends_with("sets a week"))
	await _wait(3.4)
	_expectTrue("light-up ends by itself", not week.replaying())
	_expectNear("light-up lands on the month", float(week.bodyCard.bodyView.heatShown().get("lowerChest", 0.0)), float(week.shownHeat.get("lowerChest", 0.0)))
	_expectEqual("month remembered", storage.settings["homePeriod"], "month")

	# year: one row per calendar month that has a workout
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var months: Dictionary = {}
	for workout in storage.submittedWorkouts():
		var date: Dictionary = Time.get_datetime_dict_from_unix_time(int(workout["endedAt"]) + bias * 60)
		months["%d-%d" % [int(date["year"]), int(date["month"])]] = true
	week.showTab("workouts")
	week.setPeriod("year")
	await _wait(settleSeconds)
	_expectEqual("year: a row per month", week.workoutsBox.get_child_count() - 1, months.size())
	_expectTrue("year: rows are months", week.workoutsBox.get_child(1).has_meta("month"))
	_expectNear("year: same weeks covered as the month here", week.weeksCovered, weeksExpected)

	# day: today only, raw; the balance lists only the muscles worked today
	week.showTab("balance")
	week.setPeriod("day")
	await _wait(settleSeconds)
	_expectEqual("day: title", week.pageTitle.text, "Today")
	_expectNear("day: raw sets", week.weeksCovered, 1.0)
	var shownRows: int = 0
	for regionId in week.balanceRows:
		if week.balanceRows[regionId]["row"].visible:
			shownRows += 1
	_expectEqual("day: balance lists the worked muscles only", shownRows, week.balanceRanks.size())
	_expectTrue("day: fewer than all 30", week.balanceRanks.size() < 30 and week.balanceRanks.size() > 0)

	# back to the week; the old workout goes again
	week.setPeriod("week")
	week._onBodyEmptyTapped()
	storage.deleteWorkout("wPeriodOld")
	await _wait(0.1)
	_expectNear("week again", float(week.shownHeat.get("lowerChest", 0.0)), weekChest)
	_expectEqual("week remembered", storage.settings["homePeriod"], "week")


### /// RESTART ///

func _checkRestart() -> void:
	### WHAT THIS DOES
	# a running workout, then the app is closed, storage re-read from disk, a new app opened

	var week: Node = app.weekScreen()
	var workout: Node = week.startWorkout()
	await _wait(settleSeconds)
	workout.addExercises([bench, row])
	workout.setSets(1, 2)
	var startedAt: float = float(storage.currentWorkout()["startedAt"])
	_closeApp()
	await _wait(0.2)
	storage.loadAll(folder)
	await _openApp()
	_expectTrue("reopens into the running workout", _isA(app.top(), "WorkoutScreen") and app.top().live)
	_expectTrue("with the week under it", app.screens.size() == 2 and _isA(app.screens[0], "WeekScreen"))
	var reopened: Node = app.top()
	_expectEqual("entries survived", reopened.entries().size(), 2)
	_expectEqual("sets survived", reopened.entries()[1]["sets"], 2)
	_expectNear("start time survived", float(storage.currentWorkout()["startedAt"]), startedAt)
	_expectNear("its heat is back", float(reopened.bodyCard.bodyView.toHeat.get("lowerChest", 0.0)), 1.0 * _share(bench, "lowerChest"))
	reopened.discard()
	await _wait(settleSeconds)


### /// SETTINGS ///

func _checkSettings() -> void:
	var week: Node = app.weekScreen()
	var body: Node = week.bodyCard.bodyView
	var settings: Node = app.openSettings()
	await _wait(settleSeconds)

	_expectTrue("the week has the 0-N slider", week.bodyCard.slider != null)
	_expectEqual("week card title", week.bodyCard.titleLabel.text, "Sets this week")

	var plain: Color = appTheme.colour("bodyPlain")
	_expectTrue("untouched tibialis coloured (amount, ember at 0)", body.regionColours["tibialis"] != plain)
	settings.setHideUntouched(true)
	_expectTrue("hide untouched reaches the body", body.hideUntouched)
	_expectEqual("untouched tibialis now plain", body.regionColours["tibialis"], plain)
	_expectTrue("a worked region still coloured", body.regionColours["lowerChest"] != plain)
	settings.setHideUntouched(false)

	settings.setDefaultView("front")
	_expectEqual("default view reaches the week", body.viewMode, "front")
	settings.setGradient("scarlet")
	settings.setBody("male")
	settings.setName("Bea")
	_expectEqual("name saved", storage.profile["name"], "Bea")
	settings.setTheme("ocean")
	await _wait(0.2)
	_expectEqual("theme applied", appTheme.currentId, "ocean")
	_expectEqual("settings rebuilt in the new theme", settings.themeChoice.selectedId, "ocean")

	# style: Frutiger builds every screen again in its look with Settings open on top again; a style
	# that is not installed falls back to Modern
	settings.setStyle("frutiger")
	await _wait(settleSeconds)
	_expectEqual("style applied", appTheme.currentStyleId, "frutiger")
	_expectTrue("settings open again on top", _isA(app.top(), "SettingsScreen"))
	_expectTrue("the week was built again", app.weekScreen() != week)
	settings = app.top()
	settings.setStyle("noSuchStyle")
	await _wait(settleSeconds)
	_expectEqual("an unknown style falls back to modern", appTheme.currentStyleId, "modern")
	storage.setProfile("style", "modern")
	await _wait(0.2)
	week = app.weekScreen()
	body = week.bodyCard.bodyView
	app.goBack()
	await _wait(settleSeconds)
	# profile changes reach the week when it shows again
	_expectEqual("gradient reaches the body", body.gradientId, "scarlet")
	_expectEqual("and the slider", week.bodyCard.slider.gradientId, "scarlet")
	_expectEqual("body reaches the week", body.body, "male")
	_expectTrue("week greets the new name", week.greetingLabel.text.ends_with("Bea"))
	storage.setSetting("defaultView", "both")


### /// REGION SHEET AND PICKER ///

func _checkRegionSheetToPicker() -> void:
	var week: Node = app.weekScreen()
	var sheet: Node = week.openRegion("lowerChest")
	await _wait(settleSeconds)
	_expectEqual("region sheet title", sheet.titleLabel.text, "Mid/lower chest")
	_expectEqual("region outlined on the body", week.bodyCard.bodyView.selectedRegions, ["lowerChest"])
	_expectEqual("contributions listed (only the bench reaches it)", int(sheet.get_meta("contributionCount")), 1)
	_expectTrue("sets this week shown", _findText(sheet, _formatSets(float(week.shownHeat["lowerChest"]))))
	sheet.choose("find")
	await _wait(settleSeconds)
	var picker: Node = app.top()
	_expectTrue("Find exercises opens the picker", _isA(picker, "PickerScreen"))
	_expectEqual("filtered to that muscle", picker.regionFilters, ["lowerChest"])
	_expectEqual("region cleared on the week when the sheet closed", week.bodyCard.bodyView.selectedRegions, [])
	var allReach: bool = picker.results.size() > 0
	for exercise in picker.results:
		if _share(exercise["id"], "lowerChest") <= 0.0:
			allReach = false
	_expectTrue("every result reaches the muscle", allReach)
	_expectEqual("results = HeatEngine.recommend order", picker.results[0]["id"], HeatEngine.recommend(["lowerChest"], appData.exercises, {"prefs": storage.exercisePrefs, "used": storage.usedExercises()})[0]["exercise"]["id"])
	_expectEqual("nothing ticked yet", picker.addButton.text, "Tick exercises to add")
	picker.toggleExercise(bench)
	_expectEqual("start-a-workout wording", picker.addButton.text, "Start workout with 1 exercise")
	picker.clearRegionFilter()
	_expectEqual("chip clears the filter", picker.regionFilters, [])
	picker.addSelected()
	await _wait(settleSeconds)
	_expectTrue("a workout started and opened in place of the picker", _isA(app.top(), "WorkoutScreen") and app.screens.size() == 2)
	_expectEqual("with the exercise", storage.currentWorkout()["entries"].size(), 1)


func _checkPickerFilters() -> void:
	var workout: Node = app.top()
	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)

	picker.setSearch("curl")
	var allCurl: bool = picker.results.size() > 0
	for exercise in picker.results:
		if not str(exercise["name"]).to_lower().contains("curl"):
			allCurl = false
	_expectTrue("search: every result is a curl (%d)" % picker.results.size(), allCurl)
	picker.setEquipment(["dumbbell"])
	var allDumbbell: bool = picker.results.size() > 0
	for exercise in picker.results:
		if exercise["equipment"] != "dumbbell":
			allDumbbell = false
	_expectTrue("equipment chip: dumbbell only (%d)" % picker.results.size(), allDumbbell)
	_expectTrue("chip shows pressed", picker.equipmentChips["dumbbell"].button_pressed and not picker.allChip.button_pressed)
	picker.setSearch("")
	picker.setEquipment([])
	_expectTrue("All chip back on", picker.allChip.button_pressed)

	picker.setFavourite("Russian_Twist", true)
	_expectEqual("favourite listed first", picker.results[0]["id"], "Russian_Twist")
	picker.setHidden(curl, true)
	var hiddenGone: bool = true
	for exercise in picker.results:
		if exercise["id"] == curl:
			hiddenGone = false
	_expectTrue("hidden exercise not listed", hiddenGone)
	picker.setShowHidden(true)
	var hiddenBack: bool = false
	for exercise in picker.results:
		if exercise["id"] == curl:
			hiddenBack = true
	_expectTrue("show hidden lists it", hiddenBack)
	picker.setShowHidden(false)
	app.toast.pressAction()
	_expectTrue("hide undo", not bool(storage.getPref(curl)["hidden"]))

	# the rough data marker on non-curated rows, never on curated ones (medicine ball: 11 rough of 17, all
	# on the first page - checked ones list first);
	# the list makes its first rows at once and the rest over the next frames
	picker.setEquipment(["medicine ball"])
	_expectEqual("the first rows are there at once", picker.shownCount, mini(picker.firstRows, picker.results.size()))
	await _wait(settleSeconds)
	_expectTrue("the rest of the batch follows within a moment (%d rows)" % picker.shownCount, picker.shownCount >= mini(picker.pageSize, picker.results.size()))
	var roughOk: bool = true
	var roughSeen: int = 0
	for exerciseId in picker.rowsById:
		var marked: bool = _findText(picker.rowsById[exerciseId], "ROUGH DATA")
		var curated: bool = bool(appData.getExercise(exerciseId)["curated"])
		if marked == curated:
			roughOk = false
		if marked:
			roughSeen += 1
	_expectTrue("rough data marker exactly on non-curated rows (%d seen)" % roughSeen, roughOk and roughSeen > 0)
	picker.setEquipment([])

	# templates: rename + delete with undo
	picker.showTab("templates")
	var renameSheet: Node = picker.renameTemplate(firstTemplateId)
	await _wait(settleSeconds)
	renameSheet.setText("Push renamed")
	renameSheet.choose("ok")
	await _wait(settleSeconds)
	_expectEqual("template renamed", storage.templates[0]["name"], "Push renamed")
	_expectTrue("templates tab shows the new name", _findText(picker.templatesBox, "Push renamed"))
	picker.deleteTemplate(firstTemplateId)
	_expectEqual("template deleted", storage.templates.size(), 0)
	app.toast.pressAction()
	_expectEqual("template undo", storage.templates.size(), 1)
	await _wait(0.1)


### /// BACK ///

func _checkBack() -> void:
	var picker: Node = app.top()
	_expectTrue("picker on top", _isA(picker, "PickerScreen"))
	picker.openExerciseMenu(bench)
	await _wait(settleSeconds)
	_expectTrue("menu sheet open", app.topSheet() != null)
	_expectTrue("back closes the sheet", app.goBack() and app.topSheet() == null and app.top() == picker)
	await _wait(settleSeconds)
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(settleSeconds)
	_expectTrue("system back: picker -> workout", _isA(app.top(), "WorkoutScreen"))
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(settleSeconds)
	_expectTrue("system back: workout -> week, never quits mid-workout", _isA(app.top(), "WeekScreen") and storage.hasCurrentWorkout())
	_expectTrue("at the week nothing is left to close", not app.goBack())
	var workout: Node = app.weekScreen().startWorkout()
	await _wait(settleSeconds)
	workout.discard()
	await _wait(settleSeconds)


### /// SEVERAL MUSCLES, CARDIO, TARGETS ///

func _checkSeveralMuscles() -> void:
	### WHAT THIS DOES
	# a hold starts picking several muscles, then taps add / drop more; the chip names them and clears
	# them all; a tap with nothing held picks just one again

	var picker: Node = app.openPicker(null, "")
	await _wait(settleSeconds)
	_expectTrue("the body listens for a hold", picker.bodyCard.bodyView.regionLongPressed.get_connections().size() > 0)
	picker.addRegionFilter("lats")
	picker.setRegionFilter("biceps")
	_expectEqual("hold then tap: two muscles", picker.regionFilters, ["lats", "biceps"])
	_expectEqual("both outlined", picker.bodyCard.bodyView.selectedRegions, ["lats", "biceps"])
	_expectTrue("chip names both", picker.filterChip.text.contains("lats + biceps"))
	var allReach: bool = picker.results.size() > 0
	for exercise in picker.results:
		if _share(exercise["id"], "lats") + _share(exercise["id"], "biceps") <= 0.0:
			allReach = false
	_expectTrue("every result reaches one of them (%d)" % picker.results.size(), allReach)
	_expectEqual("pull-ups share is the sum", float(picker.resultShares[pullups]), _share(pullups, "lats") + _share(pullups, "biceps"))
	picker.setRegionFilter("lats")
	_expectEqual("tapping a picked one drops it", picker.regionFilters, ["biceps"])
	picker.clearRegionFilter()
	_expectTrue("chip clears them all", picker.regionFilters.is_empty() and not picker.pickingSeveral)
	picker.setRegionFilter("lats")
	picker.setRegionFilter("glutes")
	_expectEqual("plain taps: one muscle at a time", picker.regionFilters, ["glutes"])
	picker.clearRegionFilter()

	# a cardio exercise goes in with minutes and its own default effort
	picker.toggleExercise("Hiking")
	picker.addSelected()
	await _wait(settleSeconds)
	var entry: Dictionary = storage.currentWorkout()["entries"][0]
	_expectEqual("cardio entry: starting minutes", int(entry["minutes"]), storage.cardioStartMinutes)
	_expectEqual("cardio entry: Hiking defaults to easy", entry["effort"], "easy")


func _checkCardio() -> void:
	### WHAT THIS DOES
	# minutes and effort on the workout row, finish keeps a minutes-only workout, the home page's
	# Cardio chip appears and lights the vessels and the panel

	var workout: Node = app.top()
	_expectTrue("workout on top", _isA(workout, "WorkoutScreen"))
	workout.setMinutes(0, 40)
	workout.changeMinutes(0, workout.minuteStep)
	workout.setEffort(0, "hard")
	_expectEqual("row shows the minutes", workout.rowParts[0]["setsLabel"].text, "45")
	_expectEqual("effort chip follows", workout.rowParts[0]["effortChips"].selectedId, "hard")
	_expectTrue("summary counts cardio minutes", workout.summaryLabel.text.contains("45 min cardio"))
	_expectEqual("effort remembered for next time", storage.getPref("Hiking")["effort"], "hard")
	var confirm: Node = workout.requestFinish()
	await _wait(settleSeconds)
	_expectEqual("minutes alone can finish a workout", confirm.titleLabel.text, "Finish workout?")
	confirm.choose("finish")
	await _wait(settleSeconds)
	app.topSheet().choose("cancel")
	await _wait(settleSeconds)
	var week: Node = app.weekScreen()
	_expectTrue("back on the week", app.top() == week)
	_expectTrue("Cardio chip shows once cardio is logged", week.cardioChip.visible)
	_expectNear("hard cardio minutes this week", float(week.cardioMinutes["hardCardio"]), 45.0)
	week.setCardioOverlay(true)
	var layer: Node = week.bodyCard.bodyView.vesselLayer
	_expectTrue("vessels drawn", layer != null and layer.visible)
	_expectNear("red full (45 of 30 min)", float(layer.levels["red"]), 1.0)
	_expectNear("blue empty", float(layer.levels["blue"]), 0.0)
	var networks: Dictionary = layer._networks(week.bodyCard.bodyView.slots[0]["data"])
	_expectTrue("vessels: trunk + head, arm, torso, leg on each side (%d)" % networks["chains"].size(), networks["chains"].size() == 9)
	_expectTrue("hint gives the minutes", week.cardHintText().contains("Hard 45/30 min"))
	_expectTrue("cardio panel on the balance tab", week.cardioPanel.visible and _findText(week.cardioPanel, "Cardio this week"))
	week.setCardioOverlay(false)
	_expectTrue("vessels off", not layer.visible and not week.cardioPanel.visible)


func _checkTargets() -> void:
	### WHAT THIS DOES
	# presets on from the Targets screen, the home overlay against them, picker tags and Below target,
	# a custom target made, deleted and brought back

	var week: Node = app.weekScreen()
	_expectTrue("no presets on: no Targets chip", not week.targetsChip.visible)
	var screen: Node = app.openTargets()
	await _wait(settleSeconds)
	screen.toggle("basketball")
	screen.toggle("mew2")
	await _wait(0.1)
	_expectEqual("two presets on", storage.settings["activeTargets"], ["basketball", "mew2"])
	_expectTrue("their rows show on", screen.rows["basketball"].selected and screen.rows["mew2"].selected and not screen.rows["marathon"].selected)
	var baseline: float = float(storage.settings["rangeWeek"])
	var wantGlutes: float = maxf(baseline + float(appData.presetById["basketball"]["offsets"]["glutes"]), baseline + float(appData.presetById["mew2"]["offsets"]["glutes"]))

	# a custom target: +3 glutes, saved (and switched on), deleted, undone
	var editor: Node = screen.newTarget()
	await _wait(settleSeconds)
	editor.setName("Glute focus")
	for step in range(3):
		editor.changeOffset("glutes", 1)
	var step: int = editor.cardioStep
	editor.changeCardio("easyCardio", step)
	editor.save()
	await _wait(settleSeconds)
	var custom: Dictionary = storage.settings["customTargets"][0]
	_expectEqual("custom target saved", custom["offsets"]["glutes"], 3)
	_expectEqual("custom cardio saved", int(custom["cardio"]["easyCardio"]), int(appData.cardioDefaultTarget["easyCardio"]) + step)
	_expectTrue("a new target is switched on", storage.settings["activeTargets"].has(custom["id"]))
	screen.deletePreset(custom["id"])
	_expectTrue("deleted and off", storage.settings["customTargets"].is_empty() and not storage.settings["activeTargets"].has(custom["id"]))
	app.toast.pressAction()
	_expectTrue("undo brings it back on", storage.settings["customTargets"].size() == 1 and storage.settings["activeTargets"].has(custom["id"]))
	screen.deletePreset(custom["id"])
	app.goBack()
	await _wait(settleSeconds)

	# the home overlay
	_expectTrue("Targets chip shows with presets on", week.targetsChip.visible)
	week.setTargetsOverlay(true)
	_expectNear("glutes target = the higher preset", float(week.regionTargets["glutes"]), wantGlutes)
	_expectEqual("card title", week.cardTitle(), "Sets vs targets")
	var expected: Dictionary = HeatEngine.targetHeat(week.shownHeat, week.regionTargets, baseline)
	_expectNear("body shows sets as a share of the target", float(week.bodyCard.bodyView.toHeat.get("glutes", 0.0)), float(expected.get("glutes", 0.0)))
	_expectTrue("hint counts the muscles on target", week.cardHintText().contains("muscles on target"))
	_expectTrue("balance tab names the presets", week.targetsText.text.contains("Basketball") and week.targetsText.text.contains("mew2"))

	# picker: preset tags on key exercises, Below target order
	var keyId: String = appData.presetById["basketball"]["keyExercises"][0]
	var picker: Node = app.openPicker(null, "")
	await _wait(settleSeconds)
	picker.setSearch(str(appData.getExercise(keyId)["name"]))
	await _wait(settleSeconds)
	_expectTrue("key exercise tagged Basketball", picker.rowsById.has(keyId) and _findText(picker.rowsById[keyId], "Basketball"))
	picker.setSearch("")
	_expectTrue("Below target chip shown", picker.targetChip.visible)
	picker.setOrder("target")
	_expectTrue("below target: top row works a short muscle", picker.orderShares.has(picker.results[0]["id"]) and picker.targetChip.button_pressed)
	picker.setRegionFilter("lats")
	_expectTrue("a tapped muscle turns it off", picker.orderMode == "" and not picker.targetChip.button_pressed)
	app.goBack()
	await _wait(settleSeconds)

	# leave the rest of the run as it was
	week.setTargetsOverlay(false)
	storage.setSetting("activeTargets", [])
	await _wait(0.1)
	_expectTrue("presets off: chip gone, plain title", not week.targetsChip.visible and week.cardTitle() != "Sets vs targets")


### /// BACKUP ///

func _checkBackup() -> void:
	var settings: Node = app.openSettings()
	await _wait(settleSeconds)
	var exported: Dictionary = settings.exportBackup(false)
	_expectTrue("backup file written", FileAccess.file_exists(exported["path"]))
	var workoutsBefore: int = storage.submittedWorkouts().size()
	var templatesBefore: int = storage.templates.size()
	storage.deleteWorkout(storage.submittedWorkouts()[0]["id"])
	storage.setProfile("name", "Changed")
	_expectEqual("data changed after export", storage.submittedWorkouts().size(), workoutsBefore - 1)

	_expectTrue("junk is refused before any sheet", settings.askImport("not a backup") == null)
	var sheet: Node = settings.askImport(exported["text"])
	await _wait(settleSeconds)
	_expectEqual("import asks first", sheet.titleLabel.text, "Import this backup?")
	sheet.choose("import")
	await _wait(settleSeconds)
	_expectEqual("workouts restored", storage.submittedWorkouts().size(), workoutsBefore)
	_expectEqual("templates restored", storage.templates.size(), templatesBefore)
	_expectEqual("name restored", storage.profile["name"], "Bea")
	_expectEqual("settings screen shows the imported name", settings.nameEdit.text, "Bea")
	_expectEqual("toast confirms", app.toast.messageText(), "Backup imported")
	app.goBack()
	await _wait(settleSeconds)
	_expectTrue("week greets the imported name", app.weekScreen().greetingLabel.text.ends_with("Bea"))
