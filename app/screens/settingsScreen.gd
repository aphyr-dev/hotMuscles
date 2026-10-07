class_name SettingsScreen
extends AppScreen
## SettingsScreen - profile, how the week is coloured, workout defaults, backup
## what this offers (every change saves at once and the other screens follow)
## - profile: setName(text), setBody("male"/"female"), setTheme(id), redoSetup()
## - heat map: setGradient(id), setHideUntouched(on)
## - workouts: setNewExerciseSets(0 / 1), setDefaultView("front"/"back"/"both")
## - backup: exportBackup(copyToClipboard) -> {text, path} (clipboard + user://backups),
##   importFromClipboard() / askImport(text) -> confirm sheet -> importNow(text) -> {ok, error}
##   (the current data is saved as a backup file first)

### /// TUNING ///

# gap between the rows inside a section card
const rowGap: int = 10

var nameEdit: LineEdit = null
var bodyChoice: Segmented = null
var themeChoice: Segmented = null
var gradientChoice: Segmented = null
var gradientBar: GradientBar = null
var untouchedChoice: Segmented = null
var startChoice: Segmented = null
var viewChoice: Segmented = null
var column: VBoxContainer = null
var scroll: KineticScroll = null


func _ready() -> void:
	_build()
	Storage.changed.connect(_onStorageChanged)


### /// BUILDING ///

func _build() -> void:
	var frame: Dictionary = buildFrame("Settings", "Week")
	frame["bottom"].get_parent().visible = false
	scroll = makeScroll(frame["content"])
	column = scroll.get_meta("column")
	_fill()


func _fill() -> void:
	### WHAT THIS DOES
	# one card per topic: profile, heat map, workouts, backup

	Ui.clearChildren(column)

	# profile
	var profileBox: VBoxContainer = _section("Profile")
	profileBox.add_child(Ui.label("Name", "MutedLabel"))
	nameEdit = LineEdit.new()
	nameEdit.text = str(Storage.profile["name"])
	nameEdit.placeholder_text = "Your name"
	nameEdit.custom_minimum_size.y = 50.0
	nameEdit.text_changed.connect(setName)
	profileBox.add_child(nameEdit)
	profileBox.add_child(Ui.label("Body drawing", "MutedLabel"))
	bodyChoice = _choice(profileBox, [["male", "Male"], ["female", "Female"]], str(Storage.profile["body"]), setBody)
	profileBox.add_child(Ui.label("App theme", "MutedLabel"))
	var themes: Array = []
	for themeId in AppTheme.themeIds():
		themes.append([themeId, AppTheme.themeName(themeId)])
	themeChoice = _choice(profileBox, themes, str(Storage.profile["theme"]), setTheme)
	var redo: Button = Ui.button("Run the first-launch setup again", "FlatButton", redoSetup)
	redo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	profileBox.add_child(redo)

	# heat map
	var heatBox: VBoxContainer = _section("Heat map")
	heatBox.add_child(Ui.label("Heat gradient", "MutedLabel"))
	var gradients: Array = []
	for gradientId in HeatGradients.presetIds():
		gradients.append([gradientId, HeatGradients.presetName(gradientId)])
	gradientChoice = _choice(heatBox, gradients, str(Storage.profile["gradient"]), setGradient)
	gradientBar = GradientBar.new()
	gradientBar.gradientId = str(Storage.profile["gradient"])
	heatBox.add_child(gradientBar)
	heatBox.add_child(Ui.label("Muscles with no sets", "MutedLabel"))
	var untouched: String = "show"
	if bool(Storage.settings["hideUntouched"]):
		untouched = "hide"
	untouchedChoice = _choice(heatBox, [["show", "Colour them"], ["hide", "Leave plain"]], untouched, _onUntouchedPicked)

	# workouts
	var workoutBox: VBoxContainer = _section("Workouts")
	workoutBox.add_child(Ui.label("New exercises start at", "MutedLabel"))
	startChoice = _choice(workoutBox, [["0", "0 sets (planned)"], ["1", "1 set"]], str(int(Storage.settings["newExerciseSets"])), _onStartPicked)
	workoutBox.add_child(Ui.label("Body view when the app opens", "MutedLabel"))
	viewChoice = _choice(workoutBox, [["front", "Front"], ["back", "Back"], ["both", "Both"]], str(Storage.settings["defaultView"]), setDefaultView)

	# backup
	var backupBox: VBoxContainer = _section("Backup")
	backupBox.add_child(Ui.wrapLabel("Export copies everything (profile, workouts, templates, favourites) to the clipboard as text and also saves it in the app's backups folder. Paste it somewhere safe. Import reads a backup from the clipboard and replaces what is here.", "FaintLabel"))
	var exportButton: Button = Ui.button("Export backup", "Button", _onExportPressed)
	backupBox.add_child(exportButton)
	var importButton: Button = Ui.button("Import from clipboard", "Button", importFromClipboard)
	backupBox.add_child(importButton)


