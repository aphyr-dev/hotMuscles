extends Node
## AppTheme (autoload) - the app colour themes, built as a Godot Theme in code
## what this offers
## - themeIds() / themeName(id)                 "ember", "ocean", "forest", "light"
## - apply(themeId)                             builds the theme, puts it on the root window (every
##                                              Control inherits it), sets the clear colour, emits themeChanged
## - buildTheme(themeId) -> Theme               a theme without applying it (e.g. a live preview panel:
##                                              set panel.theme = AppTheme.buildTheme(id))
## - colour(key) / paletteOf(themeId)           raw palette colours: bg, page, surface, surfaceHi, line, text,
##                                              textMuted, textFaint, accent, accentText, cold, neutral, hot,
##                                              ghost, bodyPlain, bodyCosmetic, bodyGap
## - every palette colour is also in the theme as type "App" (get_theme_color("accent", "App"))
## - type variations: AccentButton, FlatButton, ChipButton (toggle chips), CardPanel, SheetPanel,
##   BackgroundPanel, RowPanel (list rows), HeaderLabel, TitleLabel, BoldLabel, MutedLabel, FaintLabel
## - boldFont() the default font thickened (titles, bold labels and AccentButton use it)
## follows Storage.profile.theme by itself (re-applies when the profile changes)

signal themeChanged(themeId: String)

### /// TUNING ///

# base text size in design px (the app is designed at 430 px wide)
const fontSize: int = 17
# text sizes of the label variations
const headerFontSize: int = 28
const titleFontSize: int = 21
const smallFontSize: int = 14
# corner rounding of buttons, cards and sheets
const buttonRadius: int = 14
const cardRadius: int = 18
const sheetRadius: int = 24
const chipRadius: int = 20
# inner padding of buttons - with the font this makes buttons ~52 px tall (touch size)
const buttonPadH: int = 18
const buttonPadV: int = 15
# inner padding of chips (smaller, still a comfortable tap)
const chipPadH: int = 14
const chipPadV: int = 10
# inner padding of cards
const cardPad: int = 16
# size of the slider grab handle and check box icons
const grabberSize: int = 30
const checkSize: int = 28
# thickness of slider tracks
const sliderThickness: int = 8
# fallback theme when an unknown id is asked for
const fallbackTheme: String = "ember"
# how much the bold text (titles, main buttons, row names) is thickened - the font has no real bold
const boldStrength: float = 0.6
# list rows: corner rounding and inner padding
const rowRadius: int = 16
const rowPadH: int = 14
const rowPadV: int = 12

