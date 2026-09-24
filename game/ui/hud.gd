class_name SpiderHUD
extends CanvasLayer

## Everything the player needs to read at a glance: how much silk is left,
## how close the next size is, and what build mode is about to do.

const HOTBAR_SLOT := 54.0
const HOTBAR_GAP := 6.0

const HELP_TEXT := """[ Spoolunky ]
WASD / Space / Shift   move, jump, sprint
walk into a wall       climb it — walls and ceilings are floors to you
silk is sticky         stand on it and it holds you; jump to come off

Left Mouse             grapple there, trailing silk
Right Mouse            shoot a web — it sticks where it lands, and wraps
                       whatever it lands on
1-9 / wheel            pick a pocket
E                      the tree — spend what you have eaten
F                      wrap prey, then drain it
X                      pull down the web you're looking at

L  camera   T  free the mouse   H  hide this   Esc  quit"""

## Leave empty to find the spider by its group.
@export var spider_path: NodePath

var _spider: SpiderPlayer
var _toast_timer := 0.0
var _hotbar: HBoxContainer
var _pockets: Array[Panel] = []
var _tree: TraitTree

@onready var stage_label: Label = $Stats/StageLabel
@onready var state_label: Label = $Stats/StateLabel
@onready var silk_label: Label = $Stats/SilkLabel
@onready var silk_bar: ProgressBar = $Stats/SilkBar
@onready var biomass_label: Label = $Stats/BiomassLabel
@onready var biomass_bar: ProgressBar = $Stats/BiomassBar
@onready var pattern_label: Label = $Build/PatternLabel
@onready var hint_label: Label = $Build/HintLabel
@onready var problem_label: Label = $Build/ProblemLabel
@onready var dial_label: Label = $Build/DialLabel
@onready var toast_label: Label = $Toast
@onready var help_label: Label = $Help



func _ready() -> void:
	help_label.text = HELP_TEXT
	toast_label.modulate.a = 0.0
	_build_hotbar()
	_build_tree()
	problem_label.text = ""
	dial_label.text = ""
	_bind.call_deferred()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		toast_label.modulate.a = clampf(_toast_timer, 0.0, 1.0)
	if _spider == null:
		return
	_refresh_state()
	_refresh_hotbar()
	_refresh_build_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		help_label.visible = not help_label.visible
		get_viewport().set_input_as_handled()
	# Opening the tree frees the mouse, and a free mouse is exactly what stops
	# the spider reading its keys — so the way back out has to be handled here.
	elif _tree != null and _tree.open and event.is_action_pressed("skill_tree"):
		_tree.close()
		get_viewport().set_input_as_handled()


func show_message(text: String) -> void:
	toast_label.text = text
	_toast_timer = 3.2
	toast_label.modulate.a = 1.0


func _bind() -> void:
	_spider = get_node_or_null(spider_path) as SpiderPlayer
	if _spider == null:
		_spider = get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if _spider == null:
		push_warning("HUD could not find the spider")
		return

	_spider.notice.connect(show_message)
	_spider.skill_tree_toggled.connect(_on_tree_asked_for)
	if _spider.traits != null:
		_tree.setup(_spider.traits)
		_spider.traits.gained.connect(_on_trait_gained)
	_spider.silk.changed.connect(_on_silk_changed)
	_spider.growth.biomass_changed.connect(_on_biomass_changed)
	_spider.grew.connect(_on_grew)

	_on_silk_changed(_spider.silk.current, _spider.silk.maximum)
	_on_biomass_changed(_spider.growth.biomass, _spider.growth.progress())
	_on_grew(_spider.stage(), _spider.growth.stage_index)


func _on_silk_changed(current: float, maximum: float) -> void:
	silk_bar.max_value = maxf(maximum, 0.001)
	silk_bar.value = current
	if _spider != null and _spider.silk.unlimited:
		silk_label.text = "Silk   ∞   [J] to make it cost again"
	else:
		silk_label.text = "Silk   %d / %d" % [floori(current), roundi(maximum)]


func _on_biomass_changed(biomass: float, progress: float) -> void:
	biomass_bar.max_value = 1.0
	biomass_bar.value = progress
	if _spider == null:
		return
	var remaining := _spider.growth.biomass_to_next()
	if remaining <= 0.0:
		biomass_label.text = "Biomass   %d   (fully grown)" % roundi(biomass)
	else:
		biomass_label.text = "Biomass   %d   (%d to grow)" % [roundi(biomass), ceili(remaining)]


func _on_grew(stage: GrowthStage, index: int) -> void:
	stage_label.text = "Stage %d — %s" % [index + 1, stage.display_name]
	if _spider != null:
		_on_biomass_changed(_spider.growth.biomass, _spider.growth.progress())


# --- the tree -----------------------------------------------------------

func _build_tree() -> void:
	_tree = TraitTree.new()
	_tree.name = "TraitTree"
	add_child(_tree)


