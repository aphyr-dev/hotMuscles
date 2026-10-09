extends SceneTree
## testTouchUi.gd - windowed check of the phone touch details on the REAL app, with synthetic
## finger input (InputEventScreenTouch / ScreenDrag through Input.parse_input_event, paced in real time)
## what this offers: python tests/runGodot.py script res://tests/testTouchUi.gd --window
## checks: tapping a row opens it, dragging on a row scrolls instead; tapping a muscle opens its
## sheet; bottom sheets close by swiping down and by tapping the dim; buttons shrink while held;
## the stepper takes taps; picker rows tick on tap, long-press opens the menu, swipe right stars,
## swipe left hides (undo on the toast); the chip strip slides sideways without pressing a chip;
## Escape goes back; the safe-area insets push the screens down
## runs on a throwaway save folder (deleted at the end); prints PASS/FAIL and ALL PASS / N FAILURE(S)

### /// TUNING ///

# throwaway folder name prefix inside user://
const folderPrefix: String = "_testPhase2Touch_"
# seconds for slides and sheets to settle
const settleSeconds: float = 0.5

var storage: Node = null
var appTheme: Node = null
var app: Node = null
var folder: String = ""
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")


func _run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	storage = root.get_node("/root/Storage")
	appTheme = root.get_node("/root/AppTheme")
	folder = "user://%s%d_%d" % [folderPrefix, OS.get_process_id(), Time.get_ticks_usec()]
	_seed()
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await _wait(settleSeconds)

	await _checkWeekRows()
	await _checkBodyTapAndDim()
	await _checkWorkoutButtons()
	await _checkPickerRows()
	await _checkChipStrip()
	await _checkEscapeAndSafeArea()

	app.queue_free()
	await _wait(0.1)
	_removeFolder(folder)
	if failures == 0:
		print("ALL PASS (%d checks)" % checks)
	else:
		print("%d FAILURE(S) of %d checks" % [failures, checks])
	quit(mini(failures, 1))


func _seed() -> void:
	storage.loadAll(folder)
	storage.setProfile("name", "Sam")
	storage.setProfile("setupDone", true)
	var now: float = Time.get_unix_time_from_system()
	storage.startWorkout(now - 86400.0)
	storage.addEntry("Barbell_Bench_Press_-_Medium_Grip", 4, false)
	storage.addEntry("Wide-Grip_Lat_Pulldown", 3, false)
	storage.finishWorkout(now - 86400.0 + 3000.0)
	appTheme.apply("ember")


### /// CHECKS ///

func _checkWeekRows() -> void:
	### WHAT THIS DOES
	# a drag that starts on a balance row scrolls the page and opens nothing; a tap opens the sheet;
	# the sheet goes away when swiped down

	var week: Node = app.weekScreen()
	week.scroll.scrollTo(560.0)
	await _wait(0.2)
	var row: Control = _firstTapRow(week.balanceBox)
	var centre: Vector2 = row.get_global_rect().get_center()
	var offsetBefore: float = week.scroll.scrollOffset
	await _drag(centre, centre + Vector2(0.0, -160.0), 0.3, 0.05)
	await _wait(0.4)
	_expectTrue("drag on a row scrolls the page (%.0f -> %.0f)" % [offsetBefore, week.scroll.scrollOffset], week.scroll.scrollOffset > offsetBefore + 100.0)
	_expectTrue("and opens nothing", app.topSheet() == null)

	week.scroll.scrollTo(560.0)
	await _wait(0.2)
	centre = row.get_global_rect().get_center()
	await _tap(centre)
	await _wait(settleSeconds)
	var sheet: Node = app.topSheet()
	_expectTrue("tap on a balance row opens its region sheet", sheet != null and str(sheet.get_meta("regionId", "")) == str(row.get_meta("regionId")))
	if sheet == null:
		return

	# swipe the sheet down by its header
	var grab: Vector2 = sheet.panel.get_global_rect().position + Vector2(215.0, 40.0)
	await _drag(grab, grab + Vector2(0.0, 320.0), 0.25, 0.0)
	await _wait(settleSeconds)
	_expectTrue("swiping the sheet down closes it", app.topSheet() == null)


