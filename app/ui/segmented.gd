class_name Segmented
extends HBoxContainer
## Segmented - a row of toggle chips where exactly one is on (Front | Back | Both, tabs, options)
## what this offers
## - setOptions([[id, text], ...], selectedId)   builds the chips
## - select(id, emitSignal = false)              changes the choice from code
## - selectedId; buttons (id -> Button)
## - fillWidth = true makes every chip the same width across the row
## signal changed(optionId) when the user picks a different chip

signal changed(optionId: String)

### /// TUNING ///

# gap between chips
const chipGap: int = 6
# chip height (touch size)
const chipHeight: float = 44.0

var buttons: Dictionary = {}
var selectedId: String = ""
var fillWidth: bool = false
var group: ButtonGroup = null


func _init() -> void:
	add_theme_constant_override("separation", chipGap)


func setOptions(options: Array, selected: String) -> void:
	### WHAT THIS DOES
	# replaces the chips with new ones, one per [id, text]

	Ui.clearChildren(self)
	buttons = {}
	group = ButtonGroup.new()
	for option in options:
		var optionId: String = str(option[0])
		var chip: Button = Ui.button(str(option[1]), "ChipButton")
		chip.toggle_mode = true
		chip.button_group = group
		chip.custom_minimum_size.y = chipHeight
		if fillWidth:
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_onChipPressed.bind(optionId))
		add_child(chip)
		buttons[optionId] = chip
	select(selected, false)


func select(optionId: String, emitSignal: bool = false) -> void:
	if not buttons.has(optionId):
		return
	selectedId = optionId
	# button_pressed un-presses the rest of the group; only "toggled" fires, our handler listens to "pressed"
	buttons[optionId].button_pressed = true
	if emitSignal:
		changed.emit(optionId)


func _onChipPressed(optionId: String) -> void:
	if optionId == selectedId:
		return
	selectedId = optionId
	changed.emit(optionId)