const palettes: Dictionary = {
	"ember": {
		"name": "Ember",
		"page": Color("#0b0c0f"),
		"bg": Color("#121317"),
		"surface": Color("#1b1d22"),
		"surfaceHi": Color("#262930"),
		"line": Color("#2c2f37"),
		"text": Color("#ece8e1"),
		"textMuted": Color("#8d919b"),
		"textFaint": Color("#5d616b"),
		"accent": Color("#ff6a2b"),
		"accentText": Color("#1a0d06"),
		"cold": Color("#2f6dff"),
		"neutral": Color("#4cc27a"),
		"hot": Color("#ff2a1a"),
		"ghost": Color("#7ff0ff"),
		"bodyPlain": Color("#3a3d45"),
		"bodyCosmetic": Color("#2a2c33"),
		"bodyGap": Color("#0b0c0f"),
	},
	"ocean": {
		"name": "Ocean",
		"page": Color("#08111a"),
		"bg": Color("#0d1620"),
		"surface": Color("#142231"),
		"surfaceHi": Color("#1c2e42"),
		"line": Color("#24384d"),
		"text": Color("#e6f1f8"),
		"textMuted": Color("#8aa3b5"),
		"textFaint": Color("#58708a"),
		"accent": Color("#2fd4e8"),
		"accentText": Color("#04161a"),
		"cold": Color("#3d6bff"),
		"neutral": Color("#4fcf8f"),
		"hot": Color("#ff3d2e"),
		"ghost": Color("#c8ff9a"),
		"bodyPlain": Color("#33475a"),
		"bodyCosmetic": Color("#23344a"),
		"bodyGap": Color("#060d14"),
	},
	"forest": {
		"name": "Forest",
		"page": Color("#090e0a"),
		"bg": Color("#0f1611"),
		"surface": Color("#17211a"),
		"surfaceHi": Color("#213025"),
		"line": Color("#2a3a2d"),
		"text": Color("#e9f0e4"),
		"textMuted": Color("#93a38f"),
		"textFaint": Color("#5e6e5b"),
		"accent": Color("#a6e22e"),
		"accentText": Color("#121a05"),
		"cold": Color("#3d7bff"),
		"neutral": Color("#5fcf9a"),
		"hot": Color("#ff3d2e"),
		"ghost": Color("#7ff0ff"),
		"bodyPlain": Color("#36423a"),
		"bodyCosmetic": Color("#263128"),
		"bodyGap": Color("#070b08"),
	},
	"light": {
		"name": "Light",
		"page": Color("#e2e5ea"),
		"bg": Color("#eceef1"),
		"surface": Color("#ffffff"),
		"surfaceHi": Color("#f1f3f6"),
		"line": Color("#d5d9e0"),
		"text": Color("#1b1e24"),
		"textMuted": Color("#5d6470"),
		"textFaint": Color("#9097a3"),
		"accent": Color("#2f6bff"),
		"accentText": Color("#ffffff"),
		"cold": Color("#2f5bff"),
		"neutral": Color("#2fae64"),
		"hot": Color("#ff2a1a"),
		"ghost": Color("#00a6d6"),
		"bodyPlain": Color("#c3c8d0"),
		"bodyCosmetic": Color("#a9afb9"),
		"bodyGap": Color("#3a3f48"),
	},
}

### /// STATE ///

var currentId: String = ""
var palette: Dictionary = {}
var theme: Theme = null


func _ready() -> void:
	var storage: Node = get_node_or_null("/root/Storage")
	var startTheme: String = fallbackTheme
	if storage != null:
		startTheme = str(storage.profile.get("theme", fallbackTheme))
		storage.changed.connect(_onStorageChanged)
	apply(startTheme)


func _onStorageChanged(_section: String) -> void:
	var storage: Node = get_node_or_null("/root/Storage")
	var wanted: String = str(storage.profile.get("theme", fallbackTheme))
	if wanted != currentId:
		apply(wanted)


### /// PUBLIC ///

func themeIds() -> Array:
	return ["ember", "ocean", "forest", "light"]


func themeName(themeId: String) -> String:
	return paletteOf(themeId)["name"]


func paletteOf(themeId: String) -> Dictionary:
	if palettes.has(themeId):
		return palettes[themeId]
	return palettes[fallbackTheme]


func colour(key: String) -> Color:
	if palette.has(key):
		return palette[key]
	return paletteOf(fallbackTheme)[key]


func apply(themeId: String) -> void:
	### WHAT THIS DOES
	# swaps the whole app to a theme at runtime

	var useId: String = themeId
	if not palettes.has(useId):
		useId = fallbackTheme
	currentId = useId
	palette = paletteOf(useId)
	theme = buildTheme(useId)
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(palette["page"])
	themeChanged.emit(useId)


### /// THEME BUILDING ///

func buildTheme(themeId: String) -> Theme:
	### WHAT THIS DOES
	# every control type the app uses, styled from one palette

	var colours: Dictionary = paletteOf(themeId)
	var built := Theme.new()

	built.default_font_size = fontSize
	_addPalette(built, colours)
	_addLabels(built, colours)
	_addButtons(built, colours)
	_addPanels(built, colours)
	_addInputs(built, colours)
	_addSliders(built, colours)
	_addChecks(built, colours)
	_addLists(built, colours)
	return built


