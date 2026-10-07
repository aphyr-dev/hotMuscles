class_name KineticScroll
extends Container
## KineticScroll - a vertical list container that scrolls like a phone list
## what this offers
## - put ONE Control in it (usually a VBoxContainer of rows); it is stretched to the scroll's width
##   and scrolled vertically
## - drag with a finger or the mouse; the list keeps gliding after release and slows with friction;
##   soft rubber-band overscroll at both ends, springs back; mouse wheel and trackpad scroll too
## - tap vs drag: a press only becomes a drag after dragThresholdPx of vertical travel; from then on
##   the button under the finger is told the pointer left it, so a drag never presses a button
##   (Buttons inside need no special settings)
## - touching a gliding list just stops it (that touch does not press anything)
## - a mostly sideways move is left alone (swipe-on-row actions keep working)
## - children that want the gesture for themselves (a zoomed BodyView, a slider) join the group
##   "kineticClaimers" and answer claimsDrag(globalPoint) / claimsWheel(globalPoint)
## - overlays drawn above the list (bottom sheets, dialogs) join the group "kineticBlockers" so a
##   press on them does not scroll the list underneath; an inner KineticScroll wins over an outer one
## functions: scrollTo(offset), scrollBy(amount), maxOffset(), isDragging(), isMoving(); enabled = false
## ignores input
## signals: scrolled(offset), dragStarted(), dragEnded()

signal scrolled(offset: float)
signal dragStarted()
signal dragEnded()

### /// TUNING ///

# finger travel (design px) before a press becomes a drag
var dragThresholdPx: float = 10.0
# how fast a fling slows down - higher stops sooner (per second)
var friction: float = 2.4
# glide speed (px/s) below which the list stops
var stopSpeed: float = 8.0
# fastest fling allowed (px/s)
var maxFlingSpeed: float = 7000.0
# the fling speed is measured over the last this many seconds of the drag
var velocityWindowSeconds: float = 0.08
# a finger resting longer than this before lifting means no fling
var restBeforeLiftSeconds: float = 0.09
# touching a list gliding faster than this (px/s) only stops it
var catchSpeed: float = 80.0
# rubber band: how hard it is to pull past the ends (lower = stiffer)
var overscrollResistance: float = 0.55
# furthest the list can be pulled past an end, as a fraction of its height
var maxOverscrollFraction: float = 0.3
# spring that pulls it back from past the end (higher = snappier)
var springStiffness: float = 170.0
# glide speed one mouse-wheel notch adds (px/s)
var wheelImpulse: float = 1300.0
# trackpad scroll multiplier
var panGestureScale: float = 1.0
# physics steps per frame for the spring (keeps it stable on slow frames)
var springSubsteps: int = 4

### /// STATE ///

# false = ignores all input (a bottom sheet turns its list off while everything fits, so a
# downward drag moves the sheet instead of rubber-banding the list)
var enabled: bool = true
var scrollOffset: float = 0.0
var velocity: float = 0.0
var pressing: bool = false
var dragging: bool = false
var caught: bool = false
var pressPos: Vector2 = Vector2.ZERO
var dragFingerStart: float = 0.0
var dragRawStart: float = 0.0
var samples: Array = []
var touchIds: Dictionary = {}
var sendingFake: bool = false

# where cancel events are sent - far outside every control
const farPoint: Vector2 = Vector2(-100000.0, -100000.0)


func _ready() -> void:
	clip_contents = true
	add_to_group("kineticScrolls")
	set_process(false)


### /// LAYOUT ///

func _content() -> Control:
	for child in get_children():
		if child is Control and child.visible and not child.top_level:
			return child
	return null


