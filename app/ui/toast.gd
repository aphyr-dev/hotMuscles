class_name Toast
extends PanelContainer
## Toast - a short message that slides up near the bottom, with an optional action ("Undo")
## what this offers
## - showMessage(text, actionText = "", action = Callable(), seconds = holdSeconds)
##   a new message replaces the one showing (the old one's action is dropped)
## - pressAction()   what tapping the action does (checks use it); hideNow()
## - isShowing(), messageText()
## sits in group "kineticBlockers" so a tap on it never scrolls the list behind

### /// TUNING ///

# seconds a message stays up
var holdSeconds: float = 5.0
# seconds to slide in / out
var slideSeconds: float = 0.22
# how far below its resting place it starts (px)
var slideDistance: float = 40.0
# side margin from the screen edge and distance from the screen bottom
var sideMargin: float = 14.0
var bottomMargin: float = 100.0
# corner rounding and padding
var radius: int = 16

### /// STATE ///

var messageLabel: Label = null
var actionButton: Button = null
var action: Callable = Callable()
var showing: bool = false
var hideAt: float = 0.0
var safeBottom: float = 0.0
var tween: Tween = null
var styling: bool = false


func _init() -> void:
	add_to_group("kineticBlockers")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row: HBoxContainer = Ui.hbox(8)
	add_child(row)
	messageLabel = Ui.wrapLabel("", "")
	messageLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(messageLabel)
	actionButton = Ui.button("Undo", "FlatButton", pressAction)
	actionButton.custom_minimum_size = Vector2(64.0, 48.0)
	row.add_child(actionButton)
	set_process(false)


func _ready() -> void:
	_applyStyle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_applyStyle()


func _applyStyle() -> void:
	# an inverted card: text colour background, page colour text - stands out on every theme
	# (adding the overrides sends another theme-changed notification - the flag stops the loop)
	if styling or not has_theme_color("text", "App"):
		return
	styling = true
	var box := StyleBoxFlat.new()
	box.bg_color = get_theme_color("text", "App")
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	box.shadow_size = 8
	add_theme_stylebox_override("panel", box)
	messageLabel.add_theme_color_override("font_color", get_theme_color("bg", "App"))
	# the action in the accent, pushed away from the toast's own colour so it reads
	var actionColour: Color = get_theme_color("accent", "App")
	if box.bg_color.get_luminance() > 0.5:
		actionColour = actionColour.darkened(0.2)
	else:
		actionColour = actionColour.lightened(0.3)
	actionButton.add_theme_color_override("font_color", actionColour)
	actionButton.add_theme_color_override("font_pressed_color", actionColour)
	actionButton.add_theme_color_override("font_hover_color", actionColour)
	styling = false


func _restY() -> float:
	var parentHeight: float = get_parent_area_size().y
	return parentHeight - bottomMargin - safeBottom - size.y


func _place(slide: float) -> void:
	var parentWidth: float = get_parent_area_size().x
	size = Vector2(parentWidth - sideMargin * 2.0, 0.0)
	size = Vector2(parentWidth - sideMargin * 2.0, get_combined_minimum_size().y)
	position = Vector2(sideMargin, _restY() + slideDistance * (1.0 - slide))


func showMessage(text: String, actionText: String = "", newAction: Callable = Callable(), seconds: float = -1.0) -> void:
	### WHAT THIS DOES
	# shows (or replaces) the message, slides it in, starts the hide timer

	var hold: float = seconds
	if hold <= 0.0:
		hold = holdSeconds
	messageLabel.text = text
	action = newAction
	actionButton.text = actionText
	actionButton.visible = actionText != "" and newAction.is_valid()
	visible = true
	showing = true
	hideAt = _now() + hold
	modulate.a = 0.0
	_place(0.0)
	if tween != null and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_place, 0.0, 1.0, slideSeconds)
	tween.tween_property(self, "modulate:a", 1.0, slideSeconds)
	set_process(true)


func pressAction() -> void:
	var run: Callable = action
	action = Callable()
	hideNow()
	if run.is_valid():
		run.call()


func hideNow() -> void:
	if not showing:
		return
	showing = false
	set_process(false)
	if tween != null and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, slideSeconds)
	tween.tween_callback(_finishHide)


func _finishHide() -> void:
	if not showing:
		visible = false


func isShowing() -> bool:
	return showing


func messageText() -> String:
	return messageLabel.text


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if showing and _now() >= hideAt:
		action = Callable()
		hideNow()