func _addPalette(built: Theme, colours: Dictionary) -> void:
	for key in colours:
		if key != "name":
			built.set_color(key, "App", colours[key])


func boldFont() -> FontVariation:
	# the default font thickened - for titles, row names and the main buttons
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = boldStrength
	return bold


func _addLabels(built: Theme, colours: Dictionary) -> void:
	var bold: FontVariation = boldFont()
	built.set_color("font_color", "Label", colours["text"])
	built.set_type_variation("HeaderLabel", "Label")
	built.set_font_size("font_size", "HeaderLabel", headerFontSize)
	built.set_font("font", "HeaderLabel", bold)
	built.set_type_variation("TitleLabel", "Label")
	built.set_font_size("font_size", "TitleLabel", titleFontSize)
	built.set_font("font", "TitleLabel", bold)
	built.set_type_variation("BoldLabel", "Label")
	built.set_font("font", "BoldLabel", bold)
	built.set_type_variation("MutedLabel", "Label")
	built.set_font_size("font_size", "MutedLabel", smallFontSize)
	built.set_color("font_color", "MutedLabel", colours["textMuted"])
	built.set_type_variation("FaintLabel", "Label")
	built.set_font_size("font_size", "FaintLabel", smallFontSize)
	built.set_color("font_color", "FaintLabel", colours["textFaint"])


func _setButtonFonts(built: Theme, typeName: String, normal: Color, pressed: Color, disabled: Color) -> void:
	built.set_color("font_color", typeName, normal)
	built.set_color("font_hover_color", typeName, normal)
	built.set_color("font_focus_color", typeName, normal)
	built.set_color("font_pressed_color", typeName, pressed)
	built.set_color("font_hover_pressed_color", typeName, pressed)
	built.set_color("font_disabled_color", typeName, disabled)
	built.set_color("icon_normal_color", typeName, normal)
	built.set_color("icon_pressed_color", typeName, pressed)
	built.set_color("icon_hover_color", typeName, normal)


