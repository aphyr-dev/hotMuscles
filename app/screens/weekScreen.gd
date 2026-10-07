class_name WeekScreen
extends AppScreen
## WeekScreen - home: the rolling last 7 days
## what this offers
## - header (greeting, "This week", date range, workouts, total sets) and a settings button
## - body card with the week's heat (the heat gradient and 0-N slider, like the workout card; its own N)
## - Balance | Workouts tabs: showTab("balance" / "workouts")
## - openRegion(regionId) -> the region sheet (sets, band, short/over, contributions, Find exercises)
## - workouts tab: tap = openEditor(workoutId); delete with undo = deleteWorkout(workoutId);
##   saveAsTemplate(workoutId) asks for a name; long-press / "..." = the row menu
## - startWorkout(): starts one (or resumes the running one) and opens it; the button reads
##   "Resume workout · mm:ss" while one runs
## - showFinished(workout): back from a finished workout - the heat blends slowly to the new week
## - refresh(animate); weekHeat (regionId -> effective sets) and weekWorkouts hold what is shown

### /// TUNING ///

# tallest the body gets on the week card
const bodyMaxHeight: float = 470.0
# seconds the heat takes to blend after finishing a workout (normal changes use BodyView's own)
const finishBlendSeconds: float = 1.8
# tiny body thumbnail on a workout row
const thumbSize: Vector2 = Vector2(78.0, 84.0)
# main button height
const mainButtonHeight: float = 58.0
# balance rows made in the same frame a fresh week fills (they cover the screen below the body),
# then rows made per frame after that until all 30 are there - all at once cost a ~50 ms frame
const firstBalanceRows: int = 4
const balanceRowsPerFrame: int = 3

### /// STATE ///

var scroll: KineticScroll = null
var column: VBoxContainer = null
var greetingLabel: Label = null
var statsLabel: Label = null
var bodyCard: BodyCard = null
var tabs: Segmented = null
var balanceBox: VBoxContainer = null
var workoutsBox: VBoxContainer = null
var startButton: Button = null
var currentTab: String = "balance"
var weekHeat: Dictionary = {}
var weekWorkouts: Array = []
var balanceNote: Label = null
var balanceRanks: Array = []
var balanceRows: Dictionary = {}
var balancePending: bool = false
var workoutsShown: String = ""
var workoutRows: Dictionary = {}
var regionSheet: BottomSheet = null
var dirty: bool = true
var normalBlendSeconds: float = 0.9
var lastClockText: String = ""
var appliedDefaultView: String = ""


func _ready() -> void:
	_build()
	Storage.changed.connect(_onStorageChanged)
	refresh(false)


### /// BUILDING ///

func _build() -> void:
	### WHAT THIS DOES
	# one scrolling page (header, body card, tabs, rows) over a fixed start button

	var page := PanelContainer.new()
	page.theme_type_variation = "BackgroundPanel"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout: VBoxContainer = Ui.vbox(0)
	page.add_child(layout)

	scroll = KineticScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	column = Ui.vbox(pageGap)
	scroll.add_child(Ui.margin(column, pagePad, 14, pagePad, 24))

	# header
	var header: HBoxContainer = Ui.hbox(8)
	column.add_child(header)
	var titles: VBoxContainer = Ui.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	greetingLabel = Ui.label("", "MutedLabel")
	titles.add_child(greetingLabel)
	titles.add_child(Ui.label("This week", "HeaderLabel"))
	statsLabel = Ui.wrapLabel("", "MutedLabel")
	titles.add_child(statsLabel)
	var settingsButton: Button = Ui.iconButton("gear", "Button", "textMuted")
	settingsButton.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settingsButton.pressed.connect(_onSettingsPressed)
	header.add_child(settingsButton)

	# body card
	bodyCard = BodyCard.new()
	column.add_child(bodyCard)
	bodyCard.configure("Sets this week", bodyMaxHeight, "rangeWeek", true, "Tap a muscle for details · pinch to zoom")
	bodyCard.regionTapped.connect(openRegion)
	normalBlendSeconds = bodyCard.bodyView.transitionSeconds

	# tabs
	tabs = Segmented.new()
	tabs.fillWidth = true
	column.add_child(tabs)
	tabs.setOptions([["balance", "Balance"], ["workouts", "Workouts"]], currentTab)
	tabs.changed.connect(showTab)
	balanceBox = Ui.vbox(8)
	column.add_child(balanceBox)
	workoutsBox = Ui.vbox(8)
	column.add_child(workoutsBox)

	# start / resume
	startButton = Ui.button("Start workout", "AccentButton", startWorkout)
	startButton.custom_minimum_size.y = mainButtonHeight
	layout.add_child(Ui.margin(startButton, pagePad, 8, pagePad, 12))
	_applyTab()


