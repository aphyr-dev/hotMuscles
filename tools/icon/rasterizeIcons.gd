extends SceneTree
## rasterizeIcons.gd - turns the icon svgs into the pngs the export presets point at
## what this offers:
##   run by tools/icon/makeIcon.py (headless): godot --headless --script res://tools/icon/rasterizeIcons.gd -- <backgroundHex>
## writes icons/icon192.png, icons/icon256.png (from icon.svg), icons/androidForeground432.png
## (from icons/androidForeground.svg) and icons/androidBackground432.png (a flat background colour)
## prints ICONS DONE at the end

### /// TUNING ///

# the svg drawings are this many units wide
const svgSize: float = 512.0
# [source svg, output png, pixel size]
const jobs: Array = [
	["res://icon.svg", "res://icons/icon192.png", 192],
	["res://icon.svg", "res://icons/icon256.png", 256],
	["res://icons/androidForeground.svg", "res://icons/androidForeground432.png", 432],
]
# the adaptive background png
const backgroundPath: String = "res://icons/androidBackground432.png"
const backgroundSize: int = 432


func _initialize() -> void:
	### WHAT THIS DOES
	# svg -> png at each size, then the flat background

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var backColour: Color = Color("#0b0c0f")
	var failed: int = 0

	if args.size() > 0:
		backColour = Color(args[0])

	# each svg at its size
	for job in jobs:
		var svgText: String = FileAccess.get_file_as_string(job[0])
		var image: Image = Image.new()
		var scale: float = float(job[2]) / svgSize
		var error: int = image.load_svg_from_string(svgText, scale)
		if error != OK or image.get_width() != int(job[2]):
			print("FAILED %s -> %s (error %d, width %d)" % [job[0], job[1], error, image.get_width()])
			failed += 1
			continue
		image.save_png(ProjectSettings.globalize_path(job[1]))
		print("wrote %s (%d px)" % [job[1], job[2]])

	# the flat adaptive background
	var background: Image = Image.create(backgroundSize, backgroundSize, false, Image.FORMAT_RGBA8)
	background.fill(backColour)
	background.save_png(ProjectSettings.globalize_path(backgroundPath))
	print("wrote %s (%d px)" % [backgroundPath, backgroundSize])

	if failed > 0:
		print("ICONS FAILED (%d)" % failed)
		quit(1)
		return
	print("ICONS DONE")
	quit(0)
