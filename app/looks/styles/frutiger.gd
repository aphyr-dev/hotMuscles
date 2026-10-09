extends AppStyle
## Frutiger - the glossy, playful nature-and-water look of Frutiger Aero (bubbles and swooshes)
## what the owner sees
## - glossy orb-like controls: round-ended pill buttons with a wet highlight, a bead of light and a
##   bright glow along the bottom edge; the main action is a glowing accent orb
## - glass cards with a rim light, a wet streak across the top corner and a few water droplets
## - the page is a sky-to-horizon gradient built from the palette (cold at the top, accent glow at the
##   bottom) with see-through soap bubbles drifting in it and glowing light-streak swooshes (curved
##   ribbons in the accent and cold colours) sweeping behind the header and the bottom bar
## - dark palettes become smoked glass with glowing rims and luminous bubbles; light palettes become
##   bright glass with white sheen and tinted bubbles
## - sliders are glass tubes filled with liquid, with a glossy bead as the handle; bars are liquid too
## everything is drawn in code (no image files); decorations take no input and sit behind content


### /// TUNING ///

# how round the controls are - big numbers make full pills
const pillRadius: int = 28
# how much of the page colours the sky takes from the cold colour (top) and the accent (bottom)
const skyColdAmountDark: float = 0.20
const skyColdAmountLight: float = 0.30
const skyAccentAmountDark: float = 0.16
const skyAccentAmountLight: float = 0.20
# where the sky's middle colour sits down the page (0 top - 1 bottom)
const skyMiddleAt: float = 0.5
# how see-through the glass is (1 = solid) on dark and light palettes
const cardAlphaDark: float = 0.80
const cardAlphaLight: float = 0.74
# strength of the white sheen over the top of glass, on dark and light palettes
const glossDark: float = 0.10
const glossLight: float = 0.36
# strength of the little wet streak and bead of light on buttons and cards
const lensAlphaDark: float = 0.38
const lensAlphaLight: float = 0.80
# strength of the swoosh ribbons (1 = as designed)
const swooshStrength: float = 1.0
# strength of the bubbles in the page (1 = as designed)
const bubbleStrength: float = 1.0
# the water droplets on cards: size and how many
const dropletSize: float = 4.5
const dropletsOnCards: int = 3
# the header fizz: how many small bubbles rise beside the title
const headerFizzCount: int = 7

# the bubbles of the page: [x as a share of the width, y as a share of the height, radius in px at
# 430 wide, colour (0 water, 1 accent, 2 cold, 3 white), strength]
const pageBubbles: Array = [
	[0.86, 0.045, 17.0, 0, 1.0],
	[0.94, 0.085, 9.0, 1, 1.0],
	[0.75, 0.03, 7.0, 3, 0.9],
	[0.05, 0.12, 12.0, 2, 0.9],
	[0.03, 0.22, 24.0, 0, 1.0],
	[0.97, 0.26, 30.0, 0, 1.0],
	[0.93, 0.40, 11.0, 3, 0.8],
	[0.03, 0.43, 8.0, 3, 0.8],
	[0.30, 0.38, 66.0, 0, 0.55],
	[0.72, 0.56, 84.0, 2, 0.45],
	[0.04, 0.58, 36.0, 1, 0.9],
	[0.96, 0.69, 19.0, 0, 1.0],
	[0.06, 0.76, 13.0, 3, 0.9],
	[0.88, 0.82, 44.0, 0, 1.0],
	[0.14, 0.90, 28.0, 2, 1.0],
	[0.50, 0.945, 11.0, 3, 0.9],
	[0.43, 0.975, 17.0, 0, 1.0],
	[0.70, 0.96, 7.0, 1, 0.9],
	[0.60, 0.80, 21.0, 0, 0.5],
]


### /// SMALL DRAWING TOOLS ///

