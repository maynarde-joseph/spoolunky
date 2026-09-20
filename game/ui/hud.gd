class_name SpiderHUD
extends CanvasLayer

## Everything the player needs to read at a glance: how much silk is left,
## how close the next size is, and what build mode is about to do.

const HELP_TEXT := """[ Spoolunky — sandbox ]
WASD / Space / Shift   move, jump, sprint
Q                      web build mode
Left Mouse             place anchor
Right Mouse            undo anchor / leave build mode
F                      spin the web
Wheel or Z / C         change web pattern
E                      wrap prey, then drain it (also re-arms a snare)
X                      pull down the web you're looking at
R                      free-fly (debug)   T  free the mouse   Esc  quit
H                      hide this"""

## Leave empty to find the spider by its group.
@export var spider_path: NodePath

@onready var stage_label: Label = $Stats/StageLabel
@onready var silk_label: Label = $Stats/SilkLabel
@onready var silk_bar: ProgressBar = $Stats/SilkBar
@onready var biomass_label: Label = $Stats/BiomassLabel
@onready var biomass_bar: ProgressBar = $Stats/BiomassBar
@onready var pattern_label: Label = $Build/PatternLabel
@onready var hint_label: Label = $Build/HintLabel
@onready var problem_label: Label = $Build/ProblemLabel
@onready var toast_label: Label = $Toast
@onready var help_label: Label = $Help

var _spider: SpiderPlayer
var _toast_timer := 0.0


func _ready() -> void:
	help_label.text = HELP_TEXT
	toast_label.modulate.a = 0.0
	problem_label.text = ""
	_bind.call_deferred()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		toast_label.modulate.a = clampf(_toast_timer, 0.0, 1.0)
	if _spider == null:
		return
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


func _refresh_build_panel() -> void:
	var builder := _spider.web_builder
	if builder == null:
		return

	if not builder.building:
		pattern_label.text = ""
		hint_label.text = ""
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

	pattern_label.text = "%s     ~%d silk     %d anchor%s" % [
		pattern.display_name,
		ceili(builder.estimated_cost),
		builder.anchors.size(),
		"" if builder.anchors.size() == 1 else "s"]
	hint_label.text = builder.hint_text()
	problem_label.text = builder.problem_text()
