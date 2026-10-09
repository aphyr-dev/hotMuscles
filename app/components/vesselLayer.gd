class_name VesselLayer
extends Control
## VesselLayer - the cardio overlay over a BodyView: two vessel networks along the figure, red
## (arteries) for hard cardio and blue (veins) for easy cardio, each as bright as its light is full
## what this offers
## - setLevels({"red": 0..1, "blue": 0..1})   how full each light is (minutes / target, capped at 1);
##                                            an empty light still shows faintly, a lit one carries a
##                                            travelling pulse; the front view gets a beating heart
## - lives as a child of BodyView (BodyView.setVessels makes it) and reads its slots, zoom and pan
## - the paths run through each region's left / right anchor (AppData.bodyView anchors), so they follow
##   whichever body and view is shown; colours are a code, not anatomy (the research note says so)
## - the style decides the finish (AppStyle.glassVessels): flat crisp lines, or glassy glowing tubes

### /// TUNING ///

# the two networks
const redColour: Color = Color("#ff3b55")
const blueColour: Color = Color("#3f8cff")
# line width as a share of the figure height (at the card's own zoom), and the thinnest it gets in px
const lineWidthShare: float = 0.006
const minLineWidth: float = 1.8
# the dark outline under each vessel (its own colour, darkened): width as a multiple of the line
# width, how much darker, and how opaque
const underWidthScale: float = 1.55
const underDarken: float = 0.6
const underAlpha: float = 0.9
# glassy finish only: the soft glow around each vessel (x line width) and the white shine along it
const glowWidthScale: float = 3.4
const glowAlpha: float = 0.25
const shineWidthScale: float = 0.32
const shineAlpha: float = 0.55
# how strong an empty network still shows (0..1), and how much a full one whitens its core
const emptyStrength: float = 0.28
const fullWhiten: float = 0.3
# red and blue run side by side: their distance from the path, as a share of the figure height
const pairOffsetShare: float = 0.0045
# points per smoothed stretch between two anchors
const smoothSteps: int = 6
# the travelling pulse: share of a vessel per second, its dot size (x line width), and its glow size
const pulseSpeed: float = 0.35
const pulseDotScale: float = 2.0
const pulseGlowScale: float = 4.0
# the heart (front view): size as a share of the figure height, and seconds per beat
const heartSizeShare: float = 0.012
const heartBeatSeconds: float = 0.85

### /// STATE ///

var bodyView: Control = null
var levels: Dictionary = {}
var clock: float = 0.0
var chainCache: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setLevels(newLevels: Dictionary) -> void:
	levels = newLevels.duplicate()
	visible = levels.size() > 0
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	# the pulse and the heart move; nothing runs while the layer is hidden
	if not is_visible_in_tree():
		return
	clock += delta
	queue_redraw()


### /// THE PATHS ///

