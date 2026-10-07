class_name PickerScreen
extends AppScreen
## PickerScreen - add exercises: search, equipment chips, favourites first, tick several, a ghost
## preview on the body, tap a muscle for recommendations, and the Templates tab
## what this offers
## - PickerScreen.create(target, regionId)   target = the WorkoutScreen to add to, or null (from the
##   week: adds to the running workout, or starts one - the button then reads "Start workout with N")
## - exercises tab: setSearch(text), toggleEquipment(name), setEquipment(names), setShowHidden(on),
##   setRegionFilter(regionId) / clearRegionFilter(), toggleExercise(exerciseId), addSelected()
##   results (exercise dicts in list order), selected (ticked ids), ghost() (the preview heat)
## - star / hide: setFavourite(id, on), setHidden(id, on) (undo toast), openExerciseMenu(id)
##   (long-press), swipe right = star, swipe left = hide
## - templates tab: showTab("templates"), previewTemplate(id), applyTemplate(id),
##   renameTemplate(id) (asks), deleteTemplate(id) (undo toast)
## - "rough data" tag on non-curated exercises, "in workout" on ones already added

### /// TUNING ///

# tallest the body gets here (the list needs the room)
const bodyMaxHeight: float = 250.0
# rows kept ready below the visible ones, and how close to the bottom the next batch is asked for (px)
const pageSize: int = 40
const loadMoreMargin: float = 900.0
# rows made in the same frame the list changes (more than fit on screen), then rows made per frame
# after that until the batch is ready - making all 40 at once cost a ~90 ms frame
const firstRows: int = 6
const rowsPerFrame: int = 3
# seconds after the last keystroke before the list updates
const searchDelay: float = 0.15
# tick circle size
const tickSize: float = 26.0
# main button height
const mainButtonHeight: float = 58.0

### /// STATE ///

var target: WorkoutScreen = null
var regionFilter: String = ""
var query: String = ""
var equipment: Array = []
var showHidden: bool = false
var selected: Array = []
var currentTab: String = "exercises"
var previewTemplateId: String = ""
var results: Array = []
var resultShares: Dictionary = {}
var shownCount: int = 0
var rowsWanted: int = 0
var rowsById: Dictionary = {}
var spareRows: Dictionary = {}
var bodyCard: BodyCard = null
var tabs: Segmented = null
var exercisesPanel: VBoxContainer = null
var templatesPanel: VBoxContainer = null
var searchEdit: LineEdit = null
var equipmentChips: Dictionary = {}
var allChip: Button = null
var hiddenChip: Button = null
var filterRow: HBoxContainer = null
var filterChip: Button = null
var countLabel: Label = null
var list: KineticScroll = null
var listBox: VBoxContainer = null
var templateList: KineticScroll = null
var templatesBox: VBoxContainer = null
var addButton: Button = null
var searchPending: bool = false
var searchAt: float = 0.0


static func create(targetScreen: WorkoutScreen, regionId: String) -> PickerScreen:
	var made := PickerScreen.new()
	made.target = targetScreen
	made.regionFilter = regionId
	return made


func _ready() -> void:
	_build()
	Storage.changed.connect(_onStorageChanged)
	if regionFilter != "":
		setRegionFilter(regionFilter)
	else:
		refreshList()
	refreshTemplates()
	_updateBody()
	_updateAddButton()


### /// BUILDING ///

