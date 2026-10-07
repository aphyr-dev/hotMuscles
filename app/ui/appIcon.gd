class_name AppIcon
extends Control
## AppIcon - small line icons drawn in code (the default font has no icon glyphs)
## what this offers
## - kind: "back", "close", "plus", "minus", "check", "star", "starFilled", "more", "gear", "eye",
##   "eyeOff", "trash", "bookmark", "search", "edit", "dot", "circle", "circleCheck" (picker ticks)
## - colourKey: palette colour from the theme (type "App"), or set customColour (alpha > 0 wins)
## - iconSize: drawn size in px, centred in the control (the control itself can be bigger)
## never takes input (mouse_filter ignore) - put it inside a Button

### /// TUNING ///

# line thickness as a fraction of the icon size
const lineFraction: float = 0.095

### /// PUBLIC STATE ///

var kind: String = "close": set = _setKind
var colourKey: String = "text": set = _setColourKey
var customColour: Color = Color(0, 0, 0, 0): set = _setCustomColour
var iconSize: float = 22.0: set = _setIconSize


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(iconSize, iconSize)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _setKind(value: String) -> void:
	kind = value
	queue_redraw()


func _setColourKey(value: String) -> void:
	colourKey = value
	queue_redraw()


func _setCustomColour(value: Color) -> void:
	customColour = value
	queue_redraw()


func _setIconSize(value: float) -> void:
	iconSize = value
	queue_redraw()


### /// DRAWING ///

func _ink() -> Color:
	if customColour.a > 0.0:
		return customColour
	if has_theme_color(colourKey, "App"):
		return get_theme_color(colourKey, "App")
	return Color.WHITE


func _p(x: float, y: float) -> Vector2:
	# icon space 0..1 -> local px, centred
	var origin: Vector2 = (size - Vector2(iconSize, iconSize)) * 0.5
	return origin + Vector2(x, y) * iconSize


func _line(points: Array, ink: Color) -> void:
	var line := PackedVector2Array()
	for point in points:
		line.append(_p(point[0], point[1]))
	draw_polyline(line, ink, maxf(iconSize * lineFraction, 1.5), true)


func _starPoints() -> PackedVector2Array:
	var points := PackedVector2Array()
	var centre: Vector2 = _p(0.5, 0.54)
	for index in range(10):
		var angle: float = -PI * 0.5 + index * PI / 5.0
		var radius: float = iconSize * 0.46
		if index % 2 == 1:
			radius = iconSize * 0.2
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw() -> void:
	### WHAT THIS DOES
	# one small drawing per kind, in icon space 0..1

	var ink: Color = _ink()
	var width: float = maxf(iconSize * lineFraction, 1.5)

	if kind == "back":
		_line([[0.64, 0.16], [0.3, 0.5], [0.64, 0.84]], ink)
	elif kind == "close":
		_line([[0.22, 0.22], [0.78, 0.78]], ink)
		_line([[0.78, 0.22], [0.22, 0.78]], ink)
	elif kind == "plus":
		_line([[0.5, 0.16], [0.5, 0.84]], ink)
		_line([[0.16, 0.5], [0.84, 0.5]], ink)
	elif kind == "minus":
		_line([[0.16, 0.5], [0.84, 0.5]], ink)
	elif kind == "check":
		_line([[0.16, 0.52], [0.4, 0.76], [0.86, 0.26]], ink)
	elif kind == "star":
		var outline: PackedVector2Array = _starPoints()
		outline.append(outline[0])
		draw_polyline(outline, ink, width * 0.8, true)
	elif kind == "starFilled":
		draw_colored_polygon(_starPoints(), ink)
	elif kind == "more":
		for x in [0.2, 0.5, 0.8]:
			draw_circle(_p(x, 0.5), iconSize * 0.085, ink)
	elif kind == "gear":
		var centre: Vector2 = _p(0.5, 0.5)
		draw_arc(centre, iconSize * 0.27, 0.0, TAU, 32, ink, width, true)
		draw_arc(centre, iconSize * 0.1, 0.0, TAU, 20, ink, width * 0.9, true)
		for index in range(8):
			var angle: float = index * TAU / 8.0
			var direction: Vector2 = Vector2(cos(angle), sin(angle))
			draw_line(centre + direction * iconSize * 0.3, centre + direction * iconSize * 0.45, ink, width * 1.5, true)
	elif kind == "eye" or kind == "eyeOff":
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for index in range(17):
			var t: float = float(index) / 16.0
			var x: float = lerpf(0.1, 0.9, t)
			var lift: float = sin(t * PI) * 0.26
			top.append(_p(x, 0.5 - lift))
			bottom.append(_p(x, 0.5 + lift))
		draw_polyline(top, ink, width, true)
		draw_polyline(bottom, ink, width, true)
		draw_circle(_p(0.5, 0.5), iconSize * 0.11, ink)
		if kind == "eyeOff":
			_line([[0.16, 0.86], [0.84, 0.14]], ink)
	elif kind == "trash":
		_line([[0.18, 0.26], [0.82, 0.26]], ink)
		_line([[0.4, 0.26], [0.42, 0.14], [0.58, 0.14], [0.6, 0.26]], ink)
		_line([[0.26, 0.26], [0.3, 0.86], [0.7, 0.86], [0.74, 0.26]], ink)
	elif kind == "bookmark":
		_line([[0.28, 0.14], [0.72, 0.14], [0.72, 0.86], [0.5, 0.68], [0.28, 0.86], [0.28, 0.14]], ink)
	elif kind == "search":
		draw_arc(_p(0.43, 0.43), iconSize * 0.26, 0.0, TAU, 28, ink, width, true)
		_line([[0.62, 0.62], [0.86, 0.86]], ink)
	elif kind == "edit":
		_line([[0.18, 0.82], [0.22, 0.62], [0.68, 0.16], [0.84, 0.32], [0.38, 0.78], [0.18, 0.82]], ink)
	elif kind == "dot":
		draw_circle(_p(0.5, 0.5), iconSize * 0.3, ink)
	elif kind == "circle":
		draw_arc(_p(0.5, 0.5), iconSize * 0.42, 0.0, TAU, 36, ink, width * 0.9, true)
	elif kind == "circleCheck":
		draw_circle(_p(0.5, 0.5), iconSize * 0.46, ink)
		var tick: Color = Color.WHITE
		if has_theme_color("accentText", "App"):
			tick = get_theme_color("accentText", "App")
		var points := PackedVector2Array([_p(0.28, 0.52), _p(0.44, 0.67), _p(0.73, 0.36)])
		draw_polyline(points, tick, width * 1.1, true)
