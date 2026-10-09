class_name TargetEditor
extends AppScreen
## TargetEditor - make or change your own target preset
## what this offers
## - TargetEditor.create({id ("" = new), name, offsets {regionId: sets}, cardio {lightId: minutes}})
## - setName(text), setOffset(regionId, value), changeOffset(regionId, delta) (-12..+10 from the
##   baseline), setCardio(lightId, minutes), changeCardio(lightId, delta) (steps of cardioStep)
## - a preview body with the target this preset alone gives (baseline + offset per muscle)
## - save() stores it (a new one is switched on at once) and goes back; deleteTarget() (existing
##   ones) removes it with an undo; back with unsaved changes asks first
## - draft holds the values being edited, dirty says whether they changed

### /// TUNING ///

# the preview body's tallest height
const bodyMaxHeight: float = 240.0
# cardio minutes per stepper press, and the most a week
const cardioStep: int = 10
const cardioMax: int = 1500
# stepper number width
const numberWidth: float = 44.0

### /// STATE ///

var draft: Dictionary = {}
var dirty: bool = false
var bodyCard: BodyCard = null
var nameEdit: LineEdit = null
var offsetLabels: Dictionary = {}
var resultLabels: Dictionary = {}
var cardioLabels: Dictionary = {}
var saveButton: Button = null


static func create(source: Dictionary) -> TargetEditor:
	var made := TargetEditor.new()
	made.draft = source.duplicate(true)
	for regionId in AppData.regionIds:
		if not made.draft["offsets"].has(regionId):
			made.draft["offsets"][regionId] = 0
	for light in AppData.cardioLights:
		if not made.draft["cardio"].has(light["id"]):
			made.draft["cardio"][light["id"]] = int(AppData.cardioDefaultTarget.get(light["id"], 0))
	return made


func isNew() -> bool:
	return str(draft.get("id", "")) == ""


func _ready() -> void:
	_build()
	_refresh()


### /// BUILDING ///

func _build() -> void:
	### WHAT THIS DOES
	# name, preview body, one card per muscle group with a stepper per muscle, the cardio card,
	# Save (and Delete for an existing one)

	var title: String = "Edit target"
	if isNew():
		title = "New target"
	var frame: Dictionary = buildFrame(title, "Targets")
	var scroll: KineticScroll = makeScroll(frame["content"])
	var column: VBoxContainer = scroll.get_meta("column")

	# name + preview
	column.add_child(Ui.label("Name", "MutedLabel"))
	nameEdit = LineEdit.new()
	nameEdit.text = str(draft["name"])
	nameEdit.max_length = Targets.nameMaxLength
	nameEdit.custom_minimum_size.y = 50.0
	nameEdit.text_changed.connect(setName)
	column.add_child(nameEdit)
	column.add_child(Ui.wrapLabel("Each number adds to (or takes from) your weekly baseline of %d sets - the home slider - for that muscle." % int(Targets.baseline()), "FaintLabel"))
	bodyCard = BodyCard.new()
	column.add_child(bodyCard)
	bodyCard.configure("This target", bodyMaxHeight, "", false, "")

	# a card per muscle group
	for group in AppData.groups:
		var box: VBoxContainer = _card(column, str(group["name"]))
		for region in AppData.regions:
			if region["group"] == group["id"]:
				box.add_child(_offsetRow(region))

	# cardio
	var cardioBox: VBoxContainer = _card(column, "Cardio a week")
	for light in AppData.cardioLights:
		cardioBox.add_child(_cardioRow(light))

	# save / delete
	saveButton = Ui.button("Save target", "AccentButton", save)
	saveButton.custom_minimum_size.y = 56.0
	frame["bottom"].add_child(saveButton)
	if not isNew():
		var deleteButton: Button = Ui.button("Delete target", "FlatButton", deleteTarget)
		frame["bottom"].add_child(deleteButton)


