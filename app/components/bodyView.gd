class_name BodyView
extends Control
## BodyView - the flat heat-map body, front / back / both side by side
## what this offers
## properties (set any time, it redraws):
##   body "male"/"female", viewMode "front"/"back"/"both",
##   gradientId (HeatGradients preset), rangeMax (amount mode: 0..rangeMax spans the gradient, above clips),
##   hideUntouched (0-set regions stay plain body colour), selectedRegions (each outlined), interactive
##   (false = a picture only, e.g. thumbnails: no taps, no zoom)
## functions:
##   setHeat(regionId -> effective sets, animate = true)   colours blend smoothly to the new values
##   setGhost(regionId -> sets)                             pulsing dashed outline + translucent fill
##                                                          (a preview, clearly not real heat); {} clears
##   flashRegion(regionId, strength = 1.0)                  the region lights up towards white and fades
##                                                          back over flashSeconds (the week replay)
##   resetZoom(animate = true), zoomAt(localPoint, factor), regionAt(localPoint) -> regionId or ""
##   regionCentre(regionId) -> local point well inside the region's biggest piece (Vector2.INF if not shown)
##   heatShown() -> the values currently drawn (mid-animation too)
##   heightToFitWidth(width) -> the height at which the current view fills that width exactly
##   setVessels({"red": 0..1, "blue": 0..1})              the cardio overlay (VesselLayer) over the
##                                                          figures, which fade toward the card under it; {} hides
## signals: regionTapped(regionId), regionLongPressed(regionId), emptyTapped(), zoomChanged(zoom)
## input: tap a region (finger or mouse); hold one still for longPressSeconds = a long press (only
##   when something listens to regionLongPressed; the tap is then dropped); two-finger pinch zoom + pan; mouse wheel zooms at the
##   cursor; one finger / mouse drag pans while zoomed; double tap resets the zoom
##   (while zoomed a single tap waits doubleTapSeconds to see if a second one comes)
## inside a KineticScroll: claims the drag only while zoomed or pinching, so the page still scrolls
## drawing: each figure is ONE baked region map (AppData.bodyMap) drawn through bodyMap.gdshader; the
##   colours live in a tiny palette texture rewritten when the heat changes - nothing geometric is
##   computed here. Taps are tested against the baked tap shapes (at most 32 corners each)
## colours come from the theme type "App" (bodyPlain, bodyCosmetic, bodyGap, ghost, text)

signal regionTapped(regionId: String)
signal regionLongPressed(regionId: String)
signal emptyTapped()
signal zoomChanged(zoom: float)

### /// TUNING ///

# seconds a heat change takes to blend to the new colours
var transitionSeconds: float = 0.9
# gap between the front and back figure in "both" mode, as a fraction of the width
var pairGap: float = 0.04
# empty margin around the figures, in px
var edgeMargin: float = 6.0
# sets below this count as untouched (for hideUntouched)
var untouchedBelow: float = 0.01
# ghost preview: seconds of one pulse, fill strength range, outline width in px
# (dash length and gap are baked into the maps - tools/appData/bakeBodyMaps.py)
var ghostPulseSeconds: float = 1.3
var ghostFillLow: float = 0.18
var ghostFillHigh: float = 0.5
var ghostOutlinePx: float = 2.2
# outline width of the selected region and of the dark halo under it, in px
var selectedOutlinePx: float = 2.5
var selectedHaloPx: float = 6.0
# zoom limits and mouse wheel step
var zoomMin: float = 1.0
var zoomMax: float = 6.0
var wheelZoomStep: float = 1.18
# seconds the double-tap zoom reset takes
var resetSeconds: float = 0.28
# a press that moves more than this many px is not a tap
var tapMovePx: float = 14.0
# a press held longer than this is not a tap
var tapMaxSeconds: float = 0.6
# a still press held this long is a long press (and buzzes on a phone)
var longPressSeconds: float = 0.45
var longPressBuzzMs: int = 30
# how much the figures fade toward the card colour while the cardio vessels are drawn over them
var vesselDim: float = 0.5
# two taps closer than this in time and space are a double tap
var doubleTapSeconds: float = 0.3
var doubleTapDistancePx: float = 40.0
# a tap landing in a seam still counts for a region within this many px
var hitTolerancePx: float = 9.0
# flash (flashRegion): seconds it takes to fade, the colour it lights towards and how far at full strength
var flashSeconds: float = 0.5
var flashColour: Color = Color(1.0, 0.97, 0.9)
var flashMix: float = 0.75
# palette width (map ids 0..paletteSize-1)
const paletteSize: int = 64

