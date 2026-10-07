extends SceneTree
## testKineticScroll.gd - windowed check of KineticScroll (and BodyView inside it) with synthetic input
## what this offers: python tests/runGodot.py script res://tests/testKineticScroll.gd --window
## drives real input events through Input.parse_input_event (mouse and touch, paced in real time)
## and checks: taps still press buttons, drags and flings never do, the glide carries on and slows,
## the ends bounce back, the wheel scrolls, a touch on a gliding list stops it, and a BodyView in the
## list taps / scrolls / pans / pinches correctly. prints PASS/FAIL lines and ALL PASS / N FAILURE(S)

### /// TUNING ///

# rows in the test list and their height
const rowCount: int = 40
const rowHeight: float = 60.0
# the list's place on screen (design px)
const listRect: Rect2 = Rect2(0.0, 80.0, 430.0, 640.0)
# body view height at the top of the list
const bodyHeight: float = 380.0

var scroll: KineticScroll = null
var bodyView: BodyView = null
var buttons: Array = []
var pressCounts: Dictionary = {}
var tappedRegions: Array = []
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")


func _run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	_buildScene()
	await _frames(5)
	print("list max offset %.0f, view height %.0f" % [scroll.maxOffset(), scroll.size.y])

	await _testTap()
	await _testSlowDrag()
	await _testFling()
	await _testBounceTop()
	await _testFlingIntoBottom()
	await _testWheel()
	await _testTouchDrag()
	await _testCatchGlide()
	await _testBodyInside()

	if failures == 0:
		print("ALL PASS (%d checks)" % checks)
	else:
		print("%d FAILURE(S) of %d checks" % [failures, checks])
	quit(mini(failures, 1))


### /// SCENE ///

func _buildScene() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#121317")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	scroll = KineticScroll.new()
	scroll.position = listRect.position
	scroll.size = listRect.size
	root.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	scroll.add_child(column)

	bodyView = BodyView.new()
	bodyView.custom_minimum_size = Vector2(0.0, bodyHeight)
	bodyView.viewMode = "front"
	bodyView.regionTapped.connect(_onRegionTapped)
	column.add_child(bodyView)

	for index in range(rowCount):
		var button := Button.new()
		button.text = "row %d" % index
		button.custom_minimum_size = Vector2(0.0, rowHeight)
		button.pressed.connect(_onPressed.bind(index))
		column.add_child(button)
		buttons.append(button)
		pressCounts[index] = 0


func _onPressed(index: int) -> void:
	pressCounts[index] += 1


func _onRegionTapped(regionId: String) -> void:
	tappedRegions.append(regionId)


func _totalPresses() -> int:
	var total: int = 0
	for index in pressCounts:
		total += pressCounts[index]
	return total


func _resetCounts() -> void:
	for index in pressCounts:
		pressCounts[index] = 0
	tappedRegions.clear()


### /// CHECK HELPERS ///

