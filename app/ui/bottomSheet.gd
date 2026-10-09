class_name BottomSheet
extends Control
## BottomSheet - a panel that slides up from the bottom over a dimmed screen
## what this offers
## - setTitle(title, subtitle = "")        header text (a close X sits at its right)
## - body: VBoxContainer                   put the content here; it scrolls (KineticScroll) once the
##                                         sheet reaches maxHeightFraction of the screen
## - footer: VBoxContainer                 fixed under the body (action buttons go here)
## - addAction(id, text, variation)        a full-width button that runs choose(id)
## - addTextField(text, placeholder)       a LineEdit in the body (textValue() reads it); Enter = submitAction
## - onChoice: Callable(id)                called with the chosen action id after the sheet closes
## - choose(id)                            same as pressing that action's button (checks use it)
## - dismiss()                             what the X, a tap on the dim, a swipe down and the back
##                                         button do: closes, and runs dismissAction if one is set
## - signals: closed()
## a sheet is in group "kineticBlockers" (the list behind never scrolls under it); only the top
## sheet takes the swipe-down. AppRoot.openSheet(sheet) shows it; it frees itself when closed

signal closed()

### /// TUNING ///

# seconds to slide in and out
var openSeconds: float = 0.28
var closeSeconds: float = 0.2
# dim strength behind the sheet
var dimAlpha: float = 0.55
# tallest the sheet gets, as a fraction of the screen height
var maxHeightFraction: float = 0.88
# finger travel before a downward press becomes a sheet drag
var dragThresholdPx: float = 10.0
# let go past this fraction of the sheet height (or faster than closeFlingSpeed px/s) = close
var closeDragFraction: float = 0.28
var closeFlingSpeed: float = 900.0
# seconds the sheet takes to settle back after a short drag
var settleSeconds: float = 0.2
# grab handle size and colour strength
var handleSize: Vector2 = Vector2(44.0, 5.0)
# gap between body rows
var bodyGap: int = 12

### /// PUBLIC STATE ///

var body: VBoxContainer = null
var footer: VBoxContainer = null
var titleLabel: Label = null
var subtitleLabel: Label = null
var lineEdit: LineEdit = null
var onChoice: Callable = Callable()
var dismissAction: String = ""
var submitAction: String = ""
var safeBottom: float = 0.0
var chosen: String = ""

### /// INTERNAL STATE ///

var dim: ColorRect = null
var panel: PanelContainer = null
var scroll: KineticScroll = null
var bottomPad: Control = null
var closeButton: Button = null
var actions: Dictionary = {}
var progress: float = 0.0
var dragOffset: float = 0.0
var closing: bool = false
var pressing: bool = false
var dragging: bool = false
var pressY: float = 0.0
var dragStartY: float = 0.0
var lastY: float = 0.0
var lastTime: float = 0.0
var dragSpeed: float = 0.0
var sendingFake: bool = false

const farPoint: Vector2 = Vector2(-100000.0, -100000.0)


func _init() -> void:
	### WHAT THIS DOES
	# dim + panel (handle, header, scrolling body, footer, safe-area pad), built before it enters the tree

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("kineticBlockers")

	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_onDimInput)
	add_child(dim)

	panel = PanelContainer.new()
	panel.theme_type_variation = "SheetPanel"
	add_child(panel)
	var column: VBoxContainer = Ui.vbox(10)
	panel.add_child(column)

	# grab handle
	var handle := Control.new()
	handle.custom_minimum_size = Vector2(0.0, handleSize.y + 2.0)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.draw.connect(_drawHandle.bind(handle))
	column.add_child(handle)

	# header
	var header: HBoxContainer = Ui.hbox(8)
	column.add_child(header)
	var titles: VBoxContainer = Ui.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titleLabel = Ui.wrapLabel("", "TitleLabel")
	titles.add_child(titleLabel)
	subtitleLabel = Ui.wrapLabel("", "MutedLabel")
	subtitleLabel.visible = false
	titles.add_child(subtitleLabel)
	closeButton = Ui.iconButton("close", "Button", "textMuted")
	closeButton.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	closeButton.pressed.connect(dismiss)
	header.add_child(closeButton)

	# body (scrolls once the sheet is at its tallest)
	scroll = KineticScroll.new()
	column.add_child(scroll)
	body = Ui.vbox(bodyGap)
	scroll.add_child(body)
	body.minimum_size_changed.connect(_queueLayout)

	footer = Ui.vbox(10)
	column.add_child(footer)
	footer.minimum_size_changed.connect(_queueLayout)

	bottomPad = Control.new()
	bottomPad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottomPad)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layoutPanel)
	bottomPad.custom_minimum_size.y = safeBottom
	_layoutPanel()


func _drawHandle(handle: Control) -> void:
	handle.draw_style_box(AppTheme.box("sheetHandle"), Rect2((handle.size.x - handleSize.x) * 0.5, 0.0, handleSize.x, handleSize.y))


### /// CONTENT ///

func setTitle(title: String, subtitle: String = "") -> void:
	titleLabel.text = title
	subtitleLabel.text = subtitle
	subtitleLabel.visible = subtitle != ""


func addAction(actionId: String, text: String, variation: String = "") -> Button:
	var made: Button = Ui.button(text, variation)
	made.custom_minimum_size.y = 52.0
	made.pressed.connect(choose.bind(actionId))
	footer.add_child(made)
	actions[actionId] = made
	return made


