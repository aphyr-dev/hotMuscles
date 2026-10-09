class_name BodyCard
extends VBoxContainer
## BodyCard - the card around a BodyView: title, Front | Back | Both chips, the body, the 0-N
## slider and a hint line
## what this offers
## - configure(title, maxBodyHeight, rangeKey, showSlider, hint)
##     rangeKey: the Storage setting that remembers N for this card ("rangeWeek" / "rangeWorkout");
##     the slider writes it back when moved
## - bodyView (the BodyView), slider (HeatRangeSlider or null), viewChips (Segmented)
## - setHeat(heat, animate), setGhost(ghost), setGradient(id), setBody(body),
##   setView(view), setHideUntouched(hide), setHint(text), setTitle(text)
## - addFooterChip(text) -> a toggle chip under the slider, the hint line beside it
## - setRangeKey(key)   the slider now shows and writes a different Storage setting
## - the body is edge to edge in the card; its height fits the figures to the card width
##   (so "both" fills the width) and never passes maxBodyHeight
## signals: regionTapped(regionId), emptyTapped(), viewChanged(view)

signal regionTapped(regionId: String)
signal emptyTapped()
signal viewChanged(view: String)

### /// TUNING ///

# padding of the rows above and below the body
const sidePad: int = 16
const topPad: int = 12
const bottomPad: int = 10
# the body view: smallest height, and the spacing BodyView keeps around the figures
const minBodyHeight: float = 150.0
const bodyEdgeMargin: float = 4.0
const bodyPairGap: float = 0.03

var bodyView: BodyView = null
var slider: HeatRangeSlider = null
var viewChips: Segmented = null
var titleLabel: Label = null
var hintLabel: Label = null
var bottomBox: VBoxContainer = null
var maxBodyHeight: float = 470.0
var rangeKey: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 6)

	# title + view chips
	var top: HBoxContainer = Ui.hbox(8)
	add_child(Ui.margin(top, sidePad, topPad, sidePad - 4, 0))
	titleLabel = Ui.label("", "BoldLabel")
	titleLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titleLabel.clip_text = true
	titleLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(titleLabel)
	viewChips = Segmented.new()
	viewChips.changed.connect(_onViewPicked)
	top.add_child(viewChips)

	# the body
	bodyView = BodyView.new()
	bodyView.edgeMargin = bodyEdgeMargin
	bodyView.pairGap = bodyPairGap
	bodyView.custom_minimum_size = Vector2(0.0, minBodyHeight)
	bodyView.regionTapped.connect(_onRegionTapped)
	bodyView.emptyTapped.connect(_onEmptyTapped)
	add_child(bodyView)

	# slider / legend + hint
	bottomBox = Ui.vbox(4)
	add_child(Ui.margin(bottomBox, sidePad, 0, sidePad, bottomPad))
	hintLabel = Ui.wrapLabel("", "FaintLabel")
	hintLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hintLabel.visible = false
	bottomBox.add_child(hintLabel)


func configure(title: String, bodyHeight: float, storageRangeKey: String, showSlider: bool, hint: String) -> void:
	### WHAT THIS DOES
	# fills in the card from the profile and settings; call once after creating it

	maxBodyHeight = bodyHeight
	rangeKey = storageRangeKey
	titleLabel.text = title
	bodyView.body = str(Storage.profile["body"])
	bodyView.gradientId = str(Storage.profile["gradient"])
	bodyView.hideUntouched = bool(Storage.settings["hideUntouched"])
	bodyView.viewMode = str(Storage.settings["defaultView"])
	if rangeKey != "":
		bodyView.rangeMax = float(Storage.settings[rangeKey])
	viewChips.setOptions([["front", "Front"], ["back", "Back"], ["both", "Both"]], bodyView.viewMode)
	if showSlider:
		slider = HeatRangeSlider.new()
		slider.gradientId = bodyView.gradientId
		# set the value before connecting - setting it fires valueChanged
		slider.value = int(bodyView.rangeMax)
		slider.valueChanged.connect(_onRangeChanged)
		bottomBox.add_child(slider)
		bottomBox.move_child(slider, 0)
	setHint(hint)
	_fitBody()


### /// SETTERS ///

func setTitle(text: String) -> void:
	titleLabel.text = text


func setHint(text: String) -> void:
	hintLabel.text = text
	hintLabel.visible = text != ""


func setHeat(heat: Dictionary, animate: bool = true) -> void:
	bodyView.setHeat(heat, animate)


func setGhost(ghost: Dictionary) -> void:
	bodyView.setGhost(ghost)


func setGradient(gradientId: String) -> void:
	bodyView.gradientId = gradientId
	if slider != null:
		slider.gradientId = gradientId


func setBody(bodyName: String) -> void:
	bodyView.body = bodyName
	_fitBody()


func setView(view: String) -> void:
	viewChips.select(view, false)
	bodyView.viewMode = view
	_fitBody()


func setHideUntouched(hide: bool) -> void:
	bodyView.hideUntouched = hide


func addFooterChip(text: String) -> Button:
	### WHAT THIS DOES
	# a toggle chip at the left of the hint line (the title row has no room left on a phone); the
	# caller listens to its toggled signal

	var row: HBoxContainer = Ui.hbox(10)
	var chip: Button = Ui.button(text, "ChipButton")

	bottomBox.add_child(row)
	bottomBox.move_child(row, hintLabel.get_index())
	chip.toggle_mode = true
	chip.custom_minimum_size.y = Segmented.chipHeight
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	hintLabel.reparent(row)
	hintLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hintLabel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hintLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return chip


func setRangeKey(storageRangeKey: String) -> void:
	# the slider follows another remembered N (e.g. the workout card showing the whole week)
	rangeKey = storageRangeKey
	setRange(int(Storage.settings[rangeKey]))


func setRange(rangeMax: int) -> void:
	# from code (settings changed elsewhere) - no write back
	bodyView.rangeMax = float(rangeMax)
	if slider != null and slider.value != rangeMax:
		slider.valueChanged.disconnect(_onRangeChanged)
		slider.value = rangeMax
		slider.valueChanged.connect(_onRangeChanged)


### /// LAYOUT AND DRAWING ///

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fitBody()
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _fitBody() -> void:
	# tall enough that the figures fill the card width, capped at maxBodyHeight
	if size.x <= 1.0:
		return
	var wanted: float = bodyView.heightToFitWidth(size.x)
	if wanted <= 0.0:
		wanted = maxBodyHeight
	var height: float = clampf(wanted, minBodyHeight, maxBodyHeight)
	if absf(bodyView.custom_minimum_size.y - height) > 0.5:
		bodyView.custom_minimum_size.y = height


func _draw() -> void:
	var box: StyleBox = get_theme_stylebox("panel", "CardPanel")
	if box != null:
		draw_style_box(box, Rect2(Vector2.ZERO, size))


### /// HANDLERS ///

func _onViewPicked(view: String) -> void:
	bodyView.viewMode = view
	_fitBody()
	viewChanged.emit(view)


func _onRangeChanged(value: int) -> void:
	bodyView.rangeMax = float(value)
	if rangeKey != "":
		Storage.setSetting(rangeKey, value)


func _onRegionTapped(regionId: String) -> void:
	regionTapped.emit(regionId)


func _onEmptyTapped() -> void:
	emptyTapped.emit()
