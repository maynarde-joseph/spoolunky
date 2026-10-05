class_name ShopScreen
extends Control

## The shop, on [E]: everything the farm can build, row by row — pens, care,
## crops, the kitchen — with what each costs.
##
## A card is a button. Press one and the screen goes and the spider has it in hand,
## to put down on the farm (see [FarmBuilder]). Something the farm cannot afford yet
## is still shown, dimmed, with its price: what you are saving for is worth being
## able to see.
##
## Built in code from the resources, like the spell tree it grew out of: a new
## .tres in the structures folder is a new card, with nothing here to edit.

## Something was picked: a [StructureKind].
signal chosen(what: Resource)

const CARD := Vector2(300.0, 150.0)
const CARD_GAP := 12.0
const ROW_GAP := 12.0
const ROW_HEADER := 170.0

## The rows, in order: the structures' own categories.
const ROWS := ["Pens", "Care", "Crops", "Kitchen"]

const AFFORD := Color(1.0, 0.98, 0.82, 1.0)
const SHORT := Color(0.52, 0.54, 0.60, 1.0)

var open := false

var _farm: Farm
var _coins_line: Label
var _message: Label
var _cards := {}
var _restore_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Anchors and offsets both: by the time this runs it is already in the tree, and
	# anchors alone keep the rect it had, which was none.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.02, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## Binds to [param farm] and builds a card for everything in the catalogue. Safe
## to call once.
func setup(farm: Farm) -> void:
	if _farm != null or farm == null:
		return
	_farm = farm
	_farm.coins_changed.connect(func(_coins: int) -> void: _refresh())
	_build()
	_refresh()


func toggle() -> void:
	if open:
		close()
	else:
		show_shop()


func show_shop() -> void:
	if open:
		return
	open = true
	visible = true
	_message.text = ""
	_refresh()
	# The cards are pressed with the mouse, so it is freed; the spider ignores its
	# keys while it is, which is what stops a click here throwing silk out there.
	_restore_mouse = Input.get_mouse_mode()
	if _restore_mouse == Input.MOUSE_MODE_VISIBLE:
		_restore_mouse = Input.MOUSE_MODE_CAPTURED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	Input.set_mouse_mode(_restore_mouse)


## What pressing the card for [param id] does: picks it, if the farm can afford it.
## Returns whether it was picked. What a click does, and what a check calls to
## click.
func press(id: String) -> bool:
	var what := _what(id)
	if what == null or _farm == null:
		return false
	var cost := _cost(what)
	if not _farm.can_afford(cost):
		_message.text = "%s — %d coins, and the farm has %d" % [_name(what), cost, _farm.coins]
		return false
	close()
	chosen.emit(what)
	return true


## What the card for [param id] says about where it stands.
func card_text(id: String) -> String:
	var card := _cards.get(id) as Control
	var state := card.get_node_or_null(NodePath("Margin/Lines/State")) as Label if card != null else null
	return state.text if state != null else ""


func card_ids() -> Array:
	return _cards.keys()


func message_text() -> String:
	return _message.text if _message != null else ""


# --- building -----------------------------------------------------------

func _build() -> void:
	var middle := CenterContainer.new()
	middle.name = "Middle"
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	var page := VBoxContainer.new()
	page.name = "Page"
	page.add_theme_constant_override("separation", int(ROW_GAP))
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(page)
	page.add_child(_heading("Farm Shop", 40, Color(1, 1, 1, 1)))
	_coins_line = _heading("", 24, Color(1.0, 0.86, 0.45, 1.0))
	page.add_child(_coins_line)
	page.add_child(_heading("click something to build it · left click puts it down, R turns it,"
		+ " right click puts it away · [E] back", 17, Color(0.72, 0.78, 0.72, 1.0)))
	for row in ROWS:
		var line := _row(row)
		if line != null:
			page.add_child(line)
	_message = _heading("", 19, AFFORD)
	page.add_child(_message)


func _row(category: String) -> HBoxContainer:
	var entries: Array[Resource] = []
	for kind in Catalogue.structures():
		if kind.category == category:
			entries.append(kind)
	if entries.is_empty():
		return null
	var line := HBoxContainer.new()
	line.name = "Row" + category
	line.add_theme_constant_override("separation", int(CARD_GAP))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := _heading(category, 22, Color(0.86, 0.94, 0.82, 1.0))
	header.custom_minimum_size = Vector2(ROW_HEADER, CARD.y)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(header)
	for what in entries:
		line.add_child(_card(what))
	return line


func _card(what: Resource) -> Button:
	var id := _id(what)
	var card := Button.new()
	card.name = id
	card.custom_minimum_size = CARD
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = true
	card.pressed.connect(press.bind(id))
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	card.add_child(margin)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.add_theme_constant_override("separation", 1)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(lines)
	lines.add_child(_line("Name", _name(what), 19))
	lines.add_child(_line("State", "", 15))
	var about := _line("What", _about(what), 14)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.max_lines_visible = 4
	about.custom_minimum_size = Vector2(CARD.x - 20.0, 0.0)
	about.modulate = Color(0.82, 0.85, 0.8, 1.0)
	lines.add_child(about)
	_cards[id] = card
	return card


func _line(line_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = line_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _heading(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = colour
	return label


# --- what it says now -----------------------------------------------------

func _refresh() -> void:
	if _farm == null or _coins_line == null:
		return
	_coins_line.text = "%d coins" % _farm.coins
	for id in _cards:
		var what := _what(id)
		var card := _cards[id] as Button
		var state := card.get_node_or_null(NodePath("Margin/Lines/State")) as Label
		var cost := _cost(what)
		var can := _farm.can_afford(cost)
		if state != null:
			state.text = _price(what) + ("" if can else "  ·  short %d" % (cost - _farm.coins))
		card.modulate = AFFORD if can else SHORT


## What the card for [param id] is for.
func _what(id: String) -> Resource:
	return Catalogue.structure(id)


static func _id(what: Resource) -> String:
	return (what as StructureKind).id


static func _name(what: Resource) -> String:
	return (what as StructureKind).display_name


static func _about(what: Resource) -> String:
	return (what as StructureKind).description


static func _cost(what: Resource) -> int:
	return (what as StructureKind).cost if what != null else 0


static func _price(what: Resource) -> String:
	if what is StructureKind and (what as StructureKind).placement == StructureKind.Placement.RUN:
		return "%d coins a length" % _cost(what)
	return "%d coins" % _cost(what)
