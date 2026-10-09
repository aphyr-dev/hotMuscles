class_name AppStyle
extends RefCounted
## AppStyle - the base of every style: the shapes, panels, fonts and "feel" of the app, painted with
## whichever palette is picked. On its own it IS the Modern look; a style module extends it and
## overrides only what it changes (see app/looks/styles/ and the registry in app/looks/looks.gd)
## what a style can change (all optional):
## - the shape vars in _init (radii, paddings, text sizes, bold strength)
## - adjustColours(colours) -> colours   tweak the palette for this style (e.g. see-through surfaces)
## - box(role, colours, tint) -> StyleBox   every panel, button, chip, field, tag... by role name
##   (the roles are listed above box() below); return a StyleBoxFlat, a ShapeBox, anything
## - regularFont() / boldFont() / headerFont()   fonts (FontVariation on the built-in font)
## - upperCase(variation) -> bool           labels of that variation drawn in capitals
## - buildTheme(colours) -> Theme          only if the role boxes are not enough
## - decorateFrame(parts, colours)         add decoration nodes to a screen's frame (header bars,
##   side blocks...); parts = {page, header, content, bottom, titleLabel} - decorations must not
##   take input (mouse_filter IGNORE) and must not move the screen's own controls
## - drawCardChrome(card, rect, colours)   extra drawing on top of a card's panel (BodyCard calls it)
## a style never changes what a screen does, only how it looks

### /// TUNING ///

var styleId: String = "modern"
var styleName: String = "Modern"
# base text size in design px (the app is designed at 430 px wide)
var fontSize: int = 17
# text sizes of the label variations
var headerFontSize: int = 28
var titleFontSize: int = 21
var smallFontSize: int = 14
var chipFontSize: int = 15
var tagFontSize: int = 12
# corner rounding of buttons, cards, sheets, chips, list rows, fields and tags
var buttonRadius: int = 14
var cardRadius: int = 18
var sheetRadius: int = 24
var chipRadius: int = 20
var rowRadius: int = 16
var fieldRadius: int = 12
var tagRadius: int = 8
# inner padding of buttons - with the font this makes buttons ~52 px tall (touch size)
var buttonPadH: int = 18
var buttonPadV: int = 15
# inner padding of chips, cards, rows, fields and tags
var chipPadH: int = 14
var chipPadV: int = 10
var cardPad: int = 16
var rowPadH: int = 14
var rowPadV: int = 12
var fieldPadH: int = 16
var fieldPadV: int = 14
var tagPadH: int = 9
var tagPadV: int = 3
# how strong a status tag's background is
var tagFillAlpha: float = 0.2
# size of the slider grab handle and check box icons, thickness of slider tracks
var grabberSize: int = 30
var checkSize: int = 28
var sliderThickness: int = 8
# how much the bold text is thickened - the built-in font has no real bold
var boldStrength: float = 0.6


### /// COLOURS ///

func adjustColours(colours: Dictionary) -> Dictionary:
	# the palette as this style wants it; Modern uses it as it is
	return colours


### /// FONTS ///

func regularFont() -> Font:
	return ThemeDB.fallback_font


func boldFont() -> Font:
	# the default font thickened - titles, row names and the main buttons
	var bold := FontVariation.new()
	bold.base_font = regularFont()
	bold.variation_embolden = boldStrength
	return bold


func headerFont() -> Font:
	return boldFont()


func upperCase(_variation: String) -> bool:
	return false


### /// DECORATION ///

func decorateFrame(_parts: Dictionary, _colours: Dictionary) -> void:
	pass


func drawCardChrome(_card: Control, _rect: Rect2, _colours: Dictionary) -> void:
	pass


### /// BOXES ///

