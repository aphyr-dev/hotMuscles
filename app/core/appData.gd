extends Node
## AppData (autoload) - the read-only app data, loaded once from res://appData
## what this offers
## - regions: [{id, name, group, views, band: [low, high]}] in body order; regionById; regionIds
## - groups: [{id, name}]
## - exercises: [{id, name, equipment, category, targets: [{region, share}], forearmKind, curated,
##   aliases (optional: other names search matches, e.g. "pec deck")}]
##   sorted by name; exerciseById
## - getRegion(id) / regionName(id) / regionBand(id) / getExercise(id) / exerciseShare(exerciseId, regionId)
## - search(query, equipmentFilter = [], limit = 0)   name + alias search, every word must match
## - equipmentList()                                   every equipment name, sorted
## - exercisesForRegion(regionId)                      exercises that reach a region, biggest share first
## - bodyView(body, view)  what BodyView needs for one figure (all baked by tools/appData, nothing
##       computed here): {viewBox: Rect2, bounds: Rect2 (figure + seam border, for layout),
##       mapFile: res path of the baked region map, mapRect: Rect2 (where the map sits, drawing units),
##       taps: [{region, polygon: PackedVector2Array (<= 32 corners), box: Rect2}],
##       centres: {regionId: Vector2}}
## - bodyMap(body, view)  the region map as a texture, loaded once and shared; a missing map is a loud
##       error and returns null. Every map starts decoding on a worker thread as soon as the data
##       loads, so the first figure only waits for its own map and the others are ready later for free
## - mapIdOf(regionId)    the red value a region has in the maps; mapGapId, mapCosmeticId, mapOutsideId;
##       mapTexelsPerUnit (map texels per drawing unit); mapDashShare (drawn share of a ghost dash period);
##       mapEdgeSteps (blue steps per texel of edge distance)
## - loadAll(folder) - called by itself on start; tests can call it on their own instance
## - appStartMs: engine ticks when the app's own code first ran (this is the first autoload) - main.gd
##       prints how long loading the app's scripts took from here

### /// TUNING ///

# where the built data lives (tools/appData/buildAppData.py writes it)
var dataFolder: String = "res://appData"

### /// STATE ///

var loaded: bool = false
var regions: Array = []
var regionById: Dictionary = {}
var regionIds: PackedStringArray = PackedStringArray()
var groups: Array = []
var exercises: Array = []
var exerciseById: Dictionary = {}
var bodies: Dictionary = {}
var viewCache: Dictionary = {}
var mapCache: Dictionary = {}
var mapTasks: Dictionary = {}
var mapImages: Dictionary = {}
var mapMutex: Mutex = Mutex.new()
var mapOutsideId: int = 0
var mapGapId: int = 1
var mapCosmeticId: int = 2
var mapFirstRegionId: int = 3
var mapTexelsPerUnit: float = 1.0
var mapDashShare: float = 0.6
var mapEdgeSteps: float = 64.0
var searchNames: Dictionary = {}
var searchOrder: Array = []
var appStartMs: int = 0


func _init() -> void:
	appStartMs = Time.get_ticks_msec()


func _enter_tree() -> void:
	if not loaded:
		loadAll(dataFolder)


### /// LOADING ///

func loadAll(folder: String) -> bool:
	### WHAT THIS DOES
	# reads muscles.json + exercises.json; any missing or broken file is a loud error

	var muscles: Variant = _readJson(folder.path_join("muscles.json"))
	var exerciseFile: Variant = _readJson(folder.path_join("exercises.json"))

	if typeof(muscles) != TYPE_DICTIONARY or typeof(exerciseFile) != TYPE_DICTIONARY:
		push_error("AppData: could not load app data from %s - rebuild it with tools/appData/buildAppData.py" % folder)
		loaded = false
		return false

	# regions
	regions = muscles["regions"]
	groups = muscles["groups"]
	bodies = muscles["bodies"]
	var mapIds: Dictionary = muscles["mapIds"]
	mapOutsideId = int(mapIds["outside"])
	mapGapId = int(mapIds["gap"])
	mapCosmeticId = int(mapIds["cosmetic"])
	mapFirstRegionId = int(mapIds["firstRegion"])
	mapTexelsPerUnit = float(mapIds["texelsPerUnit"])
	mapDashShare = float(mapIds["dashShare"])
	mapEdgeSteps = float(mapIds["edgeSteps"])
	mapCache.clear()
	_startMapDecodes(folder)
	regionById.clear()
	regionIds = PackedStringArray()
	for region in regions:
		regionById[region["id"]] = region
		regionIds.append(region["id"])

	# exercises
	exercises = exerciseFile["exercises"]
	exerciseById.clear()
	searchNames.clear()
	for exercise in exercises:
		exerciseById[exercise["id"]] = exercise
		# the name first (a query matching its start ranks highest), then the aliases ("pec deck")
		var searchText: String = _normaliseName(exercise["name"])
		for alias in exercise.get("aliases", []):
			searchText += "|" + _normaliseName(str(alias))
		searchNames[exercise["id"]] = searchText
	_sortSearchOrder()

	viewCache.clear()
	loaded = true
	return true


