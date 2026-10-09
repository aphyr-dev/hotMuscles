class_name Looks
extends RefCounted
## Looks - the registry of styles and palettes the app can wear (AppTheme reads it)
## what this offers
## - stylePaths / palettePaths   the modules, in menu order. To add one: put the file in
##   app/looks/styles/ or app/looks/palettes/ and add its path here. To remove one: delete the file
##   and its line. A path that does not load is skipped with an error in the log
## - defaultStyle / defaultPalette   what the app wears when nothing is picked yet, or when the picked
##   one is gone (this default must always exist)
## - loadStyles() -> {id: AppStyle}, loadPalettes() -> {id: {name, colours}}, styleOrder(), paletteOrder()

### /// THE REGISTRY ///

const defaultStyle: String = "modern"
const defaultPalette: String = "ember"

const stylePaths: Array = [
	"res://app/looks/styles/modern.gd",
	"res://app/looks/styles/frutiger.gd",
]

const palettePaths: Array = [
	"res://app/looks/palettes/ember.gd",
	"res://app/looks/palettes/ocean.gd",
	"res://app/looks/palettes/forest.gd",
	"res://app/looks/palettes/dusk.gd",
	"res://app/looks/palettes/copper.gd",
	"res://app/looks/palettes/graphite.gd",
	"res://app/looks/palettes/light.gd",
	"res://app/looks/palettes/glacier.gd",
	"res://app/looks/palettes/sand.gd",
	"res://app/looks/palettes/sakura.gd",
]


### /// LOADING ///

static func idOf(path: String) -> String:
	# a module's id is its file name: res://app/looks/palettes/dusk.gd -> "dusk"
	return path.get_file().get_basename()


static func loadStyle(path: String) -> AppStyle:
	# one style module, or null (with an error) when it is missing or broken
	if not ResourceLoader.exists(path):
		push_error("Looks: style module missing: %s" % path)
		return null
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		push_error("Looks: style module does not load: %s" % path)
		return null
	var made: Variant = script.new()
	if not (made is AppStyle):
		push_error("Looks: %s does not extend AppStyle" % path)
		return null
	return made


static func loadStyles() -> Dictionary:
	var found: Dictionary = {}
	for path in stylePaths:
		var style: AppStyle = loadStyle(path)
		if style != null:
			found[style.styleId] = style
	return found


static func loadPalettes() -> Dictionary:
	### WHAT THIS DOES
	# every palette module's name and colours, keyed by its file name

	var found: Dictionary = {}

	for path in palettePaths:
		if not ResourceLoader.exists(path):
			push_error("Looks: palette module missing: %s" % path)
			continue
		var script: GDScript = load(path)
		if script == null:
			push_error("Looks: palette module does not load: %s" % path)
			continue
		var constants: Dictionary = script.get_script_constant_map()
		if not constants.has("colours") or not constants.has("paletteName"):
			push_error("Looks: %s needs paletteName and colours" % path)
			continue
		found[idOf(path)] = {"name": str(constants["paletteName"]), "colours": constants["colours"]}
	return found