## roles (state words after the dot are separate roles):
##   button, button.hover, button.pressed, button.disabled       plain buttons
##   accent, accent.hover, accent.pressed, accent.disabled       the big main action
##   flat, flat.hover, flat.pressed                              text-only buttons
##   chip, chip.hover, chip.on, chip.onHover                     toggle chips (on = selected)
##   card        cards (body card, settings sections)
##   row         list rows                      rowRing      the selected row's outline (no fill)
##   sheet       bottom sheets (top corners only)              sheetHandle  the grab bar on a sheet
##   background  the page behind everything
##   popup       popups and menus               popupHover   a hovered menu line
##   field, field.focus, field.readOnly                         text fields
##   track, trackFill                           slider track and its filled part
##   progress, progressFill                     small bars (contributions)
##   tile        a stat tile inside a sheet
##   tag         a status pill (tint = the status colour)
##   planned     a planned (0 set) exercise row (tint = the ghost colour)
##   swipe       the action revealed behind a swiped row (tint = the action colour)
##   balance     the bar of a balance row (tint = its fill colour)
##   toast       the toast card (inverted: text colour)
func box(role: String, colours: Dictionary, tint: Color = Color(0, 0, 0, 0)) -> StyleBox:
	### WHAT THIS DOES
	# the Modern look: flat rounded boxes in the palette

	var surface: Color = colours["surface"]
	var surfaceHi: Color = colours["surfaceHi"]
	var accent: Color = colours["accent"]
	var text: Color = colours["text"]
	var line: Color = colours["line"]
	var hover: Color = surfaceHi.lerp(text, 0.06)
	var pressedFill: Color = surfaceHi.lerp(accent, 0.35)

	match role:
		"button":
			return flat(surfaceHi, buttonRadius, buttonPadH, buttonPadV)
		"button.hover":
			return flat(hover, buttonRadius, buttonPadH, buttonPadV)
		"button.pressed":
			return flat(pressedFill, buttonRadius, buttonPadH, buttonPadV)
		"button.disabled":
			return flat(surface, buttonRadius, buttonPadH, buttonPadV)
		"accent":
			return flat(accent, buttonRadius, buttonPadH, buttonPadV)
		"accent.hover":
			return flat(accent.lightened(0.08), buttonRadius, buttonPadH, buttonPadV)
		"accent.pressed":
			return flat(accent.darkened(0.18), buttonRadius, buttonPadH, buttonPadV)
		"accent.disabled":
			return flat(accent.lerp(surface, 0.6), buttonRadius, buttonPadH, buttonPadV)
		"flat":
			return flat(Color(0, 0, 0, 0), buttonRadius, buttonPadH, buttonPadV)
		"flat.hover":
			return flat(Color(text, 0.05), buttonRadius, buttonPadH, buttonPadV)
		"flat.pressed":
			return flat(Color(text, 0.1), buttonRadius, buttonPadH, buttonPadV)
		"chip":
			return flat(surface, chipRadius, chipPadH, chipPadV, line, 1)
		"chip.hover":
			return flat(hover, chipRadius, chipPadH, chipPadV, line, 1)
		"chip.on":
			return flat(accent, chipRadius, chipPadH, chipPadV)
		"chip.onHover":
			return flat(accent.lightened(0.06), chipRadius, chipPadH, chipPadV)
		"card":
			return flat(surface, cardRadius, cardPad, cardPad)
		"row":
			return flat(surface, rowRadius, rowPadH, rowPadV)
		"rowRing":
			var ring: StyleBoxFlat = flat(Color(0, 0, 0, 0), rowRadius, 0, 0, accent, 2)
			ring.draw_center = false
			return ring
		"sheet":
			var sheet: StyleBoxFlat = flat(surface, sheetRadius, cardPad + 4, cardPad + 4)
			sheet.corner_radius_bottom_left = 0
			sheet.corner_radius_bottom_right = 0
			return sheet
		"sheetHandle":
			return flat(Color(text, 0.25), 3, 0, 0)
		"background":
			return flat(colours["bg"], 0, 0, 0)
		"popup":
			return flat(surface, cardRadius, cardPad, cardPad, line, 1)
		"popupHover":
			return flat(surfaceHi, 10, 8, 8)
		"field":
			return flat(surfaceHi, fieldRadius, fieldPadH, fieldPadV, line, 1)
		"field.focus":
			return flat(surfaceHi, fieldRadius, fieldPadH, fieldPadV, accent, 2)
		"field.readOnly":
			return flat(surface, fieldRadius, fieldPadH, fieldPadV, line, 1)
		"track":
			return flat(surfaceHi, sliderThickness / 2, 0, sliderThickness / 2)
		"trackFill":
			return flat(accent, sliderThickness / 2, 0, sliderThickness / 2)
		"progress":
			return flat(surfaceHi, 6, 0, 0)
		"progressFill":
			return flat(accent, 6, 0, 0)
		"tile":
			return flat(surfaceHi, 14, 12, 10)
		"tag":
			return flat(Color(tint, tagFillAlpha), tagRadius, tagPadH, tagPadV)
		"planned":
			var planned: StyleBoxFlat = flat(Color(surface, 0.45), rowRadius, rowPadH, rowPadV, tint, 2)
			return planned
		"swipe":
			return flat(tint, rowRadius, 0, 0)
		"balance":
			return flat(tint, 5, 0, 0)
		"toast":
			var toast: StyleBoxFlat = flat(text, 22, 18, 6)
			toast.content_margin_right = 8
			toast.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
			toast.shadow_size = 8
			return toast
	push_error("AppStyle: unknown box role '%s'" % role)
	return flat(Color.MAGENTA, 0, 0, 0)


