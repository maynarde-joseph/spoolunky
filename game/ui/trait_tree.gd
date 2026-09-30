class_name TraitTree
extends Control

## The evolution screen. Three branches, three deep: what you are, and what eating
## might make you.
##
## Nothing is bought here any more — traits come from meals, by chance — so the
## screen is a map rather than a shop. Every trait you do not have yet says what
## carries it and what your odds are from a meal of each, as you are now: those
## move as you climb the ladder, as your luck runs out, and with how big the
## creature is next to you, and this is the one place all three can be read off.
##
## Built in code for the same reason the bar is: it is nine of the same card,
## and a grid authored by hand is a grid where one column drifts and nobody
## notices for a month. The shape comes out of the resources — branch, depth
## and requirements — so adding a trait is dropping a .tres in a folder, and
## the screen grows a card for it with nothing here to edit.
##
## Locked traits are shown, not hidden. You should always be able to see what
## you are working toward, which is the one thing worth keeping from the genre
## this game is not.

const CARD := Vector2(320.0, 132.0)
const COLUMN_GAP := 22.0
const CARD_GAP := 14.0

## Owned, open — something you can eat could pass it on — and still locked.
const TAKEN := Color(0.62, 0.92, 0.66, 1.0)
const OPEN := Color(1.0, 0.98, 0.82, 1.0)
const SHUT := Color(0.52, 0.54, 0.60, 1.0)

var open := false

var _traits: SpiderTraits
var _growth: SpiderGrowth
var _larder: Label
var _cards := {}
var _restore_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Anchors *and* offsets. By the time this runs the screen is already in the
	# tree, and setting anchors alone keeps the rect it has — which was none — so
	# for as long as it read like that the page sat in the top corner with nothing
	# dimmed behind it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## Binds to a spider's traits and builds a card per trait. Safe to call once.
## [param growth] is where the odds are read from; without it they are a
## spiderling's.
func setup(traits: SpiderTraits, growth: SpiderGrowth = null) -> void:
	if _traits != null or traits == null:
		return
	_traits = traits
	_growth = growth
	_traits.changed.connect(_refresh)
	if _growth != null:
		_growth.stage_changed.connect(_on_stage_changed)
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
	# Nothing on it is clicked any more, but the mouse is still freed: the spider
	# ignores input while it is, and that is what stops you spinning a web into
	# the page you are reading.
	_restore_mouse = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	Input.set_mouse_mode(_restore_mouse)


## What the card for [param trait_id] says about where the trait comes from.
func from_text(trait_id: String) -> String:
	var line := _line_of(trait_id, "From")
	return line.text if line != null else ""


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

	page.add_child(_heading("Evolution", 42, Color(1, 1, 1, 1)))

	_larder = _heading("", 24, Color(1.0, 0.88, 0.7, 1.0))
	page.add_child(_larder)

	page.add_child(_heading(
		"what you eat can change you — likelier the further up you are, and the bigger it is"
		+ "    ·    [E] back", 19, Color(0.72, 0.75, 0.82, 1.0)))

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

	var header := _heading(SpiderTrait.BRANCH_NAMES[which], 27, Color(0.86, 0.9, 1.0, 1.0))
	header.custom_minimum_size = Vector2(CARD.x, 0.0)
	column.add_child(header)

	for gift in _traits.branch(which):
		var card := _card(gift)
		column.add_child(card)
		_cards[gift.id] = card
	return column


## A card that grows to what is written on it. The list of what carries a trait
## runs to two or three lines, and a card of fixed height let it spill into the
## one below.
func _card(gift: SpiderTrait) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = gift.id
	card.custom_minimum_size = CARD
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lines)

	lines.add_child(_line("Name", gift.display_name, 23))
	lines.add_child(_line("What", gift.description, 15))
	lines.add_child(_line("Effect", gift.effect_line(), 17))
	lines.add_child(_line("From", "", 17))
	return card


func _line(line_name: String, text: String, size: int) -> Label:
	var label := Label.new()
	label.name = line_name
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CARD.x - 24.0, 0.0)
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


func _line_of(trait_id: String, line_name: String) -> Label:
	var card: Control = _cards.get(trait_id)
	if card == null:
		return null
	return card.get_node_or_null(NodePath("Lines/" + line_name)) as Label


# --- state --------------------------------------------------------------

func _on_stage_changed(_stage: GrowthStage, _index: int) -> void:
	_refresh()


func _refresh() -> void:
	if _traits == null:
		return
	if _larder != null:
		_larder.text = _traits.larder_line()
	for gift in _traits.tree:
		var card: PanelContainer = _cards.get(gift.id)
		if card == null:
			continue
		_dress(card, gift)


func _dress(card: PanelContainer, gift: SpiderTrait) -> void:
	var taken := _traits.has(gift.id)
	var reachable := _traits.unlocked(gift)
	var tint := TAKEN if taken else (OPEN if reachable else SHUT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.94)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.9 if taken else 0.35)
	var edge := 3 if taken else 1
	style.border_width_left = edge
	style.border_width_right = edge
	style.border_width_top = edge
	style.border_width_bottom = edge
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color(1, 1, 1, 1) if reachable or taken else Color(1, 1, 1, 0.55)

	var name_line := _line_of(gift.id, "Name")
	if name_line != null:
		name_line.add_theme_color_override("font_color", tint)

	var from_line := _line_of(gift.id, "From")
	if from_line == null:
		return
	if taken:
		from_line.text = "— yours —"
	elif not reachable:
		from_line.text = "needs %s" % _requirement_names(gift)
	else:
		from_line.text = _odds_line(gift)
	from_line.add_theme_color_override("font_color", tint)


## What carries it and the odds from a meal of each, for the spider as it is now.
## Carriers with the same odds are grouped, least likely first, so the end of the
## line is where to go hunting.
func _odds_line(gift: SpiderTrait) -> String:
	var rung := _growth.stage_index if _growth != null else 0
	var bite := _growth.current_stage().bite_power if _growth != null else 1
	var names_at := {}
	for kind in _traits.carriers(gift):
		var percent := roundi(_traits.odds(gift, kind, rung, kind.size_class - bite) * 100.0)
		if not names_at.has(percent):
			names_at[percent] = PackedStringArray()
		var names: PackedStringArray = names_at[percent]
		names.append(kind.display_name)
		names_at[percent] = names
	var levels: Array = names_at.keys()
	levels.sort()
	var parts := PackedStringArray()
	for percent in levels:
		var names: PackedStringArray = names_at[percent]
		var odds_text := "sure" if percent >= 100 else ("%d%%" % maxi(percent, 1))
		parts.append("%s %s" % [", ".join(names), odds_text])
	return "  ·  ".join(parts) if parts.size() > 0 else "carried by nothing yet"


func _requirement_names(gift: SpiderTrait) -> String:
	var parts := PackedStringArray()
	for needed in gift.requires:
		var earlier := _traits.by_id(str(needed))
		parts.append(earlier.display_name if earlier != null else str(needed))
	return ", ".join(parts)