func rebuild() -> void:
	# a new theme: the workout rows carry theme colours, so they are made again
	workoutsShown = ""
	refresh(false)


### /// REFRESH ///

func _now() -> float:
	return Time.get_unix_time_from_system()


func _onStorageChanged(section: String) -> void:
	if section == "settings":
		_applySettings()
		return
	if section == "exercisePrefs":
		return
	dirty = true
	if is_visible_in_tree():
		call_deferred("_refreshIfDirty")


func _refreshIfDirty() -> void:
	if dirty:
		refresh(true)


func onShown() -> void:
	if dirty:
		refresh(true)
	_applySettings()


func _applySettings() -> void:
	if bodyCard == null:
		return
	bodyCard.setHideUntouched(bool(Storage.settings["hideUntouched"]))
	bodyCard.setRange(int(Storage.settings["rangeWeek"]))
	# a changed "default body view" setting wins over the chips; otherwise the chips' pick stays
	var defaultView: String = str(Storage.settings["defaultView"])
	if defaultView != appliedDefaultView:
		appliedDefaultView = defaultView
		bodyCard.setView(defaultView)


func refresh(animate: bool) -> void:
	### WHAT THIS DOES
	# recomputes the rolling week from storage and redraws everything on the page

	var now: float = _now()
	var submitted: Array = Storage.submittedWorkouts()

	dirty = false
	weekWorkouts = HeatEngine.workoutsInWindow(submitted, now)
	weekHeat = HeatEngine.weekHeat(submitted, AppData.exerciseById, now)

	# header
	var totalSets: int = Ui.setCount(HeatEngine.weekEntries(weekWorkouts))
	var workoutWord: String = "workouts"
	if weekWorkouts.size() == 1:
		workoutWord = "workout"
	greetingLabel.text = Ui.greeting(str(Storage.profile["name"]), now)
	statsLabel.text = "%s · %d %s · %d sets" % [Ui.weekRangeLabel(now), weekWorkouts.size(), workoutWord, totalSets]

	# body
	bodyCard.setBody(str(Storage.profile["body"]))
	bodyCard.setGradient(str(Storage.profile["gradient"]))
	_applySettings()
	bodyCard.setHeat(weekHeat, animate)

	_fillBalance()
	_fillWorkouts()
	_updateStartButton()


### /// TABS ///

func showTab(tabId: String) -> void:
	currentTab = tabId
	tabs.select(tabId, false)
	_applyTab()


func _applyTab() -> void:
	balanceBox.visible = currentTab == "balance"
	workoutsBox.visible = currentTab == "workouts"


### /// BALANCE ///

func _fillBalance() -> void:
	### WHAT THIS DOES
	# one row per region, furthest from its target band first; each row is made once and after that
	# only gets new numbers and a new place, and a fresh page makes the first few rows now and the
	# rest over the next frames (_process)

	if balanceNote == null:
		balanceNote = Ui.label("Effective sets in the last 7 days against each muscle's weekly target band", "FaintLabel")
		balanceNote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		balanceBox.add_child(balanceNote)
	balanceRanks = HeatEngine.rankRegions(weekHeat, AppData.regions)
	_placeBalanceRows(firstBalanceRows)


func _placeBalanceRows(newRowLimit: int) -> void:
	### WHAT THIS DOES
	# puts the rows in rank order with fresh numbers, making at most newRowLimit missing rows;
	# stops at the first row it may not make yet and leaves the rest for the next frame

	var made: int = 0
	var place: int = 1

	balancePending = false
	for rank in balanceRanks:
		var regionId: String = str(rank["region"])
		if not balanceRows.has(regionId):
			if made >= newRowLimit:
				balancePending = true
				return
			balanceRows[regionId] = _balanceRow(regionId, str(rank["name"]))
			balanceBox.add_child(balanceRows[regionId]["row"])
			made += 1
		var parts: Dictionary = balanceRows[regionId]
		_updateBalanceRow(parts, rank)
		balanceBox.move_child(parts["row"], place)
		place += 1


