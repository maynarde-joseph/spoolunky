class_name SpellTreeScreen
extends Control

## The spell tree, on [E]: the ranks down the page, each rank's row of skills across
## it, and the loadout along the foot.
##
## A card is a button. Press one that can be learned and it is learned; press a
## spell you know and it goes on the keys, or comes off them. A row the spider has
## not reached yet is still shown, dimmed, with the rank that opens it: what you are
## working toward is worth being able to see.
##
## Built in code, like the evolution screen it took the key from: the shape comes
## out of the resources — row, column and what each skill stands on — so adding a
## skill is dropping a .tres in a folder, and the page grows a card for it with
## nothing here to edit.

const CARD := Vector2(300.0, 132.0)
const CARD_GAP := 12.0
const ROW_GAP := 10.0
const ROW_HEADER := 230.0

## Learned, learnable now, and not yet.
const LEARNED := Color(0.62, 0.92, 0.66, 1.0)
const OPEN := Color(1.0, 0.98, 0.82, 1.0)
const SHUT := Color(0.52, 0.54, 0.60, 1.0)

var open := false

var _tree: SpellTree
var _spells: SpiderSpells
var _rank_line: Label
var _loadout_line: Label
var _message: Label
var _cards := {}
var _row_headers := {}
var _restore_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Anchors and offsets both, for the reason the evolution screen found out: by
	# the time this runs it is already in the tree, and anchors alone keep the rect
	# it had, which was none.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.04, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


## Binds to a spider's tree and builds a card per skill. Safe to call once.
## [param spells] is what names the keys on the loadout line.
func setup(tree: SpellTree, spells: SpiderSpells = null) -> void:
	if _tree != null or tree == null:
		return
	_tree = tree
	_spells = spells
	_tree.changed.connect(_refresh)
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
	_message.text = ""
	_refresh()
	# The cards are pressed with the mouse, so it is freed; the spider ignores its
	# keys while it is, which is what stops a click here spinning a web out there.
	_restore_mouse = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	Input.set_mouse_mode(_restore_mouse)


## What pressing the card for [param skill_id] does: learns it if it can be
## learned, and puts a spell you know on the keys or takes it off. Returns whether
## anything changed. What a click does, and what a check calls to click.
func press(skill_id: String) -> bool:
	var skill := _tree.by_id(skill_id) if _tree != null else null
	if skill == null:
		return false
	if not _tree.has(skill_id):
		if _tree.learn(skill):
			_say("Learned %s" % skill.display_name)
			return true
		_say("%s — %s" % [skill.display_name, _tree.why_not(skill)])
		return false
	if skill.kind != SpellSkill.Kind.SPELL:
		return false
	var spell := SpellLibrary.find(skill.spell)
	var spell_name := spell.display_name if spell != null else skill.display_name
	if _tree.open_all:
		_say("Every spell is in the loadout while everything is open")
		return false
	if _tree.is_slotted(skill.spell):
		_tree.unslot(skill.spell)
		_say("%s out of the loadout" % spell_name)
		return true
	if _tree.slot(skill.spell):
		_say("%s into the loadout" % spell_name)
		return true
	_say("The loadout is full — take a spell off it first")
	return false


## What the card for [param skill_id] says about where it stands.
func card_text(skill_id: String) -> String:
	var card := _cards.get(skill_id) as Control
	var state := card.get_node_or_null(NodePath("Margin/Lines/State")) as Label \
		if card != null else null
	return state.text if state != null else ""


## The rank line across the top.
func rank_text() -> String:
	return _rank_line.text if _rank_line != null else ""


## The loadout line along the foot.
func loadout_text() -> String:
	return _loadout_line.text if _loadout_line != null else ""


## What the last press said.
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

	page.add_child(_heading("Spell Tree", 40, Color(1, 1, 1, 1)))
	_rank_line = _heading("", 24, Color(1.0, 0.88, 0.7, 1.0))
	page.add_child(_rank_line)
	page.add_child(_heading(
		"catching and eating earn ranks · each rank opens its row and two points"
		+ " · click a skill to learn it · [E] back", 17, Color(0.72, 0.75, 0.82, 1.0)))

	for row in SpellTree.RANKS.size():
		page.add_child(_row(row))

	_loadout_line = _heading("", 22, Color(0.86, 0.9, 1.0, 1.0))
	page.add_child(_loadout_line)
	page.add_child(_heading("click a spell you know to put it in the loadout, or take it out",
		16, Color(0.72, 0.75, 0.82, 1.0)))
	_message = _heading("", 19, OPEN)
	page.add_child(_message)