class Art:
	## the pieces the style draws with: discs, rings, arcs, glowing ribbons, bubbles and droplets

	static func points(centre: Vector2, radius: float, from: float, to: float, steps: int) -> PackedVector2Array:
		var made := PackedVector2Array()
		for index in range(steps + 1):
			var angle: float = from + (to - from) * float(index) / float(steps)
			made.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		return made

	static func disc(canvasItem: RID, centre: Vector2, radius: float, colour: Color) -> void:
		var steps: int = clampi(int(radius * 1.4) + 12, 14, 64)
		var made: PackedVector2Array = points(centre, radius, 0.0, TAU, steps)
		made.remove_at(made.size() - 1)
		RenderingServer.canvas_item_add_polygon(canvasItem, made, PackedColorArray([colour]))

	static func ring(canvasItem: RID, centre: Vector2, radius: float, width: float, colour: Color) -> void:
		var steps: int = clampi(int(radius * 1.4) + 12, 14, 64)
		RenderingServer.canvas_item_add_polyline(canvasItem, points(centre, radius, 0.0, TAU, steps), PackedColorArray([colour]), width, true)

	static func arc(canvasItem: RID, centre: Vector2, radius: float, from: float, to: float, width: float, colour: Color) -> void:
		RenderingServer.canvas_item_add_polyline(canvasItem, points(centre, radius, from, to, 14), PackedColorArray([colour]), width, true)

	static func bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
		var ab: Vector2 = a.lerp(b, t)
		var bc: Vector2 = b.lerp(c, t)
		var cd: Vector2 = c.lerp(d, t)
		return ab.lerp(bc, t).lerp(bc.lerp(cd, t), t)

	static func ribbon(canvasItem: RID, a: Vector2, b: Vector2, c: Vector2, d: Vector2, width: float, from: Color, to: Color, alpha: float) -> void:
		### WHAT THIS DOES
		# a glowing ribbon along a curve: thin at both ends, bright in the middle line and fading to
		# nothing at both edges (three rows of vertices drawn as a triangle strip)

		var steps: int = 44
		var verts := PackedVector2Array()
		var colours := PackedColorArray()
		var indices := PackedInt32Array()

		for index in range(steps + 1):
			var t: float = float(index) / float(steps)
			var here: Vector2 = bezier(a, b, c, d, t)
			var ahead: Vector2 = bezier(a, b, c, d, minf(t + 0.01, 1.0))
			var behind: Vector2 = bezier(a, b, c, d, maxf(t - 0.01, 0.0))
			var tangent: Vector2 = (ahead - behind).normalized()
			var normal: Vector2 = Vector2(-tangent.y, tangent.x)
			var envelope: float = pow(sin(PI * t), 0.75)
			var half: float = width * 0.5 * envelope
			var tint: Color = from.lerp(to, t)
			var peak: float = alpha * (0.25 + 0.75 * envelope)
			verts.append(here - normal * half)
			colours.append(Color(tint, 0.0))
			verts.append(here)
			colours.append(Color(tint, peak))
			verts.append(here + normal * half)
			colours.append(Color(tint, 0.0))

		for index in range(steps):
			var row: int = index * 3
			var next: int = row + 3
			indices.append_array(PackedInt32Array([row, row + 1, next, next, row + 1, next + 1]))
			indices.append_array(PackedInt32Array([row + 1, row + 2, next + 1, next + 1, row + 2, next + 2]))
		RenderingServer.canvas_item_add_triangle_array(canvasItem, indices, verts, colours)

	static func bubble(canvasItem: RID, centre: Vector2, radius: float, tint: Color, strength: float, dark: bool) -> void:
		### WHAT THIS DOES
		# a soap bubble: a thin see-through body, a bright rim, a window-shaped highlight top left and
		# a tinted refraction crescent bottom right

		var white: Color = Color.WHITE
		var rimColour: Color = tint.lerp(white, 0.55)
		var bodyAlpha: float = 0.07
		var rimAlpha: float = 0.42
		var shineAlpha: float = 0.75
		var glintColour: Color = tint.lerp(white, 0.3)
		if not dark:
			rimColour = tint.darkened(0.15)
			bodyAlpha = 0.16
			rimAlpha = 0.5
			shineAlpha = 0.95
			glintColour = tint.darkened(0.05)
		var rimWidth: float = clampf(radius * 0.07, 1.0, 2.2)

		disc(canvasItem, centre, radius, Color(tint.lerp(white, 0.4), bodyAlpha * strength))
		if radius > 14.0:
			ring(canvasItem, centre, radius * 0.86, radius * 0.22, Color(tint, 0.06 * strength))
		ring(canvasItem, centre, radius - rimWidth * 0.5, rimWidth, Color(rimColour, rimAlpha * strength))
		arc(canvasItem, centre, radius * 0.74, PI * 1.08, PI * 1.5, maxf(rimWidth * 1.6, 1.6), Color(white, shineAlpha * strength))
		arc(canvasItem, centre, radius * 0.74, PI * 0.08, PI * 0.42, maxf(rimWidth * 1.2, 1.4), Color(glintColour, 0.55 * strength))
		if radius > 8.0:
			disc(canvasItem, centre + Vector2(-0.36, -0.42) * radius, maxf(radius * 0.07, 1.0), Color(white, 0.9 * strength))

	static func droplet(canvasItem: RID, centre: Vector2, radius: float, tint: Color, dark: bool) -> void:
		### WHAT THIS DOES
		# a bead of water sitting on glass: a soft shadow under it, a clear body and a bright spot

		var shadowColour: Color = Color(0.0, 0.0, 0.0, 0.3)
		var bodyColour: Color = Color(1.0, 1.0, 1.0, 0.1)
		if not dark:
			shadowColour = Color(tint.darkened(0.5), 0.3)
			bodyColour = Color(tint, 0.16)
		disc(canvasItem, centre + Vector2(0.6, 1.1), radius, shadowColour)
		disc(canvasItem, centre, radius, bodyColour)
		arc(canvasItem, centre, radius - 0.5, PI * 0.1, PI * 0.55, 1.0, Color(tint.lerp(Color.WHITE, 0.5), 0.55))
		disc(canvasItem, centre + Vector2(-0.3, -0.35) * radius, maxf(radius * 0.26, 0.9), Color(1.0, 1.0, 1.0, 0.95))


### /// THE GLASS PANEL ///

class WetBox extends ShapeBox:
	## a ShapeBox with the wet extras: a gloss that follows a pill's round ends, a glow along the
	## bottom, a small streak and bead of light at the top left, and water droplets on the glass
	## - sheenAlpha, sheenHeight     white sheen over the top (share of the height)
	## - glowColour, glowHeight      light along the bottom inside edge (alpha in the colour)
	## - lensAlpha, lensWidth, lensHeight   the wet streak at the top left (px; 0 alpha = none)
	## - droplets                    Vector3(x, y, radius); x, y >= 0 from the left, top, < 0 from the right, bottom
	## - dropTint, darkGlass         droplet colour and whether the glass is dark

	var sheenAlpha: float = 0.0
	var sheenHeight: float = 0.5
	var glowColour: Color = Color(1.0, 1.0, 1.0, 0.0)
	var glowHeight: float = 0.4
	var lensAlpha: float = 0.0
	var lensWidth: float = 90.0
	var lensHeight: float = 8.0
	var droplets: Array = []
	var dropTint: Color = Color(1.0, 1.0, 1.0, 1.0)
	var darkGlass: bool = true

	func _draw(canvasItem: RID, rect: Rect2) -> void:
		super._draw(canvasItem, rect)
		var inner: PackedVector2Array = _outline(rect.grow(-1.0), radii - Vector4(1.0, 1.0, 1.0, 1.0))

		# sheen over the top, following the shape's own round corners
		if sheenAlpha > 0.0:
			var top: float = rect.position.y
			var cutHeight: float = rect.size.y * sheenHeight
			var cut: PackedVector2Array = PackedVector2Array([Vector2(rect.position.x - 2.0, top - 2.0), Vector2(rect.end.x + 2.0, top - 2.0), Vector2(rect.end.x + 2.0, top + cutHeight), Vector2(rect.position.x - 2.0, top + cutHeight)])
			for piece in Geometry2D.intersect_polygons(inner, cut):
				var pieceColours := PackedColorArray()
				for point in piece:
					var down: float = clampf((point.y - top) / maxf(cutHeight, 1.0), 0.0, 1.0)
					pieceColours.append(Color(1.0, 1.0, 1.0, sheenAlpha * (1.0 - down)))
				RenderingServer.canvas_item_add_polygon(canvasItem, piece, pieceColours)

		# glow along the bottom edge
		if glowColour.a > 0.0:
			var bottom: float = rect.end.y
			var glowTop: float = bottom - rect.size.y * glowHeight
			var glowCut: PackedVector2Array = PackedVector2Array([Vector2(rect.position.x - 2.0, glowTop), Vector2(rect.end.x + 2.0, glowTop), Vector2(rect.end.x + 2.0, bottom + 2.0), Vector2(rect.position.x - 2.0, bottom + 2.0)])
			for piece in Geometry2D.intersect_polygons(inner, glowCut):
				var glowColours := PackedColorArray()
				for point in piece:
					var up: float = clampf((point.y - glowTop) / maxf(bottom - glowTop, 1.0), 0.0, 1.0)
					glowColours.append(Color(glowColour, glowColour.a * up * up))
				RenderingServer.canvas_item_add_polygon(canvasItem, piece, glowColours)

		# the wet streak and its bead of light
		if lensAlpha > 0.0:
			var startX: float = rect.position.x + maxf(radii.x * 0.75, 10.0)
			var across: float = minf(rect.size.x * 0.42, lensWidth)
			var centre: Vector2 = Vector2(startX + across * 0.5, rect.position.y + 2.5 + lensHeight * 0.5)
			var lensPoints := PackedVector2Array()
			var lensColours := PackedColorArray()
			for index in range(20):
				var angle: float = TAU * float(index) / 20.0
				var point: Vector2 = centre + Vector2(cos(angle) * across * 0.5, sin(angle) * lensHeight * 0.5)
				var down: float = clampf((point.y - rect.position.y - 2.5) / maxf(lensHeight, 1.0), 0.0, 1.0)
				lensPoints.append(point)
				lensColours.append(Color(1.0, 1.0, 1.0, lensAlpha * pow(1.0 - down, 1.4)))
			RenderingServer.canvas_item_add_polygon(canvasItem, lensPoints, lensColours)
			Art.disc(canvasItem, centre + Vector2(across * 0.5 + 7.0, 0.0), 1.7, Color(1.0, 1.0, 1.0, lensAlpha * 0.9))

		# droplets sitting on the glass
		for drop in droplets:
			var x: float = drop.x
			var y: float = drop.y
			if x < 0.0:
				x = rect.end.x + x
			else:
				x = rect.position.x + x
			if y < 0.0:
				y = rect.end.y + y
			else:
				y = rect.position.y + y
			Art.droplet(canvasItem, Vector2(x, y), drop.z, dropTint, darkGlass)