func _networks(data: Dictionary) -> Dictionary:
	### WHAT THIS DOES
	# the vessels of one figure, built once per body view: {"chains": [{points, sides}], "heart":
	# Vector2 or INF}; each chain is the centre line of a red + blue pair, outward from the trunk

	var key: String = str(data.get("mapFile", ""))
	if chainCache.has(key):
		return chainCache[key]
	var anchors: Dictionary = data.get("anchors", {})
	var bounds: Rect2 = data["bounds"]
	var height: float = bounds.size.y
	var top: float = bounds.position.y
	var bottom: float = bounds.end.y
	var axis: float = bounds.get_center().x
	var chains: Array = []
	var heart: Vector2 = Vector2.INF
	var front: bool = anchors.has("upperChest")

	if anchors.has("neck") and anchors["neck"].has("l") and anchors["neck"].has("r"):
		axis = (anchors["neck"]["l"].x + anchors["neck"]["r"].x) * 0.5

	# the trunk, down the middle
	var neckBase: Vector2 = Vector2(axis, _y(anchors, "upperTraps", top + 0.24 * height))
	var trunk: Array = [neckBase]
	var pelvis: Vector2 = Vector2.ZERO
	if front:
		var chestY: float = _y(anchors, "upperChest", neckBase.y)
		var lowY: float = _y(anchors, "lowerChest", chestY)
		heart = Vector2(axis + 0.03 * height, lerpf(chestY, lowY, 0.6))
		pelvis = Vector2(axis, _y(anchors, "hipFlexors", bottom) - 0.04 * height)
		trunk.append(Vector2(axis, lerpf(chestY, lowY, 0.6)))
		trunk.append(Vector2(axis, _y(anchors, "upperAbs", lowY)))
		trunk.append(Vector2(axis, _y(anchors, "lowerAbs", lowY)))
	else:
		pelvis = Vector2(axis, _y(anchors, "gluteMed", bottom))
		trunk.append(Vector2(axis, _y(anchors, "midTraps", neckBase.y)))
		trunk.append(Vector2(axis, _y(anchors, "lowerTraps", neckBase.y)))
		trunk.append(Vector2(axis, _y(anchors, "lowerBack", neckBase.y)))
	trunk.append(pelvis)
	chains.append({"points": trunk, "side": 1.0})

	# each side: head, arm, torso branch, leg (mirrored, so red and blue swap sides with it)
	for side in ["l", "r"]:
		var sideSign: float = -1.0
		if side == "r":
			sideSign = 1.0
		var neckSide: Vector2 = _at(anchors, "neck", side)
		if neckSide != Vector2.INF:
			var spread: float = neckSide.x - axis
			chains.append({"side": sideSign, "points": [neckBase, neckSide, Vector2(axis + spread * 1.3, top + 0.12 * height), Vector2(axis + spread * 1.5, top + 0.06 * height)]})
		var arm: Array = [neckBase]
		var elbowRegion: String = "triceps"
		var shoulderRegions: Array = ["upperTraps", "rearDelt"]
		if front:
			elbowRegion = "biceps"
			shoulderRegions = ["upperChest", "frontDelt"]
		for regionId in shoulderRegions:
			_add(arm, anchors, regionId, side)
		_add(arm, anchors, elbowRegion, side)
		_add(arm, anchors, "forearms", side)
		var elbow: Vector2 = _at(anchors, elbowRegion, side)
		var wrist: Vector2 = _at(anchors, "forearms", side)
		if elbow != Vector2.INF and wrist != Vector2.INF:
			arm.append(wrist + (wrist - elbow).normalized() * 0.08 * height)
		chains.append({"side": sideSign, "points": arm})
		var torso: Array = [trunk[1]]
		if front:
			_add(torso, anchors, "serratus", side)
		else:
			_add(torso, anchors, "lats", side)
		_add(torso, anchors, "obliques", side)
		chains.append({"side": sideSign, "points": torso})
		var leg: Array = [pelvis]
		var shin: String = "calves"
		if front:
			_add(leg, anchors, "hipFlexors", side)
			_add(leg, anchors, "innerQuad", side)
			shin = "tibialis"
		else:
			_add(leg, anchors, "glutes", side)
			_add(leg, anchors, "hamstrings", side)
		_add(leg, anchors, shin, side)
		var ankle: Vector2 = _at(anchors, shin, side)
		if ankle != Vector2.INF:
			leg.append(Vector2(ankle.x, bottom - 0.025 * height))
		chains.append({"side": sideSign, "points": leg})

	# smooth every chain once, with its length along the way (for the pulse)
	var smoothed: Array = []
	for chain in chains:
		if chain["points"].size() < 2:
			continue
		smoothed.append({"points": _smooth(chain["points"]), "side": chain["side"]})
	var built: Dictionary = {"chains": smoothed, "heart": heart, "height": height}
	chainCache[key] = built
	return built


func _at(anchors: Dictionary, regionId: String, side: String) -> Vector2:
	# a region's anchor on one side (or its middle one), INF when the view does not show it
	if not anchors.has(regionId):
		return Vector2.INF
	if anchors[regionId].has(side):
		return anchors[regionId][side]
	if anchors[regionId].has("c"):
		return anchors[regionId]["c"]
	return Vector2.INF


func _y(anchors: Dictionary, regionId: String, fallback: float) -> float:
	# the height of a region (either side), for points down the middle
	for side in ["l", "r", "c"]:
		var point: Vector2 = _at(anchors, regionId, side)
		if point != Vector2.INF:
			return point.y
	return fallback


func _add(points: Array, anchors: Dictionary, regionId: String, side: String) -> void:
	var point: Vector2 = _at(anchors, regionId, side)
	if point != Vector2.INF:
		points.append(point)


func _smooth(points: Array) -> PackedVector2Array:
	### WHAT THIS DOES
	# a Catmull-Rom curve through the anchors (the ends repeated so it starts and stops on them)

	var out: PackedVector2Array = PackedVector2Array()

	for index in range(points.size() - 1):
		var p0: Vector2 = points[maxi(index - 1, 0)]
		var p1: Vector2 = points[index]
		var p2: Vector2 = points[index + 1]
		var p3: Vector2 = points[mini(index + 2, points.size() - 1)]
		for step in range(smoothSteps):
			var t: float = float(step) / float(smoothSteps)
			out.append(_catmull(p0, p1, p2, p3, t))
	out.append(points[points.size() - 1])
	return out