func _on_tree_asked_for() -> void:
	if _tree != null:
		_tree.toggle()


func _on_trait_gained(gift: SpiderTrait) -> void:
	show_message("%s — %s" % [gift.display_name, gift.effect_line()])


# --- the bar ------------------------------------------------------------

## Nine pockets along the bottom, and that is the whole inventory — what you
## are carrying is what is on screen, with no second screen behind it.
##
## Built in code rather than laid out in the scene because it is nine of the
## same thing: a row that is authored by hand is a row where slot 7 is two
## pixels out and nobody notices for a month.
func _build_hotbar() -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.add_theme_constant_override("separation", int(HOTBAR_GAP))
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.position = Vector2(0.0, -24.0)
	add_child(_hotbar)

	for i in SpiderInventory.SLOTS:
		var pocket := Panel.new()
		pocket.name = "Slot%d" % (i + 1)
		pocket.custom_minimum_size = Vector2(HOTBAR_SLOT, HOTBAR_SLOT)

		var number := Label.new()
		number.name = "Number"
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", 11)
		number.modulate = Color(1, 1, 1, 0.45)
		number.position = Vector2(4.0, 1.0)
		pocket.add_child(number)

		var count := Label.new()
		count.name = "Count"
		count.add_theme_font_size_override("font_size", 13)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		pocket.add_child(count)

		_hotbar.add_child(pocket)
		_pockets.append(pocket)


## What is in each pocket, and which one is in hand. Redrawn from the bag
## rather than kept in step with it, so there is nothing to fall out of sync.
func _refresh_hotbar() -> void:
	if _hotbar == null or _spider == null or _spider.bag == null:
		return
	var bag := _spider.bag
	var slots := bag.slots()
	for i in _pockets.size():
		var pocket: Panel = _pockets[i]
		var kind: DeviceKind = slots[i] if i < slots.size() else null
		var chosen := i == bag.selected

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.09, 0.72)
		style.border_color = Color(0.95, 0.96, 1.0, 0.85) if chosen else Color(1, 1, 1, 0.22)
		var edge := 3 if chosen else 1
		style.border_width_left = edge
		style.border_width_right = edge
		style.border_width_top = edge
		style.border_width_bottom = edge
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		pocket.add_theme_stylebox_override("panel", style)

		var count := pocket.get_node_or_null(NodePath("Count")) as Label
		if count == null:
			continue
		if kind == null:
			count.text = ""
			continue
		# No icons yet, so an initial and a number: enough to tell a spur from
		# a lure at a glance, which is all a bar has to do.
		count.text = "%s\n%d" % [kind.display_name.substr(0, 1), bag.count(kind)]
		count.modulate = kind.colour


## One line saying what the spider is standing on, or hanging from.
func _refresh_state() -> void:
	var climb := _spider.climb
	if climb == null:
		return
	if climb.is_riding():
		var along := climb.ride_velocity()
		if absf(along) < 0.4:
			state_label.text = "Riding a line — W/S along it   [F] or [Space] let go"
		else:
			state_label.text = "Riding — %.1f m/s   [F] or [Space] let go" % along
	elif climb.is_hanging():
		state_label.text = "On a line — %.1fm   [Ctrl] down  [Space] up  [RMB] let go" % climb.line_length
	elif not climb.is_attached():
		state_label.text = "Falling"
	elif climb.on_silk:
		state_label.text = "On silk — it holds you   [Space] off   [F] ride it"
	elif climb.surface_normal.dot(Vector3.UP) < -0.5:
		state_label.text = "On the ceiling   [Ctrl] drop on a line"
	elif climb.on_steep_surface():
		state_label.text = "Climbing   [Ctrl] drop on a line"
	else:
		state_label.text = "On the ground"
	_note_tether()


## What is on the end of your line, in front of wherever you are standing. Easy
## to forget you are towing something until you wonder why you are so slow.
func _note_tether() -> void:
	var tether := _spider.tether
	if tether == null or not tether.is_towing():
		return
	var pull := "trailing" if tether.slack() > 0.05 else "pulling"
	state_label.text = "Towing a %s (%s)   [Y] drop it      %s" % [
		tether.cargo_name(), pull, state_label.text]