### /// SHARED ///

const mapShader: Shader = preload("res://app/components/bodyMap.gdshader")

### /// PUBLIC STATE ///

var body: String = "male": set = _setBody
var viewMode: String = "front": set = _setViewMode
var gradientId: String = "infrared": set = _setGradientId
var rangeMax: float = 10.0: set = _setRangeMax
var hideUntouched: bool = false: set = _setHideUntouched
var selectedRegions: Array = []: set = _setSelectedRegions
var interactive: bool = true: set = _setInteractive

### /// INTERNAL STATE ///

var slots: Array = []
var shownHeat: Dictionary = {}
var fromHeat: Dictionary = {}
var toHeat: Dictionary = {}
var blendProgress: float = 1.0
var ghostHeat: Dictionary = {}
var ghostClock: float = 0.0
var flashLevels: Dictionary = {}
var regionColours: Dictionary = {}
var mapMaterial: ShaderMaterial = null
var paletteImage: Image = null
var paletteTexture: ImageTexture = null
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var zoomFrom: float = 1.0
var panFrom: Vector2 = Vector2.ZERO
var zoomProgress: float = 1.0
var touches: Dictionary = {}
var pinching: bool = false
var pinchStartDistance: float = 1.0
var pinchStartZoom: float = 1.0
var pinchStartCentre: Vector2 = Vector2.ZERO
var pinchStartPan: Vector2 = Vector2.ZERO
var pinchedThisPress: bool = false
var mouseDown: bool = false
var pressPos: Vector2 = Vector2.ZERO
var pressTime: float = 0.0
var pressMaxMove: float = 0.0
var panAtPress: Vector2 = Vector2.ZERO
var lastTapTime: float = -10.0
var lastTapPos: Vector2 = Vector2.ZERO
var pendingTapActive: bool = false
var pendingTapRegion: String = ""
var pendingTapAt: float = 0.0
var longPressFired: bool = false
var vesselLayer: VesselLayer = null


func _init() -> void:
	### WHAT THIS DOES
	# one shader material + palette per BodyView (thumbnails each carry their own heat)

	paletteImage = Image.create(paletteSize, 2, false, Image.FORMAT_RGBA8)
	paletteTexture = ImageTexture.create_from_image(paletteImage)
	mapMaterial = ShaderMaterial.new()
	mapMaterial.shader = mapShader
	mapMaterial.set_shader_parameter("palette", paletteTexture)
	material = mapMaterial
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	add_to_group("kineticClaimers")
	_applyInteractive()
	resized.connect(_layoutSlots)
	_layoutSlots()
	_updateColours()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_updateColours()


### /// SETTERS ///

func _setBody(value: String) -> void:
	body = value
	_layoutSlots()


func _setViewMode(value: String) -> void:
	viewMode = value
	_layoutSlots()


func _setGradientId(value: String) -> void:
	gradientId = value
	_updateColours()


func _setRangeMax(value: float) -> void:
	rangeMax = maxf(value, 0.001)
	_updateColours()


func _setHideUntouched(value: bool) -> void:
	hideUntouched = value
	_updateColours()


func _setSelectedRegions(value: Array) -> void:
	selectedRegions = value.duplicate()
	_writePalette()


func _setInteractive(value: bool) -> void:
	interactive = value
	_applyInteractive()


func _applyInteractive() -> void:
	if interactive:
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


### /// HEAT ///

