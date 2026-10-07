class_name GradientBar
extends Control
## GradientBar - a rounded strip showing one heat gradient over the body colour (a swatch)
## what this offers: gradientId (HeatGradients preset); barHeight

### /// TUNING ///

# strip thickness and how many slices draw the blend
var barHeight: float = 12.0
var slices: int = 40

var gradientId: String = "infrared": set = _setGradientId


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = maxf(custom_minimum_size.y, barHeight)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _setGradientId(value: String) -> void:
	gradientId = value
	queue_redraw()


func _draw() -> void:
	### WHAT THIS DOES
	# body colour underneath (so see-through ramps read like on the body), then the ramp in slices,
	# round caps at both ends

	var plain: Color = Color("#3a3d45")
	if has_theme_color("bodyPlain", "App"):
		plain = get_theme_color("bodyPlain", "App")
	var top: float = (size.y - barHeight) * 0.5
	var radius: float = barHeight * 0.5
	var left: float = radius
	var right: float = size.x - radius
	draw_circle(Vector2(left, top + radius), radius, plain.blend(HeatGradients.sample(gradientId, 0.0)))
	draw_circle(Vector2(right, top + radius), radius, plain.blend(HeatGradients.sample(gradientId, 1.0)))
	for index in range(slices):
		var a: float = float(index) / slices
		var b: float = float(index + 1) / slices
		var xa: float = lerpf(left, right, a)
		var xb: float = lerpf(left, right, b)
		var colourA: Color = plain.blend(HeatGradients.sample(gradientId, a))
		var colourB: Color = plain.blend(HeatGradients.sample(gradientId, b))
		var points := PackedVector2Array([Vector2(xa, top), Vector2(xb, top), Vector2(xb, top + barHeight), Vector2(xa, top + barHeight)])
		draw_polygon(points, PackedColorArray([colourA, colourB, colourB, colourA]))