func _refresh_build_panel() -> void:
	var builder := _spider.web_builder
	if builder == null:
		return

	dial_label.text = ""
	if builder.placing:
		var spinning := builder.current_pattern()
		# Area, not diameter: once the rim has fitted itself to the room the
		# web is rarely a circle, and "how much does it cover" is the thing
		# actually being decided.
		pattern_label.text = "%s     %.2f m²     ~%d silk" % [
			spinning.display_name if spinning != null else "—",
			builder.place_area, ceili(builder.estimated_cost)]
		# A throw has not found its room yet, so area and corners are not things
		# to report — the size being wound up is the only thing being decided.
		if builder.throwing:
			pattern_label.text = "%s     %.1f m across     thrown" % [
				spinning.display_name if spinning != null else "—",
				builder.place_radius * 2.0]
			hint_label.text = "Let go to throw it — it opens out where it lands"
			if builder.place_target != null:
				problem_label.text = "Lined up on the %s — it has to still be there" % (
					builder.place_target.species
					if "species" in builder.place_target else "target")
			else:
				problem_label.text = "Lead anything moving — the silk takes a moment"
			return
		hint_label.text = "Let go to spin it — keep holding to let it reach further"
		if builder.place_capped:
			hint_label.text = "Let go to spin it — that is as far as your silk reaches"
		if not builder.place_valid:
			problem_label.text = "Nothing to spin it against"
		elif builder.place_target != null:
			problem_label.text = "Over the %s — let go to throw it" % (
				builder.place_target.species
				if "species" in builder.place_target else "target")
		elif builder.place_anchored > 0:
			problem_label.text = "Fitting the gap — %d of %d corners have hold" % [
				builder.place_anchored, WebBuilder.PLACE_SIDES]
		else:
			problem_label.text = "Open air — nothing for the edges to catch on"
		return

	if _refresh_bag_panel():
		return

	if builder.placing_design:
		var design := builder.current_design()
		if design != null:
			pattern_label.text = "%s     ~%d silk" % [design.summary(), ceili(builder.estimated_cost)]
			hint_label.text = builder.hint_text()
			problem_label.text = builder.problem_text()
		return

	if builder.is_linking():
		pattern_label.text = "Wiring from the %s" % builder.link_source.label()
		hint_label.text = "[G] on what it should set off, or on nothing to cancel"
		var aimed := builder.aimed_node()
		problem_label.text = aimed.status_line() if aimed != null else ""
		return

	if not builder.building:
		# There is no build mode any more, so this is the only place the player
		# ever sees which web the wheel is on — and whether Q can spin it.
		var chosen := builder.current_pattern()
		if chosen == null:
			pattern_label.text = ""
			hint_label.text = ""
		elif chosen.shape == WebPattern.Shape.NET:
			pattern_label.text = "%s     [M] %s" % [chosen.display_name, builder.throw_name()]
			hint_label.text = "[Q] hold to spin one — the longer you hold, the bigger"
		else:
			pattern_label.text = chosen.display_name
			hint_label.text = "Left mouse drags this across a gap — [Q] needs a web pattern"
		var line := builder.aimed_line()
		if line != null:
			problem_label.text = "Line in reach — left mouse to get on it"
			return
		var web := builder.aimed_web()
		if web == null:
			problem_label.text = ""
		elif web.needs_rearm():
			problem_label.text = "%s     [E] re-arm   [X] pull down" % web.status_line()
		else:
			problem_label.text = "%s     [X] pull down" % web.status_line()
		return

	var pattern := builder.current_pattern()
	if pattern == null:
		return

	var dragged := builder.drag_pattern()
	var label := pattern.display_name
	if dragged != null and dragged != pattern:
		label += "  ·  dragging %s" % dragged.display_name
	if builder.estimated_cost > 0.0:
		label += "     next line ~%d silk" % ceili(builder.estimated_cost)
	pattern_label.text = label
	hint_label.text = builder.hint_text()
	problem_label.text = builder.problem_text()
	dial_label.text = "%s      %s" % [_dial_readout(builder), _weave_readout(builder)]


## Place mode takes the panel over while it is up, because the bag and the
## build wheel are two different things to be holding. True if it did.
func _refresh_bag_panel() -> bool:
	var placer := _spider.device_placer
	if placer == null or not placer.active:
		return false
	var kind := placer.current_kind()
	pattern_label.text = "%s     %s" % [kind.display_name if kind != null else "Bag empty",
		_spider.bag.summary(kind)]
	hint_label.text = placer.hint_text()
	var aimed := placer.aimed_device()
	problem_label.text = aimed.status_line() if aimed != null else placer.problem_text()
	dial_label.text = kind.description if kind != null else ""
	return true


## The three dials, with a marker on whichever one the keys are pointed at.
func _dial_readout(builder: WebBuilder) -> String:
	var tuning := builder.current_tuning()
	var parts := PackedStringArray()
	for dial in WebTuning.DIAL_NAMES.size():
		var text := tuning.bar(dial)
		parts.append("[%s]" % text if dial == builder.selected_dial else " %s " % text)
	return "   ".join(parts)


## Which way webs are being woven right now — a test switch, so it is always on
## screen while building rather than hidden in a menu.
func _weave_readout(builder: WebBuilder) -> String:
	if builder.weave == WebGeometry.Weave.INSCRIBED:
		return "[K] weave: inscribed — even spiral inside the frame"
	return "[K] weave: stretched — the web is the shape you drew"
