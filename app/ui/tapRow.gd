class_name TapRow
extends Container
## TapRow - a list row you can tap, long-press and swipe sideways, with press feedback
## what this offers
## - card: the PanelContainer drawn as the row (style variation "RowPanel" unless changed);
##   put the row's content in it with setContent(control) - content should not stop the mouse
##   (Labels and containers are fine; Buttons inside still work and keep their own presses)
## - signals: tapped(), longPressed(), swiped(actionId)
## - swipe actions: setSwipeActions(rightwards, leftwards) each {id, text, colour} or {} for none;
##   dragging the row sideways reveals the action, letting go past swipeTriggerPx fires it
## - selected (bool) draws an accent outline (picker ticks)
## inside a KineticScroll: a vertical drag scrolls the list and cancels the row's press (the list
## sends the cancel); a sideways drag is left to the row

signal tapped()
signal longPressed()
signal swiped(actionId: String)

### /// TUNING ///

# finger travel before a press stops being a tap
var tapMovePx: float = 12.0
# finger held this long without moving = long press
var longPressSeconds: float = 0.5
# sideways travel before the row starts sliding (the list claims vertical moves at 10 px)
var swipeStartPx: float = 14.0
# slide distance that fires the swipe action on release
var swipeTriggerPx: float = 96.0
# slide stops following the finger 1:1 past this, and never goes further than swipeMaxPx
var swipeMaxPx: float = 150.0
# seconds the row takes to slide back
var swipeReturnSeconds: float = 0.2
# press feedback: scale while held and how fast it changes
var pressedScale: float = 0.975
var pressSeconds: float = 0.08
# outline drawn when selected
var selectedOutlinePx: float = 2.0
# swipe action label size
var actionFontSize: int = 15

### /// STATE ///

var card: PanelContainer = null
var ring: Control = null
var selected: bool = false: set = _setSelected
var swipeRight: Dictionary = {}
var swipeLeft: Dictionary = {}
var pressing: bool = false
var moved: bool = false
var longFired: bool = false
var swiping: bool = false
var pressPos: Vector2 = Vector2.ZERO
var pressTime: float = 0.0
var swipeOffset: float = 0.0
var pressTween: Tween = null
var slideTween: Tween = null


func _init() -> void:
	card = PanelContainer.new()
	card.theme_type_variation = "RowPanel"
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(card)
	# the selected outline is drawn by a child above the card (the row's own drawing is under it)
	ring = Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_drawRing)
	add_child(ring)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func setContent(content: Control) -> void:
	card.add_child(content)


func setSwipeActions(rightwards: Dictionary, leftwards: Dictionary) -> void:
	swipeRight = rightwards
	swipeLeft = leftwards


func _setSelected(value: bool) -> void:
	selected = value
	ring.queue_redraw()


### /// LAYOUT ///

func _get_minimum_size() -> Vector2:
	return card.get_combined_minimum_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		fit_child_in_rect(card, Rect2(Vector2(swipeOffset, 0.0), size))
		fit_child_in_rect(ring, Rect2(Vector2(swipeOffset, 0.0), size))
		card.pivot_offset = size * 0.5
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
		ring.queue_redraw()
	elif what == NOTIFICATION_EXIT_TREE:
		# a list rebuild takes rows out before freeing them - stop their slides with them
		_stopTweens()


func _setSwipeOffset(value: float) -> void:
	swipeOffset = value
	card.position.x = swipeOffset
	ring.position.x = swipeOffset
	queue_redraw()


### /// DRAWING ///

