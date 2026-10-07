class_name HeatRangeSlider
extends Control
## HeatRangeSlider - the 0-N slider that doubles as the heat legend
## what this offers
## - the track is the sets scale 0..maxValue; the heat gradient runs from 0 to the handle (N) and
##   everything past the handle shows the top colour - so the bar reads exactly like the body:
##   a region with x sets has the colour under x
## - drag or tap anywhere on it (finger or mouse) to set N (whole sets, minValue..maxValue)
## properties: value (N), minValue, maxValue, gradientId
## signal: valueChanged(value)
## inside a KineticScroll it keeps the finger (claimsDrag), so dragging it never scrolls the page

signal valueChanged(value: int)

### /// TUNING ///

# height of the colour bar
var trackHeight: float = 14.0
# handle size
var handleRadius: float = 15.0
# gap between the bar and the scale numbers under it
var labelGap: float = 6.0
# scale numbers every this many sets
var tickStep: int = 5
# text size of the scale numbers and the handle number
var labelFontSize: int = 13
var handleFontSize: int = 14
# whole control height (touch size)
var controlHeight: float = 64.0
# handle fill and number colour (fixed so the number reads on every theme)
var handleFill: Color = Color("#f4f4f2")
var handleText: Color = Color("#15171c")
# slices used to draw the gradient part of the bar
var gradientSlices: int = 48

### /// PUBLIC STATE ///

var value: int = 10: set = _setValue
var minValue: int = 1: set = _setMinValue
var maxValue: int = 20: set = _setMaxValue
var gradientId: String = "infrared": set = _setGradientId

var draggingHandle: bool = false


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, controlHeight)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("kineticClaimers")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


### /// SETTERS ///

func _setValue(newValue: int) -> void:
	var clamped: int = clampi(newValue, minValue, maxValue)
	if clamped == value:
		return
	value = clamped
	queue_redraw()
	valueChanged.emit(value)


func _setMinValue(newValue: int) -> void:
	minValue = newValue
	value = clampi(value, minValue, maxValue)
	queue_redraw()


func _setMaxValue(newValue: int) -> void:
	maxValue = maxi(newValue, 1)
	value = clampi(value, minValue, maxValue)
	queue_redraw()


func _setGradientId(newValue: String) -> void:
	gradientId = newValue
	queue_redraw()


### /// GEOMETRY ///

func _trackRect() -> Rect2:
	var top: float = handleRadius - trackHeight * 0.5 + 2.0
	return Rect2(handleRadius, top, maxf(size.x - handleRadius * 2.0, 1.0), trackHeight)


func _xForSets(sets: float) -> float:
	var track: Rect2 = _trackRect()
	return track.position.x + track.size.x * sets / float(maxValue)


func _setsForX(x: float) -> int:
	var track: Rect2 = _trackRect()
	var ratio: float = (x - track.position.x) / track.size.x
	return roundi(ratio * maxValue)


func _themeColour(key: String, fallback: Color) -> Color:
	if has_theme_color(key, "App"):
		return get_theme_color(key, "App")
	return fallback


### /// DRAWING ///

func _draw() -> void:
	_drawAmountSlider()


func _drawBar(track: Rect2, fromX: float, toX: float, colourAt: Callable) -> void:
	### WHAT THIS DOES
	# a horizontal colour strip from fromX to toX, colours from colourAt(0..1), as thin quads

	var slices: int = maxi(gradientSlices, 2)
	for index in range(slices):
		var a: float = float(index) / slices
		var b: float = float(index + 1) / slices
		var xa: float = lerpf(fromX, toX, a)
		var xb: float = lerpf(fromX, toX, b)
		var colourA: Color = colourAt.call(a)
		var colourB: Color = colourAt.call(b)
		var points := PackedVector2Array([Vector2(xa, track.position.y), Vector2(xb, track.position.y), Vector2(xb, track.end.y), Vector2(xa, track.end.y)])
		var colours := PackedColorArray([colourA, colourB, colourB, colourA])
		draw_polygon(points, colours)


func _drawAmountSlider() -> void:
	### WHAT THIS DOES
	# body colour underneath (so a see-through gradient reads like on the body), gradient up to N,
	# top colour past N, round ends, scale numbers, the handle with N in it

	var track: Rect2 = _trackRect()
	var plain: Color = _themeColour("bodyPlain", Color("#3a3d45"))
	var muted: Color = _themeColour("textMuted", Color.GRAY)
	var handleX: float = _xForSets(value)
	var font: Font = get_theme_default_font()
	var top: Color = plain.blend(HeatGradients.sample(gradientId, 1.0))
	var start: Color = plain.blend(HeatGradients.sample(gradientId, 0.0))
	var radius: float = track.size.y * 0.5

	# bar
	draw_circle(Vector2(track.position.x, track.get_center().y), radius, start)
	draw_circle(Vector2(track.end.x, track.get_center().y), radius, top)
	_drawBar(track, track.position.x, handleX, func(t: float) -> Color: return plain.blend(HeatGradients.sample(gradientId, t)))
	if handleX < track.end.x:
		draw_rect(Rect2(handleX, track.position.y, track.end.x - handleX, track.size.y), top)

	# scale numbers
	var labelY: float = track.end.y + labelGap + labelFontSize
	var tick: int = 0
	while tick <= maxValue:
		var text: String = str(tick)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, labelFontSize).x
		var x: float = clampf(_xForSets(tick) - width * 0.5, 0.0, size.x - width)
		draw_string(font, Vector2(x, labelY), text, HORIZONTAL_ALIGNMENT_LEFT, -1, labelFontSize, muted)
		tick += tickStep

	# handle
	var centre: Vector2 = Vector2(handleX, track.get_center().y)
	draw_circle(centre, handleRadius + 1.5, _themeColour("bodyGap", Color.BLACK))
	draw_circle(centre, handleRadius, handleFill)
	var number: String = str(value)
	var numberSize: Vector2 = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, handleFontSize)
	var numberPos: Vector2 = Vector2(centre.x - numberSize.x * 0.5, centre.y + handleFontSize * 0.36)
	draw_string(font, numberPos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, handleFontSize, handleText)


### /// INPUT ///

func claimsDrag(_globalPoint: Vector2) -> bool:
	return true


func claimsWheel(_globalPoint: Vector2) -> bool:
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		draggingHandle = event.pressed
		if event.pressed:
			value = _setsForX(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and draggingHandle:
		value = _setsForX(event.position.x)
		accept_event()
