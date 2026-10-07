class_name HScrollStrip
extends Container
## HScrollStrip - one sideways-scrolling row (filter chips): drag with finger or mouse, glides
## what this offers
## - put ONE Control in it (an HBoxContainer of chips); it keeps its natural width and slides
## - a sideways drag never presses the chip under the finger (same cancel trick as KineticScroll)
## - the mouse wheel over it scrolls it sideways (desktop)
## - scrollTo(offset), maxOffset()
## overlays above it (group "kineticBlockers") keep their presses

### /// TUNING ///

# finger travel before a press becomes a drag
var dragThresholdPx: float = 10.0
# how fast a fling slows down (per second)
var friction: float = 4.0
# glide speed (px/s) below which it stops
var stopSpeed: float = 10.0
# px one wheel notch moves it
var wheelStep: float = 60.0

### /// STATE ///

var offset: float = 0.0
var velocity: float = 0.0
var pressing: bool = false
var dragging: bool = false
var pressPos: Vector2 = Vector2.ZERO
var offsetAtPress: float = 0.0
var lastMoveX: float = 0.0
var lastMoveTime: float = 0.0
var sendingFake: bool = false

const farPoint: Vector2 = Vector2(-100000.0, -100000.0)


func _ready() -> void:
	clip_contents = true
	set_process(false)


func _content() -> Control:
	for child in get_children():
		if child is Control and child.visible:
			return child
	return null


func _get_minimum_size() -> Vector2:
	var content: Control = _content()
	if content == null:
		return Vector2.ZERO
	return Vector2(0.0, content.get_combined_minimum_size().y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var content: Control = _content()
		if content == null:
			return
		var width: float = maxf(content.get_combined_minimum_size().x, size.x)
		fit_child_in_rect(content, Rect2(-roundf(offset), 0.0, width, size.y))
		offset = clampf(offset, 0.0, maxOffset())


func maxOffset() -> float:
	var content: Control = _content()
	if content == null:
		return 0.0
	return maxf(content.get_combined_minimum_size().x - size.x, 0.0)


func scrollTo(value: float) -> void:
	offset = clampf(value, 0.0, maxOffset())
	var content: Control = _content()
	if content != null:
		content.position.x = -roundf(offset)


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


### /// INPUT ///

func _ownsPoint(point: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	if not Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * point):
		return false
	for node in get_tree().get_nodes_in_group("kineticBlockers"):
		if not (node is Control) or node.is_ancestor_of(self):
			continue
		var local: Vector2 = node.get_global_transform_with_canvas().affine_inverse() * point
		if node.is_visible_in_tree() and Rect2(Vector2.ZERO, node.size).has_point(local):
			return false
	return true


func _input(event: InputEvent) -> void:
	if sendingFake or not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _ownsPoint(event.position):
				pressing = true
				dragging = false
				pressPos = event.position
				offsetAtPress = offset
				velocity = 0.0
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_onRelease(event)
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _ownsPoint(event.position) and maxOffset() > 0.0:
				var direction: float = 1.0
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					direction = -1.0
				scrollTo(offset + direction * wheelStep)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pressing:
		_onMove(event.position)


func _onMove(point: Vector2) -> void:
	var travel: Vector2 = point - pressPos
	if not dragging:
		if absf(travel.x) > dragThresholdPx and absf(travel.x) > absf(travel.y) and maxOffset() > 0.0:
			dragging = true
			pressPos.x += signf(travel.x) * dragThresholdPx
			call_deferred("_sendCancelMotion")
		elif absf(travel.y) > dragThresholdPx:
			pressing = false
			return
		else:
			return
	var now: float = _now()
	var step: float = now - lastMoveTime
	if step > 0.0001 and lastMoveTime > 0.0:
		velocity = -(point.x - lastMoveX) / step
	lastMoveX = point.x
	lastMoveTime = now
	scrollTo(offsetAtPress - (point.x - pressPos.x))
	get_viewport().set_input_as_handled()


func _onRelease(event: InputEventMouseButton) -> void:
	if not pressing:
		return
	pressing = false
	lastMoveTime = 0.0
	if dragging:
		dragging = false
		get_viewport().set_input_as_handled()
		call_deferred("_sendCancelRelease", event.button_index)
		set_process(true)


func _process(delta: float) -> void:
	velocity *= exp(-friction * delta)
	scrollTo(offset + velocity * delta)
	if absf(velocity) < stopSpeed or offset <= 0.0 or offset >= maxOffset():
		velocity = 0.0
		set_process(false)


func _sendCancelMotion() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = farPoint
	motion.global_position = farPoint
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	sendingFake = true
	get_viewport().push_input(motion)
	sendingFake = false


func _sendCancelRelease(buttonIndex: MouseButton) -> void:
	_sendCancelMotion()
	var release := InputEventMouseButton.new()
	release.position = farPoint
	release.global_position = farPoint
	release.button_index = buttonIndex
	release.pressed = false
	sendingFake = true
	get_viewport().push_input(release)
	sendingFake = false
