class_name TargetsScreen
extends AppScreen
## TargetsScreen - the target presets: switch any mix on, see the combined targets on a body, make your own
## what this offers
## - sections Sports, Physique, Yours; tap a row = toggle(presetId) (on rows get a tick and an outline)
## - hold a row (or its "..." button) = openMenu(presetId): copy any preset into your own; edit and
##   delete your own (deletePreset(presetId), undo on the toast)
## - "+ New target" / copyPreset(presetId) / editPreset(presetId) open the TargetEditor
## - the preview body: the combined target per muscle (the highest of the presets that are on), the
##   hottest muscle = the biggest target; the line under it gives the weekly cardio target
## - rows (presetId -> TapRow) for checks

### /// TUNING ///

# the preview body's tallest height
const bodyMaxHeight: float = 300.0
# key exercises named on a researched preset's row
const keyNamesShown: int = 4
const sectionTitles: Dictionary = {"sport": "Sports", "physique": "Physique", "custom": "Yours"}
# rows made in the frame the screen opens, then per frame after that (all at once cost a ~50 ms frame)
const firstRows: int = 4
const rowsPerFrame: int = 3
# the "..." menu button's touch size
const moreButtonSize: float = 56.0

### /// STATE ///

var scroll: KineticScroll = null
var column: VBoxContainer = null
var bodyCard: BodyCard = null
var listBox: VBoxContainer = null
var rows: Dictionary = {}
var rowsKey: String = ""
var rowPlan: Array = []


func _ready() -> void:
	_build()
	Storage.changed.connect(_onStorageChanged)
	refresh()


func _build() -> void:
	var frame: Dictionary = buildFrame("Targets", "Back")
	scroll = makeScroll(frame["content"])
	column = scroll.get_meta("column")

	column.add_child(Ui.wrapLabel("Pick one or more. Each muscle's weekly target = your %d-set baseline (the home slider) plus the preset's change. If several are on, the highest wins." % int(Targets.baseline()), "MutedLabel"))
	bodyCard = BodyCard.new()
	column.add_child(bodyCard)
	bodyCard.configure("Your targets", bodyMaxHeight, "", false, "")
	listBox = Ui.vbox(10)
	column.add_child(listBox)

	var newButton: Button = Ui.button("+  New target", "AccentButton", newTarget)
	newButton.custom_minimum_size.y = 56.0
	frame["bottom"].add_child(newButton)


func rebuild() -> void:
	# a new theme: rows carry theme colours, so they are all made again
	rowsKey = ""
	refresh()


func onShown() -> void:
	refresh()


func _onStorageChanged(section: String) -> void:
	# deferred: the change usually comes from a row's own tap, and refresh remakes the rows
	if (section == "settings" or section == "all") and is_inside_tree():
		call_deferred("refresh")


### /// FILLING ///

func refresh() -> void:
	### WHAT THIS DOES
	# the preview body and its line; the rows are only made again when the presets themselves changed
	# (a toggle just moves the ticks)

	_refreshPreview()
	var key: String = JSON.stringify(Targets.allPresets())
	if key == rowsKey:
		for presetId in rows:
			_showActive(rows[presetId], Targets.isActive(presetId))
		return
	rowsKey = key
	_planRows()
	_placeRows(firstRows)


func _refreshPreview() -> void:
	# the combined targets on the body, hottest = the biggest

	var targets: Dictionary = Targets.regionTargets()
	var biggest: float = 1.0

	for regionId in targets:
		biggest = maxf(biggest, float(targets[regionId]))
	bodyCard.bodyView.rangeMax = biggest
	bodyCard.setHeat(targets, true)
	if targets.is_empty():
		bodyCard.setTitle("Your targets")
		bodyCard.setHint("Nothing switched on - tap a preset below")
	else:
		var cardio: Dictionary = Targets.cardioTargets()
		var names: Array = []
		for preset in Targets.activePresets():
			names.append(str(preset["name"]))
		bodyCard.setTitle(", ".join(names))
		bodyCard.setHint("Colour = size of target (biggest %s sets a week) · cardio %d easy + %d hard min a week" % [Ui.formatSets(biggest), int(cardio.get("easyCardio", 0)), int(cardio.get("hardCardio", 0))])


func _planRows() -> void:
	# what the list holds, in order: a title per section, its rows (or a line saying it is empty)
	Ui.clearChildren(listBox)
	rows = {}
	rowPlan = []
	for kind in ["sport", "physique", "custom"]:
		var presets: Array = []
		for preset in Targets.allPresets():
			if preset["kind"] == kind:
				presets.append(preset)
		rowPlan.append({"title": sectionTitles[kind]})
		if presets.is_empty():
			rowPlan.append({"empty": true})
		for preset in presets:
			rowPlan.append({"preset": preset})


func _placeRows(limit: int) -> void:
	# makes the next planned rows, at most `limit` preset rows (titles are cheap and come free)
	var made: int = 0
	while rowPlan.size() > 0 and made < limit:
		var item: Dictionary = rowPlan.pop_front()
		if item.has("title"):
			listBox.add_child(Ui.label(item["title"], "TitleLabel"))
		elif item.has("empty"):
			listBox.add_child(Ui.wrapLabel("None yet. Make one with + New target, or hold a preset above to copy it.", "FaintLabel"))
		else:
			var row: TapRow = _presetRow(item["preset"])
			listBox.add_child(row)
			rows[item["preset"]["id"]] = row
			made += 1


