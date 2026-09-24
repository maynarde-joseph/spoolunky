class_name TraitTree
extends Control

## The evolution screen. Three branches, three deep, and one creature-cost each.
##
## Built in code for the same reason the bar is: it is nine of the same card,
## and a grid authored by hand is a grid where one column drifts and nobody
## notices for a month. The shape comes out of the resources — branch, depth
## and requirements — so adding a trait is dropping a .tres in a folder, and
## the screen grows a card for it with nothing here to edit.
##
## Locked traits are shown, not hidden. You should always be able to see what
## you are working toward and what it will cost, which is the one thing worth
## keeping from the genre this game is not.

const CARD := Vector2(252.0, 104.0)
const COLUMN_GAP := 18.0
const CARD_GAP := 12.0

## Owned, affordable, reachable but not yet paid for, and still locked.
const TAKEN := Color(0.62, 0.92, 0.66, 1.0)
const READY := Color(1.0, 0.98, 0.82, 1.0)
const WANTING := Color(0.82, 0.85, 0.92, 1.0)
const SHUT := Color(0.52, 0.54, 0.60, 1.0)

var open := false

var _traits: SpiderTraits
var _larder: Label
var _cards := {}
var _restore_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## Binds to a spider's traits and builds a card per trait. Safe to call once.
func setup(traits: SpiderTraits) -> void:
	if _traits != null or traits == null:
		return
	_traits = traits
	_traits.changed.connect(_refresh)
	_build()
	_refresh()


func toggle() -> void:
	if open:
		close()
	else:
		show_tree()


func show_tree() -> void:
	if open:
		return
	open = true
	visible = true
	_refresh()
	# A screen you click on needs a pointer. The spider ignores input while the
	# mouse is free, so freeing it is also what stops you spinning a web into
	# the menu you are reading.
	_restore_mouse = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	Input.set_mouse_mode(_restore_mouse)


# --- building -----------------------------------------------------------

func _build() -> void:
	# A centre container rather than a centred anchor: the page is as big as the
	# cards make it, and only the container knows that once they are in.
	var middle := CenterContainer.new()
	middle.name = "Middle"
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)

	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", 10)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(page)

	page.add_child(_heading("Evolution", 26, Color(1, 1, 1, 1)))

	_larder = _heading("", 15, Color(1.0, 0.88, 0.7, 1.0))
	page.add_child(_larder)

	page.add_child(_heading("what you have eaten is what you spend	·	[E] back",
		13, Color(0.72, 0.75, 0.82, 1.0)))

	var columns := HBoxContainer.new()
	columns.name = "Branches"
	columns.add_theme_constant_override("separation", int(COLUMN_GAP))
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(columns)

	for which in SpiderTrait.BRANCH_NAMES.size():
		columns.add_child(_column(which))


func _column(which: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = SpiderTrait.BRANCH_NAMES[which]
	column.add_theme_constant_override("separation", int(CARD_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := _heading(SpiderTrait.BRANCH_NAMES[which], 18, Color(0.86, 0.9, 1.0, 1.0))
	header.custom_minimum_size = Vector2(CARD.x, 0.0)
	column.add_child(header)

	for gift in _traits.branch(which):
		var card := _card(gift)
		column.add_child(card)
		_cards[gift.id] = card
	return column


func _card(gift: SpiderTrait) -> Panel:
	var card := Panel.new()
	card.name = gift.id
	card.custom_minimum_size = CARD
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(gift))

	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 12.0
	lines.offset_right = -12.0
	lines.offset_top = 9.0
	lines.offset_bottom = -9.0
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lines)

	lines.add_child(_line("Name", gift.display_name, 16))
	lines.add_child(_line("What", gift.description, 11))
	lines.add_child(_line("Effect", gift.effect_line(), 12))
	lines.add_child(_line("Cost", "", 12))
	return card


func _line(line_name: String, text: String, size: int) -> Label:
	var label := Label.new()
	label.name = line_name
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _heading(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- state --------------------------------------------------------------

func _refresh() -> void:
	if _traits == null:
		return
	if _larder != null:
		_larder.text = _traits.larder_line()
	for gift in _traits.tree:
		var card: Panel = _cards.get(gift.id)
		if card == null:
			continue
		_dress(card, gift)


func _dress(card: Panel, gift: SpiderTrait) -> void:
	var taken := _traits.has(gift.id)
	var reachable := _traits.unlocked(gift)
	var paid := _traits.affordable(gift)

	var tint := SHUT
	if taken:
		tint = TAKEN
	elif not reachable:
		tint = SHUT
	elif paid:
		tint = READY
	else:
		tint = WANTING

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.94)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.9 if taken or paid else 0.3)
	var edge := 3 if (taken or (reachable and paid)) else 1
	style.border_width_left = edge
	style.border_width_right = edge
	style.border_width_top = edge
	style.border_width_bottom = edge
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color(1, 1, 1, 1) if reachable or taken else Color(1, 1, 1, 0.55)

	var name_line := card.get_node_or_null(NodePath("Lines/Name")) as Label
	if name_line != null:
		name_line.add_theme_color_override("font_color", tint)

	var cost_line := card.get_node_or_null(NodePath("Lines/Cost")) as Label
	if cost_line == null:
		return
	if taken:
		cost_line.text = "— yours —"
	elif not reachable:
		cost_line.text = "needs %s" % _requirement_names(gift)
	else:
		cost_line.text = _traits.cost_line(gift)
	cost_line.add_theme_color_override("font_color", tint)


func _requirement_names(gift: SpiderTrait) -> String:
	var parts := PackedStringArray()
	for needed in gift.requires:
		var earlier := _traits.by_id(str(needed))
		parts.append(earlier.display_name if earlier != null else str(needed))
	return ", ".join(parts)


func _on_card_input(event: InputEvent, gift: SpiderTrait) -> void:
	if not open:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	_traits.buy(gift)