### /// THE SKY ///

class SkyBox extends StyleBox:
	## the page: a three-colour sky, swoosh ribbons behind the header and the bottom bar, and bubbles
	## - the colours, how bright the glass is (dark flag) and the strengths are set by the style

	var skyTop: Color = Color(0.1, 0.12, 0.2)
	var skyMiddle: Color = Color(0.07, 0.08, 0.12)
	var skyBottom: Color = Color(0.12, 0.1, 0.1)
	var middleAt: float = 0.5
	var darkSky: bool = true
	var accent: Color = Color(1.0, 0.4, 0.2)
	var cold: Color = Color(0.2, 0.4, 1.0)
	var water: Color = Color(0.4, 0.9, 1.0)
	var swooshAmount: float = 1.0
	var bubbleAmount: float = 1.0
	var bubbles: Array = []

	func _draw(canvasItem: RID, rect: Rect2) -> void:
		### WHAT THIS DOES
		# sky first, then (on a full-size page only) the swooshes and the bubbles

		var left: float = rect.position.x
		var right: float = rect.end.x
		var top: float = rect.position.y
		var bottom: float = rect.end.y
		var middle: float = top + rect.size.y * middleAt

		# sky
		RenderingServer.canvas_item_add_polygon(canvasItem, PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, middle), Vector2(left, middle)]), PackedColorArray([skyTop, skyTop, skyMiddle, skyMiddle]))
		RenderingServer.canvas_item_add_polygon(canvasItem, PackedVector2Array([Vector2(left, middle), Vector2(right, middle), Vector2(right, bottom), Vector2(left, bottom)]), PackedColorArray([skyMiddle, skyMiddle, skyBottom, skyBottom]))
		if rect.size.x < 260.0 or rect.size.y < 420.0:
			return

		var unit: float = rect.size.x / 430.0
		var width: float = rect.size.x
		var height: float = rect.size.y
		var origin: Vector2 = rect.position
		var white: Color = Color.WHITE
		var swooshWhite: Color = white
		var boost: float = swooshAmount * 1.9
		if not darkSky:
			swooshWhite = water.lerp(white, 0.5)
			boost = swooshAmount * 2.3

		# swooshes behind the header
		Art.ribbon(canvasItem, origin + Vector2(-0.08 * width, 215.0 * unit), origin + Vector2(0.22 * width, 275.0 * unit), origin + Vector2(0.62 * width, 20.0 * unit), origin + Vector2(1.08 * width, 100.0 * unit), 58.0 * unit, accent, water, 0.30 * boost)
		Art.ribbon(canvasItem, origin + Vector2(-0.08 * width, 125.0 * unit), origin + Vector2(0.30 * width, 225.0 * unit), origin + Vector2(0.70 * width, -15.0 * unit), origin + Vector2(1.08 * width, 160.0 * unit), 36.0 * unit, cold, swooshWhite, 0.34 * boost)
		Art.ribbon(canvasItem, origin + Vector2(-0.08 * width, 178.0 * unit), origin + Vector2(0.25 * width, 242.0 * unit), origin + Vector2(0.65 * width, 0.0), origin + Vector2(1.08 * width, 62.0 * unit), 9.0 * unit, swooshWhite, swooshWhite, 0.40 * boost)

		# swooshes behind the bottom bar
		Art.ribbon(canvasItem, origin + Vector2(-0.08 * width, height - 150.0 * unit), origin + Vector2(0.30 * width, height - 40.0 * unit), origin + Vector2(0.70 * width, height - 230.0 * unit), origin + Vector2(1.08 * width, height - 110.0 * unit), 52.0 * unit, water, cold, 0.22 * boost)
		Art.ribbon(canvasItem, origin + Vector2(-0.08 * width, height - 112.0 * unit), origin + Vector2(0.35 * width, height - 8.0 * unit), origin + Vector2(0.75 * width, height - 190.0 * unit), origin + Vector2(1.08 * width, height - 60.0 * unit), 11.0 * unit, accent, swooshWhite, 0.34 * boost)

		# bubbles
		var tints: Array = [water, accent, cold, white]
		for entry in bubbles:
			var centre: Vector2 = origin + Vector2(float(entry[0]) * width, float(entry[1]) * height)
			var tint: Color = tints[int(entry[3])]
			Art.bubble(canvasItem, centre, float(entry[2]) * unit, tint, float(entry[4]) * bubbleAmount, darkSky)