func setHeat(heat: Dictionary, animate: bool = true) -> void:
	### WHAT THIS DOES
	# new values per region; with animate the colours blend over transitionSeconds

	fromHeat = shownHeat.duplicate()
	toHeat = heat.duplicate()
	if animate and is_inside_tree() and transitionSeconds > 0.0:
		blendProgress = 0.0
		set_process(true)
	else:
		blendProgress = 1.0
		shownHeat = toHeat.duplicate()
		_updateColours()


func heatShown() -> Dictionary:
	return shownHeat


func setGhost(ghost: Dictionary) -> void:
	ghostHeat = {}
	for regionId in ghost:
		if float(ghost[regionId]) > untouchedBelow:
			ghostHeat[regionId] = float(ghost[regionId])
	if ghostHeat.size() > 0:
		set_process(true)
	_writePalette()


func setVessels(levels: Dictionary) -> void:
	### WHAT THIS DOES
	# the cardio overlay: made on first use, drawn above the figures; the figures dim under it

	if vesselLayer == null and levels.size() > 0:
		vesselLayer = VesselLayer.new()
		vesselLayer.bodyView = self
		add_child(vesselLayer)
	if vesselLayer != null:
		vesselLayer.setLevels(levels)
	var dim: float = 0.0
	if levels.size() > 0:
		dim = vesselDim
	mapMaterial.set_shader_parameter("dim", dim)
	queue_redraw()


func flashRegion(regionId: String, strength: float = 1.0) -> void:
	# lights the region up at once; _process fades it back
	flashLevels[regionId] = maxf(float(flashLevels.get(regionId, 0.0)), clampf(strength, 0.0, 1.0))
	set_process(true)
	_writePalette()


func _blendHeat() -> void:
	# shownHeat = smooth mix of fromHeat and toHeat at blendProgress
	var eased: float = smoothstep(0.0, 1.0, blendProgress)
	var keys: Dictionary = {}
	for regionId in fromHeat:
		keys[regionId] = true
	for regionId in toHeat:
		keys[regionId] = true
	shownHeat = {}
	for regionId in keys:
		var a: float = float(fromHeat.get(regionId, 0.0))
		var b: float = float(toHeat.get(regionId, 0.0))
		shownHeat[regionId] = lerpf(a, b, eased)


func _themeColour(key: String, fallback: Color) -> Color:
	if has_theme_color(key, "App"):
		return get_theme_color(key, "App")
	return fallback


func _updateColours() -> void:
	### WHAT THIS DOES
	# one colour per region from the shown heat and the gradient, then into the palette

	var plain: Color = _themeColour("bodyPlain", Color("#3a3d45"))
	var appData: Node = _appData()

	regionColours = {}
	if appData == null:
		return
	for regionId in appData.regionIds:
		var sets: float = float(shownHeat.get(regionId, 0.0))
		var colourHere: Color = plain
		if hideUntouched and sets < untouchedBelow:
			colourHere = plain
		else:
			colourHere = plain.blend(HeatGradients.amountColour(gradientId, sets, rangeMax))
		regionColours[regionId] = colourHere
	_writePalette()