func _expectTrue(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


### /// SYNTHETIC INPUT ///

func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _toWindow(point: Vector2) -> Vector2:
	# design px -> window px (the inverse of the stretch mapping)
	return root.get_final_transform() * point


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouseButton(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _toWindow(point)
	event.global_position = event.position
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(event)


func _mouseMove(point: Vector2, relative: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _toWindow(point)
	event.global_position = event.position
	event.relative = relative
	if held:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(event)


func _wheel(point: Vector2, down: bool) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		if down:
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		else:
			event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.factor = 1.0
		event.position = _toWindow(point)
		event.global_position = event.position
		_send(event)


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = _toWindow(point)
	_send(event)


func _touchMove(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _toWindow(point)
	event.relative = relative
	_send(event)


func _tap(point: Vector2) -> void:
	_mouseMove(point, Vector2.ZERO, false)
	await _frames(1)
	_mouseButton(point, true)
	await _frames(3)
	_mouseButton(point, false)
	await _frames(3)


func _drag(from: Vector2, to: Vector2, seconds: float, restSeconds: float, useTouch: bool) -> void:
	### WHAT THIS DOES
	# press at from, move to `to` over `seconds` of real time, rest, release

	var start: float = _now()
	var last: Vector2 = from
	if useTouch:
		_touch(0, from, true)
	else:
		_mouseMove(from, Vector2.ZERO, false)
		await _frames(1)
		_mouseButton(from, true)
	await _frames(1)
	while true:
		await process_frame
		var t: float = clampf((_now() - start) / seconds, 0.0, 1.0)
		var point: Vector2 = from.lerp(to, t)
		if useTouch:
			_touchMove(0, point, point - last)
		else:
			_mouseMove(point, point - last, true)
		last = point
		if t >= 1.0:
			break
	if restSeconds > 0.0:
		await _wait(restSeconds)
	if useTouch:
		_touch(0, to, false)
	else:
		_mouseButton(to, false)


func _settle(maxSeconds: float) -> float:
	# waits until the list stops (or the time runs out), returns the seconds it took
	var start: float = _now()
	while scroll.isMoving() and _now() - start < maxSeconds:
		await process_frame
	await _frames(2)
	return _now() - start


func _rowPoint(index: int) -> Vector2:
	return buttons[index].get_global_rect().get_center()


func _visibleRow(skip: int) -> int:
	# the (skip+1)-th row whose centre is well inside the visible list right now
	var found: int = 0
	for index in range(buttons.size()):
		var y: float = _rowPoint(index).y
		if y > listRect.position.y + 40.0 and y < listRect.end.y - 40.0:
			if found == skip:
				return index
			found += 1
	return -1


### /// TESTS ///

func _testTap() -> void:
	scroll.scrollTo(0.0)
	await _frames(3)
	_resetCounts()
	await _tap(_rowPoint(2))
	_expectTrue("a still tap presses the button under it (row 2 pressed %d)" % pressCounts[2], pressCounts[2] == 1 and _totalPresses() == 1)
	_expectTrue("a tap does not scroll (offset %.1f)" % scroll.scrollOffset, scroll.scrollOffset == 0.0)


func _testSlowDrag() -> void:
	### WHAT THIS DOES
	# slow drag up 300 px over row 6, finger rests before lifting: moves ~300, no glide, no press

	scroll.scrollTo(0.0)
	await _frames(3)
	_resetCounts()
	var row: int = _visibleRow(2)
	var from: Vector2 = _rowPoint(row)
	print("  slow drag starts on row %d at y %.0f" % [row, from.y])
	await _drag(from, from + Vector2(0.0, -300.0), 0.5, 0.2, false)
	await _frames(2)
	var afterRelease: float = scroll.scrollOffset
	await _wait(0.3)
	_expectTrue("slow drag moves the list with the finger (%.1f, want 280-300)" % afterRelease, afterRelease >= 280.0 and afterRelease <= 300.5)
	_expectTrue("finger rested before lifting: no glide (%.1f -> %.1f)" % [afterRelease, scroll.scrollOffset], absf(scroll.scrollOffset - afterRelease) < 0.5)
	_expectTrue("dragging over a button never presses it (presses %d)" % _totalPresses(), _totalPresses() == 0)


func _testFling() -> void:
	### WHAT THIS DOES
	# quick flick, release while moving: the list keeps going, slows down, stops by itself

	scroll.scrollTo(200.0)
	await _frames(3)
	_resetCounts()
	var from: Vector2 = Vector2(215.0, 600.0)
	await _drag(from, from + Vector2(0.0, -200.0), 0.1, 0.0, false)
	var o0: float = scroll.scrollOffset
	await _wait(0.15)
	var o1: float = scroll.scrollOffset
	await _wait(0.45)
	var o2: float = scroll.scrollOffset
	var settleTime: float = await _settle(6.0)
	var o3: float = scroll.scrollOffset
	var earlySpeed: float = (o1 - o0) / 0.15
	var lateSpeed: float = (o2 - o1) / 0.45
	print("  fling offsets: release %.0f, +0.15s %.0f, +0.6s %.0f, settled %.0f after %.2fs" % [o0, o1, o2, o3, settleTime])
	_expectTrue("fling glides on after release (%.0f px in 0.15 s)" % (o1 - o0), o1 - o0 > 60.0)
	_expectTrue("glide slows with friction (%.0f px/s -> %.0f px/s)" % [earlySpeed, lateSpeed], lateSpeed < earlySpeed * 0.8 and lateSpeed > 0.0)
	_expectTrue("glide stops by itself (%.2f s)" % settleTime, not scroll.isMoving() and settleTime < 6.0)
	_expectTrue("a fling never presses a button (presses %d)" % _totalPresses(), _totalPresses() == 0)


func _testBounceTop() -> void:
	### WHAT THIS DOES
	# at the top, pull down 250 px: it gives way less than the finger, then springs back to 0

	scroll.scrollTo(0.0)
	await _frames(3)
	_resetCounts()
	var from: Vector2 = Vector2(215.0, 300.0)
	var lowest: float = 0.0
	var start: float = _now()
	_mouseMove(from, Vector2.ZERO, false)
	await _frames(1)
	_mouseButton(from, true)
	var last: Vector2 = from
	while _now() - start < 0.5:
		await process_frame
		var point: Vector2 = from.lerp(from + Vector2(0.0, 250.0), clampf((_now() - start) / 0.4, 0.0, 1.0))
		_mouseMove(point, point - last, true)
		last = point
		lowest = minf(lowest, scroll.scrollOffset)
	var held: float = scroll.scrollOffset
	_mouseButton(last, false)
	var limit: float = scroll.size.y * scroll.maxOverscrollFraction
	print("  pulled 250 px past the top: list went to %.1f (limit -%.0f)" % [held, limit])
	_expectTrue("overscroll gives way, but less than the finger (%.1f)" % held, held < -20.0 and held > -250.0 * 0.8)
	_expectTrue("overscroll never passes its limit (%.1f)" % lowest, lowest >= -limit - 0.01)
	var settleTime: float = await _settle(2.0)
	_expectTrue("springs back to exactly 0 (%.2f after %.2f s)" % [scroll.scrollOffset, settleTime], scroll.scrollOffset == 0.0 and settleTime < 1.5)
	_expectTrue("the pull pressed nothing (presses %d)" % _totalPresses(), _totalPresses() == 0)


func _testFlingIntoBottom() -> void:
	### WHAT THIS DOES
	# fling hard toward the end: it runs past the end a little, then settles exactly on it

	var high: float = scroll.maxOffset()
	scroll.scrollTo(high - 150.0)
	await _frames(3)
	var from: Vector2 = Vector2(215.0, 650.0)
	await _drag(from, from + Vector2(0.0, -260.0), 0.07, 0.0, false)
	var highest: float = scroll.scrollOffset
	var start: float = _now()
	while _now() - start < 1.5:
		await process_frame
		highest = maxf(highest, scroll.scrollOffset)
	await _settle(2.0)
	print("  fling into the end: max %.1f, end %.1f, settled %.1f" % [highest, high, scroll.scrollOffset])
	_expectTrue("a fling runs past the end (overshoot %.1f px)" % (highest - high), highest > high + 5.0)
	_expectTrue("then settles exactly on the end (%.2f vs %.2f)" % [scroll.scrollOffset, high], absf(scroll.scrollOffset - high) < 0.01)


func _testWheel() -> void:
	scroll.scrollTo(400.0)
	await _frames(3)
	var point: Vector2 = Vector2(215.0, 650.0)
	_mouseMove(point, Vector2.ZERO, false)
	for _notch in range(3):
		_wheel(point, true)
		await _frames(2)
	await _settle(4.0)
	var down: float = scroll.scrollOffset
	for _notch in range(2):
		_wheel(point, false)
		await _frames(2)
	await _settle(4.0)
	print("  wheel: 400 -> %.0f (3 down) -> %.0f (2 up)" % [down, scroll.scrollOffset])
	_expectTrue("wheel down scrolls down smoothly (%.0f)" % down, down > 500.0)
	_expectTrue("wheel up scrolls back up (%.0f)" % scroll.scrollOffset, scroll.scrollOffset < down - 100.0)


func _testTouchDrag() -> void:
	### WHAT THIS DOES
	# a finger (touch events, plus the mouse events the engine makes from them) drags the list

	scroll.scrollTo(0.0)
	await _frames(3)
	_resetCounts()
	var row: int = _visibleRow(1)
	var from: Vector2 = _rowPoint(row)
	print("  finger drag starts on row %d at y %.0f" % [row, from.y])
	await _drag(from, from + Vector2(0.0, -200.0), 0.4, 0.2, true)
	await _frames(3)
	_expectTrue("a finger drag scrolls (%.1f, want 180-200)" % scroll.scrollOffset, scroll.scrollOffset >= 180.0 and scroll.scrollOffset <= 200.5)
	_expectTrue("a finger drag over a button never presses it (presses %d)" % _totalPresses(), _totalPresses() == 0)
	var tapRow: int = _visibleRow(3)
	var tapAt: Vector2 = _rowPoint(tapRow)
	_touch(0, tapAt, true)
	await _frames(3)
	_touch(0, tapAt, false)
	await _frames(3)
	_expectTrue("a finger tap still presses its button (row %d: %d)" % [tapRow, pressCounts[tapRow]], pressCounts[tapRow] == 1 and _totalPresses() == 1)


func _testCatchGlide() -> void:
	### WHAT THIS DOES
	# fling, then touch the gliding list: it stops dead and the touched button is not pressed

	scroll.scrollTo(0.0)
	await _frames(3)
	_resetCounts()
	var from: Vector2 = Vector2(215.0, 650.0)
	await _drag(from, from + Vector2(0.0, -150.0), 0.06, 0.0, false)
	await _wait(0.12)
	var speedBefore: float = scroll.velocity
	var catchPoint: Vector2 = Vector2(215.0, 400.0)
	await _tap(catchPoint)
	var caughtAt: float = scroll.scrollOffset
	await _wait(0.3)
	print("  caught a glide at %.0f px/s" % speedBefore)
	_expectTrue("the glide was really moving when touched (%.0f px/s)" % speedBefore, absf(speedBefore) > scroll.catchSpeed)
	_expectTrue("touching a gliding list stops it (%.1f -> %.1f)" % [caughtAt, scroll.scrollOffset], absf(scroll.scrollOffset - caughtAt) < 0.5)
	_expectTrue("the touch that stopped it pressed nothing (presses %d)" % _totalPresses(), _totalPresses() == 0)


func _testBodyInside() -> void:
	### WHAT THIS DOES
	# BodyView at the top of the list: tap picks a muscle, a drag on it scrolls the page while
	# not zoomed, pans the body while zoomed, and two fingers pinch-zoom it without scrolling

	scroll.scrollTo(0.0)
	await _frames(3)
	_resetCounts()
	bodyView.resetZoom(false)

	# tap a muscle
	var chest: Vector2 = bodyView.get_global_transform_with_canvas() * bodyView.regionCentre("lowerChest")
	await _tap(chest)
	await _frames(2)
	_expectTrue("tap on the body picks the muscle (%s)" % str(tappedRegions), tappedRegions == ["lowerChest"])
	_expectTrue("tapping the body does not scroll (%.1f)" % scroll.scrollOffset, scroll.scrollOffset == 0.0)

	# drag on the unzoomed body scrolls the page
	tappedRegions.clear()
	var onBody: Vector2 = Vector2(215.0, listRect.position.y + 300.0)
	await _drag(onBody, onBody + Vector2(0.0, -150.0), 0.4, 0.2, false)
	await _frames(3)
	_expectTrue("a drag on the unzoomed body scrolls the page (%.1f)" % scroll.scrollOffset, scroll.scrollOffset > 120.0)
	_expectTrue("that drag picked no muscle (%s)" % str(tappedRegions), tappedRegions.is_empty())

	# zoomed: a drag pans the body, not the page
	scroll.scrollTo(0.0)
	await _frames(3)
	var bodyMiddle: Vector2 = bodyView.size * 0.5
	bodyView.zoomAt(bodyMiddle, 2.5)
	await _frames(2)
	var panBefore: Vector2 = bodyView.pan
	await _drag(onBody, onBody + Vector2(40.0, -120.0), 0.4, 0.1, false)
	await _frames(3)
	_expectTrue("zoomed body pans with the drag (pan %s -> %s)" % [str(panBefore), str(bodyView.pan)], bodyView.pan.distance_to(panBefore) > 50.0)
	_expectTrue("zoomed body keeps the page still (%.1f)" % scroll.scrollOffset, scroll.scrollOffset == 0.0)

	# double tap resets the zoom
	var tapPoint: Vector2 = Vector2(215.0, listRect.position.y + 200.0)
	await _tap(tapPoint)
	await _tap(tapPoint)
	await _wait(0.5)
	_expectTrue("double tap resets the zoom (%.2f)" % bodyView.zoom, bodyView.zoom == 1.0)

	# two-finger pinch zooms, page stays put
	tappedRegions.clear()
	scroll.scrollTo(0.0)
	await _frames(3)
	var centre: Vector2 = Vector2(215.0, listRect.position.y + 190.0)
	var a: Vector2 = centre + Vector2(0.0, -30.0)
	var b: Vector2 = centre + Vector2(0.0, 30.0)
	_touch(0, a, true)
	await _frames(1)
	_touch(1, b, true)
	await _frames(1)
	var start: float = _now()
	var lastA: Vector2 = a
	var lastB: Vector2 = b
	while true:
		await process_frame
		var t: float = clampf((_now() - start) / 0.4, 0.0, 1.0)
		var nextA: Vector2 = a + Vector2(0.0, -60.0) * t
		var nextB: Vector2 = b + Vector2(0.0, 60.0) * t
		_touchMove(0, nextA, nextA - lastA)
		_touchMove(1, nextB, nextB - lastB)
		lastA = nextA
		lastB = nextB
		if t >= 1.0:
			break
	_touch(1, lastB, false)
	await _frames(1)
	_touch(0, lastA, false)
	await _frames(3)
	print("  pinch: finger gap 60 -> 180 px, zoom now %.2f" % bodyView.zoom)
	_expectTrue("two-finger spread zooms the body about 3x (%.2f)" % bodyView.zoom, bodyView.zoom > 2.5 and bodyView.zoom < 3.5)
	_expectTrue("the pinch does not scroll the page (%.1f)" % scroll.scrollOffset, absf(scroll.scrollOffset) < 0.5)
	_expectTrue("the pinch picks no muscle (%s)" % str(tappedRegions), tappedRegions.is_empty())

	# mouse wheel over the body zooms it and leaves the page alone
	bodyView.resetZoom(false)
	scroll.scrollTo(0.0)
	await _frames(3)
	var wheelPoint: Vector2 = Vector2(215.0, listRect.position.y + 200.0)
	_mouseMove(wheelPoint, Vector2.ZERO, false)
	for _notch in range(2):
		_wheel(wheelPoint, false)
		await _frames(2)
	await _frames(5)
	var wantZoom: float = bodyView.wheelZoomStep * bodyView.wheelZoomStep
	_expectTrue("wheel up over the body zooms it (%.3f, want %.3f)" % [bodyView.zoom, wantZoom], absf(bodyView.zoom - wantZoom) < 0.001)
	_expectTrue("wheel over the body does not scroll the page (%.1f)" % scroll.scrollOffset, scroll.scrollOffset == 0.0)
	bodyView.resetZoom(false)
