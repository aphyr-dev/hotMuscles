extends SceneTree
## shotBodyView.gd - windowed screenshot driver for BodyView, the slider and the placeholder home
## what this offers:
##   python tests/runGodot.py script res://tests/shotBodyView.gd --window --resolution 1290x930 -- <outFolder> [prefix]
## every plate is three phone-width columns side by side; files are <prefix>_<name>.png (prefix
## defaults to "phase1"); nothing is written anywhere except the folder given

### /// TUNING ///

# one column = one phone width in design px
const columnWidth: float = 430.0
# room for the caption over each column
const captionHeight: float = 34.0
# frames to wait before each grab (layout + redraw)
const settleFrames: int = 3
# seconds to let the home screen's heat blend in before its grab
const homeSettleSeconds: float = 1.4
# effective sets the amount colouring spans in the plates
const plateRange: float = 12.0
# the sample week used for the heat (same as the placeholder home)
const sampleWeek: Array = [
	["Barbell_Bench_Press_-_Medium_Grip", 4], ["Bent_Over_Barbell_Row", 4], ["Standing_Military_Press", 3],
	["Wide-Grip_Lat_Pulldown", 3], ["Side_Lateral_Raise", 3], ["Barbell_Curl", 3], ["Triceps_Pushdown", 3],
	["Barbell_Squat", 4], ["Romanian_Deadlift", 3], ["Leg_Press", 3], ["Lying_Leg_Curls", 3],
	["Standing_Calf_Raises", 4], ["Incline_Dumbbell_Press", 4], ["Seated_Cable_Rows", 4], ["Pullups", 3],
	["Face_Pull", 3], ["Hammer_Curls", 3], ["Cable_Crunch", 3],
]
# the ghost example: a planned ab + lower-trap add-on
const ghostEntries: Array = [["Hanging_Leg_Raise", 3], ["Russian_Twist", 3], ["Y_Raise", 3]]

var outFolder: String = ""
var prefix: String = "phase1"
var holder: Control = null
var shots: Array = []
var appData: Node = null


func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("usage: ... -- <outFolder> [prefix]")
		quit(2)
		return
	outFolder = args[0]
	if args.size() > 1:
		prefix = args[1]
	if not DirAccess.dir_exists_absolute(outFolder):
		print("out folder does not exist: " + outFolder)
		quit(2)
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	appData = root.get_node("AppData")
	print("render size %s" % str(root.get_visible_rect().size))

	var heat: Dictionary = _heatOf(sampleWeek)
	var ghost: Dictionary = _heatOf(ghostEntries)

	# every body x colouring, front | back | both
	for bodyName in ["male", "female"]:
		for colouring in ["infrared", "scarlet", "ember"]:
			var views: Array = []
			for view in ["front", "back", "both"]:
				views.append(_viewSpec(bodyName, view, colouring, "%s %s - %s" % [bodyName, view, colouring]))
			await _plate("%s_%s" % [bodyName, colouring], views, heat, {})

	# ghost preview over real heat, at the bright and the dim end of its pulse
	await _plate("ghost", [
		_viewSpec("male", "both", "infrared", "ghost - pulse bright"),
		_viewSpec("male", "both", "infrared", "ghost - pulse dim", {"ghostPhase": 0.0}),
		_viewSpec("female", "front", "ember", "ghost on ember, no heat", {"noHeat": true}),
	], heat, ghost)

	# zoom, hidden untouched, selection
	await _plate("zoomUntouched", [
		_viewSpec("male", "front", "infrared", "zoom x3 on the chest", {"zoom": 3.0, "zoomRegion": "upperChest"}),
		_viewSpec("female", "back", "infrared", "untouched hidden", {"hideUntouched": true, "light": true}),
		_viewSpec("male", "both", "infrared", "selected: lats", {"selected": "lats"}),
	], heat, {})

	# edges up close: the deepest zoom, with a selection, and the ghost zoomed in
	await _plate("zoomEdges", [
		_viewSpec("male", "front", "infrared", "zoom x6, selected: lower chest", {"zoom": 6.0, "zoomRegion": "lowerChest", "selected": "lowerChest"}),
		_viewSpec("female", "back", "ember", "zoom x6 on the glutes", {"zoom": 6.0, "zoomRegion": "glutes"}),
		_viewSpec("male", "back", "scarlet", "zoom x2.5, selected: lats", {"zoom": 2.5, "zoomRegion": "lats", "selected": "lats"}),
	], heat, {})
	await _plate("zoomGhost", [
		_viewSpec("male", "front", "infrared", "ghost zoom x4 on the abs", {"zoom": 4.0, "zoomRegion": "lowerAbs"}),
		_viewSpec("male", "back", "infrared", "ghost zoom x3 on lower traps", {"zoom": 3.0, "zoomRegion": "lowerTraps"}),
		_viewSpec("female", "front", "ember", "ghost x1.5, no heat", {"zoom": 1.5, "zoomRegion": "upperAbs", "noHeat": true}),
	], heat, ghost)

	# the placeholder home in all four themes
	await _homePlate("themesA", ["ember", "ocean", "forest"])
	await _homePlate("themesB", ["light"])

	print("SHOTS %d" % shots.size())
	for path in shots:
		print("  " + path)
	print("body maps loaded: %s" % str(appData.mapCache.keys()))
	quit(0)