func _build() -> void:
	var backText: String = "Week"
	if target != null:
		backText = "Workout"
	var frame: Dictionary = buildFrame("Add exercises", backText)
	var content: VBoxContainer = frame["content"]

	# body: this workout + the ghost of what is ticked
	bodyCard = BodyCard.new()
	content.add_child(Ui.margin(bodyCard, pagePad, 0, pagePad, 8))
	var cardTitle: String = "Workout + ticked"
	if not _hasWorkout():
		cardTitle = "Preview"
	bodyCard.configure(cardTitle, bodyMaxHeight, "rangeWorkout", false, "")
	bodyCard.regionTapped.connect(setRegionFilter)

	tabs = Segmented.new()
	tabs.fillWidth = true
	content.add_child(Ui.margin(tabs, pagePad, 0, pagePad, 8))
	tabs.setOptions([["exercises", "Exercises"], ["templates", "Templates"]], currentTab)
	tabs.changed.connect(showTab)

	# exercises tab
	exercisesPanel = Ui.vbox(8)
	exercisesPanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(exercisesPanel)
	searchEdit = LineEdit.new()
	searchEdit.placeholder_text = "Search exercises"
	searchEdit.clear_button_enabled = true
	searchEdit.custom_minimum_size.y = 50.0
	searchEdit.text_changed.connect(_onSearchTyped)
	exercisesPanel.add_child(Ui.margin(searchEdit, pagePad, 0, pagePad, 0))
	exercisesPanel.add_child(_buildChips())
	filterRow = Ui.hbox(8)
	exercisesPanel.add_child(Ui.margin(filterRow, pagePad, 0, pagePad, 0))
	filterChip = Ui.button("", "ChipButton", clearRegionFilter)
	filterChip.toggle_mode = true
	filterChip.button_pressed = true
	filterRow.add_child(filterChip)
	var why: Label = Ui.label("best match first", "FaintLabel")
	why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	filterRow.add_child(why)
	list = makeScroll(exercisesPanel)
	listBox = list.get_meta("column")
	listBox.add_theme_constant_override("separation", 8)
	list.scrolled.connect(_onListScrolled)
	countLabel = Ui.label("", "FaintLabel")
	listBox.add_child(countLabel)

	# templates tab
	templatesPanel = Ui.vbox(8)
	templatesPanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(templatesPanel)
	templateList = makeScroll(templatesPanel)
	templatesBox = templateList.get_meta("column")
	templatesBox.add_theme_constant_override("separation", 8)

	addButton = Ui.button("", "AccentButton", addSelected)
	addButton.custom_minimum_size.y = mainButtonHeight
	frame["bottom"].add_child(addButton)
	_applyTab()


func _buildChips() -> HScrollStrip:
	### WHAT THIS DOES
	# All, then each equipment (most exercises first), then Show hidden - one sideways strip

	var strip := HScrollStrip.new()
	var row: HBoxContainer = Ui.hbox(6)
	strip.add_child(Ui.margin(row, pagePad, 0, pagePad, 0))
	allChip = _chip(row, "All")
	allChip.pressed.connect(setEquipment.bind([]))
	var counts: Dictionary = {}
	for exercise in AppData.exercises:
		counts[exercise["equipment"]] = int(counts.get(exercise["equipment"], 0)) + 1
	var names: Array = AppData.equipmentList()
	names.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]))
	# "other" is a catch-all, not an equipment - it goes last
	if names.has("other"):
		names.erase("other")
		names.append("other")
	for equipmentName in names:
		var chip: Button = _chip(row, equipmentName)
		chip.pressed.connect(toggleEquipment.bind(equipmentName))
		equipmentChips[equipmentName] = chip
	hiddenChip = _chip(row, "Show hidden")
	hiddenChip.pressed.connect(_onHiddenChip)
	_syncChips()
	return strip


func _chip(row: HBoxContainer, text: String) -> Button:
	var chip: Button = Ui.button(text, "ChipButton")
	chip.toggle_mode = true
	chip.custom_minimum_size.y = 44.0
	row.add_child(chip)
	return chip


func rebuild() -> void:
	# a new theme: rows carry theme colours, so none of them is reused
	_dropRows()
	refreshList()
	refreshTemplates()


### /// HELPERS ///

func _hasWorkout() -> bool:
	if target != null:
		return true
	return Storage.hasCurrentWorkout()


func _workoutEntries() -> Array:
	if target != null and is_instance_valid(target):
		return target.entries()
	return Storage.currentWorkout().get("entries", [])


func _startSets() -> int:
	return int(Storage.settings["newExerciseSets"])


func _onStorageChanged(section: String) -> void:
	if section == "templates":
		refreshTemplates()


### /// TABS ///

func showTab(tabId: String) -> void:
	currentTab = tabId
	tabs.select(tabId, false)
	_applyTab()
	_updateBody()
	_updateAddButton()


func _applyTab() -> void:
	exercisesPanel.visible = currentTab == "exercises"
	templatesPanel.visible = currentTab == "templates"