func addTextField(text: String, placeholder: String) -> LineEdit:
	lineEdit = LineEdit.new()
	lineEdit.text = text
	lineEdit.placeholder_text = placeholder
	lineEdit.custom_minimum_size.y = 52.0
	lineEdit.select_all_on_focus = true
	lineEdit.text_submitted.connect(_onTextSubmitted)
	body.add_child(lineEdit)
	return lineEdit


func textValue() -> String:
	if lineEdit == null:
		return ""
	return lineEdit.text.strip_edges()


func setText(text: String) -> void:
	if lineEdit != null:
		lineEdit.text = text


func _onTextSubmitted(_text: String) -> void:
	if submitAction != "":
		choose(submitAction)


### /// OPEN AND CLOSE ///

func animateOpen() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_setProgress, 0.0, 1.0, openSeconds)


func choose(actionId: String) -> void:
	### WHAT THIS DOES
	# closes the sheet, then tells the owner which action was picked

	if closing:
		return
	chosen = actionId
	_close()
	if onChoice.is_valid():
		onChoice.call(actionId)


func dismiss() -> void:
	if closing:
		return
	if dismissAction != "":
		choose(dismissAction)
		return
	_close()


func isClosing() -> bool:
	return closing


func _close() -> void:
	closing = true
	if lineEdit != null and lineEdit.has_focus():
		lineEdit.release_focus()
	if not is_inside_tree():
		closed.emit()
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_method(_setProgress, progress, 0.0, closeSeconds)
	tween.tween_callback(_finishClose)


func _finishClose() -> void:
	closed.emit()
	queue_free()


func _setProgress(value: float) -> void:
	progress = value
	dim.color = Color(0.0, 0.0, 0.0, dimAlpha * progress)
	_layoutPanel()


### /// LAYOUT ///

func _queueLayout() -> void:
	call_deferred("_layoutPanel")


func _layoutPanel() -> void:
	### WHAT THIS DOES
	# height = its content, up to maxHeightFraction of the screen (then the body scrolls);
	# slid down by (1 - progress) and by the finger's drag

	if not is_inside_tree() or size.y <= 1.0:
		return
	var contentHeight: float = body.get_combined_minimum_size().y
	var chrome: float = panel.get_combined_minimum_size().y - scroll.custom_minimum_size.y
	var tallest: float = size.y * maxHeightFraction
	var scrollHeight: float = maxf(minf(contentHeight, tallest - chrome), 0.0)
	scroll.custom_minimum_size.y = scrollHeight
	scroll.enabled = contentHeight > scrollHeight + 0.5
	var height: float = chrome + scrollHeight
	panel.size = Vector2(size.x, height)
	panel.position = Vector2(0.0, size.y - height * progress + dragOffset)


### /// INPUT ///

func _onDimInput(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dismiss()


func _isTop() -> bool:
	# no other open sheet above this one
	var parent: Node = get_parent()
	if parent == null:
		return false
	for index in range(get_index() + 1, parent.get_child_count()):
		var other: Node = parent.get_child(index)
		if other is BottomSheet and not other.isClosing():
			return false
	return true


func _inDragZone(point: Vector2) -> bool:
	# anywhere on the panel, except over a list that has something to scroll
	var local: Vector2 = panel.get_global_transform_with_canvas().affine_inverse() * point
	if not Rect2(Vector2.ZERO, panel.size).has_point(local):
		return false
	if scroll.enabled:
		var inScroll: Vector2 = scroll.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, scroll.size).has_point(inScroll):
			return false
	return true


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _input(event: InputEvent) -> void:
	if sendingFake or closing or not is_visible_in_tree() or not _isTop():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _inDragZone(event.position):
				pressing = true
				dragging = false
				pressY = event.position.y
				lastY = pressY
				lastTime = _now()
				dragSpeed = 0.0
		else:
			_onRelease(event)
	elif event is InputEventMouseMotion and pressing:
		_onMove(event.position)


func _onMove(point: Vector2) -> void:
	var travel: float = point.y - pressY
	if not dragging:
		if travel > dragThresholdPx:
			dragging = true
			dragStartY = pressY + dragThresholdPx
			call_deferred("_sendCancelMotion")
		elif travel < -dragThresholdPx:
			pressing = false
			return
		else:
			return
	var now: float = _now()
	if now - lastTime > 0.0001:
		dragSpeed = (point.y - lastY) / (now - lastTime)
	lastY = point.y
	lastTime = now
	dragOffset = maxf(point.y - dragStartY, 0.0)
	_layoutPanel()
	get_viewport().set_input_as_handled()


func _onRelease(event: InputEventMouseButton) -> void:
	if not pressing:
		return
	pressing = false
	if not dragging:
		return
	dragging = false
	get_viewport().set_input_as_handled()
	call_deferred("_sendCancelRelease", event.button_index)
	var recent: bool = _now() - lastTime < 0.1
	if dragOffset > panel.size.y * closeDragFraction or (recent and dragSpeed > closeFlingSpeed):
		dismiss()
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_setDragOffset, dragOffset, 0.0, settleSeconds)


func _setDragOffset(value: float) -> void:
	dragOffset = value
	_layoutPanel()


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