### /// THEME BUILDING ///

func buildTheme(colours: Dictionary) -> Theme:
	### WHAT THIS DOES
	# every control type the app uses, from box() and the fonts

	var built := Theme.new()

	built.default_font = regularFont()
	built.default_font_size = fontSize
	for key in colours:
		if key != "name":
			built.set_color(key, "App", colours[key])
	_addLabels(built, colours)
	_addButtons(built, colours)
	_addPanels(built, colours)
	_addInputs(built, colours)
	_addSliders(built, colours)
	_addChecks(built, colours)
	_addLists(built, colours)
	return built


func _addLabels(built: Theme, colours: Dictionary) -> void:
	var bold: Font = boldFont()
	built.set_color("font_color", "Label", colours["text"])
	built.set_type_variation("HeaderLabel", "Label")
	built.set_font_size("font_size", "HeaderLabel", headerFontSize)
	built.set_font("font", "HeaderLabel", headerFont())
	built.set_type_variation("TitleLabel", "Label")
	built.set_font_size("font_size", "TitleLabel", titleFontSize)
	built.set_font("font", "TitleLabel", headerFont())
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


func _buttonBoxes(built: Theme, typeName: String, roleBase: String, colours: Dictionary) -> void:
	built.set_stylebox("normal", typeName, box(roleBase, colours))
	built.set_stylebox("hover", typeName, box(roleBase + ".hover", colours))
	built.set_stylebox("pressed", typeName, box(roleBase + ".pressed", colours))
	built.set_stylebox("hover_pressed", typeName, box(roleBase + ".pressed", colours))


