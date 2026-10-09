extends SceneTree
## shotPhase2.gd - photographs every phase-2 screen and sheet of the REAL app at phone size
## what this offers:
##   python tests/runGodot.py script res://tests/shotPhase2.gd --window -- <outFolder> [only]
## runs the app (main.tscn) on a throwaway save folder seeded with a sample week, drives it through
## the screens' public functions and saves <outFolder>/phase2_<theme>_<body>_<shot>.png
## passes: Ember + male, Light + female (every screen), Ocean + male (a few), then the first-launch
## setup steps; [only] = a pass name ("ember", "light", "ocean", "setup") to run just that one
## look pass: `-- <outFolder> look <style script res path> <palette,palette,...>` puts that style module
##   on the app (registered or not - for judging a new style) and shoots the main screens once per
##   palette as look_<style file>_<palette>_<shot>.png; a style that does not load fails the run
## the sample week holds two cardio sessions; the full passes and the look pass also shoot the targets
##   and cardio parts (both home overlays, the Targets screen and editor, a cardio workout row, the
##   picker with several muscles, preset tags and Below target)
## the throwaway folder is deleted at the end; prints each file it saved

### /// TUNING ///

# throwaway save folder prefix inside user://
const folderPrefix: String = "_phase2Shots_"
# seconds to let slides, sheets and heat blends settle before a grab
const settleSeconds: float = 0.7
const blendSeconds: float = 1.3
# pretend notch and gesture-bar heights for the safe-area plates (design px)
const safeTopPx: float = 40.0
const safeBottomPx: float = 28.0

var outFolder: String = ""
var only: String = ""
var folder: String = ""
var app: Node = null
var storage: Node = null
var appTheme: Node = null
var saved: int = 0
var prefix: String = ""


func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1 or not DirAccess.dir_exists_absolute(args[0]):
		print("usage: ... -- <existing outFolder> [only]")
		quit(2)
		return
	outFolder = args[0]
	if args.size() > 1:
		only = args[1]
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	storage = root.get_node("/root/Storage")
	appTheme = root.get_node("/root/AppTheme")
	folder = "user://%s%d" % [folderPrefix, OS.get_process_id()]

	if only == "look":
		if args.size() < 4:
			print("usage: ... -- <outFolder> look <style script res path> <palette,palette,...>")
			quit(2)
			return
		var ok: bool = await _lookPass(args[2], args[3].split(","))
		_closeApp()
		_removeFolder(folder)
		print("SHOTS DONE (%d saved)" % saved)
		if ok:
			quit(0)
		else:
			quit(1)
		return
	if only == "" or only == "ember":
		await _themePass("ember", "male", true)
	if only == "" or only == "light":
		await _themePass("light", "female", true)
	if only == "" or only == "ocean":
		await _themePass("ocean", "male", false)
	if only == "" or only == "setup":
		await _setupPass()

	_closeApp()
	_removeFolder(folder)
	print("SHOTS DONE (%d saved)" % saved)
	quit(0)


### /// SAMPLE DATA ///

func _seed(themeId: String, body: String) -> void:
	### WHAT THIS DOES
	# a fresh save folder with a profile, three workouts this week, one older, prefs and a template

	_removeFolder(folder)
	storage.loadAll(folder)
	storage.setProfile("name", "Sam")
	storage.setProfile("body", body)
	storage.setProfile("gradient", "infrared")
	storage.setProfile("theme", themeId)
	storage.setProfile("setupDone", true)
	var now: float = Time.get_unix_time_from_system()
	var day: float = 86400.0
	_addWorkout(now - 5.2 * day, 3900.0, [["Barbell_Bench_Press_-_Medium_Grip", 4], ["Incline_Dumbbell_Press", 3], ["Standing_Military_Press", 3], ["Side_Lateral_Raise", 3], ["Triceps_Pushdown", 3]])
	_addWorkout(now - 3.1 * day, 3300.0, [["Bent_Over_Barbell_Row", 4], ["Wide-Grip_Lat_Pulldown", 3], ["Pullups", 3], ["Face_Pull", 3], ["Barbell_Curl", 3], ["Hammer_Curls", 2]])
	_addWorkout(now - 1.05 * day, 4200.0, [["Barbell_Squat", 4], ["Romanian_Deadlift", 3], ["Leg_Press", 3], ["Lying_Leg_Curls", 3], ["Standing_Calf_Raises", 4], ["Cable_Crunch", 3]])
	_addWorkout(now - 10.0 * day, 3000.0, [["Barbell_Deadlift", 3]])
	_addCardio(now - 4.0 * day, "Walking_Brisk", 50, "easy")
	_addCardio(now - 2.0 * day, "Running_Outdoor", 25, "hard")
	storage.setFavourite("Face_Pull", true)
	storage.setFavourite("Side_Lateral_Raise", true)
	storage.setHidden("Cable_Shrugs", true)
	storage.saveTemplate("Push A", storage.submittedWorkouts()[0]["entries"])
	storage.saveTemplate("Pull A", storage.submittedWorkouts()[1]["entries"])
	appTheme.apply(themeId)