func _checkBodyTapAndDim() -> void:
	var week: Node = app.weekScreen()
	week.scroll.scrollTo(0.0)
	await _wait(0.2)
	var body: Control = week.bodyCard.bodyView
	var point: Vector2 = body.get_global_transform_with_canvas() * body.regionCentre("lowerChest")
	await _tap(point)
	await _wait(settleSeconds)
	var sheet: Node = app.topSheet()
	_expectTrue("tap on the chest opens the chest sheet", sheet != null and str(sheet.get_meta("regionId", "")) == "lowerChest")
	_expectEqual("chest outlined", body.selectedRegions, ["lowerChest"])
	await _tap(Vector2(215.0, 60.0))
	await _wait(settleSeconds)
	_expectTrue("tap on the dim closes the sheet", app.topSheet() == null)

	# a short drag on the sheet springs back instead of closing
	week.openRegion("lats")
	await _wait(settleSeconds)
	sheet = app.topSheet()
	var grab: Vector2 = sheet.panel.get_global_rect().position + Vector2(215.0, 40.0)
	await _drag(grab, grab + Vector2(0.0, 40.0), 0.5, 0.2)
	await _wait(settleSeconds)
	_expectTrue("a short slow drag keeps the sheet", app.topSheet() == sheet and absf(sheet.dragOffset) < 1.0)
	app.goBack()
	await _wait(settleSeconds)


func _checkWorkoutButtons() -> void:
	var workout: Node = app.weekScreen().startWorkout()
	await _wait(settleSeconds)
	workout.addExercises(["Face_Pull"])
	await _wait(0.2)
	workout.scroll.scrollTo(workout.scroll.maxOffset())
	await _wait(0.3)
	var plus: Button = workout.rowParts[0]["plus"]
	var setsBefore: int = int(workout.entries()[0]["sets"])
	var centre: Vector2 = plus.get_global_rect().get_center()

	# held: shrinks; released: springs back and counts
	_touch(0, centre, true)
	await _wait(0.15)
	_expectTrue("a held button shrinks (%.3f)" % plus.scale.x, plus.scale.x < 0.99)
	_touch(0, centre, false)
	await _wait(0.4)
	_expectTrue("and springs back (%.3f)" % plus.scale.x, absf(plus.scale.x - 1.0) < 0.01)
	_expectEqual("the + took the tap", int(workout.entries()[0]["sets"]), setsBefore + 1)
	await _tap(centre)
	await _wait(0.1)
	_expectEqual("and another", int(workout.entries()[0]["sets"]), setsBefore + 2)


func _checkPickerRows() -> void:
	### WHAT THIS DOES
	# tap ticks, a vertical drag scrolls without ticking, long-press opens the menu,
	# swipe right stars, swipe left hides (toast undo by tapping it)

	var workout: Node = app.top()
	var picker: Node = workout.openPicker()
	await _wait(settleSeconds)
	var first: Control = _firstTapRow(picker.listBox)
	var firstId: String = _rowId(picker, first)
	await _tap(first.get_global_rect().get_center())
	await _wait(0.1)
	_expectTrue("tap ticks the row (%s)" % firstId, picker.selected.has(firstId) and first.selected)
	await _tap(first.get_global_rect().get_center())
	await _wait(0.1)
	_expectTrue("tap again unticks it", not picker.selected.has(firstId))

	var start: Vector2 = first.get_global_rect().get_center()
	await _drag(start, start + Vector2(0.0, -150.0), 0.3, 0.05)
	await _wait(0.5)
	_expectTrue("drag on the list scrolls it (%.0f)" % picker.list.scrollOffset, picker.list.scrollOffset > 80.0)
	_expectEqual("and ticks nothing", picker.selected.size(), 0)
	picker.list.scrollTo(0.0)
	await _wait(0.2)

	# long press
	var centre: Vector2 = first.get_global_rect().get_center()
	_touch(0, centre, true)
	await _wait(0.75)
	_touch(0, centre, false)
	await _wait(settleSeconds)
	var menu: Node = app.topSheet()
	_expectTrue("long-press opens the star / hide menu", menu != null and menu.titleLabel.text == _exerciseName(firstId))
	_expectEqual("long-press ticks nothing", picker.selected.size(), 0)
	app.goBack()
	await _wait(settleSeconds)

	# swipe right = star
	var favouriteBefore: bool = bool(storage.getPref(firstId)["favourite"])
	var y: float = first.get_global_rect().get_center().y
	await _drag(Vector2(60.0, y), Vector2(300.0, y), 0.25, 0.0)
	await _wait(0.4)
	_expectTrue("swipe right toggles the star", bool(storage.getPref(firstId)["favourite"]) != favouriteBefore)
	_expectEqual("swipe ticks nothing", picker.selected.size(), 0)

	# swipe left = hide, undo from the toast
	var row: Control = _firstTapRow(picker.listBox)
	var rowId: String = _rowId(picker, row)
	y = row.get_global_rect().get_center().y
	await _drag(Vector2(380.0, y), Vector2(130.0, y), 0.25, 0.0)
	await _wait(0.4)
	_expectTrue("swipe left hides it (%s)" % rowId, bool(storage.getPref(rowId)["hidden"]))
	_expectTrue("hide shows an undo toast", app.toast.isShowing())
	await _tap(app.toast.actionButton.get_global_rect().get_center())
	await _wait(0.2)
	_expectTrue("tapping Undo un-hides it", not bool(storage.getPref(rowId)["hidden"]))