### /// FILTERS ///

func setSearch(text: String) -> void:
	query = text
	if searchEdit.text != text:
		searchEdit.text = text
	searchPending = false
	refreshList()


func _onSearchTyped(text: String) -> void:
	query = text
	searchPending = true
	searchAt = Time.get_ticks_msec() / 1000.0 + searchDelay


func setEquipment(names: Array) -> void:
	equipment = names.duplicate()
	_syncChips()
	refreshList()


func toggleEquipment(equipmentName: String) -> void:
	var names: Array = equipment.duplicate()
	if names.has(equipmentName):
		names.erase(equipmentName)
	else:
		names.append(equipmentName)
	setEquipment(names)


func setShowHidden(on: bool) -> void:
	showHidden = on
	_syncChips()
	refreshList()


func _onHiddenChip() -> void:
	setShowHidden(not showHidden)


func _syncChips() -> void:
	allChip.set_pressed_no_signal(equipment.is_empty())
	for equipmentName in equipmentChips:
		equipmentChips[equipmentName].set_pressed_no_signal(equipment.has(equipmentName))
	hiddenChip.set_pressed_no_signal(showHidden)


func setRegionFilter(regionId: String) -> void:
	### WHAT THIS DOES
	# recommended exercises for one muscle; the body turns to a view that shows it

	regionFilter = regionId
	bodyCard.bodyView.selectedRegion = regionId
	var views: Array = AppData.getRegion(regionId).get("views", [])
	var viewMode: String = bodyCard.bodyView.viewMode
	if viewMode != "both" and views.size() > 0 and not views.has(viewMode):
		bodyCard.setView(str(views[0]))
	if currentTab != "exercises":
		showTab("exercises")
	refreshList()


func clearRegionFilter() -> void:
	regionFilter = ""
	bodyCard.bodyView.selectedRegion = ""
	refreshList()


### /// RESULTS ///

func computeResults() -> Array:
	### WHAT THIS DOES
	# with a muscle: HeatEngine.recommend order (search words still filter); without: favourites,
	# then (no search) recently used, then the search order; hidden ones only with Show hidden

	var prefs: Dictionary = Storage.exercisePrefs
	var used: Dictionary = Storage.usedExercises()
	var hasQuery: bool = query.strip_edges() != ""
	var rows: Array = []

	resultShares = {}
	if regionFilter != "":
		var allowed: Dictionary = {}
		if hasQuery:
			for exercise in AppData.search(query, equipment):
				allowed[exercise["id"]] = true
		var options: Dictionary = {"prefs": prefs, "used": used, "equipment": equipment, "showHidden": showHidden}
		for recommended in HeatEngine.recommend(regionFilter, AppData.exercises, options):
			var exercise: Dictionary = recommended["exercise"]
			if hasQuery and not allowed.has(exercise["id"]):
				continue
			rows.append(exercise)
			resultShares[exercise["id"]] = float(recommended["share"])
		return rows

	var favourites: Array = []
	var recent: Array = []
	var rest: Array = []
	for exercise in AppData.search(query, equipment):
		var pref: Dictionary = Storage.getPref(exercise["id"])
		if bool(pref["hidden"]) and not showHidden:
			continue
		if bool(pref["favourite"]):
			favourites.append(exercise)
		elif not hasQuery and used.has(exercise["id"]):
			recent.append(exercise)
		else:
			rest.append(exercise)
	recent.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(used[a["id"]]) > float(used[b["id"]]))
	rows.append_array(favourites)
	rows.append_array(recent)
	rows.append_array(rest)
	return rows


