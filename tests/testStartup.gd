extends SceneTree
## testStartup.gd - windowed check that the REAL app (main.tscn) starts fast and never hitches
## what this offers: python tests/runGodot.py script res://tests/testStartup.gd --window
## part 1 - first launch: the app on an empty save folder (the profile setup screen); the app's own
##   share of the start - from the main scene entering the tree to its first drawn frame (building
##   the screens, drawing them once) - must stay under appShareLimitMs. Printed but not checked: the
##   whole launch (Godot opening its window, ~2-2.5 s on this PC) and the script loading before the
##   main scene (the engine compiling every app script; ~600 ms from source here, ~400 ms in the exe)
## part 2 - a seeded week: the app data loaded again (body maps decoding from scratch) and the app
##   rebuilt on a folder with four workouts (week screen, body in "both", workout thumbnails); data
##   load -> first drawn frame must stay under appShareLimitMs
## part 3 - normal use: setup choices, finishing setup, body views, region sheet, starting a workout,
##   the picker (open, muscle filter, search, star, ghost, filter by unused), finishing; in each step the longest gap
##   between two drawn frames must stay under worstFrameLimitMs
## the window must be on screen (parked is fine, never minimised); prints every number, PASS/FAIL lines
## and ALL PASS / N FAILURE(S); runs on a throwaway save folder deleted at the end
## frame times are only meaningful on a quiet PC: another game, an export or a test batch running at
## the same time makes the frame check fail - check the CPU first and run it again before believing it

### /// TUNING ///

# the app's own start (main scene -> first drawn frame on a first launch; data load -> first drawn
# frame on a seeded week)
const appShareLimitMs: float = 500.0
# longest gap between two drawn frames during normal use (60 fps = 16.7 ms a frame) - the aim is
# 33 ms (two frames, so a phone stays smooth); measured worst here 27-32 ms (v003). A frame that just
# misses the screen's refresh shows as a 33 ms gap even on an idle step, so the line sits at 40
const worstFrameLimitMs: float = 40.0
# throwaway folder name prefix inside user://
const folderPrefix: String = "_testStartup_"
# seconds to let each step's slides, sheets and blends play out while frames are timed
const stepSeconds: float = 0.8

var storage: Node = null
var appTheme: Node = null
var appData: Node = null
var app: Node = null
var folder: String = ""
var failures: int = 0
var checks: int = 0
var frameTimes: PackedInt64Array = PackedInt64Array()
var stepWorst: Dictionary = {}


func _initialize() -> void:
	### WHAT THIS DOES
	# part 1 starts right here, before the first frame: an empty folder and the real app

	Engine.max_fps = 60
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	storage = root.get_node("Storage")
	appTheme = root.get_node("AppTheme")
	appData = root.get_node("AppData")
	folder = "user://%s%d_%d" % [folderPrefix, OS.get_process_id(), Time.get_ticks_usec()]
	storage.loadAll(folder)
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	RenderingServer.frame_post_draw.connect(_onFrameDrawn)
	call_deferred("_run")


func _onFrameDrawn() -> void:
	frameTimes.append(Time.get_ticks_usec())


func _run() -> void:
	await _firstLaunch()
	await _setupSteps()
	await _seededWeek()
	await _normalUse()

	print("")
	print("worst frame per step (ms):")
	var worstOverall: float = 0.0
	for stepName in stepWorst:
		print("  %-28s %6.1f" % [stepName, stepWorst[stepName]])
		worstOverall = maxf(worstOverall, stepWorst[stepName])
	print("worst frame in normal use: %.1f ms" % worstOverall)

	app.queue_free()
	await _wait(0.1)
	_removeFolder(folder)
	if failures == 0:
		print("ALL PASS (%d checks)" % checks)
	else:
		print("%d FAILURE(S) of %d checks" % [failures, checks])
	quit(mini(failures, 1))


### /// PARTS ///

func _firstLaunch() -> void:
	### WHAT THIS DOES
	# the first frame after launch, read off the app's own numbers

	while app.firstFrameMs < 0:
		await process_frame
	print("first launch: whole launch %d ms (engine window opening included, not checked)" % app.firstFrameMs)
	print("first launch: scripts loaded in %d ms (not checked)" % (app.mainEnterMs - appData.appStartMs))
	_expectTrue("first launch: the app's own start takes %d ms (limit %d)" % [app.appShareMs, appShareLimitMs], app.appShareMs >= 0 and app.appShareMs <= appShareLimitMs)
	_expectEqual("first launch opens the profile setup", app.top().get_script().get_global_name(), "ProfileSetup")