func _balanceRow(regionId: String, regionName: String) -> Dictionary:
	# one region's row, without numbers yet (_updateBalanceRow fills them)
	var row := TapRow.new()
	var box: VBoxContainer = Ui.vbox(8)
	row.setContent(box)
	var top: HBoxContainer = Ui.hbox(8)
	box.add_child(top)
	var nameLabel: Label = Ui.label(regionName, "BoldLabel")
	nameLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nameLabel)
	var amount: Label = Ui.label("", "MutedLabel")
	top.add_child(amount)
	var status: PanelContainer = Ui.tag("", Ui.colour("textMuted"))
	top.add_child(status)
	var bar := BalanceBar.new()
	box.add_child(bar)
	row.tapped.connect(openRegion.bind(regionId))
	row.set_meta("regionId", regionId)
	return {"row": row, "amount": amount, "status": status, "bar": bar}


func _updateBalanceRow(parts: Dictionary, rank: Dictionary) -> void:
	var band: Array = rank["band"]
	parts["amount"].text = "%s / %d–%d" % [Ui.formatSets(rank["sets"]), int(band[0]), int(band[1])]
	Ui.retag(parts["status"], Ui.statusText(rank["status"]), Ui.statusColour(rank["status"]))
	parts["bar"].setValues(float(rank["sets"]), band, str(rank["status"]))


### /// WORKOUTS ///

func _fillWorkouts() -> void:
	### WHAT THIS DOES
	# the workouts of the rolling week, newest first; tap to edit, swipe or "..." for more; a row is
	# only made again when something it shows changed (its workout, the body, the colours, the 0-N
	# range, the date - day names follow it), otherwise it is kept and moved into place

	var newestFirst: Array = weekWorkouts.duplicate()
	var shared: String = JSON.stringify([Storage.profile["body"], Storage.profile["gradient"], Storage.settings["rangeWorkout"], Time.get_date_string_from_system()])
	var keptRows: Dictionary = {}
	var place: int = 1

	newestFirst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["startedAt"]) > float(b["startedAt"]))

	# nothing this week: the hint text instead of rows
	if newestFirst.is_empty():
		if workoutsShown == "empty":
			return
		workoutsShown = "empty"
		Ui.clearChildren(workoutsBox)
		workoutRows = {}
		var empty: Label = Ui.wrapLabel("No workouts in the last 7 days yet. Start one with the button below - it shows up here when you finish it.", "MutedLabel")
		workoutsBox.add_child(Ui.margin(empty, 4, 8, 4, 8))
		return

	# the line over the rows (a fresh list, after the hint text, or after a theme change)
	if workoutsShown != "rows":
		workoutsShown = "rows"
		Ui.clearChildren(workoutsBox)
		workoutRows = {}
		workoutsBox.add_child(Ui.label("Tap to edit · swipe left to delete, right to save as a template", "FaintLabel"))

	# rows: kept when unchanged, made when new, in newest-first order; the rest go away
	for workout in newestFirst:
		var rowKey: String = JSON.stringify(workout) + shared
		var row: TapRow = workoutRows.get(rowKey, null)
		if row == null:
			row = _workoutRow(workout)
			workoutsBox.add_child(row)
		keptRows[rowKey] = row
		workoutsBox.move_child(row, place)
		place += 1
	for rowKey in workoutRows:
		if not keptRows.has(rowKey):
			workoutsBox.remove_child(workoutRows[rowKey])
			workoutRows[rowKey].queue_free()
	workoutRows = keptRows


func _workoutRow(workout: Dictionary) -> TapRow:
	var row := TapRow.new()
	var entries: Array = workout["entries"]
	var line: HBoxContainer = Ui.hbox(12)
	row.setContent(line)

	# tiny body with this workout's own heat (a picture, not tappable)
	var thumb := BodyView.new()
	thumb.interactive = false
	thumb.viewMode = "both"
	thumb.edgeMargin = 2.0
	thumb.pairGap = 0.02
	thumb.custom_minimum_size = thumbSize
	thumb.body = str(Storage.profile["body"])
	thumb.gradientId = str(Storage.profile["gradient"])
	thumb.rangeMax = float(Storage.settings["rangeWorkout"])
	line.add_child(thumb)
	thumb.setHeat(HeatEngine.effectiveSets(entries, AppData.exerciseById), false)

	# text
	var texts: VBoxContainer = Ui.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	var started: float = float(workout["startedAt"])
	texts.add_child(Ui.label("%s · %s" % [Ui.dayLabel(started), Ui.timeLabel(started)], "BoldLabel"))
	var length: float = HeatEngine.workoutTime(workout) - started
	var exerciseWord: String = "exercises"
	if entries.size() == 1:
		exerciseWord = "exercise"
	texts.add_child(Ui.label("%s · %d sets · %d %s" % [Ui.formatLength(length), Ui.setCount(entries), entries.size(), exerciseWord], "MutedLabel"))
	var names: Array = []
	for entry in entries:
		names.append(str(AppData.getExercise(entry["exerciseId"]).get("name", entry["exerciseId"])))
	var nameLine: Label = Ui.label(", ".join(names), "FaintLabel")
	nameLine.clip_text = true
	nameLine.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nameLine.custom_minimum_size.x = 60.0
	texts.add_child(nameLine)

	var more: Button = Ui.iconButton("more", "FlatButton", "textMuted")
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	more.pressed.connect(openWorkoutMenu.bind(str(workout["id"])))
	line.add_child(more)

	var workoutId: String = str(workout["id"])
	row.setSwipeActions({"id": "template", "text": "Save as template", "colour": Ui.colour("accent")}, {"id": "delete", "text": "Delete", "colour": Ui.colour("hot")})
	row.tapped.connect(openEditor.bind(workoutId))
	row.longPressed.connect(openWorkoutMenu.bind(workoutId))
	row.swiped.connect(_onWorkoutSwiped.bind(workoutId))
	row.set_meta("workoutId", workoutId)
	return row


