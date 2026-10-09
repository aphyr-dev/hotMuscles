class_name AppRoot
extends Control
## AppRoot (main.tscn) - the app itself: a stack of screens, bottom sheets and a toast on top,
## the Android back button and the phone's safe area (status bar / notch)
## what this offers
## - screens: push(screen, animate), pop(animate), replaceTop(screen), resetTo(screen), top(),
##   weekScreen(); a newly built screen that slides in (or replaces everything) stays hidden for the
##   frame it is built in and shows from the next one, so building it and laying it out never land
##   in the same frame
## - going places: openWorkout(), openWorkoutEditor(workoutId), openPicker(target, regionId),
##   openSettings(), openProfileSetup(firstLaunch)
## - overlays: openSheet(sheet), topSheet(), confirm(title, message, actions, onChoice, dismissAction),
##   askText(title, message, text, placeholder, okText, onChoice, cancelText), showToast(text, actionText, action)
## - goBack() -> bool   back button / gesture / Escape: closes the top sheet, else asks the top
##   screen, else pops a screen; false = nothing left to close (Android then leaves the app)
## - setSafeInsets(top, bottom)   design px kept clear at the top and bottom (read from the phone)
## - startUp()   (re)opens the first screens from what is saved: profile setup on first launch,
##   else the week, plus the running workout on top if there is one (without one, the week replays
##   its workouts on the body - WeekScreen.startReplay)
## - prints once (stdout + the log): "first frame drawn <a> ms after launch: scripts loaded in <b> ms,
##   main scene -> first frame <c> ms"; a = the whole launch (Godot opening its window included),
##   b = from the app's first code (AppData.appStartMs) until this scene enters the tree - the engine
##   compiling every app script, c = the app's own share: building the screens and drawing them once
##   (on the very first launch also the graphics driver preparing its shaders). The startup checks
##   (tests/testStartup.gd, tools/build/checkBuild.py) read c

### /// TUNING ///

# seconds a screen takes to slide in or out
const slideSeconds: float = 0.26
# how far the screen underneath drifts left while the new one slides over it (fraction of width)
const underDrift: float = 0.22
# dim drawn over the screen underneath during a slide
const underDim: float = 0.35

### /// STATE ///

var background: PanelContainer = null
var safeBox: MarginContainer = null
var screenLayer: Control = null
var overlayLayer: Control = null
var toast: Toast = null
var screens: Array = []
var safeTop: float = 0.0
var safeBottom: float = 0.0
var safeOverridden: bool = false
var sliding: Tween = null
var firstFrameMs: int = -1
var mainEnterMs: int = -1
var appShareMs: int = -1
var pendingShow: Callable = Callable()
var pendingFrame: int = 0


func _enter_tree() -> void:
	if mainEnterMs < 0:
		mainEnterMs = Time.get_ticks_msec()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("appRoot")
	_build()
	AppTheme.themeChanged.connect(_onThemeChanged)
	get_viewport().size_changed.connect(_readSafeArea)
	_readSafeArea()
	startUp()
	RenderingServer.frame_post_draw.connect(_onFirstFrame, CONNECT_ONE_SHOT)


func _onFirstFrame() -> void:
	# launch -> first drawn frame of the app (engine ticks start with the process)
	firstFrameMs = Time.get_ticks_msec()
	appShareMs = firstFrameMs - mainEnterMs
	print("first frame drawn %d ms after launch: scripts loaded in %d ms, main scene -> first frame %d ms" % [firstFrameMs, mainEnterMs - AppData.appStartMs, appShareMs])


func _build() -> void:
	### WHAT THIS DOES
	# page colour under everything, the safe-area box holding the screens, overlays above all

	background = PanelContainer.new()
	background.theme_type_variation = "BackgroundPanel"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	safeBox = MarginContainer.new()
	safeBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safeBox)
	safeBox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screenLayer = Control.new()
	screenLayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screenLayer.clip_contents = true
	safeBox.add_child(screenLayer)

	overlayLayer = Control.new()
	overlayLayer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlayLayer)
	overlayLayer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast = Toast.new()
	overlayLayer.add_child(toast)


func startUp() -> void:
	# first screens from the saved state
	_flushPending()
	for sheet in overlayLayer.get_children():
		if sheet is BottomSheet:
			sheet.queue_free()
	for screen in screens:
		screen.queue_free()
	screens = []
	if not bool(Storage.profile["setupDone"]):
		push(ProfileSetup.create(true), false)
		return
	var week := WeekScreen.new()
	push(week, false)
	if Storage.hasCurrentWorkout():
		push(WorkoutScreen.createLive(), false)
	else:
		week.startReplay()


### /// SAFE AREA ///