func refreshList(keepScroll: bool = false) -> void:
	### WHAT THIS DOES
	# the list for the current search, chips and muscle: the first rows now, the rest a few per frame
	# (_process); a row that would look the same as before is moved into place instead of made again -
	# the old rows stay in the list until taken or freed (taking a row out of the tree and putting it
	# back costs as much as making it). keepScroll = star / hide: the rows that were there all come
	# back at once, so the scroll position still means the same

	var oldOffset: float = list.scrollOffset
	var oldCount: int = shownCount

	# old rows hide while a new list fills in; for star / hide every row comes back in this same
	# frame, so they stay on show (switching 40 rows off and on again costs a frame of layout)
	results = computeResults()
	for exerciseId in rowsById:
		spareRows[exerciseId] = rowsById[exerciseId]
		if not keepScroll:
			rowsById[exerciseId].visible = false
	rowsById = {}
	shownCount = 0

	# filter chip + count line
	filterRow.get_parent().visible = regionFilter != ""
	filterChip.text = "for: %s  ×" % AppData.regionName(regionFilter)
	if results.is_empty():
		countLabel.text = "Nothing matches - try fewer words or clear a filter."
	elif regionFilter != "":
		countLabel.text = "%d exercises reach %s · tap a row to tick it" % [results.size(), AppData.regionName(regionFilter).to_lower()]
	else:
		countLabel.text = "%d exercises · tap to tick · hold or swipe to star / hide" % results.size()

	rowsWanted = pageSize
	if keepScroll:
		rowsWanted = maxi(oldCount, pageSize)
		_appendRows(maxi(oldCount, firstRows))
		list.call_deferred("scrollTo", oldOffset)
	else:
		_appendRows(firstRows)
		list.scrollTo(0.0)


func _appendRows(count: int) -> void:
	# the next rows of the results, each moved to its place under the count line; once the wanted rows
	# are all there, old rows nobody took go away
	var end: int = mini(shownCount + count, results.size())
	for index in range(shownCount, end):
		var row: TapRow = _rowFor(results[index])
		listBox.move_child(row, index + 1)
	shownCount = end
	if shownCount >= rowsWanted or shownCount >= results.size():
		_freeSpares()


func _rowFor(exercise: Dictionary) -> TapRow:
	# the row this exercise had in the list before when it would look the same, otherwise a new one
	var exerciseId: String = exercise["id"]
	if spareRows.has(exerciseId):
		var old: TapRow = spareRows[exerciseId]
		spareRows.erase(exerciseId)
		if str(old.get_meta("look")) == _rowLook(exerciseId):
			rowsById[exerciseId] = old
			_showTicked(old, selected.has(exerciseId))
			old.visible = true
			return old
		old.queue_free()
	var row: TapRow = _exerciseRow(exercise)
	listBox.add_child(row)
	return row


func _freeSpares() -> void:
	# queue_free: a row can be the one whose swipe asked for this refresh
	for exerciseId in spareRows:
		spareRows[exerciseId].queue_free()
	spareRows = {}


func _dropRows() -> void:
	for exerciseId in rowsById:
		spareRows[exerciseId] = rowsById[exerciseId]
		rowsById[exerciseId].visible = false
	rowsById = {}
	shownCount = 0
	_freeSpares()


func _onListScrolled(offset: float) -> void:
	# near the bottom once the current batch is all there: ask for another (_process makes it a few
	# rows per frame)
	if shownCount < rowsWanted:
		return
	if shownCount < results.size() and offset > list.maxOffset() - loadMoreMargin:
		rowsWanted = maxi(rowsWanted, shownCount + pageSize)


func _rowLook(exerciseId: String) -> String:
	# everything a row shows that can change while the picker is open (the tick is set separately)
	var pref: Dictionary = Storage.getPref(exerciseId)
	var share: String = ""
	var inWorkout: bool = false
	if resultShares.has(exerciseId):
		share = "%s %s" % [Ui.formatSets(resultShares[exerciseId]), regionFilter]
	for entry in _workoutEntries():
		if entry["exerciseId"] == exerciseId:
			inWorkout = true
			break
	return "%s|%s|%s|%s" % [bool(pref["favourite"]), bool(pref["hidden"]), share, inWorkout]