func _addButtons(built: Theme, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# plain, accent, flat and chip buttons - all touch sized, with a pressed look

	var surfaceHi: Color = colours["surfaceHi"]
	var accent: Color = colours["accent"]
	var hover: Color = surfaceHi.lerp(colours["text"], 0.06)
	var pressedFill: Color = surfaceHi.lerp(accent, 0.35)
	var focusRing: StyleBoxFlat = _box(Color(0, 0, 0, 0), buttonRadius, buttonPadH, buttonPadV, accent.lerp(colours["text"], 0.2), 2)
	focusRing.draw_center = false

	# plain
	built.set_stylebox("normal", "Button", _box(surfaceHi, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover", "Button", _box(hover, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("pressed", "Button", _box(pressedFill, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover_pressed", "Button", _box(pressedFill, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("disabled", "Button", _box(colours["surface"], buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("focus", "Button", focusRing)
	_setButtonFonts(built, "Button", colours["text"], colours["text"], colours["textFaint"])
	built.set_constant("h_separation", "Button", 10)

	# accent (the big main action)
	built.set_type_variation("AccentButton", "Button")
	built.set_stylebox("normal", "AccentButton", _box(accent, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover", "AccentButton", _box(accent.lightened(0.08), buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("pressed", "AccentButton", _box(accent.darkened(0.18), buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover_pressed", "AccentButton", _box(accent.darkened(0.18), buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("disabled", "AccentButton", _box(accent.lerp(colours["surface"], 0.6), buttonRadius, buttonPadH, buttonPadV))
	_setButtonFonts(built, "AccentButton", colours["accentText"], colours["accentText"], colours["textFaint"])
	built.set_font("font", "AccentButton", boldFont())
	built.set_font_size("font_size", "AccentButton", fontSize + 1)

	# flat (text only)
	built.set_type_variation("FlatButton", "Button")
	built.set_stylebox("normal", "FlatButton", _box(Color(0, 0, 0, 0), buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover", "FlatButton", _box(Color(colours["text"], 0.05), buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("pressed", "FlatButton", _box(Color(colours["text"], 0.1), buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover_pressed", "FlatButton", _box(Color(colours["text"], 0.1), buttonRadius, buttonPadH, buttonPadV))
	_setButtonFonts(built, "FlatButton", colours["accent"], colours["accent"], colours["textFaint"])

	# chips (toggle buttons: pressed = selected)
	built.set_type_variation("ChipButton", "Button")
	built.set_stylebox("normal", "ChipButton", _box(colours["surface"], chipRadius, chipPadH, chipPadV, colours["line"], 1))
	built.set_stylebox("hover", "ChipButton", _box(hover, chipRadius, chipPadH, chipPadV, colours["line"], 1))
	built.set_stylebox("pressed", "ChipButton", _box(accent, chipRadius, chipPadH, chipPadV))
	built.set_stylebox("hover_pressed", "ChipButton", _box(accent.lightened(0.06), chipRadius, chipPadH, chipPadV))
	built.set_stylebox("focus", "ChipButton", StyleBoxEmpty.new())
	built.set_font_size("font_size", "ChipButton", 15)
	_setButtonFonts(built, "ChipButton", colours["text"], colours["accentText"], colours["textFaint"])

	# option and menu buttons share the plain look
	built.set_stylebox("normal", "OptionButton", _box(surfaceHi, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("hover", "OptionButton", _box(hover, buttonRadius, buttonPadH, buttonPadV))
	built.set_stylebox("pressed", "OptionButton", _box(pressedFill, buttonRadius, buttonPadH, buttonPadV))
	_setButtonFonts(built, "OptionButton", colours["text"], colours["text"], colours["textFaint"])


func _addPanels(built: Theme, colours: Dictionary) -> void:
	built.set_stylebox("panel", "Panel", _box(colours["bg"], 0, 0, 0))
	built.set_stylebox("panel", "PanelContainer", _box(colours["surface"], cardRadius, cardPad, cardPad))
	built.set_type_variation("CardPanel", "PanelContainer")
	built.set_stylebox("panel", "CardPanel", _box(colours["surface"], cardRadius, cardPad, cardPad))
	built.set_type_variation("BackgroundPanel", "PanelContainer")
	built.set_stylebox("panel", "BackgroundPanel", _box(colours["bg"], 0, 0, 0))
	built.set_type_variation("RowPanel", "PanelContainer")
	built.set_stylebox("panel", "RowPanel", _box(colours["surface"], rowRadius, rowPadH, rowPadV))
	built.set_type_variation("SheetPanel", "PanelContainer")
	var sheet: StyleBoxFlat = _box(colours["surface"], sheetRadius, cardPad + 4, cardPad + 4)
	sheet.corner_radius_bottom_left = 0
	sheet.corner_radius_bottom_right = 0
	built.set_stylebox("panel", "SheetPanel", sheet)
	built.set_stylebox("panel", "PopupPanel", _box(colours["surface"], cardRadius, cardPad, cardPad, colours["line"], 1))
	built.set_stylebox("panel", "PopupMenu", _box(colours["surface"], buttonRadius, 8, 8, colours["line"], 1))
	built.set_stylebox("hover", "PopupMenu", _box(colours["surfaceHi"], 10, 8, 8))
	built.set_color("font_color", "PopupMenu", colours["text"])
	built.set_color("font_hover_color", "PopupMenu", colours["text"])
	built.set_stylebox("panel", "AcceptDialog", _box(colours["surface"], 0, cardPad, cardPad))
	built.set_stylebox("separator", "HSeparator", _line(colours["line"]))
	built.set_constant("separation", "HSeparator", 12)


func _addInputs(built: Theme, colours: Dictionary) -> void:
	var field: StyleBoxFlat = _box(colours["surfaceHi"], 12, 16, 14, colours["line"], 1)
	var focused: StyleBoxFlat = _box(colours["surfaceHi"], 12, 16, 14, colours["accent"], 2)
	for typeName in ["LineEdit", "TextEdit"]:
		built.set_stylebox("normal", typeName, field)
		built.set_stylebox("focus", typeName, focused)
		built.set_stylebox("read_only", typeName, _box(colours["surface"], 12, 16, 14, colours["line"], 1))
		built.set_color("font_color", typeName, colours["text"])
		built.set_color("font_placeholder_color", typeName, colours["textFaint"])
		built.set_color("caret_color", typeName, colours["accent"])
		built.set_color("selection_color", typeName, Color(colours["accent"], 0.35))
		built.set_color("font_selected_color", typeName, colours["text"])
		built.set_color("clear_button_color", typeName, colours["textMuted"])


func _addSliders(built: Theme, colours: Dictionary) -> void:
	var half: int = sliderThickness / 2
	var track: StyleBoxFlat = _box(colours["surfaceHi"], half, 0, half)
	var filled: StyleBoxFlat = _box(colours["accent"], half, 0, half)
	var grabber: ImageTexture = _circleIcon(grabberSize, colours["text"], colours["accent"])
	var grabberHot: ImageTexture = _circleIcon(grabberSize, Color.WHITE, colours["accent"])
	for typeName in ["HSlider", "VSlider"]:
		built.set_stylebox("slider", typeName, track)
		built.set_stylebox("grabber_area", typeName, filled)
		built.set_stylebox("grabber_area_highlight", typeName, filled)
		built.set_icon("grabber", typeName, grabber)
		built.set_icon("grabber_highlight", typeName, grabberHot)
		built.set_icon("grabber_disabled", typeName, grabber)
	var barBack: StyleBoxFlat = _box(colours["surfaceHi"], 6, 0, 0)
	var barFill: StyleBoxFlat = _box(colours["accent"], 6, 0, 0)
	built.set_stylebox("background", "ProgressBar", barBack)
	built.set_stylebox("fill", "ProgressBar", barFill)
	built.set_color("font_color", "ProgressBar", colours["text"])


func _addChecks(built: Theme, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# check boxes with big drawn boxes; own (clear) styleboxes so they do not inherit the button fill

	var clear: StyleBoxFlat = _box(Color(0, 0, 0, 0), 10, 6, 10)
	var pressedClear: StyleBoxFlat = _box(Color(colours["text"], 0.06), 10, 6, 10)
	var checked: ImageTexture = _checkIcon(checkSize, true, colours)
	var unchecked: ImageTexture = _checkIcon(checkSize, false, colours)

	for typeName in ["CheckBox", "CheckButton"]:
		built.set_stylebox("normal", typeName, clear)
		built.set_stylebox("hover", typeName, clear)
		built.set_stylebox("pressed", typeName, clear)
		built.set_stylebox("hover_pressed", typeName, pressedClear)
		built.set_stylebox("focus", typeName, StyleBoxEmpty.new())
		built.set_stylebox("disabled", typeName, clear)
		_setButtonFonts(built, typeName, colours["text"], colours["text"], colours["textFaint"])
		built.set_constant("h_separation", typeName, 12)
	built.set_icon("checked", "CheckBox", checked)
	built.set_icon("unchecked", "CheckBox", unchecked)
	built.set_icon("checked_disabled", "CheckBox", checked)
	built.set_icon("unchecked_disabled", "CheckBox", unchecked)


func _addLists(built: Theme, colours: Dictionary) -> void:
	var grab: StyleBoxFlat = _box(Color(colours["text"], 0.25), 3, 3, 3)
	var grabHot: StyleBoxFlat = _box(Color(colours["text"], 0.4), 3, 3, 3)
	for typeName in ["VScrollBar", "HScrollBar"]:
		built.set_stylebox("scroll", typeName, _box(Color(0, 0, 0, 0), 3, 3, 3))
		built.set_stylebox("grabber", typeName, grab)
		built.set_stylebox("grabber_highlight", typeName, grabHot)
		built.set_stylebox("grabber_pressed", typeName, grabHot)
	built.set_stylebox("tab_selected", "TabBar", _box(colours["surfaceHi"], 12, 16, 12))
	built.set_stylebox("tab_unselected", "TabBar", _box(Color(0, 0, 0, 0), 12, 16, 12))
	built.set_stylebox("tab_hovered", "TabBar", _box(Color(colours["text"], 0.05), 12, 16, 12))
	built.set_color("font_selected_color", "TabBar", colours["text"])
	built.set_color("font_unselected_color", "TabBar", colours["textMuted"])
	built.set_color("font_hovered_color", "TabBar", colours["text"])


### /// DRAWING HELPERS ///

func _box(fill: Color, radius: int, padH: int, padV: int, border: Color = Color(0, 0, 0, 0), borderWidth: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.content_margin_left = padH
	box.content_margin_right = padH
	box.content_margin_top = padV
	box.content_margin_bottom = padV
	box.border_color = border
	box.set_border_width_all(borderWidth)
	box.anti_aliasing = true
	box.corner_detail = 8
	return box


func _line(colour: Color) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = colour
	line.thickness = 1
	return line


func _circleIcon(size: int, fill: Color, ring: Color) -> ImageTexture:
	### WHAT THIS DOES
	# an anti-aliased disc with a coloured ring, drawn pixel by pixel

	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre: float = (size - 1) * 0.5
	var outer: float = size * 0.5 - 1.0
	var ringWidth: float = 3.0

	for y in range(size):
		for x in range(size):
			var distance: float = Vector2(x - centre, y - centre).length()
			var coverage: float = clampf(outer - distance + 0.5, 0.0, 1.0)
			var colourHere: Color = fill
			if distance > outer - ringWidth:
				colourHere = ring
			colourHere.a *= coverage
			image.set_pixel(x, y, colourHere)
	return ImageTexture.create_from_image(image)


func _checkIcon(size: int, ticked: bool, colours: Dictionary) -> ImageTexture:
	### WHAT THIS DOES
	# a rounded box, filled with the accent and a tick when checked, outlined when not

	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius: float = 6.0
	var inset: float = 1.5
	var border: float = 2.0
	var lo: float = inset
	var hi: float = size - 1 - inset
	var tickA: Vector2 = Vector2(size * 0.26, size * 0.52)
	var tickB: Vector2 = Vector2(size * 0.43, size * 0.69)
	var tickC: Vector2 = Vector2(size * 0.75, size * 0.33)

	for y in range(size):
		for x in range(size):
			# signed distance to the rounded box
			var px: float = clampf(x, lo + radius, hi - radius)
			var py: float = clampf(y, lo + radius, hi - radius)
			var outside: float = Vector2(x - px, y - py).length() - radius
			var coverage: float = clampf(0.5 - outside, 0.0, 1.0)
			var colourHere: Color = Color(0, 0, 0, 0)
			if ticked:
				colourHere = colours["accent"]
				var tickDistance: float = minf(_segmentDistance(Vector2(x, y), tickA, tickB), _segmentDistance(Vector2(x, y), tickB, tickC))
				var tickCover: float = clampf(2.2 - tickDistance, 0.0, 1.0)
				colourHere = colourHere.lerp(colours["accentText"], tickCover)
				colourHere.a = coverage
			else:
				var ringCover: float = clampf(outside + border + 0.5, 0.0, 1.0)
				colourHere = colours["textMuted"]
				colourHere.a = coverage * ringCover
			image.set_pixel(x, y, colourHere)
	return ImageTexture.create_from_image(image)


func _segmentDistance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
	return point.distance_to(closest)
