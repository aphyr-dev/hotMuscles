class_name HeatGradients
extends RefCounted
## what this offers
## - heat colour ramps as plain lists of colour stops (like a Blender colour ramp) - adding a
##   gradient = adding one entry to `presets` below
## - HeatGradients.sample(presetId, t)            colour at t in 0..1 (clamped)
## - HeatGradients.amountColour(presetId, sets, rangeMax)   colour for N effective sets on a 0..rangeMax scale
## - HeatGradients.presetIds() / presetName(id) / makeGradient(id) (a Godot Gradient, for textures)
## all functions are static - no instance needed

### /// TUNING ///

# the gradient presets - each stop is [position 0..1, colour]
const presets: Dictionary = {
	"infrared": {
		"name": "Infrared",
		"stops": [
			[0.0, Color(0.0, 0.0, 0.0, 1.0)],
			[0.1667, Color(0.42, 0.12, 0.62, 1.0)],
			[0.3333, Color(0.12, 0.25, 1.0, 1.0)],
			[0.5, Color(0.0, 0.88, 1.0, 1.0)],
			[0.6667, Color(0.15, 0.9, 0.3, 1.0)],
			[0.8333, Color(1.0, 0.9, 0.15, 1.0)],
			[1.0, Color(1.0, 0.13, 0.08, 1.0)],
		],
	},
	"scarlet": {
		"name": "Scarlet",
		"stops": [
			[0.0, Color(1.0, 0.1, 0.12, 0.0)],
			[1.0, Color(1.0, 0.1, 0.12, 1.0)],
		],
	},
	"ember": {
		"name": "Ember",
		"stops": [
			[0.0, Color(0.17, 0.04, 0.02, 1.0)],
			[0.3, Color(0.6, 0.15, 0.03, 1.0)],
			[0.55, Color(1.0, 0.48, 0.1, 1.0)],
			[0.8, Color(1.0, 0.79, 0.23, 1.0)],
			[1.0, Color(1.0, 0.97, 0.88, 1.0)],
		],
	},
}

# the gradient used when an unknown id is asked for
const fallbackPreset: String = "infrared"


### /// PRESETS ///

static func presetIds() -> Array:
	# ids in display order
	return ["infrared", "scarlet", "ember"]


static func presetName(presetId: String) -> String:
	if presets.has(presetId):
		return presets[presetId]["name"]
	return presetId


static func stopsOf(presetId: String) -> Array:
	# the stop list of a preset, the fallback one for unknown ids
	if presets.has(presetId):
		return presets[presetId]["stops"]
	return presets[fallbackPreset]["stops"]


static func makeGradient(presetId: String) -> Gradient:
	### WHAT THIS DOES
	# builds a Godot Gradient resource from a preset - for GradientTexture1D/2D

	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()

	for stop in stopsOf(presetId):
		offsets.append(stop[0])
		colours.append(stop[1])
	gradient.offsets = offsets
	gradient.colors = colours
	return gradient


### /// SAMPLING ///

static func sample(presetId: String, t: float) -> Color:
	### WHAT THIS DOES
	# linear blend between the two stops around t (t is clamped to 0..1)

	var stops: Array = stopsOf(presetId)
	var clamped: float = clampf(t, 0.0, 1.0)

	if clamped <= stops[0][0]:
		return stops[0][1]
	for index in range(1, stops.size()):
		var stopPos: float = stops[index][0]
		if clamped <= stopPos:
			var prevPos: float = stops[index - 1][0]
			var span: float = stopPos - prevPos
			var local: float = 0.0
			if span > 0.0:
				local = (clamped - prevPos) / span
			var prevColour: Color = stops[index - 1][1]
			var nextColour: Color = stops[index][1]
			return prevColour.lerp(nextColour, local)
	return stops[stops.size() - 1][1]


static func amountColour(presetId: String, sets: float, rangeMax: float) -> Color:
	# colour for an amount of effective sets on the 0..rangeMax scale - above rangeMax clips to the top
	var top: float = maxf(rangeMax, 0.001)
	return sample(presetId, sets / top)

