class_name Ui
extends RefCounted
## Ui - small static helpers every screen uses (no state)
## what this offers
## - building: label(text, variation), wrapLabel(text, variation), button(text, variation, handler),
##   iconButton(kind, variation, colourKey), margin(child, left, top, right, bottom), hbox(gap),
##   vbox(gap), spacer(), tag(text, colour, upperCase), clearChildren(node)
## - pressFx(button)                       the small press-down bounce every button and row gets
## - colours: colour(key) (current theme palette), statusColour(status)
## - text: formatClock(seconds) "mm:ss" / "h:mm:ss", formatLength(seconds) "52 min",
##   formatSets(value) "2.5", dayLabel(unix) "Sun 4 Oct", timeLabel(unix) "18:20",
##   weekRangeLabel(nowUnix) "Sep 28 - Oct 4", greeting(name, nowUnix), exerciseMeta(exercise),
##   setCount(entries) (sets in a list of entries), statusText(status)

### /// TUNING ///

# press feedback: how far a pressed button shrinks, and how fast it goes down and springs back
const pressScale: float = 0.95
const pressDownSeconds: float = 0.06
const pressUpSeconds: float = 0.16
# icon button size (touch target) and icon size inside it
const iconButtonSize: float = 48.0
const iconSize: float = 22.0
# regions named in an exercise's one-line summary
const metaRegionCount: int = 3

const monthNames: Array = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const dayNames: Array = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]


### /// BUILDING ///

static func label(text: String, variation: String = "") -> Label:
	var made := Label.new()
	made.text = text
	if variation != "":
		made.theme_type_variation = variation
	made.uppercase = AppTheme.style.upperCase(variation)
	return made


static func wrapLabel(text: String, variation: String = "") -> Label:
	# a label that wraps onto more lines instead of pushing its container wider
	var made: Label = label(text, variation)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size.x = 40.0
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


static func button(text: String, variation: String = "", handler: Callable = Callable()) -> Button:
	var made := Button.new()
	made.text = text
	made.focus_mode = Control.FOCUS_NONE
	if variation != "":
		made.theme_type_variation = variation
	if handler.is_valid():
		made.pressed.connect(handler)
	pressFx(made)
	return made


static func iconButton(kind: String, variation: String = "FlatButton", colourKey: String = "text") -> Button:
	### WHAT THIS DOES
	# a square touch-sized button with a drawn icon in the middle

	var made := Button.new()
	made.theme_type_variation = variation
	made.focus_mode = Control.FOCUS_NONE
	made.custom_minimum_size = Vector2(iconButtonSize, iconButtonSize)
	var icon := AppIcon.new()
	icon.kind = kind
	icon.colourKey = colourKey
	icon.iconSize = iconSize
	made.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	made.set_meta("icon", icon)
	pressFx(made)
	return made


static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_left", left)
	box.add_theme_constant_override("margin_top", top)
	box.add_theme_constant_override("margin_right", right)
	box.add_theme_constant_override("margin_bottom", bottom)
	if child != null:
		box.add_child(child)
	return box