func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _offset(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	# the same line moved sideways by distance (along each point's normal)
	var out: PackedVector2Array = PackedVector2Array()
	for index in range(points.size()):
		var before: Vector2 = points[maxi(index - 1, 0)]
		var after: Vector2 = points[mini(index + 1, points.size() - 1)]
		var direction: Vector2 = (after - before).normalized()
		out.append(points[index] + Vector2(-direction.y, direction.x) * distance)
	return out


### /// DRAWING ///

func _draw() -> void:
	### WHAT THIS DOES
	# per figure: the blue and red vessels (dark outline, bright core; glassy styles add a glow and a
	# shine), a pulse running along each lit one (outward on red, inward on blue), and the heart

	if bodyView == null or levels.is_empty():
		return
	for slot in bodyView.slots:
		var viewXf: Transform2D = Transform2D(0.0, Vector2(bodyView.zoom, bodyView.zoom), 0.0, bodyView.pan) * slot["xf"]
		var networks: Dictionary = _networks(slot["data"])
		var unit: float = slot["scale"] * bodyView.zoom
		var width: float = maxf(minLineWidth, lineWidthShare * float(networks["height"]) * unit)
		var pair: float = pairOffsetShare * float(networks["height"])
		_drawNetwork(networks["chains"], viewXf, pair, width, blueColour, float(levels.get("blue", 0.0)), false)
		_drawNetwork(networks["chains"], viewXf, -pair, width, redColour, float(levels.get("red", 0.0)), true)
		if networks["heart"] != Vector2.INF:
			_drawHeart(viewXf * networks["heart"], heartSizeShare * float(networks["height"]) * unit)


func _drawNetwork(chains: Array, viewXf: Transform2D, pair: float, width: float, colour: Color, level: float, outward: bool) -> void:
	var strength: float = lerpf(emptyStrength, 1.0, clampf(level, 0.0, 1.0))
	var core: Color = colour.lerp(Color.WHITE, fullWhiten * level)
	var glass: bool = _glassy()
	var outline: Color = Color(colour.darkened(underDarken), underAlpha * strength)

	for index in range(chains.size()):
		var chain: Dictionary = chains[index]
		var model: PackedVector2Array = _offset(chain["points"], pair * float(chain["side"]))
		var points: PackedVector2Array = viewXf * model

		# the vessel
		if glass:
			draw_polyline(points, Color(colour, glowAlpha * strength * strength), width * glowWidthScale, true)
		draw_polyline(points, outline, width * underWidthScale, true)
		draw_polyline(points, Color(core, strength), width, true)
		if glass:
			draw_polyline(points, Color(1.0, 1.0, 1.0, shineAlpha * strength), width * shineWidthScale, true)

		# the pulse
		if level > 0.0:
			var travelled: float = fposmod(clock * pulseSpeed + float(index) * 0.37, 1.0)
			if not outward:
				travelled = 1.0 - travelled
			var spot: Vector2 = _pointAlong(points, travelled)
			if glass:
				draw_circle(spot, width * pulseGlowScale, Color(colour, 0.35 * level))
			draw_circle(spot, width * (pulseDotScale + 0.5), Color(colour.darkened(underDarken), underAlpha))
			draw_circle(spot, width * pulseDotScale, Color.WHITE.lerp(colour, 0.25))


func _glassy() -> bool:
	# the style's finish (AppStyle.glassVessels), looked up by path so the layer also compiles in
	# drivers that run without the autoloads
	var theme: Node = null
	if is_inside_tree():
		theme = get_node_or_null("/root/AppTheme")
	if theme == null:
		return false
	return bool(theme.style.glassVessels)


func _pointAlong(points: PackedVector2Array, share: float) -> Vector2:
	# the point a share of the way along a polyline
	var total: float = 0.0
	for index in range(points.size() - 1):
		total += points[index].distance_to(points[index + 1])
	var wanted: float = total * share
	for index in range(points.size() - 1):
		var piece: float = points[index].distance_to(points[index + 1])
		if wanted <= piece and piece > 0.0:
			return points[index].lerp(points[index + 1], wanted / piece)
		wanted -= piece
	return points[points.size() - 1]


func _drawHeart(centre: Vector2, radius: float) -> void:
	# a crisp red dot with a dark outline and a double beat ("lub-dub"), brighter as the red light
	# fills; glassy styles add a soft glow
	var phase: float = fposmod(clock / heartBeatSeconds, 1.0)
	var beat: float = maxf(exp(-pow((phase - 0.08) * 14.0, 2.0)), 0.7 * exp(-pow((phase - 0.3) * 14.0, 2.0)))
	var strength: float = lerpf(emptyStrength, 1.0, clampf(float(levels.get("red", 0.0)), 0.0, 1.0))
	var size: float = radius * (1.0 + 0.25 * beat)
	if _glassy():
		draw_circle(centre, size * 2.0, Color(redColour, 0.22 * strength))
	draw_circle(centre, size + 1.5, Color(redColour.darkened(underDarken), underAlpha * strength))
	draw_circle(centre, size, Color(redColour.lerp(Color.WHITE, 0.25 * beat), strength))