func _addWorkout(startedAt: float, length: float, rows: Array) -> void:
	storage.startWorkout(startedAt)
	for row in rows:
		storage.addEntry(row[0], row[1], false)
	storage.finishWorkout(startedAt + length)


func _addCardio(startedAt: float, exerciseId: String, minutes: int, effort: String) -> void:
	storage.startWorkout(startedAt)
	storage.addEntry(exerciseId)
	storage.setEntryMinutes(0, minutes)
	storage.setEntryEffort(0, effort)
	storage.finishWorkout(startedAt + minutes * 60.0)


### /// PASSES ///

func _openApp() -> void:
	_closeApp()
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await _wait(settleSeconds)


func _closeApp() -> void:
	if app != null and is_instance_valid(app):
		app.queue_free()
	app = null


func _themePass(themeId: String, body: String, everything: bool) -> void:
	### WHAT THIS DOES
	# every screen and sheet for one theme + body

	prefix = "phase2_%s_%s" % [themeId, body]
	_seed(themeId, body)
	await _openApp()
	var week: Node = app.weekScreen()
	await _wait(blendSeconds)
	await _grab("week_replay")
	while week.replaying():
		await _wait(0.1)
	await _wait(blendSeconds)
	await _grab("week_both")
	if everything:
		week.bodyCard.setView("front")
		await _wait(0.3)
		await _grab("week_front")
		week.bodyCard.setView("back")
		await _wait(0.3)
		await _grab("week_back")
		week.bodyCard.setView("both")
	week.scroll.scrollTo(560.0)
	await _wait(0.3)
	await _grab("week_balance")
	week.showTab("workouts")
	await _wait(0.3)
	await _grab("week_workouts")
	week.showTab("balance")
	week.scroll.scrollTo(0.0)

	# region sheet
	week.openRegion("rearDelt")
	await _wait(settleSeconds)
	await _grab("region_sheet")
	app.goBack()
	await _wait(settleSeconds)

	# workout with real + planned entries and grips
	var workout: Node = week.startWorkout()
	await _wait(settleSeconds)
	workout.addExercises(["Bent_Over_Barbell_Row", "Wide-Grip_Lat_Pulldown", "Face_Pull", "Barbell_Curl"])
	workout.setSets(0, 4)
	workout.setSets(1, 3)
	workout.setGrips(1, true)
	workout.setSets(2, 0)
	workout.setSets(3, 2)
	await _wait(blendSeconds)
	await _grab("workout_top")
	workout.scroll.scrollTo(380.0)
	await _wait(0.3)
	await _grab("workout_rows")
	workout.scroll.scrollTo(0.0)
	workout.setShowWeek(true)
	await _wait(blendSeconds)
	await _grab("workout_week")
	workout.setShowWeek(false)

	# picker: search + equipment + ticks with the ghost
	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)
	await _grab("picker_open")
	if everything:
		picker.toggleExercise("Seated_Cable_Rows")
		picker.toggleExercise("Reverse_Flyes")
		picker.toggleExercise("Side_Lateral_Raise")
		picker.setSearch("raise")
		picker.toggleEquipment("dumbbell")
		await _wait(0.4)
		await _grab("picker_search_ticked")
		picker.setSearch("")
		picker.setEquipment([])
		picker.setRegionFilter("rearDelt")
		await _wait(0.4)
		await _grab("picker_muscle")
		picker.setOrder("unused")
		await _wait(0.4)
		await _grab("picker_unused")
		picker.openExerciseMenu("Face_Pull")
		await _wait(settleSeconds)
		await _grab("picker_menu")
		app.goBack()
		await _wait(settleSeconds)
		picker.showTab("templates")
		picker.previewTemplate(storage.templates[0]["id"])
		await _wait(0.4)
		await _grab("picker_templates")
	app.goBack()
	await _wait(settleSeconds)

	# finish flow
	workout.requestFinish()
	await _wait(settleSeconds)
	await _grab("finish_confirm")
	app.topSheet().choose("finish")
	await _wait(settleSeconds)
	await _grab("finish_template")
	app.topSheet().setText("Pull B")
	app.topSheet().choose("ok")
	await _wait(0.5)
	await _grab("finish_week_blending")
	await _wait(2.0)

	# delete with the undo toast
	week.showTab("workouts")
	var newest: Array = storage.submittedWorkouts()
	week.deleteWorkout(newest[newest.size() - 1]["id"])
	await _wait(0.6)
	await _grab("undo_toast")
	app.toast.pressAction()
	await _wait(0.4)

	# editor of a past workout
	if everything:
		var editor: Node = week.openEditor(storage.submittedWorkouts()[1]["id"])
		await _wait(settleSeconds)
		editor.setSets(0, 5)
		await _wait(0.6)
		await _grab("editor")
		app.goBack()
		await _wait(settleSeconds)
		await _grab("editor_leave")
		app.topSheet().choose("discard")
		await _wait(settleSeconds)

	if everything:
		await _targetShots(week)

	# settings
	var settings: Node = app.openSettings()
	await _wait(settleSeconds)
	await _grab("settings_top")
	if everything:
		settings.scroll.scrollTo(900.0)
		await _wait(0.3)
		await _grab("settings_bottom")
	app.goBack()
	await _wait(settleSeconds)

	# a phone with a notch and a gesture bar: content, toast and sheets keep clear of both
	app.setSafeInsets(safeTopPx, safeBottomPx)
	await _wait(0.2)
	app.showToast("Safe area check", "Undo", func() -> void: pass)
	await _wait(settleSeconds)
	await _grab("safe_area_week")
	week.openRegion("lats")
	await _wait(settleSeconds)
	await _grab("safe_area_sheet")
	app.goBack()
	await _wait(settleSeconds)
	app.setSafeInsets(0.0, 0.0)