func _writePalette() -> void:
	### WHAT THIS DOES
	# row 0: colour per map id (outside clear, seam, cosmetic, regions); row 1: ghost strength (red)
	# and selected (green) per id; plus the theme colours the shader draws outlines in

	var appData: Node = _appData()
	var gapColour: Color = _themeColour("bodyGap", Color("#0b0c0f"))
	var cosmeticColour: Color = _themeColour("bodyCosmetic", Color("#2a2c33"))
	var plain: Color = _themeColour("bodyPlain", Color("#3a3d45"))

	if appData == null:
		return
	paletteImage.fill(Color(0.0, 0.0, 0.0, 0.0))
	paletteImage.set_pixel(appData.mapGapId, 0, gapColour)
	paletteImage.set_pixel(appData.mapCosmeticId, 0, cosmeticColour)
	for regionId in appData.regionIds:
		var mapId: int = appData.mapIdOf(regionId)
		var colourHere: Color = regionColours.get(regionId, plain)
		if flashLevels.has(regionId):
			var fade: float = float(flashLevels[regionId])
			colourHere = colourHere.lerp(flashColour, flashMix * fade * fade)
		paletteImage.set_pixel(mapId, 0, colourHere)
		var flags: Color = Color(0.0, 0.0, 0.0, 1.0)
		if ghostHeat.has(regionId):
			flags.r = 0.35 + 0.65 * clampf(float(ghostHeat[regionId]) / rangeMax, 0.0, 1.0)
		if selectedRegions.has(regionId):
			flags.g = 1.0
		paletteImage.set_pixel(mapId, 1, flags)
	paletteTexture.update(paletteImage)

	mapMaterial.set_shader_parameter("outlinesOn", selectedRegions.size() > 0 or ghostHeat.size() > 0)
	mapMaterial.set_shader_parameter("ghostColour", _themeColour("ghost", Color("#7ff0ff")))
	mapMaterial.set_shader_parameter("haloColour", gapColour)
	var card: Color = _themeColour("surface", Color("#16181d"))
	mapMaterial.set_shader_parameter("dimColour", Vector3(card.r, card.g, card.b))
	mapMaterial.set_shader_parameter("lineColour", Color.WHITE)
	mapMaterial.set_shader_parameter("selectedOutlinePx", selectedOutlinePx)
	mapMaterial.set_shader_parameter("selectedHaloPx", selectedHaloPx)
	mapMaterial.set_shader_parameter("ghostOutlinePx", ghostOutlinePx)
	mapMaterial.set_shader_parameter("ghostFillLow", ghostFillLow)
	mapMaterial.set_shader_parameter("ghostFillHigh", ghostFillHigh)
	mapMaterial.set_shader_parameter("ghostDashShare", appData.mapDashShare)
	mapMaterial.set_shader_parameter("edgeSteps", appData.mapEdgeSteps)
	_writePulse()
	queue_redraw()


func _writePulse() -> void:
	var pulse: float = 0.5 - 0.5 * cos(TAU * ghostClock / maxf(ghostPulseSeconds, 0.05))
	mapMaterial.set_shader_parameter("pulse", pulse)


func _appData() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/AppData")


### /// LAYOUT ///

func _viewList() -> Array:
	if viewMode == "back":
		return ["back"]
	if viewMode == "both":
		return ["front", "back"]
	return ["front"]


func heightToFitWidth(width: float) -> float:
	### WHAT THIS DOES
	# the control height at which the figure(s) exactly fill the given width - lets a card size
	# itself so "both" mode wastes no space above and below the figures (0 if nothing to draw)

	var views: Array = _viewList()
	var innerWidth: float = width - edgeMargin * 2.0
	var gap: float = 0.0
	var tallest: float = 0.0
	var widest: float = 0.0
	var appData: Node = _appData()

	if appData == null:
		return 0.0
	if views.size() == 2:
		gap = pairGap * innerWidth
	var slotWidth: float = (innerWidth - gap * (views.size() - 1)) / views.size()
	for view in views:
		var data: Dictionary = appData.bodyView(body, view)
		if data.is_empty():
			return 0.0
		var bounds: Rect2 = data["bounds"]
		tallest = maxf(tallest, bounds.size.y)
		widest = maxf(widest, bounds.size.x)
	if widest <= 0.0 or slotWidth <= 0.0:
		return 0.0
	return tallest * slotWidth / widest + edgeMargin * 2.0


