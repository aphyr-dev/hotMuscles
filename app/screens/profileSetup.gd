class_name ProfileSetup
extends AppScreen
## ProfileSetup - first launch (and "run the setup again" from Settings): name, body, heat
## gradient, app theme - four big steps with a live body preview in the chosen gradient and theme
## what this offers
## - ProfileSetup.create(firstLaunch)
## - setNameText(text), chooseBody(body), chooseGradient(id), chooseTheme(id), next(), back(), finish()
## - step (0..3), nameValue, bodyValue, gradientValue, themeValue
## the whole screen wears the chosen theme while you pick (AppTheme.buildTheme, not applied app-wide
## until finish); finish saves the profile and opens the week (first launch) or goes back

### /// TUNING ///

# height of the preview body
const previewHeight: float = 300.0
# body thumbnails on the body step
const bodyChoiceHeight: float = 150.0
# the sample heat shown in the preview (effective sets, 0..previewRange spans the gradient)
const previewRange: float = 10.0
const previewHeat: Dictionary = {
	"lowerChest": 9.0, "upperChest": 6.0, "frontDelt": 8.0, "sideDelt": 4.0, "rearDelt": 3.0,
	"triceps": 7.0, "biceps": 6.0, "forearms": 2.0, "lats": 10.0, "midTraps": 5.0, "rhomboids": 5.0,
	"upperTraps": 3.5, "upperAbs": 3.0, "lowerAbs": 2.0, "obliques": 1.0, "midQuad": 4.5,
	"outerQuad": 3.5, "innerQuad": 2.5, "glutes": 2.0, "hamstrings": 1.5, "calves": 1.0,
}
# main button height
const mainButtonHeight: float = 58.0

const stepCount: int = 4

### /// STATE ///

var firstLaunch: bool = true
var step: int = 0
var nameValue: String = ""
var bodyValue: String = "male"
var gradientValue: String = "infrared"
var themeValue: String = "ember"
var previewBody: BodyView = null
var stepLabel: Label = null
var stepTitle: Label = null
var stepHint: Label = null
var optionsBox: VBoxContainer = null
var nameEdit: LineEdit = null
var nextButton: Button = null
var previousButton: Button = null
var optionRows: Dictionary = {}
var previewThemeId: String = ""


static func create(isFirstLaunch: bool) -> ProfileSetup:
	var made := ProfileSetup.new()
	made.firstLaunch = isFirstLaunch
	made.nameValue = str(Storage.profile["name"])
	made.bodyValue = str(Storage.profile["body"])
	made.gradientValue = str(Storage.profile["gradient"])
	made.themeValue = str(Storage.profile["theme"])
	return made


func _ready() -> void:
	_build()
	_showStep()


### /// BUILDING ///

func _build() -> void:
	### WHAT THIS DOES
	# step counter, the preview card, the question, its options, back / next

	var page := PanelContainer.new()
	page.theme_type_variation = "BackgroundPanel"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout: VBoxContainer = Ui.vbox(0)
	page.add_child(layout)

	var scroll := KineticScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var column: VBoxContainer = Ui.vbox(14)
	scroll.add_child(Ui.margin(column, pagePad + 4, 18, pagePad + 4, 16))

	stepLabel = Ui.label("", "MutedLabel")
	column.add_child(stepLabel)

	# live preview
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	column.add_child(card)
	previewBody = BodyView.new()
	previewBody.interactive = false
	previewBody.viewMode = "both"
	previewBody.rangeMax = previewRange
	previewBody.custom_minimum_size = Vector2(0.0, previewHeight)
	card.add_child(previewBody)

	stepTitle = Ui.wrapLabel("", "HeaderLabel")
	column.add_child(stepTitle)
	stepHint = Ui.wrapLabel("", "MutedLabel")
	column.add_child(stepHint)
	optionsBox = Ui.vbox(10)
	column.add_child(optionsBox)

	# back / next
	var buttons: HBoxContainer = Ui.hbox(10)
	layout.add_child(Ui.margin(buttons, pagePad, 8, pagePad, 12))
	previousButton = Ui.button("Back", "FlatButton", back)
	previousButton.custom_minimum_size = Vector2(100.0, mainButtonHeight)
	buttons.add_child(previousButton)
	nextButton = Ui.button("Next", "AccentButton", next)
	nextButton.custom_minimum_size.y = mainButtonHeight
	nextButton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(nextButton)


func rebuild() -> void:
	_showStep()


### /// STEPS ///

