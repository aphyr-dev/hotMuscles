class_name BalanceBar
extends Control
## BalanceBar - one region's effective sets against its weekly target band, as a thin bar
## what this offers: setValues(sets, band [low, high], status) - draws the track, the band as a
## lighter stretch with end ticks, and the sets as a fill in the status colour (Ui.statusColour)
## the scale runs to whichever is bigger: band top x scaleOverBand, or the sets x scaleOverSets

### /// TUNING ///

# bar thickness and the band tick height
const barHeight: float = 8.0
const tickHeight: float = 14.0
# the scale shows at least this much past the band top, and some room past the sets
const scaleOverBand: float = 1.5
const scaleOverSets: float = 1.1

var sets: float = 0.0
var band: Array = [0, 1]
var status: String = "missed"


func _ready() -> void:
	custom_minimum_size.y = tickHeight
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func setValues(newSets: float, newBand: Array, newStatus: String) -> void:
	sets = newSets
	band = newBand
	status = newStatus
	queue_redraw()


func _draw() -> void:
	### WHAT THIS DOES
	# track, band stretch, band end ticks, fill

	if not has_theme_color("surfaceHi", "App"):
		return
	var top: float = maxf(float(band[1]) * scaleOverBand, sets * scaleOverSets)
	top = maxf(top, 1.0)
	var middle: float = size.y * 0.5
	var barTop: float = middle - barHeight * 0.5
	var lowX: float = size.x * float(band[0]) / top
	var highX: float = size.x * float(band[1]) / top
	var fillX: float = size.x * clampf(sets / top, 0.0, 1.0)
	var track: Color = get_theme_color("surfaceHi", "App")
	var bandColour: Color = get_theme_color("line", "App").lerp(get_theme_color("textMuted", "App"), 0.25)
	var tickColour: Color = get_theme_color("textMuted", "App")

	_bar(Rect2(0.0, barTop, size.x, barHeight), track)
	_bar(Rect2(lowX, barTop, highX - lowX, barHeight), bandColour)
	if fillX > 0.5:
		_bar(Rect2(0.0, barTop, maxf(fillX, barHeight), barHeight), Ui.statusColour(status))
	draw_line(Vector2(lowX, middle - tickHeight * 0.5), Vector2(lowX, middle + tickHeight * 0.5), tickColour, 2.0)
	draw_line(Vector2(highX, middle - tickHeight * 0.5), Vector2(highX, middle + tickHeight * 0.5), tickColour, 2.0)


func _bar(rect: Rect2, fill: Color) -> void:
	draw_style_box(AppTheme.box("balance", fill), rect)