func _get_minimum_size() -> Vector2:
	var content: Control = _content()
	if content == null:
		return Vector2.ZERO
	return Vector2(content.get_combined_minimum_size().x, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var content: Control = _content()
		if content == null:
			return
		var height: float = maxf(content.get_combined_minimum_size().y, size.y)
		fit_child_in_rect(content, Rect2(0.0, -roundf(scrollOffset), size.x, height))
		if not dragging and not isMoving():
			_setOffset(clampf(scrollOffset, 0.0, maxOffset()))


func maxOffset() -> float:
	var content: Control = _content()
	if content == null:
		return 0.0
	return maxf(content.size.y - size.y, 0.0)


func _setOffset(value: float) -> void:
	var content: Control = _content()
	scrollOffset = value
	if content != null:
		content.position.y = -roundf(scrollOffset)
	scrolled.emit(scrollOffset)


func scrollTo(offset: float) -> void:
	velocity = 0.0
	_setOffset(clampf(offset, 0.0, maxOffset()))


func scrollBy(amount: float) -> void:
	scrollTo(scrollOffset + amount)


func isDragging() -> bool:
	return dragging


func isMoving() -> bool:
	return velocity != 0.0 or _excess() != 0.0


### /// RUBBER BAND ///

func _maxOverscroll() -> float:
	return maxf(size.y * maxOverscrollFraction, 1.0)


func _rubber(raw: float) -> float:
	# finger travel past an end -> how far the list really goes (diminishing, never past the limit)
	var limit: float = _maxOverscroll()
	var high: float = maxOffset()
	if raw < 0.0:
		return -limit * (1.0 - 1.0 / (-raw * overscrollResistance / limit + 1.0))
	if raw > high:
		return high + limit * (1.0 - 1.0 / ((raw - high) * overscrollResistance / limit + 1.0))
	return raw


func _unrubber(shown: float) -> float:
	# the inverse of _rubber, so grabbing a list mid-bounce does not make it jump
	var limit: float = _maxOverscroll()
	var high: float = maxOffset()
	if shown < 0.0:
		var part: float = minf(-shown / limit, 0.999)
		return -limit * (1.0 / (1.0 - part) - 1.0) / overscrollResistance
	if shown > high:
		var partHigh: float = minf((shown - high) / limit, 0.999)
		return high + limit * (1.0 / (1.0 - partHigh) - 1.0) / overscrollResistance
	return shown


func _excess() -> float:
	if scrollOffset < 0.0:
		return scrollOffset
	var high: float = maxOffset()
	if scrollOffset > high:
		return scrollOffset - high
	return 0.0


### /// GLIDE ///

func _process(delta: float) -> void:
	### WHAT THIS DOES
	# friction inside the range, a critically damped spring past the ends; sleeps when settled

	if pressing:
		return
	var high: float = maxOffset()
	var step: float = delta / springSubsteps
	for _substep in range(springSubsteps):
		var excess: float = _excess()
		if excess != 0.0:
			var damping: float = 2.0 * sqrt(springStiffness)
			velocity += (-springStiffness * excess - damping * velocity) * step
			var next: float = scrollOffset + velocity * step
			# back inside the range: stop at the edge instead of bouncing through
			if excess < 0.0 and next >= 0.0:
				next = 0.0
				velocity = 0.0
			elif excess > 0.0 and next <= high:
				next = high
				velocity = 0.0
			scrollOffset = next
		else:
			velocity *= exp(-friction * step)
			scrollOffset += velocity * step
	var limit: float = _maxOverscroll()
	scrollOffset = clampf(scrollOffset, -limit, high + limit)
	if _excess() == 0.0 and absf(velocity) < stopSpeed:
		velocity = 0.0
	if absf(_excess()) < 0.5 and absf(velocity) < stopSpeed:
		scrollOffset = clampf(scrollOffset, 0.0, high)
		velocity = 0.0
	_setOffset(scrollOffset)
	if velocity == 0.0 and _excess() == 0.0:
		set_process(false)


### /// WHO OWNS A PRESS ///

func _containsGlobal(control: Control, point: Vector2) -> bool:
	var local: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, control.size).has_point(local)


func _ownsPoint(point: Vector2) -> bool:
	### WHAT THIS DOES
	# inside this list, not under a blocker overlay, not inside a nested list that is under it

	if not is_visible_in_tree() or not _containsGlobal(self, point):
		return false
	for node in get_tree().get_nodes_in_group("kineticBlockers"):
		# a blocker this list sits inside (its own bottom sheet) never blocks it
		if not (node is Control) or node.is_ancestor_of(self) or is_ancestor_of(node):
			continue
		if node.is_visible_in_tree() and _containsGlobal(node, point):
			return false
	for node in get_tree().get_nodes_in_group("kineticScrolls"):
		if node != self and is_ancestor_of(node) and node.is_visible_in_tree() and _containsGlobal(node, point):
			return false
	return true


func _claimedBy(point: Vector2, methodName: String) -> bool:
	for node in get_tree().get_nodes_in_group("kineticClaimers"):
		if not (node is Control) or not is_ancestor_of(node) or not node.is_visible_in_tree():
			continue
		if _containsGlobal(node, point) and node.has_method(methodName) and node.call(methodName, point):
			return true
	return false


### /// INPUT ///