func _process(_delta: float) -> void:
	if rowPlan.size() > 0:
		_placeRows(rowsPerFrame)


func _presetRow(preset: Dictionary) -> TapRow:
	### WHAT THIS DOES
	# tick, name, the one-line summary, and on researched presets the first key exercises

	var presetId: String = preset["id"]
	var active: bool = Targets.isActive(presetId)
	var row := TapRow.new()
	var line: HBoxContainer = Ui.hbox(12)
	row.setContent(line)

	var tick := AppIcon.new()
	tick.iconSize = 26.0
	tick.custom_minimum_size = Vector2(26.0, 26.0)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tick)
	row.set_meta("tick", tick)

	var texts: VBoxContainer = Ui.vbox(3)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(texts)
	texts.add_child(Ui.wrapLabel(str(preset["name"]), "BoldLabel"))
	if str(preset["summary"]) != "":
		texts.add_child(Ui.wrapLabel(str(preset["summary"]), "MutedLabel"))
	else:
		texts.add_child(Ui.wrapLabel(_offsetSummary(preset), "MutedLabel"))
	var keys: Array = []
	for exerciseId in preset["keyExercises"]:
		if keys.size() >= keyNamesShown:
			break
		keys.append(str(AppData.getExercise(exerciseId).get("name", exerciseId)))
	if keys.size() > 0:
		# one line, trimmed: the row stays short however long the names are
		var keyLine: Label = Ui.label("Key: %s" % ", ".join(keys), "FaintLabel")
		keyLine.clip_text = true
		keyLine.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		keyLine.custom_minimum_size.x = 40.0
		keyLine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(keyLine)

	var more: Button = Ui.iconButton("more", "FlatButton", "textMuted")
	more.custom_minimum_size = Vector2(moreButtonSize, moreButtonSize)
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	more.pressed.connect(openMenu.bind(presetId))
	line.add_child(more)

	_showActive(row, active)
	row.tapped.connect(toggle.bind(presetId))
	row.longPressed.connect(openMenu.bind(presetId))
	return row


func _showActive(row: TapRow, active: bool) -> void:
	var tick: AppIcon = row.get_meta("tick")
	row.selected = active
	if active:
		tick.kind = "circleCheck"
		tick.colourKey = "accent"
	else:
		tick.kind = "circle"
		tick.colourKey = "textMuted"


func _offsetSummary(preset: Dictionary) -> String:
	# a custom target's biggest pushes, e.g. "+6 glutes, +4 lats, -4 biceps"
	var offsets: Dictionary = preset["offsets"]
	var ids: Array = []
	for regionId in offsets:
		if int(offsets[regionId]) != 0:
			ids.append(regionId)
	ids.sort_custom(func(a: String, b: String) -> bool: return absi(int(offsets[a])) > absi(int(offsets[b])))
	var parts: Array = []
	for regionId in ids.slice(0, 3):
		parts.append("%+d %s" % [int(offsets[regionId]), AppData.regionName(regionId).to_lower()])
	if parts.is_empty():
		return "Your baseline on every muscle"
	return ", ".join(parts)


### /// ACTIONS ///

func toggle(presetId: String) -> void:
	Targets.toggle(presetId)


func openMenu(presetId: String) -> BottomSheet:
	var preset: Dictionary = Targets.getPreset(presetId)
	var actions: Array = [["copy", "Copy into my own", "Button"]]
	if Targets.isCustom(presetId):
		actions = [["edit", "Edit", "Button"], ["copy", "Copy", "Button"], ["delete", "Delete", "Button"]]
	return app.confirm(str(preset.get("name", presetId)), str(preset.get("summary", "")), actions, _onMenu.bind(presetId))


func _onMenu(actionId: String, presetId: String) -> void:
	if actionId == "edit":
		editPreset(presetId)
	elif actionId == "copy":
		copyPreset(presetId)
	elif actionId == "delete":
		deletePreset(presetId)


func newTarget() -> TargetEditor:
	var offsets: Dictionary = {}
	for regionId in AppData.regionIds:
		offsets[regionId] = 0
	return app.openTargetEditor({"id": "", "name": Targets.newTargetName, "offsets": offsets, "cardio": AppData.cardioDefaultTarget.duplicate()})


func copyPreset(presetId: String) -> TargetEditor:
	var preset: Dictionary = Targets.getPreset(presetId)
	return app.openTargetEditor({"id": "", "name": "%s (mine)" % str(preset["name"]), "offsets": preset["offsets"].duplicate(), "cardio": preset["cardio"].duplicate()})


func editPreset(presetId: String) -> TargetEditor:
	var preset: Dictionary = Targets.getPreset(presetId)
	return app.openTargetEditor({"id": presetId, "name": preset["name"], "offsets": preset["offsets"].duplicate(), "cardio": preset["cardio"].duplicate()})


func deletePreset(presetId: String) -> void:
	var wasActive: bool = Targets.isActive(presetId)
	var removed: Dictionary = Targets.deleteCustom(presetId)
	if removed.is_empty():
		return
	app.showToast("Deleted \"%s\"" % str(removed["name"]), "Undo", func() -> void: Targets.restoreCustom(removed, wasActive))
