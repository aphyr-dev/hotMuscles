class_name WorkoutScreen
extends AppScreen
## WorkoutScreen - the running workout, and the editor for a finished one (same screen)
## what this offers
## - WorkoutScreen.createLive()               the workout in progress (Storage.current)
## - WorkoutScreen.createEditor(workoutId)    a finished workout, edited on a copy until Save changes
## - entries() -> the shown entries; live, editId, editWorkout, dirty
## - setSets(index, sets), changeSets(index, delta), setGrips(index, on), removeEntry(index) (undo toast),
##   addExercises(exerciseIds) (Storage.newEntry: the "new exercises start at" setting, grips and
##   cardio effort remembered), addEntries([entry]) (templates), openPicker()
## - cardio exercises log minutes and how hard it felt instead of sets: setMinutes(index, minutes),
##   changeMinutes(index, delta) (steps of minuteStep), setEffort(index, effortId) (remembered per
##   exercise); they light the home page's cardio overlay, not the muscles
## - live: requestFinish() -> confirm sheet -> optional save-as-template sheet -> the week, animated;
##   discard from the confirm sheet (undo on the toast)
## - editor: saveChanges(); back with unsaved changes asks first
## - the exercise list shows the newest exercise on top (the saved order stays oldest first)
## - the body card shows only this workout's heat (amount colouring, its own 0-N); entries with 0 sets
##   (0 minutes for cardio) are "planned": a ghost outline on the body and a dashed-look row
## - its "+ Week" chip (setShowWeek(on), remembered in the workoutShowWeek setting) adds the last 7 days
##   of finished workouts to the body, on the week's own 0-N - the same numbers as the week screen
## - grips checkbox only on exercises with forearmKind "grip" (ticked = no forearm heat)

### /// TUNING ///

# tallest the body gets here
const bodyMaxHeight: float = 400.0
# main button height
const mainButtonHeight: float = 58.0
# sets number in the stepper
const stepperFontSize: int = 22
const stepperNumberWidth: float = 40.0
# sets the ghost uses for a planned (0-set) exercise
const plannedGhostSets: int = 1
# most sets the stepper allows
const maxSets: int = 99
# cardio: minutes per stepper press, and the small word under the number
const minuteStep: int = 5
const minuteWord: String = "min"
# body card title and hint, with and without the week added
const titleWorkout: String = "This workout"
const titleWithWeek: String = "Workout + week"
const hintWorkout: String = "Dashed outline = planned (0 sets) · tap a muscle to find exercises"
const hintWithWeek: String = "Last 7 days + this workout · tap a muscle to find exercises"

### /// STATE ///

var live: bool = true
var editId: String = ""
var editWorkout: Dictionary = {}
var dirty: bool = false
var finished: bool = false
var scroll: KineticScroll = null
var column: VBoxContainer = null
var bodyCard: BodyCard = null
var weekChip: Button = null
var summaryLabel: Label = null
var rowsBox: VBoxContainer = null
var emptyLabel: Label = null
var timerLabel: Label = null
var mainButton: Button = null
var rowParts: Array = []
var shownIds: Array = []
var lastClock: String = ""
var refreshQueued: bool = false


static func createLive() -> WorkoutScreen:
	var made := WorkoutScreen.new()
	made.live = true
	return made


static func createEditor(workoutId: String) -> WorkoutScreen:
	var made := WorkoutScreen.new()
	made.live = false
	made.editId = workoutId
	var index: int = Storage.findWorkoutIndex(workoutId)
	if index >= 0:
		made.editWorkout = Storage.submittedWorkouts()[index].duplicate(true)
	return made


func _ready() -> void:
	_build()
	Storage.changed.connect(_onStorageChanged)
	refreshRows(false)


### /// BUILDING ///