func _draw() -> void:
	### WHAT THIS DOES
	# the swipe action revealed behind the sliding card, and the selected outline

	var radius: float = 16.0
	if absf(swipeOffset) > 1.0:
		var action: Dictionary = swipeRight
		if swipeOffset < 0.0:
			action = swipeLeft
		if not action.is_empty():
			var fill: Color = action.get("colour", Color.GRAY)
			var strength: float = clampf(absf(swipeOffset) / swipeTriggerPx, 0.35, 1.0)
			fill.a = strength
			var back := StyleBoxFlat.new()
			back.bg_color = fill
			back.set_corner_radius_all(int(radius))
			draw_style_box(back, Rect2(Vector2.ZERO, size))
			var font: Font = get_theme_default_font()
			var text: String = str(action.get("text", ""))
			var textSize: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, actionFontSize)
			var x: float = 20.0
			if swipeOffset < 0.0:
				x = size.x - 20.0 - textSize.x
			# dark text on a light action colour (lime, light grey), white on the rest
			var ink: Color = Color.WHITE
			var solid: Color = action.get("colour", Color.GRAY)
			if solid.get_luminance() > 0.6:
				ink = Color(0.08, 0.08, 0.1)
			draw_string(font, Vector2(x, size.y * 0.5 + actionFontSize * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, actionFontSize, ink)


func _drawRing() -> void:
	if not selected:
		return
	var outline := StyleBoxFlat.new()
	outline.draw_center = false
	outline.border_color = _accent()
	outline.set_border_width_all(int(selectedOutlinePx))
	outline.set_corner_radius_all(16)
	outline.anti_aliasing = true
	ring.draw_style_box(outline, Rect2(Vector2.ZERO, ring.size))


func _accent() -> Color:
	if has_theme_color("accent", "App"):
		return get_theme_color("accent", "App")
	return Color.ORANGE


### /// INPUT ///

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_onPress(event.position)
		else:
			_onRelease(event.position)
		accept_event()
	elif event is InputEventMouseMotion and pressing:
		_onMove(event.position)
		accept_event()


func _onPress(point: Vector2) -> void:
	pressing = true
	moved = false
	longFired = false
	swiping = false
	pressPos = point
	pressTime = _now()
	_animatePress(true)
	set_process(true)


func _onMove(point: Vector2) -> void:
	### WHAT THIS DOES
	# a move far outside = the list took the drag (it sends a far-away move): cancel;
	# a sideways move starts the swipe; any other move past tapMovePx just means "not a tap"

	var travel: Vector2 = point - pressPos
	var outside: bool = not Rect2(Vector2(-60.0, -60.0), size + Vector2(120.0, 120.0)).has_point(point)

	if outside and not swiping:
		_cancel()
		return
	if not swiping and not longFired and _hasSwipe() and absf(travel.x) > swipeStartPx and absf(travel.x) > absf(travel.y) * 1.2:
		swiping = true
		moved = true
		_animatePress(false)
	if swiping:
		_setSwipeOffset(_swipeFor(travel.x))
		return
	if travel.length() > tapMovePx:
		moved = true
		_animatePress(false)


func _hasSwipe() -> bool:
	return not swipeRight.is_empty() or not swipeLeft.is_empty()


func _swipeFor(travel: float) -> float:
	# follows the finger, softens past the trigger, stops at the max; no slide toward a missing action
	if travel > 0.0 and swipeRight.is_empty():
		return 0.0
	if travel < 0.0 and swipeLeft.is_empty():
		return 0.0
	var distance: float = absf(travel)
	if distance > swipeTriggerPx:
		distance = swipeTriggerPx + (distance - swipeTriggerPx) * 0.4
	distance = minf(distance, swipeMaxPx)
	return signf(travel) * distance


func _onRelease(point: Vector2) -> void:
	if not pressing:
		return
	pressing = false
	set_process(false)
	_animatePress(false)
	if swiping:
		swiping = false
		var fired: String = ""
		if swipeOffset >= swipeTriggerPx and not swipeRight.is_empty():
			fired = str(swipeRight.get("id", ""))
		elif swipeOffset <= -swipeTriggerPx and not swipeLeft.is_empty():
			fired = str(swipeLeft.get("id", ""))
		_slideBack()
		if fired != "":
			# deferred: handlers often rebuild the list, which must not happen mid input event
			swiped.emit.call_deferred(fired)
		return
	var inside: bool = Rect2(Vector2.ZERO, size).has_point(point)
	if inside and not moved and not longFired:
		tapped.emit.call_deferred()


func _cancel() -> void:
	pressing = false
	swiping = false
	set_process(false)
	_animatePress(false)
	if swipeOffset != 0.0:
		_slideBack()


func _slideBack() -> void:
	if slideTween != null and slideTween.is_valid():
		slideTween.kill()
	slideTween = create_tween()
	slideTween.set_trans(Tween.TRANS_CUBIC)
	slideTween.set_ease(Tween.EASE_OUT)
	slideTween.tween_method(_setSwipeOffset, swipeOffset, 0.0, swipeReturnSeconds)


func _stopTweens() -> void:
	if slideTween != null and slideTween.is_valid():
		slideTween.kill()
	if pressTween != null and pressTween.is_valid():
		pressTween.kill()


func _process(_delta: float) -> void:
	# the long press fires while the finger is still down
	if pressing and not moved and not longFired and not swiping and _now() - pressTime >= longPressSeconds:
		longFired = true
		_animatePress(false)
		if OS.has_feature("mobile"):
			Input.vibrate_handheld(30)
		longPressed.emit()
		set_process(false)


func _animatePress(down: bool) -> void:
	var target: float = 1.0
	if down:
		target = pressedScale
	if pressTween != null and pressTween.is_valid():
		pressTween.kill()
	pressTween = create_tween()
	pressTween.tween_property(card, "scale", Vector2(target, target), pressSeconds)