func _card(column: VBoxContainer, title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	column.add_child(card)
	var box: VBoxContainer = Ui.vbox(6)
	card.add_child(box)
	box.add_child(Ui.label(title, "TitleLabel"))
	return box


func _offsetRow(region: Dictionary) -> HBoxContainer:
	# name, "= 15 sets", and the - n + stepper
	var regionId: String = region["id"]
	var row: HBoxContainer = Ui.hbox(6)
	var texts: VBoxContainer = Ui.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	texts.add_child(Ui.label(str(region["name"]), "BoldLabel"))
	var result: Label = Ui.label("", "FaintLabel")
	texts.add_child(result)
	resultLabels[regionId] = result
	offsetLabels[regionId] = _stepper(row, changeOffset.bind(regionId, -1), changeOffset.bind(regionId, 1))
	return row


func _cardioRow(light: Dictionary) -> HBoxContainer:
	var lightId: String = light["id"]
	var row: HBoxContainer = Ui.hbox(6)
	var texts: VBoxContainer = Ui.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	texts.add_child(Ui.label(str(light["name"]), "BoldLabel"))
	texts.add_child(Ui.label("minutes a week", "FaintLabel"))
	cardioLabels[lightId] = _stepper(row, changeCardio.bind(lightId, -cardioStep), changeCardio.bind(lightId, cardioStep))
	return row


func _stepper(row: HBoxContainer, onMinus: Callable, onPlus: Callable) -> Label:
	var minus: Button = Ui.iconButton("minus", "Button", "text")
	minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	minus.pressed.connect(onMinus)
	row.add_child(minus)
	var number: Label = Ui.label("0", "BoldLabel")
	number.custom_minimum_size.x = numberWidth
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	var plus: Button = Ui.iconButton("plus", "Button", "text")
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.pressed.connect(onPlus)
	row.add_child(plus)
	return number


### /// EDITING ///

func setName(text: String) -> void:
	draft["name"] = text
	_markDirty()


func setOffset(regionId: String, value: int) -> void:
	draft["offsets"][regionId] = clampi(value, Storage.offsetMin, Storage.offsetMax)
	_markDirty()
	_refresh()


func changeOffset(regionId: String, delta: int) -> void:
	setOffset(regionId, int(draft["offsets"].get(regionId, 0)) + delta)


func setCardio(lightId: String, minutes: int) -> void:
	draft["cardio"][lightId] = clampi(minutes, 0, cardioMax)
	_markDirty()
	_refresh()


func changeCardio(lightId: String, delta: int) -> void:
	setCardio(lightId, int(draft["cardio"].get(lightId, 0)) + delta)


func _markDirty() -> void:
	dirty = true


func _refresh() -> void:
	### WHAT THIS DOES
	# every stepper number, each muscle's resulting sets, and the preview body

	var baseline: float = Targets.baseline()
	var targets: Dictionary = HeatEngine.regionTargets([draft], baseline)
	var biggest: float = 1.0

	for regionId in offsetLabels:
		var offset: int = int(draft["offsets"].get(regionId, 0))
		offsetLabels[regionId].text = "%+d" % offset
		if offset == 0:
			offsetLabels[regionId].text = "0"
		resultLabels[regionId].text = "= %s sets a week" % Ui.formatSets(float(targets.get(regionId, 0.0)))
		biggest = maxf(biggest, float(targets.get(regionId, 0.0)))
	for lightId in cardioLabels:
		cardioLabels[lightId].text = str(int(draft["cardio"].get(lightId, 0)))
	bodyCard.bodyView.rangeMax = biggest
	bodyCard.setHeat(targets, true)
	bodyCard.setHint("Hottest = biggest target (%s sets a week)" % Ui.formatSets(biggest))


### /// SAVE AND LEAVE ///

func save() -> void:
	var wasNew: bool = isNew()
	var saved: Dictionary = Targets.saveCustom(draft)
	if wasNew:
		Targets.toggle(str(saved["id"]))
	dirty = false
	app.pop(true)
	app.showToast("Saved \"%s\"" % str(saved["name"]))


func deleteTarget() -> void:
	var presetId: String = str(draft["id"])
	var wasActive: bool = Targets.isActive(presetId)
	var removed: Dictionary = Targets.deleteCustom(presetId)
	dirty = false
	app.pop(true)
	if not removed.is_empty():
		app.showToast("Deleted \"%s\"" % str(removed["name"]), "Undo", func() -> void: Targets.restoreCustom(removed, wasActive))


func onBack() -> bool:
	if not dirty:
		return false
	var actions: Array = [["save", "Save target", "AccentButton"], ["discard", "Discard changes", "Button"], ["keep", "Keep editing", "FlatButton"]]
	app.confirm("Unsaved changes", "Save this target?", actions, _onLeaveChoice)
	return true


func _onLeaveChoice(actionId: String) -> void:
	if actionId == "save":
		save()
	elif actionId == "discard":
		dirty = false
		app.pop(true)