func _layoutSlots() -> void:
	### WHAT THIS DOES
	# fits the figure(s) into the control: one shared scale, each centred in its half

	var views: Array = _viewList()
	var inner: Rect2 = Rect2(Vector2(edgeMargin, edgeMargin), size - Vector2(edgeMargin, edgeMargin) * 2.0)
	var gap: float = 0.0
	var fitScale: float = INF
	var datas: Array = []
	var appData: Node = _appData()

	slots = []
	if appData == null or inner.size.x <= 1.0 or inner.size.y <= 1.0:
		queue_redraw()
		return
	if views.size() == 2:
		gap = pairGap * inner.size.x
	var slotWidth: float = (inner.size.x - gap * (views.size() - 1)) / views.size()
	for view in views:
		var data: Dictionary = appData.bodyView(body, view)
		if data.is_empty():
			queue_redraw()
			return
		datas.append(data)
		var bounds: Rect2 = data["bounds"]
		fitScale = minf(fitScale, minf(slotWidth / bounds.size.x, inner.size.y / bounds.size.y))
	for index in range(views.size()):
		var bounds: Rect2 = datas[index]["bounds"]
		var slotRect: Rect2 = Rect2(inner.position.x + index * (slotWidth + gap), inner.position.y, slotWidth, inner.size.y)
		var drawn: Vector2 = bounds.size * fitScale
		var origin: Vector2 = slotRect.position + (slotRect.size - drawn) * 0.5 - bounds.position * fitScale
		slots.append({
			"view": views[index],
			"data": datas[index],
			"map": appData.bodyMap(body, views[index]),
			"scale": fitScale,
			"xf": Transform2D(0.0, Vector2(fitScale, fitScale), 0.0, origin),
		})
	_clampPan()
	queue_redraw()


### /// DRAWING ///

func _draw() -> void:
	### WHAT THIS DOES
	# one textured rect per figure through the map shader (seams, colours, ghost and selection
	# all come out of the shader); a missing map draws a loud red block instead

	_writePulse()
	for slot in slots:
		var data: Dictionary = slot["data"]
		var viewXf: Transform2D = Transform2D(0.0, Vector2(zoom, zoom), 0.0, pan) * slot["xf"]
		var unitScale: float = slot["scale"] * zoom
		var appData: Node = _appData()
		mapMaterial.set_shader_parameter("texelsPerPx", appData.mapTexelsPerUnit / maxf(unitScale, 0.0001))
		draw_set_transform_matrix(viewXf)
		if slot["map"] == null:
			draw_rect(data["bounds"], Color.RED)
			continue
		draw_texture_rect(slot["map"], data["mapRect"], false)
	draw_set_transform_matrix(Transform2D())


func _process(delta: float) -> void:
	### WHAT THIS DOES
	# heat blend, flashes fading, zoom reset animation, ghost pulse, delayed single tap - sleeps when idle

	var busy: bool = false

	if flashLevels.size() > 0:
		for regionId in flashLevels.keys():
			var level: float = float(flashLevels[regionId]) - delta / maxf(flashSeconds, 0.05)
			if level <= 0.0:
				flashLevels.erase(regionId)
			else:
				flashLevels[regionId] = level
		busy = true
	if blendProgress < 1.0:
		blendProgress = minf(blendProgress + delta / transitionSeconds, 1.0)
		_blendHeat()
		_updateColours()
		busy = true
	elif busy:
		_writePalette()
	if zoomProgress < 1.0:
		zoomProgress = minf(zoomProgress + delta / resetSeconds, 1.0)
		var eased: float = smoothstep(0.0, 1.0, zoomProgress)
		zoom = lerpf(zoomFrom, 1.0, eased)
		pan = panFrom.lerp(Vector2.ZERO, eased)
		zoomChanged.emit(zoom)
		queue_redraw()
		busy = true
	if ghostHeat.size() > 0:
		ghostClock += delta
		_writePulse()
		busy = true
	if pendingTapActive:
		busy = true
		if _now() >= pendingTapAt:
			pendingTapActive = false
			_emitTap(pendingTapRegion)
	if _watchingLongPress():
		busy = true
		_checkLongPress()
	if not busy:
		set_process(false)


### /// ZOOM AND PAN ///

func zoomAt(localPoint: Vector2, factor: float) -> void:
	# zooms by factor keeping the drawing under localPoint still
	var newZoom: float = clampf(zoom * factor, zoomMin, zoomMax)
	var basePoint: Vector2 = (localPoint - pan) / zoom
	zoomProgress = 1.0
	zoom = newZoom
	pan = localPoint - basePoint * zoom
	_clampPan()
	zoomChanged.emit(zoom)
	queue_redraw()