func _readSafeArea() -> void:
	### WHAT THIS DOES
	# on a phone: the status bar / notch / gesture bar insets in design px; desktop has none

	if safeOverridden:
		_applySafeArea()
		return
	safeTop = 0.0
	safeBottom = 0.0
	if OS.has_feature("mobile"):
		var windowSize: Vector2 = Vector2(DisplayServer.window_get_size())
		var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
		var designHeight: float = get_viewport().get_visible_rect().size.y
		if windowSize.y > 0.0 and safe.size.y > 0.0:
			var toDesign: float = designHeight / windowSize.y
			safeTop = maxf(safe.position.y, 0.0) * toDesign
			safeBottom = maxf(windowSize.y - safe.end.y, 0.0) * toDesign
	_applySafeArea()


func setSafeInsets(top: float, bottom: float) -> void:
	safeOverridden = true
	safeTop = top
	safeBottom = bottom
	_applySafeArea()


func _applySafeArea() -> void:
	safeBox.add_theme_constant_override("margin_top", int(safeTop))
	safeBox.add_theme_constant_override("margin_bottom", int(safeBottom))
	toast.safeBottom = safeBottom


### /// SCREENS ///

func top() -> AppScreen:
	if screens.is_empty():
		return null
	return screens[screens.size() - 1]


func weekScreen() -> WeekScreen:
	for screen in screens:
		if screen is WeekScreen:
			return screen
	return null


func _addScreen(screen: AppScreen) -> void:
	screen.app = self
	screenLayer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _finishSlide() -> void:
	# after a slide: everything settles, only the top screen stays visible
	for screen in screens:
		screen.position.x = 0.0
		screen.modulate = Color.WHITE
		screen.visible = screen == top()


func _slide(incoming: AppScreen, outgoing: AppScreen, forward: bool, freeOutgoing: bool) -> void:
	### WHAT THIS DOES
	# forward: the new screen slides in from the right over the old one; back: the top slides away

	var width: float = screenLayer.size.x
	if sliding != null and sliding.is_valid():
		sliding.kill()
		_finishSlide()
	incoming.visible = true
	outgoing.visible = true
	sliding = create_tween()
	sliding.set_parallel(true)
	sliding.set_trans(Tween.TRANS_CUBIC)
	sliding.set_ease(Tween.EASE_OUT)
	if forward:
		screenLayer.move_child(incoming, -1)
		incoming.position.x = width
		sliding.tween_property(incoming, "position:x", 0.0, slideSeconds)
		sliding.tween_property(outgoing, "position:x", -width * underDrift, slideSeconds)
		sliding.tween_property(outgoing, "modulate", Color(1.0 - underDim, 1.0 - underDim, 1.0 - underDim), slideSeconds)
	else:
		screenLayer.move_child(outgoing, -1)
		incoming.position.x = -width * underDrift
		incoming.modulate = Color(1.0 - underDim, 1.0 - underDim, 1.0 - underDim)
		sliding.tween_property(incoming, "position:x", 0.0, slideSeconds)
		sliding.tween_property(incoming, "modulate", Color.WHITE, slideSeconds)
		sliding.tween_property(outgoing, "position:x", width, slideSeconds)
	sliding.chain().tween_callback(_afterSlide.bind(outgoing, freeOutgoing))


func _afterSlide(outgoing: AppScreen, freeOutgoing: bool) -> void:
	if freeOutgoing and is_instance_valid(outgoing):
		outgoing.queue_free()
	_finishSlide()


func _showNextFrame(screen: AppScreen, show: Callable) -> void:
	### WHAT THIS DOES
	# the screen just built stays hidden this frame; `show` (its slide or swap) runs on a later
	# frame - by frame number, because a tap is handled before this node's _process in the same frame

	_flushPending()
	screen.visible = false
	pendingShow = show
	pendingFrame = Engine.get_process_frames()


func _flushPending() -> void:
	# runs a show that is still waiting (a frame passed, or another screen change comes first)
	if pendingShow.is_valid():
		var waiting: Callable = pendingShow
		pendingShow = Callable()
		waiting.call()


func _process(_delta: float) -> void:
	if pendingShow.is_valid() and Engine.get_process_frames() > pendingFrame:
		_flushPending()


func push(screen: AppScreen, animate: bool = true) -> void:
	_flushPending()
	var below: AppScreen = top()
	_addScreen(screen)
	screens.append(screen)
	if animate and below != null and is_inside_tree():
		_showNextFrame(screen, _slide.bind(screen, below, true, false))
	else:
		_finishSlide()
	screen.onShown()


func pop(animate: bool = true) -> void:
	_flushPending()
	if screens.size() <= 1:
		return
	var leaving: AppScreen = screens.pop_back()
	var below: AppScreen = top()
	below.onShown()
	if animate and is_inside_tree():
		_slide(below, leaving, false, true)
	else:
		leaving.queue_free()
		_finishSlide()