### /// HELPERS ///

func _heatOf(rows: Array) -> Dictionary:
	var entries: Array = []
	for row in rows:
		entries.append({"exerciseId": row[0], "sets": row[1], "grips": false})
	return HeatEngine.effectiveSets(entries, appData.exerciseById)


func _viewSpec(bodyName: String, view: String, colouring: String, caption: String, extra: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = {"body": bodyName, "view": view, "colouring": colouring, "caption": caption}
	spec.merge(extra)
	return spec


func _clearHolder() -> void:
	if holder != null:
		holder.free()
	holder = Control.new()
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _grab(name: String) -> void:
	for _frame in range(settleFrames):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = outFolder.path_join("%s_%s.png" % [prefix, name])
	root.get_texture().get_image().save_png(path)
	shots.append(path)


func _plate(name: String, specs: Array, heat: Dictionary, ghost: Dictionary) -> void:
	### WHAT THIS DOES
	# one screenshot: a caption + a BodyView per column, configured from its spec

	var height: float = root.get_visible_rect().size.y
	var views: Array = []

	_clearHolder()
	var backdrop := ColorRect.new()
	backdrop.color = root.get_node("AppTheme").colour("bg")
	holder.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var caption := Label.new()
		caption.text = spec["caption"]
		caption.position = Vector2(index * columnWidth + 12.0, 6.0)
		holder.add_child(caption)
		var bodyView := BodyView.new()
		bodyView.position = Vector2(index * columnWidth, captionHeight)
		bodyView.size = Vector2(columnWidth, height - captionHeight)
		bodyView.body = spec["body"]
		bodyView.viewMode = spec["view"]
		bodyView.rangeMax = plateRange
		bodyView.gradientId = spec["colouring"]
		bodyView.hideUntouched = bool(spec.get("hideUntouched", false))
		bodyView.selectedRegion = str(spec.get("selected", ""))
		holder.add_child(bodyView)
		if bool(spec.get("noHeat", false)):
			bodyView.setHeat({}, false)
		elif bool(spec.get("light", false)):
			bodyView.setHeat({"glutes": 6.0, "hamstrings": 4.0, "lats": 9.0}, false)
		else:
			bodyView.setHeat(heat, false)
		if ghost.size() > 0:
			bodyView.setGhost(ghost)
		views.append([bodyView, spec])

	# poses that need the layout done first
	await process_frame
	for pair in views:
		var bodyView: BodyView = pair[0]
		var spec: Dictionary = pair[1]
		if spec.has("zoom"):
			bodyView.zoomAt(bodyView.regionCentre(spec["zoomRegion"]), spec["zoom"])
		if ghost.size() > 0:
			# freeze the pulse at a known point (bright by default)
			bodyView.set_process(false)
			bodyView.ghostClock = bodyView.ghostPulseSeconds * float(spec.get("ghostPhase", 0.5))
			bodyView.queue_redraw()
	await _grab(name)
	for pair in views:
		print("  %s: zoom %.2f, ghost regions %d" % [pair[1]["caption"], pair[0].zoom, pair[0].ghostHeat.size()])


func _homePlate(name: String, themeIds: Array) -> void:
	### WHAT THIS DOES
	# the placeholder home scene in a column per theme (each column carries its own Theme)

	var height: float = root.get_visible_rect().size.y
	_clearHolder()
	for index in range(themeIds.size()):
		var column := Control.new()
		column.position = Vector2(index * columnWidth, 0.0)
		column.size = Vector2(columnWidth, height)
		column.theme = root.get_node("AppTheme").buildTheme(themeIds[index])
		holder.add_child(column)
		var home: Control = load("res://app/main.tscn").instantiate()
		column.add_child(home)
	await create_timer(homeSettleSeconds).timeout
	await _grab(name)