func _exerciseRow(exercise: Dictionary) -> TapRow:
	### WHAT THIS DOES
	# tick circle, name (+ star), equipment and main muscles, small tags

	var exerciseId: String = exercise["id"]
	var pref: Dictionary = Storage.getPref(exerciseId)
	var row := TapRow.new()
	row.set_meta("look", _rowLook(exerciseId))
	var line: HBoxContainer = Ui.hbox(12)
	row.setContent(line)

	var tick := AppIcon.new()
	tick.iconSize = tickSize
	tick.custom_minimum_size = Vector2(tickSize, tickSize)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tick)

	var texts: VBoxContainer = Ui.vbox(3)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(texts)
	var nameLine: HBoxContainer = Ui.hbox(6)
	texts.add_child(nameLine)
	nameLine.add_child(Ui.wrapLabel(str(exercise["name"]), "BoldLabel"))
	if bool(pref["favourite"]):
		var star := AppIcon.new()
		star.kind = "starFilled"
		star.colourKey = "accent"
		star.iconSize = 18.0
		star.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		nameLine.add_child(star)
	texts.add_child(Ui.wrapLabel(Ui.exerciseMeta(exercise), "MutedLabel"))

	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 4)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if resultShares.has(exerciseId):
		tags.add_child(Ui.tag("× %s on %s" % [Ui.formatSets(resultShares[exerciseId]), AppData.regionName(regionFilter).to_lower()], Ui.colour("accent"), false))
	if not bool(exercise.get("curated", false)):
		tags.add_child(Ui.tag("rough data", Ui.colour("textMuted")))
	if bool(pref["hidden"]):
		tags.add_child(Ui.tag("hidden", Ui.colour("hot")))
	for entry in _workoutEntries():
		if entry["exerciseId"] == exerciseId:
			tags.add_child(Ui.tag("in workout", Ui.colour("ghost")))
			break
	if tags.get_child_count() > 0:
		texts.add_child(tags)
	else:
		tags.free()

	var starText: String = "Favourite"
	if bool(pref["favourite"]):
		starText = "Unstar"
	var hideText: String = "Hide"
	if bool(pref["hidden"]):
		hideText = "Unhide"
	row.setSwipeActions({"id": "favourite", "text": starText, "colour": Ui.colour("accent")}, {"id": "hide", "text": hideText, "colour": Ui.colour("textMuted")})
	row.tapped.connect(toggleExercise.bind(exerciseId))
	row.longPressed.connect(openExerciseMenu.bind(exerciseId))
	row.swiped.connect(_onExerciseSwiped.bind(exerciseId))
	row.set_meta("tick", tick)
	rowsById[exerciseId] = row
	_showTicked(row, selected.has(exerciseId))
	return row


func _showTicked(row: TapRow, ticked: bool) -> void:
	var tick: AppIcon = row.get_meta("tick")
	row.selected = ticked
	if ticked:
		tick.kind = "circleCheck"
		tick.colourKey = "accent"
	else:
		tick.kind = "circle"
		tick.colourKey = "textFaint"


### /// TICKING AND ADDING ///

func toggleExercise(exerciseId: String) -> void:
	if selected.has(exerciseId):
		selected.erase(exerciseId)
	else:
		selected.append(exerciseId)
	if rowsById.has(exerciseId):
		_showTicked(rowsById[exerciseId], selected.has(exerciseId))
	_updateBody()
	_updateAddButton()


func ghost() -> Dictionary:
	### WHAT THIS DOES
	# the preview heat: ticked exercises (exercises tab) or the tapped template (templates tab),
	# at least one set each so a "start at 0" setting still shows where they land

	var entries: Array = []
	if currentTab == "templates":
		var index: int = Storage.findTemplateIndex(previewTemplateId)
		if index >= 0:
			for entry in Storage.templates[index]["entries"]:
				entries.append({"exerciseId": entry["exerciseId"], "sets": maxi(int(entry["sets"]), 1), "grips": entry["grips"]})
	else:
		for exerciseId in selected:
			entries.append({"exerciseId": exerciseId, "sets": maxi(_startSets(), 1), "grips": bool(Storage.getPref(exerciseId)["grips"])})
	return HeatEngine.effectiveSets(entries, AppData.exerciseById)


func _updateBody() -> void:
	bodyCard.setHeat(HeatEngine.effectiveSets(_workoutEntries(), AppData.exerciseById), false)
	bodyCard.setGhost(ghost())