func _section(title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	column.add_child(card)
	var box: VBoxContainer = Ui.vbox(rowGap)
	card.add_child(box)
	box.add_child(Ui.label(title, "TitleLabel"))
	return box


func _choice(parent: VBoxContainer, options: Array, selectedId: String, handler: Callable) -> Segmented:
	var choice := Segmented.new()
	choice.fillWidth = true
	parent.add_child(choice)
	choice.setOptions(options, selectedId)
	choice.changed.connect(handler)
	return choice


func rebuild() -> void:
	_fill()


func _onStorageChanged(section: String) -> void:
	# an import replaces everything - show the new values
	if section == "all" and is_inside_tree():
		_fill()


### /// PROFILE ///

func setName(text: String) -> void:
	Storage.setProfile("name", text.strip_edges())


func setBody(bodyName: String) -> void:
	bodyChoice.select(bodyName, false)
	Storage.setProfile("body", bodyName)


func setTheme(themeId: String) -> void:
	# the whole app re-themes at once (AppTheme follows the profile; screens rebuild)
	Storage.setProfile("theme", themeId)


func redoSetup() -> ProfileSetup:
	return app.openProfileSetup(false)


### /// HEAT MAP ///

func setGradient(gradientId: String) -> void:
	gradientChoice.select(gradientId, false)
	gradientBar.gradientId = gradientId
	Storage.setProfile("gradient", gradientId)


func setHideUntouched(on: bool) -> void:
	var choiceId: String = "show"
	if on:
		choiceId = "hide"
	untouchedChoice.select(choiceId, false)
	Storage.setSetting("hideUntouched", on)


func _onUntouchedPicked(choiceId: String) -> void:
	setHideUntouched(choiceId == "hide")


### /// WORKOUTS ///

func setNewExerciseSets(sets: int) -> void:
	startChoice.select(str(sets), false)
	Storage.setSetting("newExerciseSets", sets)


func _onStartPicked(choiceId: String) -> void:
	setNewExerciseSets(int(choiceId))


func setDefaultView(view: String) -> void:
	viewChoice.select(view, false)
	Storage.setSetting("defaultView", view)


### /// BACKUP ///

func exportBackup(copyToClipboard: bool = true) -> Dictionary:
	# checks pass false so they never touch the real clipboard
	return Storage.exportBackup(copyToClipboard)


func _onExportPressed() -> void:
	var result: Dictionary = exportBackup()
	if str(result["path"]) == "":
		app.showToast("Copied to the clipboard (the backup file could not be written)")
		return
	app.showToast("Backup copied to the clipboard and saved as %s" % str(result["path"]).get_file())


func importFromClipboard() -> BottomSheet:
	return askImport(DisplayServer.clipboard_get())


func askImport(text: String) -> BottomSheet:
	### WHAT THIS DOES
	# checks the text looks like a backup and says what is in it before replacing anything

	# parsed quietly (JSON.parse_string prints an engine error for any non-JSON clipboard)
	var reader := JSON.new()
	var parsed: Variant = null
	if reader.parse(text.strip_edges()) == OK:
		parsed = reader.data
	if not Storage.isBackup(parsed):
		app.showToast("The clipboard does not hold a hotMuscles backup")
		return null
	var workoutCount: int = 0
	var workoutsPart: Variant = parsed.get("workouts", {})
	if typeof(workoutsPart) == TYPE_DICTIONARY and typeof(workoutsPart.get("submitted")) == TYPE_ARRAY:
		workoutCount = workoutsPart["submitted"].size()
	var templateCount: int = 0
	if typeof(parsed.get("templates")) == TYPE_ARRAY:
		templateCount = parsed["templates"].size()
	var message: String = "Exported %s · %d workouts · %d templates.\nEverything here now is replaced (it is saved as a backup file first)." % [str(parsed.get("exportedAt", "?")), workoutCount, templateCount]
	var actions: Array = [["import", "Replace my data", "AccentButton"], ["cancel", "Cancel", "FlatButton"]]
	var sheet: BottomSheet = app.confirm("Import this backup?", message, actions, Callable())
	sheet.onChoice = _onImportChoice.bind(text)
	return sheet


func _onImportChoice(actionId: String, text: String) -> void:
	if actionId == "import":
		importNow(text)


func importNow(text: String) -> Dictionary:
	Storage.exportBackup(false)
	var result: Dictionary = Storage.importBackupText(text)
	if bool(result["ok"]):
		app.showToast("Backup imported")
	else:
		app.showToast(str(result["error"]))
	return result