func _input(event: InputEvent) -> void:
	if sendingFake or not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_onTouch(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_onPress(event.position)
			else:
				_onRelease(event)
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_onWheel(event)
	elif event is InputEventMouseMotion:
		if pressing:
			_onMove(event.position)
	elif event is InputEventScreenDrag:
		if dragging:
			get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		if _ownsPoint(event.position) and not _claimedBy(event.position, "claimsWheel"):
			velocity = 0.0
			_setOffset(clampf(scrollOffset + event.delta.y * panGestureScale * 20.0, 0.0, maxOffset()))
			get_viewport().set_input_as_handled()


func _onTouch(event: InputEventScreenTouch) -> void:
	# a second finger means a pinch somewhere - the list lets go
	if event.pressed:
		touchIds[event.index] = true
	else:
		touchIds.erase(event.index)
	if touchIds.size() >= 2 and (pressing or dragging):
		pressing = false
		if dragging:
			dragging = false
			dragEnded.emit()
		velocity = 0.0
		set_process(true)


func _onPress(point: Vector2) -> void:
	### WHAT THIS DOES
	# starts watching a press; a press on a gliding or bouncing list catches it instead

	if not _ownsPoint(point) or touchIds.size() >= 2:
		return
	if _claimedBy(point, "claimsDrag"):
		return
	pressing = true
	dragging = false
	pressPos = point
	samples = [[_now(), point.y]]
	caught = false
	if absf(velocity) > catchSpeed or _excess() != 0.0:
		caught = true
		call_deferred("_sendCancelMotion")
	velocity = 0.0


func _onMove(point: Vector2) -> void:
	### WHAT THIS DOES
	# decides tap vs drag, then moves the list with the finger (rubber band past the ends)

	if not dragging:
		var travel: Vector2 = point - pressPos
		if absf(travel.y) > dragThresholdPx and absf(travel.y) >= absf(travel.x):
			dragging = true
			# follow from the threshold point, so the list trails the finger by exactly the threshold
			dragFingerStart = pressPos.y + signf(travel.y) * dragThresholdPx
			dragRawStart = _unrubber(scrollOffset)
			call_deferred("_sendCancelMotion")
			dragStarted.emit()
		elif absf(travel.x) > dragThresholdPx and not caught:
			pressing = false
			return
		else:
			return
	var raw: float = dragRawStart - (point.y - dragFingerStart)
	_setOffset(_rubber(raw))
	var now: float = _now()
	samples.append([now, point.y])
	while samples.size() > 2 and now - samples[0][0] > 0.3:
		samples.pop_front()
	get_viewport().set_input_as_handled()


func _onRelease(event: InputEventMouseButton) -> void:
	if not pressing:
		return
	pressing = false
	if dragging:
		dragging = false
		velocity = _releaseVelocity()
		get_viewport().set_input_as_handled()
		call_deferred("_sendCancelRelease", event.button_index)
		dragEnded.emit()
	elif caught:
		get_viewport().set_input_as_handled()
		call_deferred("_sendCancelRelease", event.button_index)
	caught = false
	set_process(true)


func _releaseVelocity() -> float:
	### WHAT THIS DOES
	# finger speed over the last moments of the drag; zero if the finger rested before lifting

	if samples.size() < 2:
		return 0.0
	var last: Array = samples[samples.size() - 1]
	if _now() - float(last[0]) > restBeforeLiftSeconds:
		return 0.0
	var first: Array = samples[0]
	for sample in samples:
		if float(last[0]) - float(sample[0]) <= velocityWindowSeconds:
			first = sample
			break
	var seconds: float = float(last[0]) - float(first[0])
	if seconds <= 0.0001:
		return 0.0
	var speed: float = -(float(last[1]) - float(first[1])) / seconds
	return clampf(speed, -maxFlingSpeed, maxFlingSpeed)


func _onWheel(event: InputEventMouseButton) -> void:
	if not _ownsPoint(event.position) or _claimedBy(event.position, "claimsWheel"):
		return
	var notches: float = event.factor
	if notches <= 0.0:
		notches = 1.0
	var direction: float = 1.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	# a wheel turn against the glide stops it first
	if signf(velocity) != direction:
		velocity = 0.0
	velocity = clampf(velocity + direction * wheelImpulse * notches, -maxFlingSpeed, maxFlingSpeed)
	set_process(true)
	get_viewport().set_input_as_handled()


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


### /// CANCELLING THE PRESS UNDER THE FINGER ///

func _sendCancelMotion() -> void:
	# tells whatever control holds the press that the pointer left it (a Button then cannot fire)
	var motion := InputEventMouseMotion.new()
	motion.position = farPoint
	motion.global_position = farPoint
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	sendingFake = true
	get_viewport().push_input(motion)
	sendingFake = false


func _sendCancelRelease(buttonIndex: MouseButton) -> void:
	# ends that press far away from it, so it resets without firing
	_sendCancelMotion()
	var release := InputEventMouseButton.new()
	release.position = farPoint
	release.global_position = farPoint
	release.button_index = buttonIndex
	release.pressed = false
	sendingFake = true
	get_viewport().push_input(release)
	sendingFake = false