func resetZoom(animate: bool = true) -> void:
	if animate and is_inside_tree():
		zoomFrom = zoom
		panFrom = pan
		zoomProgress = 0.0
		set_process(true)
	else:
		zoomProgress = 1.0
		zoom = 1.0
		pan = Vector2.ZERO
		zoomChanged.emit(zoom)
		queue_redraw()


func isZoomed() -> bool:
	return zoom > 1.001


func _clampPan() -> void:
	# the zoomed drawing always covers the whole control (no empty edges dragged in)
	pan.x = clampf(pan.x, size.x * (1.0 - zoom), 0.0)
	pan.y = clampf(pan.y, size.y * (1.0 - zoom), 0.0)


### /// HIT TESTING ///

func regionAt(localPoint: Vector2) -> String:
	### WHAT THIS DOES
	# the region under a point; in a seam, the region most of a small ring around it lands on

	var basePoint: Vector2 = (localPoint - pan) / zoom
	var votes: Dictionary = {}
	var best: String = ""
	var bestVotes: int = 0
	var reach: float = hitTolerancePx / zoom

	var direct: String = _regionAtBase(basePoint)
	if direct != "":
		return direct
	for step in range(8):
		var angle: float = TAU * step / 8.0
		var probe: Vector2 = basePoint + Vector2(cos(angle), sin(angle)) * reach
		var hit: String = _regionAtBase(probe)
		if hit != "":
			votes[hit] = int(votes.get(hit, 0)) + 1
			if votes[hit] > bestVotes:
				bestVotes = votes[hit]
				best = hit
	return best


func _regionAtBase(basePoint: Vector2) -> String:
	# tap shapes only (baked, at most 32 corners each); the last drawn piece wins an overlap
	for slot in slots:
		var data: Dictionary = slot["data"]
		var model: Vector2 = slot["xf"].affine_inverse() * basePoint
		var taps: Array = data["taps"]
		for index in range(taps.size() - 1, -1, -1):
			var tap: Dictionary = taps[index]
			if not tap["box"].has_point(model):
				continue
			if Geometry2D.is_point_in_polygon(model, tap["polygon"]):
				return tap["region"]
	return ""


func regionCentre(regionId: String) -> Vector2:
	# the baked most-inside point of the region's biggest piece, in local coordinates
	for slot in slots:
		var data: Dictionary = slot["data"]
		if not data["centres"].has(regionId):
			continue
		var basePoint: Vector2 = slot["xf"] * data["centres"][regionId]
		return basePoint * zoom + pan
	return Vector2.INF


### /// INPUT ///

func claimsDrag(_globalPoint: Vector2) -> bool:
	# KineticScroll asks before scrolling: the body keeps the finger while zoomed or pinching
	return interactive and (isZoomed() or touches.size() >= 2)


func claimsWheel(_globalPoint: Vector2) -> bool:
	return interactive


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenTouch:
		_onTouch(event)
	elif event is InputEventScreenDrag:
		_onTouchDrag(event)
	elif event is InputEventMouseButton:
		_onMouseButton(event)
	elif event is InputEventMouseMotion:
		_onMouseMotion(event)
	elif event is InputEventMagnifyGesture:
		zoomAt(event.position, event.factor)
		accept_event()


func _onTouch(event: InputEventScreenTouch) -> void:
	### WHAT THIS DOES
	# tracks fingers; a second finger starts a pinch and cancels any tap

	if event.pressed:
		touches[event.index] = event.position
	else:
		touches.erase(event.index)
	if touches.size() >= 2:
		_startPinch()
		pinchedThisPress = true
	else:
		pinching = false
	accept_event()


func _startPinch() -> void:
	var keys: Array = touches.keys()
	keys.sort()
	var a: Vector2 = touches[keys[0]]
	var b: Vector2 = touches[keys[1]]
	pinching = true
	pinchStartDistance = maxf(a.distance_to(b), 1.0)
	pinchStartZoom = zoom
	pinchStartCentre = (a + b) * 0.5
	pinchStartPan = pan
	zoomProgress = 1.0