func _onWorkoutSwiped(actionId: String, workoutId: String) -> void:
	if actionId == "delete":
		deleteWorkout(workoutId)
	elif actionId == "template":
		saveAsTemplate(workoutId)


func openWorkoutMenu(workoutId: String) -> BottomSheet:
	var index: int = Storage.findWorkoutIndex(workoutId)
	if index < 0:
		return null
	var workout: Dictionary = Storage.submittedWorkouts()[index]
	var title: String = "%s · %s" % [Ui.dayLabel(float(workout["startedAt"])), Ui.timeLabel(float(workout["startedAt"]))]
	var actions: Array = [["edit", "Edit workout", "Button"], ["template", "Save as template", "Button"], ["delete", "Delete workout", "Button"]]
	return app.confirm(title, "", actions, _onWorkoutMenu.bind(workoutId))


func _onWorkoutMenu(actionId: String, workoutId: String) -> void:
	if actionId == "edit":
		openEditor(workoutId)
	elif actionId == "template":
		saveAsTemplate(workoutId)
	elif actionId == "delete":
		deleteWorkout(workoutId)


func openEditor(workoutId: String) -> WorkoutScreen:
	return app.openWorkoutEditor(workoutId)


func deleteWorkout(workoutId: String) -> void:
	# gone at once, with an undo on the toast (no "are you sure")
	var removed: Dictionary = Storage.deleteWorkout(workoutId)
	if removed.is_empty():
		return
	app.showToast("Workout deleted", "Undo", func() -> void: Storage.restoreWorkout(removed))


func saveAsTemplate(workoutId: String) -> BottomSheet:
	var index: int = Storage.findWorkoutIndex(workoutId)
	if index < 0:
		return null
	var workout: Dictionary = Storage.submittedWorkouts()[index]
	var suggested: String = "%s workout" % Ui.dayLabel(float(workout["startedAt"]))
	var sheet: BottomSheet = app.askText("Save as template", "Its exercises, sets and grips - apply it from Add exercise → Templates.", suggested, "Template name", "Save template", Callable())
	sheet.onChoice = _onTemplateNamed.bind(sheet, workout["entries"])
	return sheet


func _onTemplateNamed(actionId: String, sheet: BottomSheet, entries: Array) -> void:
	if actionId != "ok":
		return
	var templateName: String = sheet.textValue()
	if templateName == "":
		templateName = "Template"
	Storage.saveTemplate(templateName, entries)
	app.showToast("Template \"%s\" saved" % templateName)


### /// REGION SHEET ///