func _showStep() -> void:
	### WHAT THIS DOES
	# fills the question and options for the current step and refreshes the preview

	Ui.clearChildren(optionsBox)
	optionRows = {}
	nameEdit = null
	stepLabel.text = "Step %d of %d" % [step + 1, stepCount]
	if not firstLaunch:
		stepLabel.text = "Profile setup · step %d of %d" % [step + 1, stepCount]

	if step == 0:
		stepTitle.text = "Hi! What should we call you?"
		stepHint.text = "It shows on the week screen. Everything here can be changed later in Settings."
		nameEdit = LineEdit.new()
		nameEdit.text = nameValue
		nameEdit.placeholder_text = "Your name"
		nameEdit.custom_minimum_size.y = 56.0
		nameEdit.add_theme_font_size_override("font_size", 20)
		nameEdit.text_changed.connect(setNameText)
		nameEdit.text_submitted.connect(_onNameSubmitted)
		optionsBox.add_child(nameEdit)
	elif step == 1:
		stepTitle.text = "Which body should we draw?"
		stepHint.text = "Used on every heat map in the app."
		var pair: HBoxContainer = Ui.hbox(10)
		optionsBox.add_child(pair)
		for bodyName in ["male", "female"]:
			pair.add_child(_bodyOption(bodyName))
	elif step == 2:
		stepTitle.text = "Pick your heat colours"
		stepHint.text = "How sets show on the body, from none to a lot."
		for gradientId in HeatGradients.presetIds():
			optionsBox.add_child(_gradientOption(gradientId))
	else:
		stepTitle.text = "Pick an app theme"
		stepHint.text = "Colours for the whole app - the screen shows it as you pick."
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		optionsBox.add_child(grid)
		for themeId in AppTheme.themeIds():
			grid.add_child(_themeOption(themeId))

	previousButton.visible = step > 0 or not firstLaunch
	if step == 0:
		previousButton.text = "Cancel"
	else:
		previousButton.text = "Back"
	if step == stepCount - 1:
		nextButton.text = "Let's go"
	else:
		nextButton.text = "Next"
	_applyPreview()


func _applyPreview() -> void:
	# the screen's own theme is only rebuilt when the pick changed (re-theming lays out every control)
	if themeValue != previewThemeId:
		previewThemeId = themeValue
		theme = AppTheme.buildTheme(themeValue)
	previewBody.body = bodyValue
	previewBody.gradientId = gradientValue
	previewBody.setHeat(previewHeat, false)
	nextButton.disabled = step == 0 and nameValue.strip_edges() == ""
	var chosen: String = themeValue
	if step == 1:
		chosen = bodyValue
	elif step == 2:
		chosen = gradientValue
	for optionId in optionRows:
		var row: TapRow = optionRows[optionId]
		row.selected = optionId == chosen


func _bodyOption(bodyName: String) -> TapRow:
	var row := TapRow.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = Ui.vbox(6)
	row.setContent(box)
	var thumb := BodyView.new()
	thumb.interactive = false
	thumb.viewMode = "front"
	thumb.body = bodyName
	thumb.gradientId = gradientValue
	thumb.custom_minimum_size = Vector2(0.0, bodyChoiceHeight)
	box.add_child(thumb)
	# the same sample heat as the big preview - an empty body draws as a dark blot
	thumb.setHeat(previewHeat, false)
	var caption: Label = Ui.label(bodyName.capitalize(), "BoldLabel")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	row.tapped.connect(chooseBody.bind(bodyName))
	optionRows[bodyName] = row
	return row


func _gradientOption(gradientId: String) -> TapRow:
	var row := TapRow.new()
	var box: VBoxContainer = Ui.vbox(8)
	row.setContent(box)
	box.add_child(Ui.label(HeatGradients.presetName(gradientId), "BoldLabel"))
	var bar := GradientBar.new()
	bar.gradientId = gradientId
	bar.barHeight = 14.0
	box.add_child(bar)
	row.tapped.connect(chooseGradient.bind(gradientId))
	optionRows[gradientId] = row
	return row


func _themeOption(themeId: String) -> TapRow:
	# each option wears its own theme, so it is its own swatch
	var palette: Dictionary = AppTheme.paletteOf(themeId)
	var row := TapRow.new()
	row.theme = AppTheme.buildTheme(themeId)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = Ui.vbox(8)
	row.setContent(box)
	box.add_child(Ui.label(AppTheme.themeName(themeId), "BoldLabel"))
	var swatches: HBoxContainer = Ui.hbox(6)
	box.add_child(swatches)
	for key in ["bg", "accent", "text"]:
		var swatch := ColorRect.new()
		swatch.color = palette[key]
		swatch.custom_minimum_size = Vector2(28.0, 18.0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatches.add_child(swatch)
	row.tapped.connect(chooseTheme.bind(themeId))
	optionRows[themeId] = row
	return row


### /// CHOICES ///

func setNameText(text: String) -> void:
	nameValue = text
	if nameEdit != null and nameEdit.text != text:
		nameEdit.text = text
	nextButton.disabled = step == 0 and nameValue.strip_edges() == ""


func _onNameSubmitted(_text: String) -> void:
	if nameValue.strip_edges() != "":
		next()


func chooseBody(bodyName: String) -> void:
	bodyValue = bodyName
	_applyPreview()


func chooseGradient(gradientId: String) -> void:
	gradientValue = gradientId
	_applyPreview()


func chooseTheme(themeId: String) -> void:
	themeValue = themeId
	_applyPreview()


func next() -> void:
	if step == 0 and nameValue.strip_edges() == "":
		return
	if nameEdit != null and nameEdit.has_focus():
		nameEdit.release_focus()
	if step >= stepCount - 1:
		finish()
		return
	step += 1
	_showStep()


func back() -> void:
	if step == 0:
		if not firstLaunch:
			app.pop(true)
		return
	step -= 1
	_showStep()


func onBack() -> bool:
	if step > 0:
		back()
		return true
	return false


func finish() -> void:
	### WHAT THIS DOES
	# saves the profile (the theme goes app-wide now), then the week

	Storage.setProfileValues({"name": nameValue.strip_edges(), "body": bodyValue, "gradient": gradientValue, "setupDone": true, "theme": themeValue})
	if firstLaunch:
		app.resetTo(WeekScreen.new())
	else:
		app.pop(true)