func _setupSteps() -> void:
	# the setup screen's choices: body, gradient, theme (each redraws the preview body), then finish
	var setup: Node = app.top()
	await _timed("setup: type a name", func() -> void: setup.setNameText("Sam"))
	await _timed("setup: next", func() -> void: setup.next())
	await _timed("setup: choose female", func() -> void: setup.chooseBody("female"))
	await _timed("setup: choose male", func() -> void: setup.chooseBody("male"))
	await _timed("setup: next", func() -> void: setup.next())
	await _timed("setup: gradient ember", func() -> void: setup.chooseGradient("ember"))
	await _timed("setup: next", func() -> void: setup.next())
	await _timed("setup: theme light", func() -> void: setup.chooseTheme("light"))
	await _timed("setup: theme ember", func() -> void: setup.chooseTheme("ember"))
	await _timed("setup: finish -> week", func() -> void: setup.finish())


func _seededWeek() -> void:
	### WHAT THIS DOES
	# a fresh app on a folder holding a week of workouts: the app data loads again (the body maps
	# start decoding from scratch), the theme is applied, the app is built - up to its first frame

	var startedUsec: int = 0
	var loadedUsec: int = 0
	var themedUsec: int = 0
	var builtUsec: int = 0

	app.queue_free()
	await process_frame
	_seed()

	startedUsec = Time.get_ticks_usec()
	appData.loadAll(appData.dataFolder)
	loadedUsec = Time.get_ticks_usec()
	appTheme.apply(str(storage.profile["theme"]))
	themedUsec = Time.get_ticks_usec()
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	builtUsec = Time.get_ticks_usec()
	var framesBefore: int = frameTimes.size()
	while frameTimes.size() == framesBefore:
		await process_frame
	var drawnUsec: int = frameTimes[frameTimes.size() - 1]
	var weekMs: float = (drawnUsec - startedUsec) / 1000.0
	print("seeded week: data load %.1f ms, theme %.1f ms, app build %.1f ms, first frame %.1f ms after the data load began" % [(loadedUsec - startedUsec) / 1000.0, (themedUsec - loadedUsec) / 1000.0, (builtUsec - themedUsec) / 1000.0, weekMs])
	_expectEqual("seeded folder opens the week", app.top().get_script().get_global_name(), "WeekScreen")
	_expectTrue("seeded week: data load -> first frame takes %.1f ms (limit %d)" % [weekMs, appShareLimitMs], weekMs <= appShareLimitMs)


func _normalUse() -> void:
	### WHAT THIS DOES
	# the everyday paths, each timed frame by frame

	var week: Node = app.weekScreen()
	await _timed("week: settle", func() -> void: pass)
	await _timed("week: view front", func() -> void: week.bodyCard.setView("front"))
	await _timed("week: view back", func() -> void: week.bodyCard.setView("back"))
	await _timed("week: view both", func() -> void: week.bodyCard.setView("both"))
	await _timed("week: zoom in", func() -> void: week.bodyCard.bodyView.zoomAt(week.bodyCard.bodyView.size * 0.5, 3.0))
	await _timed("week: zoom reset", func() -> void: week.bodyCard.bodyView.resetZoom(true))
	await _timed("week: workouts tab", func() -> void: week.showTab("workouts"))
	await _timed("week: balance tab", func() -> void: week.showTab("balance"))
	await _timed("week: region sheet (lats)", func() -> void: week.openRegion("lats"))
	await _timed("week: close sheet", func() -> void: app.goBack())
	await _timed("week: start workout", func() -> void: week.startWorkout())
	var workout: Node = app.top()
	await _timed("workout: add 3 exercises", func() -> void: workout.addExercises(["Bent_Over_Barbell_Row", "Wide-Grip_Lat_Pulldown", "Barbell_Curl"]))
	await _timed("workout: sets 0 (ghost)", func() -> void: workout.setSets(2, 0))
	await _timed("workout: open picker", func() -> void: workout.openPicker())
	var picker: Node = app.top()
	await _timed("picker: tick 3 (ghost)", func() -> void: _tickThree(picker))
	await _timed("picker: muscle filter", func() -> void: picker.setRegionFilter("rearDelt"))
	await _timed("picker: search", func() -> void: picker.setSearch("raise"))
	await _timed("picker: clear search", func() -> void: picker.setSearch(""))
	await _timed("picker: star a row", func() -> void: picker.setFavourite(str(picker.results[1]["id"]), true))
	await _timed("picker: clear muscle filter", func() -> void: picker.clearRegionFilter())
	await _timed("picker: filter by unused", func() -> void: picker.setUnusedFirst(true))
	await _timed("picker: unused off", func() -> void: picker.setUnusedFirst(false))
	await _timed("picker: templates tab", func() -> void: picker.showTab("templates"))
	await _timed("picker: back", func() -> void: app.goBack())
	await _timed("workout: finish confirm", func() -> void: workout.requestFinish())
	await _timed("workout: finish", func() -> void: app.topSheet().choose("finish"))
	await _timed("workout: skip template", func() -> void: _skipTemplate())
	await _timed("week: finished blend", func() -> void: pass)
	await _timed("settings: open", func() -> void: app.openSettings())
	await _timed("settings: back", func() -> void: app.goBack())


