class_name ShapeBox
extends StyleBox
## ShapeBox - a panel shape for styles that StyleBoxFlat cannot draw: a vertical colour gradient,
## its own radius per corner, a gloss band across the top, an inner top highlight line, a border and
## a soft drop shadow. Drawn as polygons straight into the canvas (no textures)
## what this offers (set the vars, use it anywhere a StyleBox goes):
## - fillTop / fillBottom          the gradient (same colour twice = flat)
## - radii                         Vector4(top left, top right, bottom right, bottom left) in px
## - borderColour, borderWidth     outline drawn on the edge (0 = none)
## - glossAlpha, glossHeight       a white band over the top part (glossHeight = share of the height)
## - highlightAlpha                a 1 px light line just inside the top edge (glass rim)
## - shadowColour, shadowSize, shadowOffset   a soft shadow under the shape (shadowSize 0 = none)
## - content margins: the usual StyleBox content_margin_* properties
## - ShapeBox.make(fillTop, fillBottom, radius, padH, padV) -> a box with every corner the same

### /// TUNING ///

# corner points per quarter circle
const cornerSteps: int = 8
# shadow layers (each a slightly bigger, fainter copy)
const shadowLayers: int = 4

var fillTop: Color = Color(0.2, 0.2, 0.2)
var fillBottom: Color = Color(0.15, 0.15, 0.15)
var radii: Vector4 = Vector4(12.0, 12.0, 12.0, 12.0)
var borderColour: Color = Color(0, 0, 0, 0)
var borderWidth: float = 0.0
var glossAlpha: float = 0.0
var glossHeight: float = 0.45
var highlightAlpha: float = 0.0
var shadowColour: Color = Color(0, 0, 0, 0.35)
var shadowSize: float = 0.0
var shadowOffset: Vector2 = Vector2(0.0, 2.0)


static func make(top: Color, bottom: Color, radius: float, padH: float, padV: float) -> ShapeBox:
	var made := ShapeBox.new()
	made.fillTop = top
	made.fillBottom = bottom
	made.radii = Vector4(radius, radius, radius, radius)
	made.content_margin_left = padH
	made.content_margin_right = padH
	made.content_margin_top = padV
	made.content_margin_bottom = padV
	return made


### /// DRAWING ///

func _draw(canvasItem: RID, rect: Rect2) -> void:
	### WHAT THIS DOES
	# shadow layers, then the gradient body, gloss band, rim highlight and border

	var outline: PackedVector2Array = _outline(rect, radii)

	# shadow
	if shadowSize > 0.0 and shadowColour.a > 0.0:
		for layer in range(shadowLayers):
			var grow: float = shadowSize * float(layer + 1) / float(shadowLayers)
			var layerRect: Rect2 = rect.grow(grow)
			layerRect.position += shadowOffset
			var layerColour: Color = shadowColour
			layerColour.a = shadowColour.a / float(shadowLayers + 1)
			var layerRadii: Vector4 = radii + Vector4(grow, grow, grow, grow)
			RenderingServer.canvas_item_add_polygon(canvasItem, _outline(layerRect, layerRadii), PackedColorArray([layerColour]))

	# body: per-point colours make the vertical gradient
	var colours: PackedColorArray = PackedColorArray()
	for point in outline:
		var along: float = 0.0
		if rect.size.y > 0.0:
			along = clampf((point.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		colours.append(fillTop.lerp(fillBottom, along))
	RenderingServer.canvas_item_add_polygon(canvasItem, outline, colours)

	# gloss band over the top part, fading out downwards
	if glossAlpha > 0.0:
		var glossRect: Rect2 = Rect2(rect.position + Vector2(1.0, 1.0), Vector2(rect.size.x - 2.0, rect.size.y * glossHeight))
		var glossRadii: Vector4 = Vector4(maxf(radii.x - 1.0, 0.0), maxf(radii.y - 1.0, 0.0), 0.0, 0.0)
		var glossOutline: PackedVector2Array = _outline(glossRect, glossRadii)
		var glossColours: PackedColorArray = PackedColorArray()
		for point in glossOutline:
			var down: float = clampf((point.y - glossRect.position.y) / maxf(glossRect.size.y, 1.0), 0.0, 1.0)
			glossColours.append(Color(1.0, 1.0, 1.0, glossAlpha * (1.0 - down)))
		RenderingServer.canvas_item_add_polygon(canvasItem, glossOutline, glossColours)

	# rim highlight just inside the top edge
	if highlightAlpha > 0.0:
		var y: float = rect.position.y + 1.5
		var left: float = rect.position.x + radii.x * 0.7
		var right: float = rect.end.x - radii.y * 0.7
		RenderingServer.canvas_item_add_line(canvasItem, Vector2(left, y), Vector2(right, y), Color(1.0, 1.0, 1.0, highlightAlpha), 1.0, true)

	# border
	if borderWidth > 0.0 and borderColour.a > 0.0:
		var inset: float = borderWidth * 0.5
		var borderOutline: PackedVector2Array = _outline(rect.grow(-inset), radii - Vector4(inset, inset, inset, inset))
		borderOutline.append(borderOutline[0])
		RenderingServer.canvas_item_add_polyline(canvasItem, borderOutline, PackedColorArray([borderColour]), borderWidth, true)


func _outline(rect: Rect2, cornerRadii: Vector4) -> PackedVector2Array:
	### WHAT THIS DOES
	# the rounded rectangle's edge, clockwise from the top-left corner; radii clamp to fit

	var points: PackedVector2Array = PackedVector2Array()
	var most: float = minf(rect.size.x, rect.size.y) * 0.5
	var corners: Array = [
		[maxf(minf(cornerRadii.x, most), 0.0), Vector2(rect.position.x, rect.position.y), PI],
		[maxf(minf(cornerRadii.y, most), 0.0), Vector2(rect.end.x, rect.position.y), PI * 1.5],
		[maxf(minf(cornerRadii.z, most), 0.0), Vector2(rect.end.x, rect.end.y), 0.0],
		[maxf(minf(cornerRadii.w, most), 0.0), Vector2(rect.position.x, rect.end.y), PI * 0.5],
	]
	var inward: Array = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]

	for index in range(4):
		var radius: float = corners[index][0]
		var corner: Vector2 = corners[index][1]
		var startAngle: float = corners[index][2]
		if radius <= 0.5:
			points.append(corner)
			continue
		var centre: Vector2 = corner + inward[index] * radius
		for step in range(cornerSteps + 1):
			var angle: float = startAngle + (PI * 0.5) * float(step) / float(cornerSteps)
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points