static func hbox(gap: int = 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box


static func vbox(gap: int = 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box


static func spacer() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


static func tag(text: String, tint: Color, upperCase: bool = true) -> PanelContainer:
	### WHAT THIS DOES
	# a small rounded pill with coloured text on a tint of the same colour (status, "rough data")

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var caption: Label = label("")
	caption.add_theme_font_size_override("font_size", AppTheme.style.tagFontSize)
	caption.add_theme_font_override("font", AppTheme.boldFont())
	pill.add_child(caption)
	retag(pill, text, tint, upperCase)
	return pill


static func retag(pill: PanelContainer, text: String, tint: Color, upperCase: bool = true) -> void:
	# new text and colour for a pill made by tag() (rows that are updated instead of rebuilt)
	var shown: String = text
	pill.add_theme_stylebox_override("panel", AppTheme.box("tag", tint))
	if upperCase:
		shown = text.to_upper()
	var caption: Label = pill.get_child(0)
	caption.text = shown
	caption.add_theme_color_override("font_color", tint)


static func clearChildren(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


### /// PRESS FEEDBACK ///

static func pressFx(target: BaseButton) -> void:
	# shrinks a little while held, springs back on release
	target.button_down.connect(func() -> void: animatePress(target, true))
	target.button_up.connect(func() -> void: animatePress(target, false))


static func animatePress(target: Control, down: bool) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	target.pivot_offset = target.size * 0.5
	var tween: Tween = target.create_tween()
	if down:
		tween.tween_property(target, "scale", Vector2(pressScale, pressScale), pressDownSeconds)
	else:
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "scale", Vector2.ONE, pressUpSeconds)


### /// COLOURS ///

static func colour(key: String) -> Color:
	return AppTheme.colour(key)


static func statusColour(status: String) -> Color:
	# missed / under = cold, over = hot, in band = the theme's green neutral (same as the body)
	if status == HeatEngine.statusMissed:
		return colour("cold").lerp(colour("text"), 0.15)
	if status == HeatEngine.statusUnder:
		return colour("cold").lerp(colour("text"), 0.35)
	if status == HeatEngine.statusOver:
		return colour("hot").lerp(colour("text"), 0.1)
	return colour("neutral")


static func statusText(status: String) -> String:
	if status == HeatEngine.statusOk:
		return "in band"
	return status


### /// TEXT ///

static func formatClock(seconds: float) -> String:
	# "mm:ss" under an hour, "h:mm:ss" after
	var total: int = maxi(int(seconds), 0)
	var hours: int = total / 3600
	var minutes: int = (total % 3600) / 60
	var secs: int = total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


static func formatLength(seconds: float) -> String:
	# "52 min" or "1 h 05 min"
	var minutes: int = maxi(int(roundf(seconds / 60.0)), 0)
	if minutes >= 60:
		return "%d h %02d min" % [minutes / 60, minutes % 60]
	return "%d min" % minutes


static func formatSets(value: float) -> String:
	# effective sets: one decimal, no "-0.0"
	if absf(value) < 0.05:
		return "0"
	if absf(value - roundf(value)) < 0.05:
		return "%d" % int(roundf(value))
	return "%.1f" % value


static func localDate(unix: float) -> Dictionary:
	# the local calendar date/time of a unix time
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)


static func dayLabel(unix: float) -> String:
	var date: Dictionary = localDate(unix)
	return "%s %d %s" % [dayNames[int(date["weekday"])], int(date["day"]), monthNames[int(date["month"]) - 1]]


static func timeLabel(unix: float) -> String:
	var date: Dictionary = localDate(unix)
	return "%02d:%02d" % [int(date["hour"]), int(date["minute"])]


static func weekRangeLabel(nowUnix: float) -> String:
	# the rolling week: six days ago to today
	var first: Dictionary = localDate(nowUnix - 6.0 * HeatEngine.daySeconds)
	var last: Dictionary = localDate(nowUnix)
	var firstText: String = "%s %d" % [monthNames[int(first["month"]) - 1], int(first["day"])]
	var lastText: String = "%s %d" % [monthNames[int(last["month"]) - 1], int(last["day"])]
	return "%s – %s" % [firstText, lastText]


static func greeting(personName: String, nowUnix: float) -> String:
	var hour: int = int(localDate(nowUnix)["hour"])
	var part: String = "Good evening"
	if hour >= 4 and hour < 12:
		part = "Good morning"
	elif hour >= 12 and hour < 18:
		part = "Good afternoon"
	if personName.strip_edges() == "":
		return part
	return "%s, %s" % [part, personName.strip_edges()]


static func exerciseMeta(exercise: Dictionary) -> String:
	# "barbell · lats, biceps, rear delt" - equipment and the biggest regions
	var targets: Array = exercise.get("targets", []).duplicate()
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["share"]) > float(b["share"]))
	var names: Array = []
	for target in targets:
		if names.size() >= metaRegionCount:
			break
		names.append(AppData.regionName(target["region"]).to_lower())
	var parts: Array = [str(exercise.get("equipment", ""))]
	if names.size() > 0:
		parts.append(", ".join(names))
	else:
		parts.append("no muscle heat")
	return " · ".join(parts)


static func setCount(entries: Array) -> int:
	var total: int = 0
	for entry in entries:
		total += int(entry.get("sets", 0))
	return total
