extends Node
## AppTheme (autoload) - what the app wears: a STYLE (shapes, panels, fonts, feel - app/looks/styles/)
## painted in a PALETTE (colours only - app/looks/palettes/), picked independently; the registry of
## both is app/looks/looks.gd. Builds one Godot Theme from the pair and puts it on the root window
## what this offers
## - themeIds() / themeName(id)       the palettes ("theme" in the profile is the palette id)
## - styleIds() / styleName(id)       the styles
## - apply(themeId, styleId = "")     swaps the whole app at runtime ("" = keep the current style);
##                                    an unknown id falls back to Looks.defaultPalette / defaultStyle;
##                                    sets the clear colour, emits themeChanged
## - buildTheme(themeId, styleId = "") -> Theme   a theme without applying it (live previews)
## - style (the current AppStyle), currentId (palette), currentStyleId
## - colour(key) / paletteOf(themeId)  raw palette colours (after the style's adjustColours): bg, page,
##                                    surface, surfaceHi, line, text, textMuted, textFaint, accent,
##                                    accentText, cold, neutral, hot, ghost, bodyPlain, bodyCosmetic, bodyGap
## - box(role, tint)                  a StyleBox from the current style (roles: AppStyle.box)
## - boldFont() / regularFont()       the current style's fonts
## - every palette colour is also in the theme as type "App" (get_theme_color("accent", "App"))
## - type variations: AccentButton, FlatButton, ChipButton (toggle chips), CardPanel, SheetPanel,
##   BackgroundPanel, RowPanel (list rows), HeaderLabel, TitleLabel, BoldLabel, MutedLabel, FaintLabel
## follows Storage.profile.theme and Storage.profile.style by itself

signal themeChanged(themeId: String)

### /// STATE ///

var styles: Dictionary = {}
var palettes: Dictionary = {}
var style: AppStyle = null
var currentId: String = ""
var currentStyleId: String = ""
var palette: Dictionary = {}
var theme: Theme = null


func _ready() -> void:
	var storage: Node = get_node_or_null("/root/Storage")
	var startTheme: String = Looks.defaultPalette
	var startStyle: String = Looks.defaultStyle

	styles = Looks.loadStyles()
	palettes = Looks.loadPalettes()
	if not styles.has(Looks.defaultStyle) or not palettes.has(Looks.defaultPalette):
		push_error("AppTheme: the default style or palette is missing from app/looks/looks.gd")
	if storage != null:
		startTheme = str(storage.profile.get("theme", startTheme))
		startStyle = str(storage.profile.get("style", startStyle))
		storage.changed.connect(_onStorageChanged)
	apply(startTheme, startStyle)


func _onStorageChanged(_section: String) -> void:
	var storage: Node = get_node_or_null("/root/Storage")
	var wantedTheme: String = _paletteIdOr(str(storage.profile.get("theme", Looks.defaultPalette)))
	var wantedStyle: String = _styleIdOr(str(storage.profile.get("style", Looks.defaultStyle)))
	if wantedTheme != currentId or wantedStyle != currentStyleId:
		apply(wantedTheme, wantedStyle)


### /// PUBLIC ///

func themeIds() -> Array:
	var ids: Array = []
	for path in Looks.palettePaths:
		var paletteId: String = Looks.idOf(path)
		if palettes.has(paletteId):
			ids.append(paletteId)
	return ids


func themeName(themeId: String) -> String:
	return str(palettes[_paletteIdOr(themeId)]["name"])


func styleIds() -> Array:
	var ids: Array = []
	for path in Looks.stylePaths:
		var styleId: String = Looks.idOf(path)
		if styles.has(styleId):
			ids.append(styleId)
	return ids


func styleName(styleId: String) -> String:
	return styles[_styleIdOr(styleId)].styleName


func paletteOf(themeId: String) -> Dictionary:
	# the palette as the current style paints it
	var raw: Dictionary = palettes[_paletteIdOr(themeId)]["colours"]
	var colours: Dictionary = raw.duplicate()
	colours["name"] = palettes[_paletteIdOr(themeId)]["name"]
	if style == null:
		return colours
	return style.adjustColours(colours)


func colour(key: String) -> Color:
	if palette.has(key):
		return palette[key]
	return palettes[Looks.defaultPalette]["colours"][key]


func box(role: String, tint: Color = Color(0, 0, 0, 0)) -> StyleBox:
	return style.box(role, palette, tint)


func boldFont() -> Font:
	return style.boldFont()


func regularFont() -> Font:
	return style.regularFont()


func apply(themeId: String, styleId: String = "") -> void:
	### WHAT THIS DOES
	# swaps the whole app to a palette (and style) at runtime

	var useStyle: String = currentStyleId
	if styleId != "":
		useStyle = _styleIdOr(styleId)
	if useStyle == "":
		useStyle = Looks.defaultStyle
	currentStyleId = useStyle
	style = styles[useStyle]
	currentId = _paletteIdOr(themeId)
	palette = paletteOf(currentId)
	theme = style.buildTheme(palette)
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(palette["page"])
	themeChanged.emit(currentId)


func useStyleModule(made: AppStyle) -> void:
	# puts a style that is not in the registry on the app (the look-review screenshot driver)
	styles[made.styleId] = made
	apply(currentId, made.styleId)


func buildTheme(themeId: String, styleId: String = "") -> Theme:
	var useStyle: AppStyle = style
	if styleId != "":
		useStyle = styles[_styleIdOr(styleId)]
	var raw: Dictionary = palettes[_paletteIdOr(themeId)]["colours"].duplicate()
	return useStyle.buildTheme(useStyle.adjustColours(raw))


### /// FALLBACKS ///

func _paletteIdOr(themeId: String) -> String:
	# a palette that is gone (or never was) falls back to the default
	if palettes.has(themeId):
		return themeId
	return Looks.defaultPalette


func _styleIdOr(styleId: String) -> String:
	if styles.has(styleId):
		return styleId
	return Looks.defaultStyle