func _addButtons(built: Theme, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# plain, accent, flat and chip buttons - all touch sized, with a pressed look

	# plain
	_buttonBoxes(built, "Button", "button", colours)
	built.set_stylebox("disabled", "Button", box("button.disabled", colours))
	built.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_setButtonFonts(built, "Button", colours["text"], colours["text"], colours["textFaint"])
	built.set_constant("h_separation", "Button", 10)

	# accent (the big main action)
	built.set_type_variation("AccentButton", "Button")
	_buttonBoxes(built, "AccentButton", "accent", colours)
	built.set_stylebox("disabled", "AccentButton", box("accent.disabled", colours))
	_setButtonFonts(built, "AccentButton", colours["accentText"], colours["accentText"], colours["textFaint"])
	built.set_font("font", "AccentButton", boldFont())
	built.set_font_size("font_size", "AccentButton", fontSize + 1)

	# flat (text only)
	built.set_type_variation("FlatButton", "Button")
	_buttonBoxes(built, "FlatButton", "flat", colours)
	_setButtonFonts(built, "FlatButton", colours["accent"], colours["accent"], colours["textFaint"])

	# chips (toggle buttons: pressed = selected)
	built.set_type_variation("ChipButton", "Button")
	built.set_stylebox("normal", "ChipButton", box("chip", colours))
	built.set_stylebox("hover", "ChipButton", box("chip.hover", colours))
	built.set_stylebox("pressed", "ChipButton", box("chip.on", colours))
	built.set_stylebox("hover_pressed", "ChipButton", box("chip.onHover", colours))
	built.set_stylebox("focus", "ChipButton", StyleBoxEmpty.new())
	built.set_font_size("font_size", "ChipButton", chipFontSize)
	_setButtonFonts(built, "ChipButton", colours["text"], colours["accentText"], colours["textFaint"])

	# option and menu buttons share the plain look
	_buttonBoxes(built, "OptionButton", "button", colours)
	_setButtonFonts(built, "OptionButton", colours["text"], colours["text"], colours["textFaint"])


func _addPanels(built: Theme, colours: Dictionary) -> void:
	built.set_stylebox("panel", "Panel", box("background", colours))
	built.set_stylebox("panel", "PanelContainer", box("card", colours))
	built.set_type_variation("CardPanel", "PanelContainer")
	built.set_stylebox("panel", "CardPanel", box("card", colours))
	built.set_type_variation("BackgroundPanel", "PanelContainer")
	built.set_stylebox("panel", "BackgroundPanel", box("background", colours))
	built.set_type_variation("RowPanel", "PanelContainer")
	built.set_stylebox("panel", "RowPanel", box("row", colours))
	built.set_type_variation("SheetPanel", "PanelContainer")
	built.set_stylebox("panel", "SheetPanel", box("sheet", colours))
	built.set_stylebox("panel", "PopupPanel", box("popup", colours))
	built.set_stylebox("panel", "PopupMenu", box("popup", colours))
	built.set_stylebox("hover", "PopupMenu", box("popupHover", colours))
	built.set_color("font_color", "PopupMenu", colours["text"])
	built.set_color("font_hover_color", "PopupMenu", colours["text"])
	built.set_stylebox("panel", "AcceptDialog", box("popup", colours))
	var separator := StyleBoxLine.new()
	separator.color = colours["line"]
	separator.thickness = 1
	built.set_stylebox("separator", "HSeparator", separator)
	built.set_constant("separation", "HSeparator", 12)


func _addInputs(built: Theme, colours: Dictionary) -> void:
	for typeName in ["LineEdit", "TextEdit"]:
		built.set_stylebox("normal", typeName, box("field", colours))
		built.set_stylebox("focus", typeName, box("field.focus", colours))
		built.set_stylebox("read_only", typeName, box("field.readOnly", colours))
		built.set_color("font_color", typeName, colours["text"])
		built.set_color("font_placeholder_color", typeName, colours["textFaint"])
		built.set_color("caret_color", typeName, colours["accent"])
		built.set_color("selection_color", typeName, Color(colours["accent"], 0.35))
		built.set_color("font_selected_color", typeName, colours["text"])
		built.set_color("clear_button_color", typeName, colours["textMuted"])


func _addSliders(built: Theme, colours: Dictionary) -> void:
	var grabber: ImageTexture = circleIcon(grabberSize, colours["text"], colours["accent"])
	var grabberHot: ImageTexture = circleIcon(grabberSize, Color.WHITE, colours["accent"])
	for typeName in ["HSlider", "VSlider"]:
		built.set_stylebox("slider", typeName, box("track", colours))
		built.set_stylebox("grabber_area", typeName, box("trackFill", colours))
		built.set_stylebox("grabber_area_highlight", typeName, box("trackFill", colours))
		built.set_icon("grabber", typeName, grabber)
		built.set_icon("grabber_highlight", typeName, grabberHot)
		built.set_icon("grabber_disabled", typeName, grabber)
	built.set_stylebox("background", "ProgressBar", box("progress", colours))
	built.set_stylebox("fill", "ProgressBar", box("progressFill", colours))
	built.set_color("font_color", "ProgressBar", colours["text"])


func _addChecks(built: Theme, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# check boxes with big drawn boxes; own (clear) styleboxes so they do not inherit the button fill

	var clear: StyleBoxFlat = flat(Color(0, 0, 0, 0), 10, 6, 10)
	var pressedClear: StyleBoxFlat = flat(Color(colours["text"], 0.06), 10, 6, 10)
	var checked: ImageTexture = checkIcon(checkSize, true, colours)
	var unchecked: ImageTexture = checkIcon(checkSize, false, colours)

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
	var grab: StyleBoxFlat = flat(Color(colours["text"], 0.25), 3, 3, 3)
	var grabHot: StyleBoxFlat = flat(Color(colours["text"], 0.4), 3, 3, 3)
	for typeName in ["VScrollBar", "HScrollBar"]:
		built.set_stylebox("scroll", typeName, flat(Color(0, 0, 0, 0), 3, 3, 3))
		built.set_stylebox("grabber", typeName, grab)
		built.set_stylebox("grabber_highlight", typeName, grabHot)
		built.set_stylebox("grabber_pressed", typeName, grabHot)


### /// DRAWING HELPERS (styles use these too) ///

func flat(fill: Color, radius: int, padH: int, padV: int, border: Color = Color(0, 0, 0, 0), borderWidth: int = 0) -> StyleBoxFlat:
	var made := StyleBoxFlat.new()
	made.bg_color = fill
	made.set_corner_radius_all(radius)
	made.content_margin_left = padH
	made.content_margin_right = padH
	made.content_margin_top = padV
	made.content_margin_bottom = padV
	made.border_color = border
	made.set_border_width_all(borderWidth)
	made.anti_aliasing = true
	made.corner_detail = 8
	return made


func circleIcon(size: int, fill: Color, ring: Color) -> ImageTexture:
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


func checkIcon(size: int, ticked: bool, colours: Dictionary) -> ImageTexture:
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