### /// THE HEADER FIZZ ///

class HeaderFizz extends Control:
	## small bubbles that rise beside the page title with a light streak under the header row - it
	## sits behind the page content, takes no input and follows the header's size

	var headerRow: Control = null
	var titleLabel: Label = null
	var count: int = 7
	var tintWater: Color = Color(0.4, 0.9, 1.0)
	var tintAccent: Color = Color(1.0, 0.4, 0.2)
	var darkSky: bool = true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		### WHAT THIS DOES
		# bubbles rising to the right of the title text, bigger ones lower and smaller higher

		if headerRow == null or titleLabel == null or not is_instance_valid(headerRow):
			return
		var headerRect: Rect2 = headerRow.get_global_rect()
		var origin: Vector2 = get_global_transform().affine_inverse() * headerRect.position
		var textWidth: float = 0.0
		if titleLabel.get_theme_font("font") != null:
			textWidth = titleLabel.get_theme_font("font").get_string_size(titleLabel.text, HORIZONTAL_ALIGNMENT_LEFT, -1, titleLabel.get_theme_font_size("font_size")).x
		var startX: float = titleLabel.get_global_rect().position.x - headerRect.position.x + origin.x + textWidth + 26.0
		var baseY: float = origin.y + headerRect.size.y * 0.5
		var room: float = origin.x + headerRect.size.x - 70.0 - startX
		if room < 24.0:
			return
		var tints: Array = [tintWater, tintAccent, Color.WHITE]
		for index in range(count):
			var along: float = float(index) / float(maxi(count - 1, 1))
			var wobble: float = sin(float(index) * 2.1)
			var radius: float = 3.0 + 6.0 * (1.0 - along) + 2.0 * absf(wobble)
			var x: float = startX + room * along * 0.9
			var y: float = baseY - 3.0 - along * 16.0 + wobble * 8.0
			Art.bubble(get_canvas_item(), Vector2(x, y), radius, tints[index % 3], 0.9, darkSky)


### /// COLOURS ///

func _init() -> void:
	styleId = "frutiger"
	styleName = "Frutiger"
	buttonRadius = pillRadius
	cardRadius = 26
	sheetRadius = 34
	chipRadius = 24
	rowRadius = 22
	fieldRadius = 24
	tagRadius = 12
	buttonPadH = 22
	buttonPadV = 15
	chipPadH = 16
	chipPadV = 10
	cardPad = 18
	rowPadH = 16
	rowPadV = 12
	fieldPadH = 20
	fieldPadV = 14
	tagPadH = 10
	tagPadV = 3
	tagFillAlpha = 0.3
	grabberSize = 32
	checkSize = 30
	sliderThickness = 12
	boldStrength = 0.5


func _isDark(colours: Dictionary) -> bool:
	var base: Color = colours["bg"]
	return base.get_luminance() < 0.4


func boldFont() -> Font:
	var bold := FontVariation.new()
	bold.base_font = regularFont()
	bold.variation_embolden = boldStrength
	bold.spacing_glyph = 0
	return bold


### /// DECORATION ///