func _updateAddButton() -> void:
	var count: int = selected.size()
	var word: String = "exercises"
	if count == 1:
		word = "exercise"
	addButton.visible = currentTab == "exercises"
	addButton.disabled = count == 0
	if count == 0:
		addButton.text = "Tick exercises to add"
	elif not _hasWorkout():
		addButton.text = "Start workout with %d %s" % [count, word]
	else:
		addButton.text = "Add %d %s" % [count, word]


func addSelected() -> void:
	if selected.is_empty():
		return
	var entries: Array = []
	for exerciseId in selected:
		entries.append({"exerciseId": exerciseId, "sets": _startSets(), "grips": bool(Storage.getPref(exerciseId)["grips"])})
	var word: String = "exercises"
	if entries.size() == 1:
		word = "exercise"
	_deliver(entries, "Added %d %s" % [entries.size(), word])


func _deliver(entries: Array, message: String) -> void:
	### WHAT THIS DOES
	# into the workout this picker was opened from; from the week: into the running workout,
	# or a new one - then that workout opens in place of the picker

	if target != null and is_instance_valid(target):
		target.addEntries(entries)
		app.pop(true)
	else:
		Storage.addEntries(entries)
		app.replaceTop(WorkoutScreen.createLive())
	app.showToast(message)


### /// STAR AND HIDE ///

func setFavourite(exerciseId: String, on: bool) -> void:
	Storage.setFavourite(exerciseId, on)
	refreshList(true)


func setHidden(exerciseId: String, on: bool) -> void:
	Storage.setHidden(exerciseId, on)
	refreshList(true)
	if on:
		var exerciseName: String = str(AppData.getExercise(exerciseId).get("name", exerciseId))
		app.showToast("Hidden: %s" % exerciseName, "Undo", setHidden.bind(exerciseId, false))


func _onExerciseSwiped(actionId: String, exerciseId: String) -> void:
	var pref: Dictionary = Storage.getPref(exerciseId)
	if actionId == "favourite":
		setFavourite(exerciseId, not bool(pref["favourite"]))
	elif actionId == "hide":
		setHidden(exerciseId, not bool(pref["hidden"]))


func openExerciseMenu(exerciseId: String) -> BottomSheet:
	var exercise: Dictionary = AppData.getExercise(exerciseId)
	var pref: Dictionary = Storage.getPref(exerciseId)
	var starText: String = "Add to favourites"
	if bool(pref["favourite"]):
		starText = "Remove from favourites"
	var hideText: String = "Hide from lists"
	if bool(pref["hidden"]):
		hideText = "Show in lists again"
	var actions: Array = [["favourite", starText, "Button"], ["hide", hideText, "Button"]]
	return app.confirm(str(exercise.get("name", exerciseId)), Ui.exerciseMeta(exercise), actions, _onExerciseMenu.bind(exerciseId))


func _onExerciseMenu(actionId: String, exerciseId: String) -> void:
	_onExerciseSwiped(actionId, exerciseId)


### /// TEMPLATES ///

func refreshTemplates() -> void:
	Ui.clearChildren(templatesBox)
	if Storage.templates.is_empty():
		templatesBox.add_child(Ui.wrapLabel("No templates yet. Finish a workout and save it as a template, or swipe a workout right on the week's Workouts tab.", "MutedLabel"))
		return
	templatesBox.add_child(Ui.label("Tap to preview on the body · Apply adds its exercises", "FaintLabel"))
	for template in Storage.templates:
		templatesBox.add_child(_templateRow(template))


func _templateRow(template: Dictionary) -> TapRow:
	var templateId: String = template["id"]
	var entries: Array = template["entries"]
	var row := TapRow.new()
	var box: VBoxContainer = Ui.vbox(4)
	row.setContent(box)
	var top: HBoxContainer = Ui.hbox(6)
	box.add_child(top)
	var nameLabel: Label = Ui.wrapLabel(str(template["name"]), "BoldLabel")
	nameLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(nameLabel)
	var apply: Button = Ui.button("Apply", "AccentButton")
	apply.custom_minimum_size = Vector2(84.0, 48.0)
	apply.pressed.connect(applyTemplate.bind(templateId))
	top.add_child(apply)
	var more: Button = Ui.iconButton("more", "FlatButton", "textMuted")
	more.pressed.connect(openTemplateMenu.bind(templateId))
	top.add_child(more)
	var exerciseWord: String = "exercises"
	if entries.size() == 1:
		exerciseWord = "exercise"
	box.add_child(Ui.label("%d %s · %d sets" % [entries.size(), exerciseWord, Ui.setCount(entries)], "MutedLabel"))
	var names: Array = []
	for entry in entries:
		names.append(str(AppData.getExercise(entry["exerciseId"]).get("name", entry["exerciseId"])))
	box.add_child(Ui.wrapLabel(", ".join(names), "FaintLabel"))
	row.selected = templateId == previewTemplateId
	row.tapped.connect(previewTemplate.bind(templateId))
	row.longPressed.connect(openTemplateMenu.bind(templateId))
	row.set_meta("templateId", templateId)
	return row


