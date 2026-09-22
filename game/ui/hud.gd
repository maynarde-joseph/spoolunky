class_name SpiderHUD
extends CanvasLayer

## Everything the player needs to read at a glance: how much silk is left,
## how close the next size is, and what build mode is about to do.

const HELP_TEXT := """[ Spoolunky — sandbox ]
WASD / Space / Shift   move, jump, sprint
walk into a wall       climb it — walls and ceilings are floors to you
F or middle mouse      clip onto a silk line and ride it (again to let go)
Ctrl                   drop onto a dragline (from a wall or ceiling)
  Ctrl / Space           lower / raise yourself on the line
  Right Mouse            let go
Left Mouse             go there, trailing silk — every line is a zipline
Q (hold)               spin a web where you are aiming; hold longer for bigger
M                      webs: placed where you point / thrown as a bolt
Wheel or Z / C         change which web you spin
E                      wrap prey, then drain it (also re-arms a snare)
X                      pull down the web you're looking at
G                      wire two things together — press on each end
N                      bag: place a device (wheel to pick, LMB down, X back up)
B                      keep the rig you're looking at as a design
V                      place a saved design (wheel to pick, LMB to spin)
; and [ ]              pick a tuning dial, then turn it   ('  resets)
K                      switch weave: stretched / inscribed
L                      camera: third person / first person
R                      free-fly (debug)   T  free the mouse   Esc  quit
J                      silk: unlimited / costs again (sandbox)
H                      hide this"""

## Leave empty to find the spider by its group.
@export var spider_path: NodePath

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

var _spider: SpiderPlayer
var _toast_timer := 0.0


func _ready() -> void:
	help_label.text = HELP_TEXT
	toast_label.modulate.a = 0.0
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
	_refresh_build_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		help_label.visible = not help_label.visible
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


## One line saying what the spider is standing on, or hanging from.
func _refresh_state() -> void:
	var climb := _spider.climb
	if climb == null:
		return
	if climb.is_riding():
		var along := climb.ride_velocity()
		if absf(along) < 0.4:
			state_label.text = "On a line — W/S to move along it   [F] or [Space] let go"
		else:
			state_label.text = "On a line — %.1f m/s   [F] or [Space] let go" % along
	elif climb.is_hanging():
		state_label.text = "On a line — %.1fm   [Ctrl] down  [Space] up  [RMB] let go" % climb.line_length
	elif not climb.is_attached():
		state_label.text = "Falling"
	elif climb.surface_normal.dot(Vector3.UP) < -0.5:
		state_label.text = "On the ceiling   [Ctrl] drop on a line"
	elif climb.on_steep_surface():
		state_label.text = "Climbing   [Ctrl] drop on a line"
	else:
		state_label.text = "On the ground"


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
		hint_label.text = "Let go to spin it — keep holding to let it reach further"
		if builder.throwing:
			hint_label.text = "Let go to throw it — it opens out where it lands"
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
