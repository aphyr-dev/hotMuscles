class_name AppScreen
extends Control
## AppScreen - what every full screen shares
## what this offers
## - app: the AppRoot that shows it (set before it enters the tree)
## - onBack() -> bool      the back button / gesture; true = handled here, false = AppRoot goes back
## - onShown()             it became the top screen (refresh what may have changed meanwhile)
## - rebuild()             the theme changed - rebuild anything with colours set in code
## - buildFrame(title, backText) -> {page, header, content, bottom}
##       a background page with a header row (back button, title), a content box that fills the
##       middle and a bottom bar box; screens put their scroll list in content, main buttons in bottom
## - makeScroll(parent) -> KineticScroll with a padded column inside (returns the column via meta "column")

### /// TUNING ///

# side padding of every screen
const pagePad: int = 12
# gap between the stacked parts of a page
const pageGap: int = 12

var app: Node = null
var backButton: Button = null
var titleLabel: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func onBack() -> bool:
	return false


func onShown() -> void:
	pass


func rebuild() -> void:
	pass


func buildFrame(title: String, backText: String) -> Dictionary:
	### WHAT THIS DOES
	# page background, header (back + title), content (fills), bottom bar

	var page := PanelContainer.new()
	page.theme_type_variation = "BackgroundPanel"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = Ui.vbox(0)
	page.add_child(column)

	# header
	var header: HBoxContainer = Ui.hbox(4)
	header.custom_minimum_size.y = 56.0
	column.add_child(Ui.margin(header, pagePad - 6, 6, pagePad, 4))
	if backText != "":
		backButton = Ui.button(backText, "FlatButton", _onBackPressed)
		backButton.add_theme_constant_override("h_separation", 2)
		backButton.custom_minimum_size = Vector2(48.0, 48.0)
		var chevron := AppIcon.new()
		chevron.kind = "back"
		chevron.colourKey = "accent"
		chevron.iconSize = 16.0
		chevron.custom_minimum_size = Vector2(16.0, 16.0)
		# the chevron sits in the button's left padding, the text is pushed right by spaces
		backButton.text = "     " + backText
		backButton.add_child(chevron)
		chevron.anchor_top = 0.5
		chevron.anchor_bottom = 0.5
		chevron.offset_top = -8.0
		chevron.offset_bottom = 8.0
		chevron.offset_left = 12.0
		chevron.offset_right = 28.0
		header.add_child(backButton)
	titleLabel = Ui.label(title, "TitleLabel")
	titleLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titleLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titleLabel.clip_text = true
	titleLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(titleLabel)

	# content and bottom bar
	var content: VBoxContainer = Ui.vbox(0)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	var bottom: VBoxContainer = Ui.vbox(8)
	column.add_child(Ui.margin(bottom, pagePad, 8, pagePad, 12))
	return {"page": page, "header": header, "content": content, "bottom": bottom}


func makeScroll(parent: Control) -> KineticScroll:
	# a list filling the parent, with a padded column for rows (scroll.get_meta("column"))
	var scroll := KineticScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var column: VBoxContainer = Ui.vbox(pageGap)
	scroll.add_child(Ui.margin(column, pagePad, 4, pagePad, 24))
	scroll.set_meta("column", column)
	return scroll


func _onBackPressed() -> void:
	if app != null:
		app.goBack()