func _checkChipStrip() -> void:
	var picker: Node = app.top()
	var strip: Control = picker.allChip.get_parent().get_parent().get_parent()
	var y: float = strip.get_global_rect().get_center().y
	await _drag(Vector2(380.0, y), Vector2(100.0, y), 0.3, 0.05)
	await _wait(0.4)
	_expectTrue("chip strip slides sideways (%.0f)" % strip.offset, strip.offset > 100.0)
	_expectTrue("and presses no chip", picker.equipment.is_empty() and not picker.showHidden)
	strip.scrollTo(0.0)
	await _wait(0.2)
	var chip: Button = picker.equipmentChips["dumbbell"]
	await _tap(chip.get_global_rect().get_center())
	await _wait(0.2)
	_expectEqual("a tap on a chip still filters", picker.equipment, ["dumbbell"])
	await _tap(picker.allChip.get_global_rect().get_center())
	await _wait(0.2)
	_expectEqual("and All clears it", picker.equipment, [])


func _checkEscapeAndSafeArea() -> void:
	_key(KEY_ESCAPE)
	await _wait(settleSeconds)
	_expectTrue("Escape goes back (picker -> workout)", app.top().get_script().get_global_name() == "WorkoutScreen")
	_key(KEY_ESCAPE)
	await _wait(settleSeconds)
	_expectTrue("Escape again -> the week, workout still running", app.top().get_script().get_global_name() == "WeekScreen" and storage.hasCurrentWorkout())
	app.setSafeInsets(40.0, 24.0)
	await _wait(0.1)
	var rect: Rect2 = app.top().get_global_rect()
	_expectTrue("safe area pushes the screen down (%s)" % str(rect), absf(rect.position.y - 40.0) < 0.5 and absf(rect.end.y - (root.get_visible_rect().size.y - 24.0)) < 0.5)
	app.setSafeInsets(0.0, 0.0)


### /// HELPERS ///

func _exerciseName(exerciseId: String) -> String:
	return str(root.get_node("/root/AppData").getExercise(exerciseId).get("name", exerciseId))


func _firstTapRow(box: Node) -> Control:
	for child in box.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == "TapRow":
			return child
	return null


func _rowId(picker: Node, row: Control) -> String:
	for exerciseId in picker.rowsById:
		if picker.rowsById[exerciseId] == row:
			return exerciseId
	return ""


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


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _toWindow(point: Vector2) -> Vector2:
	# design px -> window px (the inverse of the stretch mapping)
	return root.get_final_transform() * point


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = _toWindow(point)
	_send(event)


func _touchMove(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _toWindow(point)
	event.relative = relative
	_send(event)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_send(event)
		await process_frame


func _tap(point: Vector2) -> void:
	_touch(0, point, true)
	await process_frame
	await process_frame
	await process_frame
	_touch(0, point, false)
	await process_frame
	await process_frame


func _drag(from: Vector2, to: Vector2, seconds: float, restSeconds: float) -> void:
	### WHAT THIS DOES
	# finger down at from, moves to `to` over `seconds` of real time, rests, lifts

	var start: float = _now()
	var last: Vector2 = from
	_touch(0, from, true)
	await process_frame
	while true:
		await process_frame
		var t: float = clampf((_now() - start) / seconds, 0.0, 1.0)
		var point: Vector2 = from.lerp(to, t)
		_touchMove(0, point, point - last)
		last = point
		if t >= 1.0:
			break
	if restSeconds > 0.0:
		await _wait(restSeconds)
	_touch(0, last, false)
	await process_frame


func _removeFolder(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_removeFolder(path.path_join(sub))
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