func _readJson(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("AppData: missing %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("AppData: %s is not valid json" % path)
	return parsed


### /// LOOKUPS ///

func getRegion(regionId: String) -> Dictionary:
	if regionById.has(regionId):
		return regionById[regionId]
	return {}


func regionName(regionId: String) -> String:
	if regionById.has(regionId):
		return regionById[regionId]["name"]
	return regionId


func regionBand(regionId: String) -> Array:
	if regionById.has(regionId):
		return regionById[regionId]["band"]
	return [0, 0]


func getExercise(exerciseId: String) -> Dictionary:
	if exerciseById.has(exerciseId):
		return exerciseById[exerciseId]
	return {}


func exerciseShare(exerciseId: String, regionId: String) -> float:
	if not exerciseById.has(exerciseId):
		return 0.0
	for target in exerciseById[exerciseId]["targets"]:
		if target["region"] == regionId:
			return float(target["share"])
	return 0.0


func equipmentList() -> Array:
	var seen: Dictionary = {}
	for exercise in exercises:
		seen[exercise["equipment"]] = true
	var names: Array = seen.keys()
	names.sort()
	return names


func exercisesForRegion(regionId: String) -> Array:
	# exercises reaching a region, biggest share first, then name
	var rows: Array = []
	for exercise in exercises:
		for target in exercise["targets"]:
			if target["region"] == regionId:
				rows.append({"exercise": exercise, "share": float(target["share"])})
				break
	rows.sort_custom(_shareBefore)
	var result: Array = []
	for row in rows:
		result.append(row["exercise"])
	return result


func _shareBefore(a: Dictionary, b: Dictionary) -> bool:
	if absf(a["share"] - b["share"]) > 0.00001:
		return a["share"] > b["share"]
	return a["exercise"]["name"] < b["exercise"]["name"]


### /// SEARCH ///

func _normaliseName(text: String) -> String:
	# lower case, punctuation to spaces, single spaces
	var lower: String = text.to_lower()
	for mark in ["-", "_", "/", "(", ")", ",", ".", "'"]:
		lower = lower.replace(mark, " ")
	while lower.contains("  "):
		lower = lower.replace("  ", " ")
	return " " + lower.strip_edges() + " "


func _sortSearchOrder() -> void:
	### WHAT THIS DOES
	# every exercise once in "curated before rough data, then a-z" order, so a search only has to
	# split its matches into the three match ranks instead of sorting them; sorted as plain text keys
	# ("0" or "1", the name, a separator below every name character, the index) by the fast built-in sort

	var keys: PackedStringArray = PackedStringArray()

	for index in range(exercises.size()):
		var exercise: Dictionary = exercises[index]
		var curatedMark: String = "1"
		if exercise["curated"]:
			curatedMark = "0"
		keys.append("%s%s\u0001%d" % [curatedMark, exercise["name"], index])
	keys.sort()
	searchOrder = []
	for key in keys:
		searchOrder.append(exercises[key.get_slice("\u0001", 1).to_int()])


func search(query: String, equipmentFilter: Array = [], limit: int = 0) -> Array:
	### WHAT THIS DOES
	# every word of the query must appear in the name; names starting with the query come first,
	# then words matching at a word start, then anywhere; curated before rough data; then a-z
	# (searchOrder already holds curated-then-a-z, so each rank keeps that order)

	var words: PackedStringArray = _normaliseName(query).strip_edges().split(" ", false)
	var whole: String = _normaliseName(query).strip_edges()
	var ranks: Array = [[], [], []]

	for exercise in searchOrder:
		if equipmentFilter.size() > 0 and not equipmentFilter.has(exercise["equipment"]):
			continue
		var nameText: String = searchNames[exercise["id"]]
		var rank: int = 0
		var matched: bool = true
		for word in words:
			if not nameText.contains(word):
				matched = false
				break
			if not nameText.contains(" " + word):
				rank = maxi(rank, 2)
			else:
				rank = maxi(rank, 1)
		if not matched:
			continue
		if whole != "" and nameText.begins_with(" " + whole):
			rank = 0
		if words.size() == 0:
			rank = 0
		ranks[rank].append(exercise)

	var result: Array = []
	for rankRows in ranks:
		result.append_array(rankRows)
	if limit > 0 and result.size() > limit:
		result.resize(limit)
	return result


### /// BODY MAPS ///

func mapIdOf(regionId: String) -> int:
	# a region's red value in the maps (its place in the region list + the first region id)
	var index: int = regionIds.find(regionId)
	if index < 0:
		return -1
	return mapFirstRegionId + index


func bodyView(body: String, view: String) -> Dictionary:
	### WHAT THIS DOES
	# the baked entry of one body + view as Godot types, converted once and cached

	var key: String = body + "/" + view
	var taps: Array = []
	var centres: Dictionary = {}

	if viewCache.has(key):
		return viewCache[key]
	if not bodies.has(body) or not bodies[body].has(view):
		push_error("AppData: no body view for %s %s" % [body, view])
		return {}
	var source: Dictionary = bodies[body][view]

	# tap shapes (hit testing) and region centres
	for tap in source["taps"]:
		taps.append({"region": tap["region"], "polygon": _toPolygon(tap["polygon"]), "box": _toRect(tap["box"])})
	for regionId in source["centres"]:
		var point: Array = source["centres"][regionId]
		centres[regionId] = Vector2(point[0], point[1])

	var prepared: Dictionary = {
		"viewBox": _toRect(source["viewBox"]),
		"bounds": _toRect(source["bounds"]),
		"mapFile": dataFolder.path_join(source["map"]["file"]),
		"mapRect": _toRect(source["map"]["rect"]),
		"taps": taps,
		"centres": centres,
	}
	viewCache[key] = prepared
	return prepared


func bodyMap(body: String, view: String) -> Texture2D:
	### WHAT THIS DOES
	# loads the baked png byte for byte (it ships untouched - importer "keep"), once per body + view

	var key: String = body + "/" + view

	if mapCache.has(key):
		return mapCache[key]
	var prepared: Dictionary = bodyView(body, view)
	if prepared.is_empty():
		return null
	var path: String = prepared["mapFile"]
	if not mapTasks.has(key):
		push_error("AppData: no body map was started for %s - loadAll first" % key)
		return null
	WorkerThreadPool.wait_for_task_completion(mapTasks[key])
	mapTasks.erase(key)
	mapMutex.lock()
	var image: Image = mapImages.get(key, null)
	mapImages.erase(key)
	mapMutex.unlock()
	if image == null:
		push_error("AppData: body map %s is missing or not a readable png - rebuild it with tools/appData/buildAppData.py" % path)
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	mapCache[key] = texture
	return texture


func _startMapDecodes(folder: String) -> void:
	### WHAT THIS DOES
	# one worker task per body + view reads and decodes its png (the slow part, ~20 ms each);
	# bodyMap() waits for the task and turns the image into a texture on the main thread

	# a reload first lets earlier tasks finish (each task is waited for exactly once)
	for key in mapTasks:
		WorkerThreadPool.wait_for_task_completion(mapTasks[key])
	mapTasks.clear()
	mapMutex.lock()
	mapImages.clear()
	mapMutex.unlock()

	for body in bodies:
		for view in bodies[body]:
			var key: String = body + "/" + view
			var path: String = folder.path_join(bodies[body][view]["map"]["file"])
			mapTasks[key] = WorkerThreadPool.add_task(_decodeMap.bind(key, path), true, "body map " + key)


func _decodeMap(key: String, path: String) -> void:
	# on a worker thread: a missing or broken file leaves no image (bodyMap reports it)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return
	mapMutex.lock()
	mapImages[key] = image
	mapMutex.unlock()


func _toPolygon(flat: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var count: int = flat.size() / 2
	polygon.resize(count)
	for index in range(count):
		polygon[index] = Vector2(flat[index * 2], flat[index * 2 + 1])
	return polygon


func _toRect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