func previewTemplate(templateId: String) -> void:
	if previewTemplateId == templateId:
		previewTemplateId = ""
	else:
		previewTemplateId = templateId
	for row in templatesBox.get_children():
		if row is TapRow:
			row.selected = str(row.get_meta("templateId", "")) == previewTemplateId
	_updateBody()


func applyTemplate(templateId: String) -> void:
	### WHAT THIS DOES
	# its exercises with their sets and grips - or at 0 sets (planned) when that setting is on

	var index: int = Storage.findTemplateIndex(templateId)
	if index < 0:
		return
	var template: Dictionary = Storage.templates[index]
	var entries: Array = []
	for entry in template["entries"]:
		var sets: int = int(entry["sets"])
		if _startSets() == 0:
			sets = 0
		entries.append({"exerciseId": entry["exerciseId"], "sets": sets, "grips": bool(entry["grips"])})
	_deliver(entries, "Added %s · %d exercises" % [str(template["name"]), entries.size()])


func openTemplateMenu(templateId: String) -> BottomSheet:
	var index: int = Storage.findTemplateIndex(templateId)
	if index < 0:
		return null
	var actions: Array = [["apply", "Apply to the workout", "Button"], ["rename", "Rename", "Button"], ["delete", "Delete template", "Button"]]
	return app.confirm(str(Storage.templates[index]["name"]), "", actions, _onTemplateMenu.bind(templateId))


func _onTemplateMenu(actionId: String, templateId: String) -> void:
	if actionId == "apply":
		applyTemplate(templateId)
	elif actionId == "rename":
		renameTemplate(templateId)
	elif actionId == "delete":
		deleteTemplate(templateId)


func renameTemplate(templateId: String) -> BottomSheet:
	var index: int = Storage.findTemplateIndex(templateId)
	if index < 0:
		return null
	var sheet: BottomSheet = app.askText("Rename template", "", str(Storage.templates[index]["name"]), "Template name", "Rename", Callable())
	sheet.onChoice = _onRenamed.bind(sheet, templateId)
	return sheet


func _onRenamed(actionId: String, sheet: BottomSheet, templateId: String) -> void:
	if actionId == "ok" and sheet.textValue() != "":
		Storage.renameTemplate(templateId, sheet.textValue())


func deleteTemplate(templateId: String) -> void:
	var removed: Dictionary = Storage.deleteTemplate(templateId)
	if removed.is_empty():
		return
	if previewTemplateId == templateId:
		previewTemplateId = ""
		_updateBody()
	app.showToast("Deleted template \"%s\"" % str(removed["name"]), "Undo", func() -> void: Storage.restoreTemplate(removed))


### /// FRAME ///

func _process(_delta: float) -> void:
	### WHAT THIS DOES
	# the list fills up a few rows per frame; the typed search lands after a short pause; on a phone
	# the body folds away while the keyboard is up so the list stays visible

	if shownCount < rowsWanted and shownCount < results.size():
		_appendRows(rowsPerFrame)
	if searchPending and Time.get_ticks_msec() / 1000.0 >= searchAt:
		searchPending = false
		refreshList()
	if OS.has_feature("mobile"):
		var keyboardUp: bool = DisplayServer.virtual_keyboard_get_height() > 0 and searchEdit.has_focus()
		var cardHolder: Control = bodyCard.get_parent()
		if cardHolder.visible == keyboardUp:
			cardHolder.visible = not keyboardUp