func _build() -> void:
	var title: String = "Workout"
	if not live:
		title = "Edit workout"
	var frame: Dictionary = buildFrame(title, "Week")

	# timer (live) or date (editor) at the right of the header
	var side: VBoxContainer = Ui.vbox(0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	frame["header"].add_child(side)
	var caption: Label = Ui.label("ELAPSED", "FaintLabel")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(caption)
	timerLabel = Ui.label("00:00", "TitleLabel")
	timerLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timerLabel.add_theme_color_override("font_color", Ui.colour("accent"))
	timerLabel.add_theme_font_size_override("font_size", 26)
	side.add_child(timerLabel)
	if not live:
		caption.text = "WORKOUT OF"
		var started: float = float(editWorkout.get("startedAt", 0.0))
		timerLabel.text = "%s · %s" % [Ui.dayLabel(started), Ui.timeLabel(started)]
		timerLabel.add_theme_font_size_override("font_size", 17)

	scroll = makeScroll(frame["content"])
	column = scroll.get_meta("column")

	# body card - only this workout
	bodyCard = BodyCard.new()
	column.add_child(bodyCard)
	bodyCard.configure(titleWorkout, bodyMaxHeight, "rangeWorkout", true, hintWorkout)
	bodyCard.regionTapped.connect(_onRegionTapped)
	weekChip = bodyCard.addFooterChip("+ Week")
	weekChip.toggled.connect(setShowWeek)
	_applyShowWeek()

	# list
	var heading: HBoxContainer = Ui.hbox(8)
	column.add_child(heading)
	heading.add_child(Ui.label("Exercises", "TitleLabel"))
	heading.add_child(Ui.spacer())
	summaryLabel = Ui.label("", "MutedLabel")
	summaryLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(summaryLabel)
	rowsBox = Ui.vbox(8)
	column.add_child(rowsBox)
	emptyLabel = Ui.wrapLabel("No exercises yet - add some and log your sets as you go.", "MutedLabel")
	column.add_child(emptyLabel)
	var addButton: Button = Ui.button("+  Add exercise", "Button", openPicker)
	addButton.custom_minimum_size.y = 56.0
	column.add_child(addButton)

	# finish / save
	if live:
		mainButton = Ui.button("Finish workout", "AccentButton", requestFinish)
	else:
		mainButton = Ui.button("Save changes", "AccentButton", saveChanges)
		mainButton.disabled = true
	mainButton.custom_minimum_size.y = mainButtonHeight
	frame["bottom"].add_child(mainButton)


func rebuild() -> void:
	timerLabel.add_theme_color_override("font_color", Ui.colour("accent"))
	shownIds = []
	refreshRows(false)


### /// THE ENTRIES ///

func entries() -> Array:
	if live:
		return Storage.currentWorkout().get("entries", [])
	return editWorkout.get("entries", [])


func _onStorageChanged(section: String) -> void:
	if finished:
		return
	if section == "settings":
		bodyCard.setHideUntouched(bool(Storage.settings["hideUntouched"]))
		bodyCard.setRange(int(Storage.settings[bodyCard.rangeKey]))
		return
	if section == "profile":
		bodyCard.setBody(str(Storage.profile["body"]))
		bodyCard.setGradient(str(Storage.profile["gradient"]))
		return
	if live and (section == "workouts" or section == "all") and not refreshQueued:
		refreshQueued = true
		call_deferred("_queuedRefresh")


func _queuedRefresh() -> void:
	refreshQueued = false
	if not finished:
		refreshRows(true)


func onShown() -> void:
	if not finished:
		refreshRows(true)


func setSets(index: int, sets: int) -> void:
	var clamped: int = clampi(sets, 0, maxSets)
	if index < 0 or index >= entries().size():
		return
	if live:
		Storage.setEntrySets(index, clamped)
	else:
		editWorkout["entries"][index]["sets"] = clamped
		_markDirty()
	refreshRows(true)


func changeSets(index: int, delta: int) -> void:
	if index < 0 or index >= entries().size():
		return
	setSets(index, int(entries()[index]["sets"]) + delta)


func setGrips(index: int, on: bool) -> void:
	if index < 0 or index >= entries().size():
		return
	if live:
		Storage.setEntryGrips(index, on)
	else:
		editWorkout["entries"][index]["grips"] = on
		Storage.setGripsMemory(str(editWorkout["entries"][index]["exerciseId"]), on)
		_markDirty()
	refreshRows(true)


func setMinutes(index: int, minutes: int) -> void:
	var clamped: int = clampi(minutes, 0, Storage.maxMinutes)
	if index < 0 or index >= entries().size():
		return
	if live:
		Storage.setEntryMinutes(index, clamped)
	else:
		editWorkout["entries"][index]["minutes"] = clamped
		_markDirty()
	refreshRows(true)


func changeMinutes(index: int, delta: int) -> void:
	if index < 0 or index >= entries().size():
		return
	setMinutes(index, int(entries()[index].get("minutes", 0)) + delta)


func setEffort(index: int, effortId: String) -> void:
	if index < 0 or index >= entries().size() or not AppData.effortById.has(effortId):
		return
	if live:
		Storage.setEntryEffort(index, effortId)
	else:
		editWorkout["entries"][index]["effort"] = effortId
		Storage.setEffortMemory(str(editWorkout["entries"][index]["exerciseId"]), effortId)
		_markDirty()
	refreshRows(true)


func removeEntry(index: int) -> void:
	### WHAT THIS DOES
	# takes the exercise out at once; the toast's Undo puts it back where it was

	if index < 0 or index >= entries().size():
		return
	var removed: Dictionary = {}
	if live:
		removed = Storage.removeEntry(index)
	else:
		removed = editWorkout["entries"][index]
		editWorkout["entries"].remove_at(index)
		_markDirty()
	refreshRows(true)
	var exerciseName: String = str(AppData.getExercise(removed["exerciseId"]).get("name", "Exercise"))
	app.showToast("Removed %s" % exerciseName, "Undo", _undoRemove.bind(index, removed))


func _undoRemove(index: int, entry: Dictionary) -> void:
	if finished:
		return
	if live:
		Storage.insertEntry(index, entry)
	else:
		editWorkout["entries"].insert(clampi(index, 0, editWorkout["entries"].size()), entry)
		_markDirty()
	refreshRows(true)


func addExercises(exerciseIds: Array) -> void:
	# new entries as the settings say (Storage.newEntry)
	var list: Array = []
	for exerciseId in exerciseIds:
		list.append(Storage.newEntry(exerciseId))
	addEntries(list)


func addEntries(list: Array) -> void:
	if live:
		Storage.addEntries(list)
	else:
		for entry in list:
			editWorkout["entries"].append(entry.duplicate())
		_markDirty()
	refreshRows(true)


func _markDirty() -> void:
	dirty = true
	if mainButton != null:
		mainButton.disabled = false


func showsWeek() -> bool:
	return bool(Storage.settings["workoutShowWeek"])


func setShowWeek(on: bool) -> void:
	# the "+ Week" chip: the body adds (or drops) the last 7 days, blending to the new heat
	if on != showsWeek():
		Storage.setSetting("workoutShowWeek", on)
	_applyShowWeek()
	refreshRows(true)


func _applyShowWeek() -> void:
	# chip, title, hint and which remembered 0-N the slider shows
	var on: bool = showsWeek()
	weekChip.set_pressed_no_signal(on)
	if on:
		bodyCard.setTitle(titleWithWeek)
		bodyCard.setHint(hintWithWeek)
		bodyCard.setRangeKey("rangeWeek")
	else:
		bodyCard.setTitle(titleWorkout)
		bodyCard.setHint(hintWorkout)
		bodyCard.setRangeKey("rangeWorkout")


func _weekHeatBesides() -> Dictionary:
	### WHAT THIS DOES
	# the last 7 days of finished workouts, leaving out the one being edited (its edited copy is
	# what this screen adds on top)

	var others: Array = []

	for workout in Storage.submittedWorkouts():
		if str(workout["id"]) != editId:
			others.append(workout)
	return HeatEngine.weekHeat(others, AppData.exerciseById, Time.get_unix_time_from_system())


func openPicker() -> PickerScreen:
	return app.openPicker(self, "")


func _onRegionTapped(regionId: String) -> void:
	app.openPicker(self, regionId)


### /// ROWS ///

func refreshRows(animate: bool) -> void:
	### WHAT THIS DOES
	# body heat + ghost, the summary, and the rows (rebuilt only when the list itself changed)

	var list: Array = entries()
	var ids: Array = []
	var planned: Array = []

	for entry in list:
		ids.append(str(entry["exerciseId"]))
		if not HeatEngine.isLogged(entry):
			planned.append({"exerciseId": entry["exerciseId"], "sets": plannedGhostSets, "grips": entry["grips"]})

	var heat: Dictionary = HeatEngine.effectiveSets(list, AppData.exerciseById)
	if showsWeek():
		var week: Dictionary = _weekHeatBesides()
		for regionId in week:
			heat[regionId] = float(heat.get(regionId, 0.0)) + float(week[regionId])
	bodyCard.setHeat(heat, animate)
	bodyCard.setGhost(HeatEngine.effectiveSets(planned, AppData.exerciseById))
	var exerciseWord: String = "exercises"
	if list.size() == 1:
		exerciseWord = "exercise"
	summaryLabel.text = "%d %s · %s" % [list.size(), exerciseWord, Ui.workSummary(list)]
	emptyLabel.visible = list.is_empty()

	# newest exercise on top - rowParts follows the saved order, the rows on screen run backwards;
	# exercises only added at the end: the rows already there stay, only the new ones are made
	if ids != shownIds:
		var keepCount: int = shownIds.size()
		if ids.size() < keepCount or ids.slice(0, keepCount) != shownIds:
			keepCount = 0
			Ui.clearChildren(rowsBox)
			rowParts = []
		shownIds = ids
		for index in range(keepCount, list.size()):
			var parts: Dictionary = _makeRow(index, list[index])
			rowsBox.add_child(parts["row"])
			rowsBox.move_child(parts["row"], 0)
			rowParts.append(parts)
	for index in range(rowParts.size()):
		_updateRow(rowParts[index], list[index])


func _makeRow(index: int, entry: Dictionary) -> Dictionary:
	### WHAT THIS DOES
	# name + summary, the - n + stepper (sets, or minutes on cardio), remove, the grips box on grip
	# exercises and the Easy / Hard / Very hard chips on cardio

	var exercise: Dictionary = AppData.getExercise(str(entry["exerciseId"]))
	var cardio: bool = entry.has("minutes")
	var row := TapRow.new()
	row.setSwipeActions({}, {"id": "remove", "text": "Remove", "colour": Ui.colour("hot")})
	row.swiped.connect(_onRowSwiped.bind(index))
	var box: VBoxContainer = Ui.vbox(6)
	row.setContent(box)

	var line: HBoxContainer = Ui.hbox(6)
	box.add_child(line)
	var texts: VBoxContainer = Ui.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	var nameLabel: Label = Ui.wrapLabel(str(exercise.get("name", entry["exerciseId"])), "BoldLabel")
	texts.add_child(nameLabel)
	var metaText: String = Ui.exerciseMeta(exercise)
	if not bool(exercise.get("curated", false)):
		metaText += " · rough data"
	var meta: Label = Ui.wrapLabel(metaText, "MutedLabel")
	texts.add_child(meta)
	var plannedTag: PanelContainer = Ui.tag("planned", Ui.colour("ghost"))
	plannedTag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	texts.add_child(plannedTag)

	# stepper (minutes in steps of minuteStep on cardio, with a small "min" under the number)
	var stepper: HBoxContainer = Ui.hbox(0)
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(stepper)
	var step: int = 1
	if cardio:
		step = minuteStep
	var minus: Button = Ui.iconButton("minus", "Button", "text")
	minus.pressed.connect(_onStep.bind(index, -step))
	stepper.add_child(minus)
	var number: VBoxContainer = Ui.vbox(0)
	number.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_child(number)
	var setsLabel: Label = Ui.label("0", "BoldLabel")
	setsLabel.custom_minimum_size.x = stepperNumberWidth
	setsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setsLabel.add_theme_font_size_override("font_size", stepperFontSize)
	number.add_child(setsLabel)
	if cardio:
		var unit: Label = Ui.label(minuteWord, "FaintLabel")
		unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_child(unit)
	var plus: Button = Ui.iconButton("plus", "Button", "text")
	plus.pressed.connect(_onStep.bind(index, step))
	stepper.add_child(plus)
	var remove: Button = Ui.iconButton("close", "FlatButton", "textMuted")
	remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove.pressed.connect(removeEntry.bind(index))
	line.add_child(remove)

	# grips (only where the forearm work is holding on)
	var grips: CheckBox = null
	if str(exercise.get("forearmKind", "none")) == "grip":
		grips = CheckBox.new()
		grips.text = "Grips / straps - no forearm heat"
		grips.focus_mode = Control.FOCUS_NONE
		grips.add_theme_font_size_override("font_size", 15)
		grips.toggled.connect(_onGripsToggled.bind(index))
		box.add_child(grips)

	# how hard it felt (cardio) - its hint under the chips says what each means
	var effortChips: Segmented = null
	var effortHint: Label = null
	if cardio:
		effortChips = Segmented.new()
		effortChips.fillWidth = true
		var options: Array = []
		for effort in AppData.cardioEfforts:
			options.append([effort["id"], effort["label"]])
		effortChips.setOptions(options, str(entry.get("effort", "")))
		effortChips.changed.connect(_onEffortPicked.bind(index))
		box.add_child(effortChips)
		effortHint = Ui.wrapLabel("", "FaintLabel")
		box.add_child(effortHint)

	return {"row": row, "setsLabel": setsLabel, "minus": minus, "plus": plus, "plannedTag": plannedTag, "grips": grips, "meta": meta, "cardio": cardio, "effortChips": effortChips, "effortHint": effortHint}


func _updateRow(parts: Dictionary, entry: Dictionary) -> void:
	var planned: bool = not HeatEngine.isLogged(entry)
	var row: TapRow = parts["row"]
	if parts["cardio"]:
		parts["setsLabel"].text = str(int(entry.get("minutes", 0)))
		var effortId: String = str(entry.get("effort", ""))
		parts["effortChips"].select(effortId, false)
		var effort: Dictionary = AppData.effortById.get(effortId, {})
		parts["effortHint"].text = ""
		if not effort.is_empty():
			parts["effortHint"].text = "%s: %s" % [effort["label"], effort["hint"]]
		parts["effortHint"].add_theme_color_override("font_color", _effortColour(effortId))
	else:
		parts["setsLabel"].text = str(int(entry["sets"]))
	parts["minus"].disabled = planned
	parts["plannedTag"].visible = planned
	if parts["grips"] != null:
		parts["grips"].set_pressed_no_signal(bool(entry["grips"]))
	if planned:
		row.card.add_theme_stylebox_override("panel", AppTheme.box("planned", Ui.colour("ghost")))
	else:
		row.card.remove_theme_stylebox_override("panel")


func _onStep(index: int, delta: int) -> void:
	if index >= 0 and index < entries().size() and entries()[index].has("minutes"):
		changeMinutes(index, delta)
		return
	changeSets(index, delta)


func _effortColour(effortId: String) -> Color:
	# the colour of the cardio light an effort fills (blue easy, red hard), as on the home overlay
	var zone: String = str(AppData.effortById.get(effortId, {}).get("zone", ""))
	for light in AppData.cardioLights:
		if float(light["zones"].get(zone, 0)) > 0.0 and str(light["colour"]) == "red":
			return VesselLayer.redColour
		if float(light["zones"].get(zone, 0)) > 0.0:
			return VesselLayer.blueColour
	return Ui.colour("textMuted")


func _onEffortPicked(effortId: String, index: int) -> void:
	setEffort(index, effortId)


func _onGripsToggled(on: bool, index: int) -> void:
	setGrips(index, on)


func _onRowSwiped(actionId: String, index: int) -> void:
	if actionId == "remove":
		removeEntry(index)


func _process(_delta: float) -> void:
	# the elapsed clock
	if not live or finished or not is_visible_in_tree() or not Storage.hasCurrentWorkout():
		return
	var text: String = Ui.formatClock(Time.get_unix_time_from_system() - float(Storage.currentWorkout()["startedAt"]))
	if text != lastClock:
		lastClock = text
		timerLabel.text = text


### /// FINISH (LIVE) ///

func requestFinish() -> BottomSheet:
	### WHAT THIS DOES
	# confirm first; with nothing logged the choice is keep going or discard

	var list: Array = entries()
	var logged: Array = []
	var planned: int = 0
	for entry in list:
		if HeatEngine.isLogged(entry):
			logged.append(entry)
		else:
			planned += 1
	var length: float = Time.get_unix_time_from_system() - float(Storage.currentWorkout().get("startedAt", 0.0))
	if logged.is_empty():
		var emptyActions: Array = [["keep", "Keep going", "AccentButton"], ["discard", "Discard workout", "FlatButton"]]
		return app.confirm("Nothing logged yet", "Add sets (or cardio minutes) to at least one exercise to finish, or throw this workout away.", emptyActions, _onFinishChoice)
	var message: String = "%d exercises · %s · %s" % [logged.size(), Ui.workSummary(logged), Ui.formatClock(length)]
	if planned > 0:
		message += "\n%d planned exercise(s) with nothing logged will be left out." % planned
	var actions: Array = [["finish", "Finish workout", "AccentButton"], ["keep", "Keep going", "Button"], ["discard", "Discard workout", "FlatButton"]]
	return app.confirm("Finish workout?", message, actions, _onFinishChoice)


func _onFinishChoice(actionId: String) -> void:
	if actionId == "finish":
		_finish()
	elif actionId == "discard":
		discard()


func _finish() -> void:
	var done: Dictionary = Storage.finishWorkout()
	finished = true
	var suggested: String = "%s workout" % Ui.dayLabel(float(done.get("startedAt", 0.0)))
	var sheet: BottomSheet = app.askText("Save as a template?", "Use the same exercises again later: Add exercise → Templates.", suggested, "Template name", "Save template", Callable(), "Not now")
	sheet.onChoice = _onTemplateChoice.bind(sheet, done)


func _onTemplateChoice(actionId: String, sheet: BottomSheet, done: Dictionary) -> void:
	if actionId == "ok":
		var templateName: String = sheet.textValue()
		if templateName == "":
			templateName = "Template"
		Storage.saveTemplate(templateName, done["entries"])
	_backToWeek(done)


func _backToWeek(done: Dictionary) -> void:
	# lands on the week with the new heat blending in
	var week: WeekScreen = app.weekScreen()
	app.pop(true)
	if week != null:
		week.showFinished(done)
	app.showToast("Workout added to your week · %s" % Ui.workSummary(done.get("entries", [])))


func discard() -> void:
	var dropped: Dictionary = Storage.discardWorkout()
	finished = true
	app.pop(true)
	app.showToast("Workout discarded", "Undo", func() -> void: Storage.resumeWorkout(dropped))


### /// SAVE (EDITOR) ///

func saveChanges() -> void:
	# planned entries (nothing logged) are dropped, like on finish
	var kept: Array = []
	for entry in editWorkout.get("entries", []):
		if HeatEngine.isLogged(entry):
			kept.append(entry)
	editWorkout["entries"] = kept
	Storage.updateWorkout(editWorkout)
	dirty = false
	finished = true
	app.pop(true)
	app.showToast("Changes saved")


func onBack() -> bool:
	if live or not dirty:
		return false
	var actions: Array = [["save", "Save changes", "AccentButton"], ["discard", "Discard changes", "Button"], ["keep", "Keep editing", "FlatButton"]]
	app.confirm("Unsaved changes", "You changed this workout. Save the changes?", actions, _onLeaveChoice)
	return true


func _onLeaveChoice(actionId: String) -> void:
	if actionId == "save":
		saveChanges()
	elif actionId == "discard":
		dirty = false
		finished = true
		app.pop(true)