func _row(which: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Row%d" % which
	line.add_theme_constant_override("separation", int(CARD_GAP))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := _heading(SpellTree.RANKS[which], 21, Color(0.86, 0.9, 1.0, 1.0))
	header.custom_minimum_size = Vector2(ROW_HEADER, CARD.y)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(header)
	_row_headers[which] = header

	for skill in _tree.row(which):
		line.add_child(_card(skill))
	return line


func _card(skill: SpellSkill) -> Button:
	var card := Button.new()
	card.name = skill.id
	card.custom_minimum_size = CARD
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = true
	card.pressed.connect(press.bind(skill.id))

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

	var title := _line("Name", skill.display_name, 19)
	lines.add_child(title)
	var kind := _line("Kind", "%s · %d point%s" % [skill.kind_name(), skill.cost,
		"" if skill.cost == 1 else "s"], 14)
	kind.modulate = Color(0.75, 0.78, 0.86, 1.0)
	lines.add_child(kind)
	# Where it stands before what it does: a long interaction runs off the foot of
	# the card, and the half that matters most is whether you can have it.
	lines.add_child(_line("State", "", 15))
	var what := _line("What", skill.description if skill.kind == SpellSkill.Kind.INTERACTION
		else skill.effect_line(), 14)
	what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	what.max_lines_visible = 3
	what.custom_minimum_size = Vector2(CARD.x - 20.0, 0.0)
	lines.add_child(what)

	_cards[skill.id] = card
	return card


func _line(line_name: String, text: String, size: int) -> Label:
	var label := Label.new()
	label.name = line_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	return label


func _heading(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.modulate = colour
	return label


# --- what it says now -----------------------------------------------------

func _refresh() -> void:
	if _tree == null or _rank_line == null:
		return
	var next := "" if _tree.is_top_rank() else "    ·    %d / %d to %s" % [
		roundi(_tree.xp), roundi(_tree.rank_xp[_tree.rank + 1]), _tree.rank_name(_tree.rank + 1)]
	_rank_line.text = "%s    ·    %d point%s to spend%s" % [_tree.rank_name(), _tree.points(),
		"" if _tree.points() == 1 else "s", next]

	for which in _row_headers:
		var header := _row_headers[which] as Label
		var reached: bool = _tree.row_open(which)
		header.text = SpellTree.RANKS[which] if reached \
			else "%s\n(not yet)" % SpellTree.RANKS[which]
		header.modulate = Color(0.86, 0.9, 1.0, 1.0) if reached else SHUT

	for skill_id in _cards:
		var skill := _tree.by_id(skill_id)
		var card := _cards[skill_id] as Button
		var state := card.get_node_or_null(NodePath("Margin/Lines/State")) as Label
		var text := ""
		var colour := SHUT
		if _tree.has(skill_id):
			colour = LEARNED
			text = "learned"
			if skill.kind == SpellSkill.Kind.SPELL:
				text = "learned · in the loadout" if _key_of(skill.spell) > 0 \
					else "learned · not in the loadout"
		elif _tree.can_learn(skill):
			colour = OPEN
			text = "learn it — %d point%s" % [skill.cost, "" if skill.cost == 1 else "s"]
		else:
			text = _tree.why_not(skill)
		if state != null:
			state.text = text
		card.modulate = colour

	var slots := PackedStringArray(["Grapple", "Silk"])
	if _spells != null:
		slots.clear()
		var innate := 0
		for spell in _spells.hand():
			slots.append(spell.display_name)
			innate += 1 if _spells.is_innate(spell) else 0
		if not _tree.open_all:
			for i in range(_spells.hand().size(), SpellTree.LOADOUT_SIZE + innate):
				slots.append("—")
	_loadout_line.text = "Loadout    " + "    ".join(slots)


## The key [param spell_id] is on, or 0.
func _key_of(spell_id: String) -> int:
	if _spells == null:
		return _tree.loadout.find(spell_id) + 2 if _tree.loadout.has(spell_id) else 0
	return _spells.key_for(_spells.by_id(spell_id))


func _say(text: String) -> void:
	if _message != null:
		_message.text = text