func openRegion(regionId: String) -> BottomSheet:
	### WHAT THIS DOES
	# sets this week, the band, how far off, which exercises gave how much, Find exercises

	var sets: float = float(weekHeat.get(regionId, 0.0))
	var band: Array = AppData.regionBand(regionId)
	var status: String = HeatEngine.targetStatus(sets, band)
	var region: Dictionary = AppData.getRegion(regionId)
	var sheet := BottomSheet.new()
	var viewWords: Array = region.get("views", [])

	bodyCard.bodyView.selectedRegion = regionId
	sheet.setTitle(str(region.get("name", regionId)), "%s view · last 7 days" % " + ".join(viewWords))

	# three stat tiles
	var tiles: HBoxContainer = Ui.hbox(8)
	sheet.body.add_child(tiles)
	tiles.add_child(_statTile(Ui.formatSets(sets), "sets this week", null))
	tiles.add_child(_statTile("%d–%d" % [int(band[0]), int(band[1])], "target band", null))
	var offText: String = "on target"
	if sets < float(band[0]):
		offText = "%s short" % Ui.formatSets(float(band[0]) - sets)
	elif sets > float(band[1]):
		offText = "%s over" % Ui.formatSets(sets - float(band[1]))
	tiles.add_child(_statTile("", offText, Ui.tag(Ui.statusText(status), Ui.statusColour(status))))

	# where it came from
	var contributions: Array = HeatEngine.contributions(regionId, HeatEngine.weekEntries(weekWorkouts), AppData.exerciseById)
	var heading: HBoxContainer = Ui.hbox(8)
	heading.add_child(Ui.label("Where it came from", "BoldLabel"))
	heading.add_child(Ui.spacer())
	heading.add_child(Ui.label("effective sets", "FaintLabel"))
	sheet.body.add_child(heading)
	if contributions.is_empty():
		sheet.body.add_child(Ui.wrapLabel("Nothing worked this muscle in the last 7 days.", "MutedLabel"))
	var biggest: float = 0.0
	for row in contributions:
		biggest = maxf(biggest, float(row["effective"]))
	for row in contributions:
		sheet.body.add_child(_contributionRow(row, biggest))

	sheet.addAction("find", "Find exercises for %s" % str(region.get("name", regionId)).to_lower(), "AccentButton")
	sheet.onChoice = _onRegionChoice.bind(regionId)
	sheet.closed.connect(_onRegionSheetClosed)
	sheet.set_meta("regionId", regionId)
	sheet.set_meta("contributionCount", contributions.size())
	regionSheet = sheet
	return app.openSheet(sheet)


func _statTile(big: String, small: String, extra: Control) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Ui.colour("surfaceHi")
	box.set_corner_radius_all(14)
	box.content_margin_left = 12
	box.content_margin_right = 8
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	tile.add_theme_stylebox_override("panel", box)
	var stack: VBoxContainer = Ui.vbox(4)
	tile.add_child(stack)
	if extra != null:
		extra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		stack.add_child(extra)
	if big != "":
		var value: Label = Ui.label(big, "TitleLabel")
		stack.add_child(value)
	stack.add_child(Ui.label(small, "MutedLabel"))
	return tile


func _contributionRow(row: Dictionary, biggest: float) -> VBoxContainer:
	var box: VBoxContainer = Ui.vbox(4)
	var top: HBoxContainer = Ui.hbox(8)
	box.add_child(top)
	var nameLabel: Label = Ui.wrapLabel(str(row["name"]), "BoldLabel")
	top.add_child(nameLabel)
	top.add_child(Ui.label(Ui.formatSets(float(row["effective"])), "BoldLabel"))
	box.add_child(Ui.label("%d sets × %s" % [int(row["sets"]), Ui.formatSets(float(row["share"]))], "MutedLabel"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6.0
	bar.max_value = maxf(biggest, 0.001)
	bar.value = float(row["effective"])
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	return box


func _onRegionChoice(actionId: String, regionId: String) -> void:
	if actionId == "find":
		app.openPicker(null, regionId)


func _onRegionSheetClosed() -> void:
	regionSheet = null
	if bodyCard != null:
		bodyCard.bodyView.selectedRegion = ""


### /// START / RESUME ///

func startWorkout() -> WorkoutScreen:
	if not Storage.hasCurrentWorkout():
		Storage.startWorkout()
	return app.openWorkout()


func _updateStartButton() -> void:
	var text: String = "Start workout"
	if Storage.hasCurrentWorkout():
		var started: float = float(Storage.currentWorkout()["startedAt"])
		text = "Resume workout · %s" % Ui.formatClock(_now() - started)
	if text != lastClockText:
		lastClockText = text
		startButton.text = text


func _process(_delta: float) -> void:
	if balancePending:
		_placeBalanceRows(balanceRowsPerFrame)
	if is_visible_in_tree() and Storage.hasCurrentWorkout():
		_updateStartButton()


func showFinished(_workout: Dictionary) -> void:
	### WHAT THIS DOES
	# back from Finish: scroll to the body and blend the new heat in slowly so the change shows

	scroll.scrollTo(0.0)
	bodyCard.bodyView.transitionSeconds = finishBlendSeconds
	refresh(true)
	get_tree().create_timer(finishBlendSeconds + 0.1).timeout.connect(_restoreBlend)


func _restoreBlend() -> void:
	if bodyCard != null:
		bodyCard.bodyView.transitionSeconds = normalBlendSeconds


func _onSettingsPressed() -> void:
	app.openSettings()