func _tickThree(picker: Node) -> void:
	picker.toggleExercise("Seated_Cable_Rows")
	picker.toggleExercise("Reverse_Flyes")
	picker.toggleExercise("Side_Lateral_Raise")


func _skipTemplate() -> void:
	var sheet: Node = app.topSheet()
	if sheet != null:
		sheet.choose("cancel")


### /// HELPERS ///

func _timed(stepName: String, action: Callable) -> void:
	### WHAT THIS DOES
	# runs one action at the start of a frame, then records the longest gap between drawn frames
	# over the next stepSeconds

	await process_frame
	var firstIndex: int = frameTimes.size()
	var startUsec: int = Time.get_ticks_usec()
	action.call()
	await _wait(stepSeconds)
	var worst: float = 0.0
	var previous: int = startUsec
	for index in range(firstIndex, frameTimes.size()):
		worst = maxf(worst, (frameTimes[index] - previous) / 1000.0)
		previous = frameTimes[index]
	var key: String = stepName
	var suffix: int = 2
	while stepWorst.has(key):
		key = "%s (%d)" % [stepName, suffix]
		suffix += 1
	stepWorst[key] = worst
	_expectTrue("%s: worst frame %.1f ms (limit %d)" % [stepName, worst, worstFrameLimitMs], worst <= worstFrameLimitMs)


func _seed() -> void:
	# a fresh folder with a profile and four workouts (three this week), like the screenshot driver
	_removeFolder(folder)
	storage.loadAll(folder)
	storage.setProfileValues({"name": "Sam", "body": "male", "gradient": "infrared", "theme": "ember", "setupDone": true})
	storage.setSetting("defaultView", "both")
	var now: float = Time.get_unix_time_from_system()
	var day: float = 86400.0
	_addWorkout(now - 5.2 * day, 3900.0, [["Barbell_Bench_Press_-_Medium_Grip", 4], ["Incline_Dumbbell_Press", 3], ["Standing_Military_Press", 3], ["Side_Lateral_Raise", 3], ["Triceps_Pushdown", 3]])
	_addWorkout(now - 3.1 * day, 3300.0, [["Bent_Over_Barbell_Row", 4], ["Wide-Grip_Lat_Pulldown", 3], ["Pullups", 3], ["Face_Pull", 3], ["Barbell_Curl", 3], ["Hammer_Curls", 2]])
	_addWorkout(now - 1.05 * day, 4200.0, [["Barbell_Squat", 4], ["Romanian_Deadlift", 3], ["Leg_Press", 3], ["Lying_Leg_Curls", 3], ["Standing_Calf_Raises", 4], ["Cable_Crunch", 3]])
	_addWorkout(now - 10.0 * day, 3000.0, [["Barbell_Deadlift", 3]])


func _addWorkout(startedAt: float, length: float, rows: Array) -> void:
	storage.startWorkout(startedAt)
	for row in rows:
		storage.addEntry(row[0], row[1], false)
	storage.finishWorkout(startedAt + length)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _expectTrue(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


func _expectEqual(label: String, actual: Variant, expected: Variant) -> void:
	checks += 1
	if actual == expected:
		print("PASS  %s" % label)
	else:
		failures += 1
		print("FAIL  %s: got %s, want %s" % [label, str(actual), str(expected)])


func _removeFolder(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_removeFolder(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