func replaceTop(screen: AppScreen) -> void:
	# the new screen slides in and the one it covers goes away (picker -> the workout it started)
	_flushPending()
	var leaving: AppScreen = screens.pop_back()
	_addScreen(screen)
	screens.append(screen)
	_showNextFrame(screen, _slide.bind(screen, leaving, true, true))
	screen.onShown()


func resetTo(screen: AppScreen) -> void:
	# one screen only (profile setup -> the week); the old ones stay on show until the new one is
	# ready to be seen, then go away a frame later (freeing a whole screen costs a frame of its own)
	_flushPending()
	var old: Array = screens
	screens = []
	_addScreen(screen)
	screens.append(screen)
	_showNextFrame(screen, _swapIn.bind(old))
	screen.onShown()


func _swapIn(old: Array) -> void:
	for screen in old:
		if is_instance_valid(screen):
			screen.visible = false
			get_tree().process_frame.connect(screen.queue_free, CONNECT_ONE_SHOT)
	_finishSlide()


### /// GOING PLACES ///

func openWorkout() -> WorkoutScreen:
	# the running workout (pops back to it if it is already open under the top)
	for index in range(screens.size()):
		var screen: AppScreen = screens[index]
		if screen is WorkoutScreen and screen.live:
			while top() != screen:
				pop(false)
			return screen
	var made: WorkoutScreen = WorkoutScreen.createLive()
	push(made)
	return made


func openWorkoutEditor(workoutId: String) -> WorkoutScreen:
	var made: WorkoutScreen = WorkoutScreen.createEditor(workoutId)
	push(made)
	return made


func openPicker(target: WorkoutScreen, regionId: String = "") -> PickerScreen:
	var made: PickerScreen = PickerScreen.create(target, regionId)
	push(made)
	return made


func openSettings() -> SettingsScreen:
	var made := SettingsScreen.new()
	push(made)
	return made


func openProfileSetup(firstLaunch: bool) -> ProfileSetup:
	var made: ProfileSetup = ProfileSetup.create(firstLaunch)
	push(made)
	return made


### /// OVERLAYS ///

func openSheet(sheet: BottomSheet) -> BottomSheet:
	sheet.safeBottom = safeBottom
	overlayLayer.add_child(sheet)
	overlayLayer.move_child(toast, -1)
	sheet.animateOpen()
	return sheet


func topSheet() -> BottomSheet:
	var children: Array = overlayLayer.get_children()
	children.reverse()
	for child in children:
		if child is BottomSheet and not child.isClosing():
			return child
	return null


func confirm(title: String, message: String, actions: Array, onChoice: Callable, dismissAction: String = "") -> BottomSheet:
	### WHAT THIS DOES
	# a sheet with a message and full-width buttons; actions = [[id, text, variation], ...]

	var sheet := BottomSheet.new()
	sheet.setTitle(title)
	if message != "":
		sheet.body.add_child(Ui.wrapLabel(message, "MutedLabel"))
	for action in actions:
		sheet.addAction(str(action[0]), str(action[1]), str(action[2]))
	sheet.onChoice = onChoice
	sheet.dismissAction = dismissAction
	return openSheet(sheet)


func askText(title: String, message: String, text: String, placeholder: String, okText: String, onChoice: Callable, cancelText: String = "Cancel") -> BottomSheet:
	# a sheet with a text box; onChoice("ok" / "cancel") - read sheet.textValue() for the text;
	# closing it any other way counts as "cancel"
	var sheet := BottomSheet.new()
	sheet.setTitle(title)
	if message != "":
		sheet.body.add_child(Ui.wrapLabel(message, "MutedLabel"))
	sheet.addTextField(text, placeholder)
	sheet.addAction("ok", okText, "AccentButton")
	sheet.addAction("cancel", cancelText, "FlatButton")
	sheet.submitAction = "ok"
	sheet.dismissAction = "cancel"
	sheet.onChoice = onChoice
	openSheet(sheet)
	if not OS.has_feature("mobile"):
		sheet.lineEdit.call_deferred("grab_focus")
	return sheet


func showToast(text: String, actionText: String = "", action: Callable = Callable()) -> void:
	toast.showMessage(text, actionText, action)


### /// BACK ///

func goBack() -> bool:
	var sheet: BottomSheet = topSheet()
	if sheet != null:
		sheet.dismiss()
		return true
	var screen: AppScreen = top()
	if screen != null and screen.onBack():
		return true
	if screens.size() > 1:
		pop()
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# android back: nothing left to close = leave the app (quit_on_go_back is off in the project)
		if not goBack():
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	# Escape does the same on desktop, but never quits
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		goBack()
		get_viewport().set_input_as_handled()


### /// THEME ///

func _onThemeChanged(_themeId: String) -> void:
	# deferred: the theme can change from inside a button press on the screen being rebuilt
	for screen in screens:
		screen.call_deferred("rebuild")