func _lookPass(stylePath: String, paletteIds: PackedStringArray) -> bool:
	### WHAT THIS DOES
	# one style module in each palette asked for: week, balance, region sheet, workout, picker, settings

	var made: Variant = load("res://app/looks/looks.gd").loadStyle(stylePath)
	if made == null:
		print("LOOK FAILED: style %s does not load" % stylePath)
		return false
	for paletteId in paletteIds:
		if not appTheme.themeIds().has(paletteId):
			print("LOOK FAILED: no palette %s" % paletteId)
			return false
		prefix = "look_%s_%s" % [stylePath.get_file().get_basename(), paletteId]
		_seed(paletteId, "male")
		appTheme.useStyleModule(made)
		storage.setProfile("style", made.styleId)
		await _openApp()
		var week: Node = app.weekScreen()
		while week.replaying():
			await _wait(0.1)
		await _wait(blendSeconds)
		await _grab("week")
		week.scroll.scrollTo(560.0)
		await _wait(0.3)
		await _grab("week_balance")
		week.scroll.scrollTo(0.0)
		week.openRegion("rearDelt")
		await _wait(settleSeconds)
		await _grab("region_sheet")
		app.goBack()
		await _wait(settleSeconds)
		var workout: Node = week.startWorkout()
		await _wait(settleSeconds)
		workout.addExercises(["Bent_Over_Barbell_Row", "Wide-Grip_Lat_Pulldown", "Face_Pull", "Barbell_Curl"])
		workout.setSets(0, 4)
		workout.setSets(1, 3)
		workout.setGrips(1, true)
		workout.setSets(2, 0)
		await _wait(blendSeconds)
		await _grab("workout")
		var picker: Node = workout.openPicker()
		await _wait(settleSeconds)
		picker.toggleExercise("Seated_Cable_Rows")
		picker.toggleExercise("Reverse_Flyes")
		await _wait(0.4)
		await _grab("picker")
		app.goBack()
		await _wait(settleSeconds)
		workout.discard()
		app.toast.hideNow()
		await _wait(settleSeconds)
		app.openSettings()
		await _wait(settleSeconds)
		await _grab("settings")
		app.goBack()
		await _wait(settleSeconds)
		await _targetShots(week)
		_closeApp()
	return true