func _onTouchDrag(event: InputEventScreenDrag) -> void:
	### WHAT THIS DOES
	# two fingers: zoom by their spread, pan by their centre; one finger: pan while zoomed

	var previous: Vector2 = touches.get(event.index, event.position)
	touches[event.index] = event.position
	if pinching and touches.size() >= 2:
		var keys: Array = touches.keys()
		keys.sort()
		var a: Vector2 = touches[keys[0]]
		var b: Vector2 = touches[keys[1]]
		var newZoom: float = clampf(pinchStartZoom * a.distance_to(b) / pinchStartDistance, zoomMin, zoomMax)
		var basePoint: Vector2 = (pinchStartCentre - pinchStartPan) / pinchStartZoom
		zoom = newZoom
		pan = (a + b) * 0.5 - basePoint * zoom
		_clampPan()
		zoomChanged.emit(zoom)
		queue_redraw()
	elif touches.size() == 1 and isZoomed():
		pan += event.position - previous
		_clampPan()
		queue_redraw()
	accept_event()


func _onMouseButton(event: InputEventMouseButton) -> void:
	### WHAT THIS DOES
	# left button = tap detection (mouse, or a finger's emulated mouse); wheel = zoom

	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoomAt(event.position, wheelZoomStep)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoomAt(event.position, 1.0 / wheelZoomStep)
		accept_event()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		mouseDown = true
		pressPos = event.position
		pressTime = _now()
		pressMaxMove = 0.0
		panAtPress = pan
		longPressFired = false
		if touches.size() <= 1:
			pinchedThisPress = false
		if _watchingLongPress():
			set_process(true)
	else:
		var wasDown: bool = mouseDown
		mouseDown = false
		var quick: bool = _now() - pressTime <= tapMaxSeconds
		if wasDown and quick and not pinchedThisPress and not longPressFired and pressMaxMove <= tapMovePx:
			_onTap(event.position)
	accept_event()


func _watchingLongPress() -> bool:
	# a press is still down, still, not a pinch, not fired yet - and someone listens
	if not mouseDown or longPressFired or pinchedThisPress:
		return false
	return regionLongPressed.get_connections().size() > 0


func _checkLongPress() -> void:
	### WHAT THIS DOES
	# once the still press has lasted longPressSeconds: buzz and report the region under it (the
	# release then is not a tap)

	if pressMaxMove > tapMovePx or touches.size() >= 2:
		return
	if _now() - pressTime < longPressSeconds:
		return
	longPressFired = true
	var regionId: String = regionAt(pressPos)
	if regionId == "":
		return
	Input.vibrate_handheld(longPressBuzzMs)
	regionLongPressed.emit(regionId)


func _onMouseMotion(event: InputEventMouseMotion) -> void:
	if not mouseDown:
		return
	pressMaxMove = maxf(pressMaxMove, event.position.distance_to(pressPos))
	# a real mouse pans while zoomed; fingers pan through _onTouchDrag
	if event.device != InputEvent.DEVICE_ID_EMULATION and isZoomed():
		pan = panAtPress + (event.position - pressPos)
		_clampPan()
		queue_redraw()
	accept_event()


func _onTap(localPoint: Vector2) -> void:
	### WHAT THIS DOES
	# a double tap resets the zoom; a single tap picks a region (delayed while zoomed, so the
	# first half of a double tap does not open anything)

	var now: float = _now()
	if now - lastTapTime <= doubleTapSeconds and localPoint.distance_to(lastTapPos) <= doubleTapDistancePx:
		lastTapTime = -10.0
		pendingTapActive = false
		if isZoomed():
			resetZoom(true)
		return
	lastTapTime = now
	lastTapPos = localPoint
	var regionId: String = regionAt(localPoint)
	if isZoomed():
		pendingTapActive = true
		pendingTapRegion = regionId
		pendingTapAt = now + doubleTapSeconds
		set_process(true)
	else:
		_emitTap(regionId)


func _emitTap(regionId: String) -> void:
	if regionId == "":
		emptyTapped.emit()
	else:
		regionTapped.emit(regionId)