func decorateFrame(parts: Dictionary, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# the header fizz: bubbles rising beside the title, behind the page content

	var page: Control = parts.get("page", null)
	var header: Control = parts.get("header", null)
	var titleLabel: Label = parts.get("titleLabel", null)
	if page == null or header == null or titleLabel == null:
		return

	var fizz := HeaderFizz.new()
	fizz.headerRow = header
	fizz.titleLabel = titleLabel
	fizz.count = headerFizzCount
	fizz.tintWater = colours["ghost"]
	fizz.tintAccent = colours["accent"]
	fizz.darkSky = _isDark(colours)
	page.add_child(fizz)
	page.move_child(fizz, 0)
	fizz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header.resized.connect(fizz.queue_redraw)
	titleLabel.resized.connect(fizz.queue_redraw)
	titleLabel.minimum_size_changed.connect(fizz.queue_redraw)


func drawCardChrome(card: Control, rect: Rect2, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# behind the body figures: a faint swoosh crossing the card and a few bubbles in the bottom corners

	var canvasItem: RID = card.get_canvas_item()
	var dark: bool = _isDark(colours)
	var water: Color = colours["ghost"]
	var accent: Color = colours["accent"]
	var cold: Color = colours["cold"]
	var white: Color = Color.WHITE
	var swooshWhite: Color = white
	if not dark:
		swooshWhite = water.lerp(white, 0.5)
	var width: float = rect.size.x
	var height: float = rect.size.y
	if width < 200.0 or height < 200.0:
		return

	Art.ribbon(canvasItem, Vector2(-8.0, height * 0.78), Vector2(width * 0.3, height * 0.98), Vector2(width * 0.62, height * 0.5), Vector2(width + 8.0, height * 0.62), 40.0, water, cold, 0.16 * swooshStrength)
	Art.ribbon(canvasItem, Vector2(-8.0, height * 0.86), Vector2(width * 0.34, height * 1.02), Vector2(width * 0.66, height * 0.58), Vector2(width + 8.0, height * 0.7), 7.0, swooshWhite, accent, 0.26 * swooshStrength)
	Art.bubble(canvasItem, Vector2(width * 0.08, height * 0.82), 15.0, water, 0.9 * bubbleStrength, dark)
	Art.bubble(canvasItem, Vector2(width * 0.15, height * 0.9), 7.0, white, 0.9 * bubbleStrength, dark)
	Art.bubble(canvasItem, Vector2(width * 0.93, height * 0.2), 11.0, water, 0.9 * bubbleStrength, dark)
	Art.bubble(canvasItem, Vector2(width * 0.89, height * 0.29), 5.0, accent, 0.9 * bubbleStrength, dark)


### /// BOXES ///

func _wet(top: Color, bottom: Color, radius: float, padH: float, padV: float) -> WetBox:
	var made := WetBox.new()
	made.fillTop = top
	made.fillBottom = bottom
	made.radii = Vector4(radius, radius, radius, radius)
	made.content_margin_left = padH
	made.content_margin_right = padH
	made.content_margin_top = padV
	made.content_margin_bottom = padV
	return made


func _skyBox(colours: Dictionary) -> SkyBox:
	var dark: bool = _isDark(colours)
	var base: Color = colours["bg"]
	var cold: Color = colours["cold"]
	var accent: Color = colours["accent"]
	var made := SkyBox.new()
	made.darkSky = dark
	made.middleAt = skyMiddleAt
	made.accent = accent
	made.cold = cold
	made.water = colours["ghost"]
	made.swooshAmount = swooshStrength
	made.bubbleAmount = bubbleStrength
	made.bubbles = pageBubbles
	if dark:
		made.skyTop = base.lerp(cold, skyColdAmountDark)
		made.skyMiddle = base
		made.skyBottom = base.lerp(accent, skyAccentAmountDark)
	else:
		made.skyTop = base.lerp(cold, skyColdAmountLight).lerp(Color.WHITE, 0.1)
		made.skyMiddle = base.lerp(Color.WHITE, 0.45)
		made.skyBottom = base.lerp(accent, skyAccentAmountLight)
	return made


func box(role: String, colours: Dictionary, tint: Color = Color(0, 0, 0, 0)) -> StyleBox:
	### WHAT THIS DOES
	# every role as glass: gradients, sheen, glow, a streak of wet light - dark glass or bright glass

	var dark: bool = _isDark(colours)
	var surface: Color = colours["surface"]
	var surfaceHi: Color = colours["surfaceHi"]
	var accent: Color = colours["accent"]
	var cold: Color = colours["cold"]
	var water: Color = colours["ghost"]
	var text: Color = colours["text"]
	var line: Color = colours["line"]
	var white: Color = Color.WHITE
	var clear: Color = Color(0, 0, 0, 0)

	var gloss: float = glossLight
	var lens: float = lensAlphaLight
	var glassAlpha: float = cardAlphaLight
	var rim: Color = Color(cold.lerp(white, 0.5), 0.6)
	var edgeLight: Color = Color(white, 0.9)
	var shadowTint: Color = Color(cold.darkened(0.35), 0.22)
	if dark:
		gloss = glossDark
		lens = lensAlphaDark
		glassAlpha = cardAlphaDark
		rim = Color(accent.lerp(white, 0.55), 0.36)
		edgeLight = Color(white, 0.30)
		shadowTint = Color(0.0, 0.0, 0.0, 0.4)

	# glass colours shared by cards, rows, sheets and popups
	var glassTop: Color = Color(surface, glassAlpha)
	var glassBottom: Color = Color(surface.lerp(cold, 0.1), glassAlpha - 0.08)
	if dark:
		glassTop = Color(surface.lerp(white, 0.07), glassAlpha)
		glassBottom = Color(surface.darkened(0.12), glassAlpha + 0.04)
	var glassGlow: Color = Color(water, 0.16)
	if not dark:
		glassGlow = Color(water.lerp(white, 0.3), 0.30)

	# orb colours for plain buttons and chips
	var orbTop: Color = surfaceHi.lerp(white, 0.55)
	var orbBottom: Color = surfaceHi.lerp(cold, 0.2)
	var orbRim: Color = Color(cold.lerp(white, 0.35), 0.55)
	var orbGlow: Color = Color(water.lerp(white, 0.3), 0.55)
	if dark:
		orbTop = surfaceHi.lerp(white, 0.16)
		orbBottom = surfaceHi.darkened(0.12)
		orbRim = Color(accent.lerp(white, 0.5), 0.42)
		orbGlow = Color(water, 0.38)

	# accent orb colours
	var gelTop: Color = accent.lightened(0.26)
	var gelBottom: Color = accent.darkened(0.12)
	var gelRim: Color = Color(accent.lerp(white, 0.65), 0.7)
	var gelGlow: Color = Color(accent.lerp(white, 0.55), 0.62)
	var gelShadow: Color = Color(accent, 0.42)
	if not dark:
		gelShadow = Color(accent.darkened(0.15), 0.4)

	match role:
		"button", "button.hover", "button.pressed", "button.disabled":
			var made: WetBox = _wet(orbTop, orbBottom, pillRadius, buttonPadH, buttonPadV)
			made.sheenAlpha = gloss * 1.1
			made.sheenHeight = 0.52
			made.glowColour = orbGlow
			made.glowHeight = 0.45
			made.lensAlpha = lens
			made.lensWidth = 70.0
			made.lensHeight = 9.0
			made.darkGlass = dark
			made.dropTint = water
			made.borderColour = orbRim
			made.borderWidth = 1.0
			made.shadowColour = shadowTint
			made.shadowSize = 6.0
			made.shadowOffset = Vector2(0.0, 3.0)
			if role == "button.hover":
				made.fillTop = orbTop.lerp(white, 0.3)
				made.fillBottom = orbBottom.lerp(white, 0.12)
				made.borderColour = Color(orbRim, 0.85)
			if role == "button.pressed":
				made.fillTop = surfaceHi.lerp(accent, 0.4).darkened(0.1)
				made.fillBottom = surfaceHi.lerp(accent, 0.55)
				made.glowColour = Color(accent.lerp(white, 0.4), 0.55)
				made.sheenAlpha = gloss * 0.5
				made.shadowSize = 0.0
				made.lensAlpha = lens * 0.5
				made.borderColour = Color(accent.lerp(white, 0.4), 0.7)
			if role == "button.disabled":
				made.fillTop = Color(surface, 0.7)
				made.fillBottom = Color(surface, 0.6)
				made.sheenAlpha = gloss * 0.4
				made.glowColour = clear
				made.lensAlpha = 0.0
				made.shadowSize = 0.0
				made.borderColour = Color(line, 0.6)
			return made

		"accent", "accent.hover", "accent.pressed", "accent.disabled":
			var made: WetBox = _wet(gelTop, gelBottom, pillRadius, buttonPadH, buttonPadV)
			made.sheenAlpha = 0.18 + gloss
			made.sheenHeight = 0.52
			made.glowColour = gelGlow
			made.glowHeight = 0.5
			made.lensAlpha = 0.45 + lens * 0.5
			made.lensWidth = 90.0
			made.lensHeight = 10.0
			made.darkGlass = dark
			made.dropTint = water
			made.borderColour = gelRim
			made.borderWidth = 1.2
			made.shadowColour = gelShadow
			made.shadowSize = 10.0
			made.shadowOffset = Vector2(0.0, 4.0)
			if role == "accent.hover":
				made.fillTop = gelTop.lightened(0.08)
				made.fillBottom = gelBottom.lightened(0.08)
			if role == "accent.pressed":
				made.fillTop = accent.darkened(0.12)
				made.fillBottom = accent.lightened(0.04)
				made.sheenAlpha = 0.1
				made.lensAlpha = 0.2
				made.shadowSize = 3.0
			if role == "accent.disabled":
				made.fillTop = accent.lerp(surface, 0.62)
				made.fillBottom = accent.lerp(surface, 0.7)
				made.sheenAlpha = 0.1
				made.glowColour = clear
				made.lensAlpha = 0.0
				made.shadowSize = 0.0
				made.borderColour = Color(accent.lerp(surface, 0.4), 0.5)
			return made

		"flat":
			return flat(clear, pillRadius, buttonPadH, buttonPadV)
		"flat.hover":
			return flat(Color(accent, 0.12), pillRadius, buttonPadH, buttonPadV)
		"flat.pressed":
			return flat(Color(accent, 0.22), pillRadius, buttonPadH, buttonPadV)

		"chip", "chip.hover":
			var made: WetBox = _wet(orbTop, orbBottom, chipRadius, chipPadH, chipPadV)
			made.sheenAlpha = gloss
			made.sheenHeight = 0.5
			made.glowColour = Color(orbGlow, orbGlow.a * 0.7)
			made.glowHeight = 0.45
			made.lensAlpha = lens * 0.8
			made.lensWidth = 40.0
			made.lensHeight = 7.0
			made.borderColour = orbRim
			made.borderWidth = 1.0
			made.shadowColour = shadowTint
			made.shadowSize = 4.0
			made.shadowOffset = Vector2(0.0, 2.0)
			if role == "chip.hover":
				made.fillTop = orbTop.lerp(white, 0.3)
				made.fillBottom = orbBottom.lerp(white, 0.12)
			return made

		"chip.on", "chip.onHover":
			var made: WetBox = _wet(gelTop, gelBottom, chipRadius, chipPadH, chipPadV)
			made.sheenAlpha = 0.16 + gloss
			made.sheenHeight = 0.5
			made.glowColour = Color(gelGlow, 0.5)
			made.glowHeight = 0.5
			made.lensAlpha = 0.45 + lens * 0.4
			made.lensWidth = 40.0
			made.lensHeight = 7.0
			made.borderColour = gelRim
			made.borderWidth = 1.0
			made.shadowColour = Color(gelShadow, gelShadow.a * 0.8)
			made.shadowSize = 7.0
			made.shadowOffset = Vector2(0.0, 2.0)
			if role == "chip.onHover":
				made.fillTop = gelTop.lightened(0.07)
				made.fillBottom = gelBottom.lightened(0.07)
			return made

		"card":
			var made: WetBox = _wet(glassTop, glassBottom, cardRadius, cardPad, cardPad)
			made.sheenAlpha = gloss * 0.8
			made.sheenHeight = 0.26
			made.glowColour = glassGlow
			made.glowHeight = 0.3
			made.lensAlpha = lens * 0.8
			made.lensWidth = 120.0
			made.lensHeight = 7.0
			made.highlightAlpha = edgeLight.a
			made.borderColour = rim
			made.borderWidth = 1.0
			made.shadowColour = shadowTint
			made.shadowSize = 14.0
			made.shadowOffset = Vector2(0.0, 6.0)
			made.darkGlass = dark
			made.dropTint = water
			var drops: Array = [Vector3(-16.0, -12.0, dropletSize), Vector3(-30.0, -8.0, dropletSize * 0.55), Vector3(12.0, -9.0, dropletSize * 0.7)]
			made.droplets = drops.slice(0, dropletsOnCards)
			return made

		"row":
			var made: WetBox = _wet(glassTop, glassBottom, rowRadius, rowPadH, rowPadV)
			made.sheenAlpha = gloss * 0.6
			made.sheenHeight = 0.4
			made.glowColour = Color(glassGlow, glassGlow.a * 0.7)
			made.glowHeight = 0.3
			made.highlightAlpha = edgeLight.a * 0.8
			made.borderColour = Color(rim, rim.a * 0.65)
			made.borderWidth = 1.0
			made.shadowColour = shadowTint
			made.shadowSize = 6.0
			made.shadowOffset = Vector2(0.0, 3.0)
			return made

		"rowRing":
			var ring: StyleBoxFlat = flat(clear, rowRadius, 0, 0, accent.lightened(0.1), 3)
			ring.draw_center = false
			return ring

		"sheet":
			var sheetTop: Color = Color(glassTop, 0.96)
			var sheetBottom: Color = Color(glassBottom, 0.98)
			var made: WetBox = _wet(sheetTop, sheetBottom, sheetRadius, cardPad + 4, cardPad + 4)
			made.radii = Vector4(sheetRadius, sheetRadius, 0.0, 0.0)
			made.sheenAlpha = gloss * 0.8
			made.sheenHeight = 0.12
			made.lensAlpha = lens
			made.lensWidth = 170.0
			made.lensHeight = 8.0
			made.highlightAlpha = edgeLight.a
			made.borderColour = rim
			made.borderWidth = 1.2
			made.shadowColour = Color(accent.lerp(cold, 0.5), 0.28)
			if not dark:
				made.shadowColour = Color(cold.darkened(0.3), 0.3)
			made.shadowSize = 22.0
			made.shadowOffset = Vector2(0.0, -4.0)
			return made

		"sheetHandle":
			return flat(Color(text, 0.28), 3, 0, 0)

		"background":
			return _skyBox(colours)

		"popup":
			var made: WetBox = _wet(Color(glassTop, 0.97), Color(glassBottom, 0.98), cardRadius, cardPad, cardPad)
			made.sheenAlpha = gloss * 0.7
			made.sheenHeight = 0.2
			made.lensAlpha = lens * 0.7
			made.lensWidth = 90.0
			made.lensHeight = 6.0
			made.highlightAlpha = edgeLight.a
			made.borderColour = rim
			made.borderWidth = 1.0
			made.shadowColour = shadowTint
			made.shadowSize = 16.0
			made.shadowOffset = Vector2(0.0, 6.0)
			return made

		"popupHover":
			var made: WetBox = _wet(Color(accent, 0.30), Color(accent, 0.16), 16.0, 8.0, 8.0)
			made.sheenAlpha = gloss * 0.8
			made.sheenHeight = 0.5
			made.borderColour = Color(accent.lerp(white, 0.4), 0.5)
			made.borderWidth = 1.0
			return made

		"field", "field.focus", "field.readOnly":
			# an inset glass trough: darker at the top, lit along the bottom lip
			var inTop: Color = surfaceHi.darkened(0.04)
			var inBottom: Color = surfaceHi.lerp(white, 0.5)
			if dark:
				inTop = surfaceHi.darkened(0.25)
				inBottom = surfaceHi.lerp(white, 0.04)
			var made: WetBox = _wet(inTop, inBottom, fieldRadius, fieldPadH, fieldPadV)
			made.borderColour = Color(cold.lerp(line, 0.5), 0.7)
			made.borderWidth = 1.0
			made.glowColour = Color(water, 0.14)
			made.glowHeight = 0.3
			if role == "field.focus":
				made.borderColour = accent
				made.borderWidth = 2.0
				made.shadowColour = Color(accent, 0.4)
				made.shadowSize = 7.0
				made.shadowOffset = Vector2(0.0, 0.0)
			if role == "field.readOnly":
				made.fillTop = Color(surface, 0.7)
				made.fillBottom = Color(surface, 0.6)
				made.glowColour = clear
			return made

		"track":
			var trackTop: Color = surfaceHi.darkened(0.2)
			var trackBottom: Color = surfaceHi.lerp(white, 0.1)
			if not dark:
				trackTop = surfaceHi.darkened(0.12)
				trackBottom = surfaceHi.lerp(white, 0.6)
			var made: WetBox = _wet(trackTop, trackBottom, 20.0, 0.0, float(sliderThickness) * 0.5)
			made.borderColour = Color(cold.lerp(line, 0.5), 0.6)
			made.borderWidth = 1.0
			made.glowColour = Color(white, 0.2)
			made.glowHeight = 0.5
			return made

		"trackFill":
			var made: WetBox = _wet(gelTop, gelBottom, 20.0, 0.0, float(sliderThickness) * 0.5)
			made.sheenAlpha = 0.45
			made.sheenHeight = 0.5
			made.glowColour = Color(gelGlow, 0.4)
			made.glowHeight = 0.5
			made.borderColour = Color(accent.lerp(white, 0.5), 0.5)
			made.borderWidth = 1.0
			return made

		"progress":
			var made: WetBox = _wet(surfaceHi.darkened(0.15), surfaceHi.lerp(white, 0.2), 20.0, 0.0, 0.0)
			made.borderColour = Color(line, 0.6)
			made.borderWidth = 1.0
			return made

		"progressFill":
			var made: WetBox = _wet(gelTop, gelBottom, 20.0, 0.0, 0.0)
			made.sheenAlpha = 0.45
			made.sheenHeight = 0.5
			made.glowColour = Color(gelGlow, 0.35)
			made.glowHeight = 0.5
			return made

		"tile":
			var tileTop: Color = Color(surfaceHi.lerp(white, 0.1), 0.86)
			var tileBottom: Color = Color(surfaceHi, 0.8)
			if not dark:
				tileTop = Color(surfaceHi.lerp(white, 0.6), 0.9)
				tileBottom = Color(surfaceHi.lerp(cold, 0.08), 0.78)
			var made: WetBox = _wet(tileTop, tileBottom, 20.0, 12.0, 10.0)
			made.sheenAlpha = gloss * 0.6
			made.sheenHeight = 0.4
			made.highlightAlpha = edgeLight.a * 0.8
			made.glowColour = Color(glassGlow, glassGlow.a * 0.7)
			made.glowHeight = 0.3
			made.borderColour = Color(rim, rim.a * 0.8)
			made.borderWidth = 1.0
			return made

		"tag":
			var tagTop: Color = Color(tint.lightened(0.15), tagFillAlpha + 0.18)
			var tagBottom: Color = Color(tint, tagFillAlpha - 0.04)
			var made: WetBox = _wet(tagTop, tagBottom, 14.0, tagPadH, tagPadV)
			made.sheenAlpha = 0.22
			made.sheenHeight = 0.5
			made.borderColour = Color(tint.lightened(0.2), 0.6)
			made.borderWidth = 1.0
			return made

		"planned":
			var made: WetBox = _wet(Color(surface, 0.4), Color(surface, 0.24), rowRadius, rowPadH, rowPadV)
			made.sheenAlpha = gloss * 0.4
			made.sheenHeight = 0.4
			made.borderColour = tint
			made.borderWidth = 2.0
			return made

		"swipe":
			return flat(tint, rowRadius, 0, 0)

		"balance":
			var made: WetBox = _wet(tint.lightened(0.28), tint.darkened(0.04), 10.0, 0.0, 0.0)
			made.sheenAlpha = 0.4
			made.sheenHeight = 0.5
			made.glowColour = Color(tint.lightened(0.5), 0.4)
			made.glowHeight = 0.5
			return made

		"toast":
			var made: WetBox = _wet(text.lerp(white, 0.1), text.lerp(colours["bg"], 0.2), 28.0, 20.0, 6.0)
			made.content_margin_right = 8
			made.sheenAlpha = 0.14
			made.sheenHeight = 0.5
			made.glowColour = Color(water, 0.22)
			made.glowHeight = 0.4
			made.lensAlpha = 0.4
			made.lensWidth = 60.0
			made.lensHeight = 7.0
			made.borderColour = Color(white, 0.3)
			made.borderWidth = 1.0
			made.shadowColour = Color(0.0, 0.0, 0.0, 0.35)
			made.shadowSize = 12.0
			made.shadowOffset = Vector2(0.0, 4.0)
			return made

	push_error("Frutiger: unknown box role '%s'" % role)
	return flat(Color.MAGENTA, 0, 0, 0)


### /// THEME PIECES ///

func _addLabels(built: Theme, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# the normal label looks, then a glass-text halo on the page titles (white on light palettes, a
	# cold glow on dark ones) - the classic Aero title glow

	super._addLabels(built, colours)
	var halo: Color = Color(Color.WHITE, 0.8)
	var haloSize: int = 5
	if _isDark(colours):
		var water: Color = colours["ghost"]
		halo = Color(water, 0.16)
		haloSize = 7
	for typeName in ["HeaderLabel", "TitleLabel"]:
		built.set_color("font_shadow_color", typeName, halo)
		built.set_constant("shadow_offset_x", typeName, 0)
		built.set_constant("shadow_offset_y", typeName, 1)
		built.set_constant("shadow_outline_size", typeName, haloSize)


func _addSliders(built: Theme, colours: Dictionary) -> void:
	### WHAT THIS DOES
	# glass tube tracks filled with liquid, and a glossy bead as the handle

	super._addSliders(built, colours)
	var dark: bool = _isDark(colours)
	var bead: ImageTexture = orbIcon(grabberSize, colours["accent"], dark, false)
	var beadHot: ImageTexture = orbIcon(grabberSize, colours["accent"], dark, true)
	for typeName in ["HSlider", "VSlider"]:
		built.set_icon("grabber", typeName, bead)
		built.set_icon("grabber_highlight", typeName, beadHot)
		built.set_icon("grabber_disabled", typeName, bead)


func _addPanels(built: Theme, colours: Dictionary) -> void:
	super._addPanels(built, colours)
	var separator := StyleBoxLine.new()
	separator.color = Color(colours["line"], 0.7)
	separator.thickness = 1
	built.set_stylebox("separator", "HSeparator", separator)


### /// ICONS ///

func orbIcon(size: int, colour: Color, dark: bool, lit: bool) -> ImageTexture:
	### WHAT THIS DOES
	# a glossy bead: lit from the top left, a bright pool of light low down, a window-shaped
	# highlight and a pale rim

	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre: float = (size - 1) * 0.5
	var radius: float = size * 0.5 - 1.0
	var topColour: Color = colour.lightened(0.38)
	var bottomColour: Color = colour.darkened(0.22)
	if lit:
		topColour = topColour.lightened(0.12)
		bottomColour = bottomColour.lightened(0.12)
	var poolColour: Color = colour.lerp(Color.WHITE, 0.6)

	for y in range(size):
		for x in range(size):
			var dx: float = (float(x) - centre) / radius
			var dy: float = (float(y) - centre) / radius
			var distance: float = Vector2(float(x) - centre, float(y) - centre).length()
			var coverage: float = clampf(radius - distance + 0.5, 0.0, 1.0)
			var shade: float = clampf(0.5 + 0.5 * (dy * 0.9 + dx * 0.3), 0.0, 1.0)
			var pixel: Color = topColour.lerp(bottomColour, shade)

			# pool of light near the bottom
			var pool: float = clampf(dy * 1.5 - 0.55, 0.0, 1.0) * clampf(1.0 - absf(dx) * 0.9, 0.0, 1.0)
			pixel = pixel.lerp(poolColour, pool * 0.6)

			# window highlight top left
			var ex: float = (dx + 0.12) / 0.58
			var ey: float = (dy + 0.52) / 0.28
			var inside: float = ex * ex + ey * ey
			if inside < 1.0:
				pixel = pixel.lerp(Color.WHITE, 0.78 * pow(1.0 - inside, 0.6))

			# pale rim
			var rimDepth: float = clampf((distance - (radius - 1.8)) / 1.8, 0.0, 1.0)
			pixel = pixel.lerp(Color.WHITE, 0.5 * rimDepth)
			pixel.a = coverage
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)


func checkIcon(size: int, ticked: bool, colours: Dictionary) -> ImageTexture:
	### WHAT THIS DOES
	# a glass box: a glossy accent gel with a white tick when checked, clear glass with a rim when not

	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius: float = float(size) * 0.34
	var inset: float = 1.5
	var border: float = 2.0
	var lo: float = inset
	var hi: float = size - 1 - inset
	var accent: Color = colours["accent"]
	var topColour: Color = accent.lightened(0.28)
	var bottomColour: Color = accent.darkened(0.1)
	var tickA: Vector2 = Vector2(size * 0.26, size * 0.52)
	var tickB: Vector2 = Vector2(size * 0.43, size * 0.69)
	var tickC: Vector2 = Vector2(size * 0.75, size * 0.33)
	var dark: bool = _isDark(colours)
	var emptyFill: Color = Color(colours["surface"], 0.55)
	if dark:
		emptyFill = Color(colours["surfaceHi"], 0.7)

	for y in range(size):
		for x in range(size):
			var px: float = clampf(x, lo + radius, hi - radius)
			var py: float = clampf(y, lo + radius, hi - radius)
			var outside: float = Vector2(x - px, y - py).length() - radius
			var coverage: float = clampf(0.5 - outside, 0.0, 1.0)
			var down: float = float(y) / float(size - 1)
			var pixel: Color = Color(0, 0, 0, 0)
			if ticked:
				pixel = topColour.lerp(bottomColour, down)
				# sheen over the top half, light pool along the bottom lip
				if down < 0.5:
					pixel = pixel.lerp(Color.WHITE, 0.4 * (1.0 - down / 0.5))
				if down > 0.7:
					pixel = pixel.lerp(accent.lerp(Color.WHITE, 0.6), 0.5 * (down - 0.7) / 0.3)
				var edge: float = clampf(outside + 1.8 + 0.5, 0.0, 1.0)
				pixel = pixel.lerp(accent.lerp(Color.WHITE, 0.7), 0.6 * edge)
				var tickDistance: float = minf(_segmentDistance(Vector2(x, y), tickA, tickB), _segmentDistance(Vector2(x, y), tickB, tickC))
				var tickCover: float = clampf(2.4 - tickDistance, 0.0, 1.0)
				pixel = pixel.lerp(colours["accentText"], tickCover)
				pixel.a = coverage
			else:
				pixel = emptyFill
				if down < 0.45:
					pixel = pixel.lerp(Color.WHITE, 0.22 * (1.0 - down / 0.45))
				var ringCover: float = clampf(outside + border + 0.5, 0.0, 1.0)
				pixel = pixel.lerp(colours["textMuted"], ringCover)
				pixel.a = coverage * maxf(emptyFill.a, ringCover)
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)