func _targetShots(week: Node) -> void:
	### WHAT THIS DOES
	# the targets and cardio parts: both home overlays (body + balance tab), the Targets screen and
	# editor, a cardio row in a workout, the picker with several muscles, preset tags, Below target

	storage.setSetting("activeTargets", ["basketball", "mew2"])
	await _wait(0.2)
	week.scroll.scrollTo(0.0)
	week.setTargetsOverlay(true)
	await _wait(blendSeconds)
	await _grab("week_targets")
	week.scroll.scrollTo(560.0)
	await _wait(0.3)
	await _grab("week_targets_balance")
	week.setTargetsOverlay(false)
	week.scroll.scrollTo(0.0)
	week.setCardioOverlay(true)
	await _wait(blendSeconds)
	await _grab("week_cardio")
	week.scroll.scrollTo(560.0)
	await _wait(0.3)
	await _grab("week_cardio_panel")
	week.scroll.scrollTo(0.0)
	week.setTargetsOverlay(true)
	await _wait(blendSeconds)
	await _grab("week_both_overlays")
	week.setTargetsOverlay(false)
	week.setCardioOverlay(false)

	var screen: Node = app.openTargets()
	await _wait(settleSeconds)
	await _grab("targets")
	screen.scroll.scrollTo(700.0)
	await _wait(0.3)
	await _grab("targets_lower")
	var editor: Node = screen.copyPreset("vTaper")
	await _wait(settleSeconds)
	editor.changeOffset("glutes", 2)
	await _wait(0.4)
	await _grab("target_editor")
	app.goBack()
	await _wait(settleSeconds)
	app.topSheet().choose("discard")
	await _wait(settleSeconds)
	app.goBack()
	await _wait(settleSeconds)

	var workout: Node = week.startWorkout()
	await _wait(settleSeconds)
	workout.addExercises(["Pullups", "Running_Outdoor"])
	workout.setMinutes(1, 30)
	await _wait(blendSeconds)
	workout.scroll.scrollTo(380.0)
	await _wait(0.3)
	await _grab("workout_cardio")
	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)
	picker.addRegionFilter("lats")
	picker.setRegionFilter("rearDelt")
	await _wait(0.4)
	await _grab("picker_several")
	picker.clearRegionFilter()
	picker.setSearch("nordic")
	await _wait(0.4)
	await _grab("picker_tags")
	picker.setSearch("")
	picker.setOrder("target")
	await _wait(0.4)
	await _grab("picker_below_target")
	app.goBack()
	await _wait(settleSeconds)
	workout.discard()
	app.toast.hideNow()
	await _wait(settleSeconds)
	storage.setSetting("activeTargets", [])


func _setupPass() -> void:
	### WHAT THIS DOES
	# the first launch: a fresh folder (no profile), each of the four steps

	prefix = "phase2_setup"
	_removeFolder(folder)
	storage.loadAll(folder)
	appTheme.apply("ember")
	await _openApp()
	var setup: Node = app.top()
	await _grab("step1_empty")
	setup.setNameText("Sam")
	setup.next()
	await _wait(0.4)
	setup.chooseBody("female")
	await _wait(0.3)
	await _grab("step2_body")
	setup.next()
	setup.chooseGradient("ember")
	await _wait(0.3)
	await _grab("step3_gradient")
	setup.next()
	setup.chooseTheme("light")
	await _wait(0.3)
	await _grab("step4_theme")
	setup.finish()
	await _wait(blendSeconds)
	await _grab("after_setup_week")


### /// HELPERS ///

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _grab(shotName: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = outFolder.path_join("%s_%s.png" % [prefix, shotName])
	root.get_texture().get_image().save_png(path)
	saved += 1
	print("saved " + path)


func _removeFolder(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_removeFolder(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
