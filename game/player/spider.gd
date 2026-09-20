class_name SpiderPlayer
extends Player

## The spider.
##
## Extends the character-controller template's player with the three things
## that make this game a spider game: a silk supply, a body that grows when it
## eats, and build mode.
##
## Growth is applied physically rather than as a stat line — the collider, the
## eye height, the stride and the camera's near plane all move with the size
## tier, so the room really does shrink around you.

## Something worth putting on screen happened.
signal notice(text: String)

## The spider changed size tier.
signal grew(stage: GrowthStage, index: int)

## Fell out of the world and got put back.
signal respawned()

@export var input_build_mode := "web_build_mode"
@export var input_place_anchor := "web_place"
@export var input_cancel_anchor := "web_cancel"
@export var input_finish_web := "web_finish"
@export var input_next_pattern := "web_next_pattern"
@export var input_prev_pattern := "web_prev_pattern"
@export var input_remove_web := "web_remove"
@export var input_interact := "interact"

## Falling below this puts the spider back where it started.
@export var kill_plane := -60.0

## Ignore build and feeding input while the mouse is free, so clicking around a
## menu doesn't spend silk. Turn off for automated tests and headless runs,
## where the display server cannot capture the mouse at all.
@export var require_captured_mouse := true

@onready var silk: SilkPool = $Silk
@onready var growth: SpiderGrowth = $Growth
@onready var web_builder: WebBuilder = $WebBuilder

var _spawn_transform: Transform3D
var _stage: GrowthStage


func _ready() -> void:
	super()
	add_to_group("spider")
	_spawn_transform = global_transform

	# The template shares these shapes between every instance of the scene,
	# and growing edits them in place — so take our own copies first.
	collision.shape = collision.shape.duplicate()
	head_check.shape = head_check.shape.duplicate()

	collision_layer = GameLayers.PLAYER
	collision_mask = GameLayers.WORLD

	web_builder.setup(self, silk, growth)
	web_builder.notice.connect(_on_notice)
	growth.stage_changed.connect(_on_stage_changed)
	growth.apply_initial()


func _physics_process(delta: float) -> void:
	super(delta)
	if global_position.y < kill_plane:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO
		respawned.emit()
		notice.emit("Fell out of the world — put you back")


func _unhandled_input(event: InputEvent) -> void:
	if require_captured_mouse and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed(input_build_mode):
		web_builder.toggle()
	elif event.is_action_pressed(input_next_pattern):
		web_builder.cycle(1)
	elif event.is_action_pressed(input_prev_pattern):
		web_builder.cycle(-1)
	elif event.is_action_pressed(input_interact):
		_interact()
	elif event.is_action_pressed(input_remove_web):
		web_builder.demolish_aimed()
	elif web_builder.building and event.is_action_pressed(input_place_anchor):
		web_builder.place()
	elif web_builder.building and event.is_action_pressed(input_cancel_anchor):
		web_builder.undo()
	elif web_builder.building and event.is_action_pressed(input_finish_web):
		web_builder.finish()
	else:
		return
	get_viewport().set_input_as_handled()


## Current size tier.
func stage() -> GrowthStage:
	return growth.current_stage()


# --- feeding ------------------------------------------------------------

func _interact() -> void:
	var prey := _aimed_prey()
	if prey != null:
		_handle_prey(prey)
		return

	var web := web_builder.aimed_web()
	if web != null and web.needs_rearm():
		if silk.spend(web.pattern.rearm_cost):
			web.rearm()
			notice.emit("Snare re-armed (%d silk)" % roundi(web.pattern.rearm_cost))
		else:
			notice.emit("Not enough silk to re-arm")
		return

	notice.emit("Nothing in reach")


func _handle_prey(prey: Prey) -> void:
	var current := stage()
	if prey.size_class > current.bite_power:
		notice.emit("The %s is too big for you — grow first" % prey.species)
		return

	if prey.wrapped:
		_drain(prey)
		return

	if prey.is_stuck():
		var cost := prey.wrap_cost()
		if silk.spend(cost):
			prey.wrap()
			notice.emit("Wrapped the %s (%d silk)" % [prey.species, roundi(cost)])
		else:
			notice.emit("Not enough silk to wrap — %d needed" % ceili(cost))
		return

	# Much bigger than it? Then you can simply take it.
	if current.bite_power >= prey.size_class * 2:
		_drain(prey)
		return

	notice.emit("The %s isn't caught — get it into a web" % prey.species)


func _drain(prey: Prey) -> void:
	var species := prey.species
	var food := prey.biomass
	var silk_back := prey.silk_value()
	prey.consume()
	silk.refill(silk_back)
	var tiers := growth.feed(food, species)
	if tiers <= 0:
		notice.emit("Drained the %s  +%d biomass  +%d silk" % [species, roundi(food), roundi(silk_back)])


# --- growth -------------------------------------------------------------

func _on_stage_changed(new_stage: GrowthStage, index: int) -> void:
	var previous_height := _stage.body_height if _stage != null else new_stage.body_height
	_stage = new_stage
	_apply_stage(new_stage, previous_height)
	grew.emit(new_stage, index)
	if index > 0:
		notice.emit("You are a %s now" % new_stage.display_name)


## Resizes the body to match a size tier.
func _apply_stage(new_stage: GrowthStage, previous_height: float) -> void:
	var height := new_stage.body_height

	var capsule := collision.shape as CapsuleShape3D
	if capsule != null:
		capsule.radius = height * 0.2
		capsule.height = height

	var head_sphere := head_check.shape as SphereShape3D
	if head_sphere != null:
		head_sphere.radius = height * 0.2
	head_check.target_position = Vector3(0, height * 0.25, 0)

	# Eye height keeps the template's proportions (0.64 on a 2m capsule).
	head.position.y = height * 0.32
	head_bob.bob_range = Vector2(0.07, 0.07) * (height / 2.0)

	_default_height = height
	height_in_crouch = height * 0.5
	crouch_ability.default_height = height
	crouch_ability.height_in_crouch = height_in_crouch

	speed = new_stage.move_speed
	_normal_speed = new_stage.move_speed
	jump_height = new_stage.jump_velocity
	jump_ability.height = new_stage.jump_velocity
	floor_snap_length = height * 0.25
	step_interval = maxf(height * 3.0, 1.0)

	silk.set_capacity(new_stage.silk_capacity)
	silk.regen_per_second = new_stage.silk_regen

	# Growing from the middle of the capsule would bury the feet in the floor.
	if previous_height < height:
		global_position.y += (height - previous_height) * 0.5

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		camera.near = clampf(height * 0.02, 0.005, 0.05)


# --- helpers ------------------------------------------------------------

## The prey nearest the middle of the screen, within reach.
func _aimed_prey() -> Prey:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var current := stage()
	var range_limit: float = maxf(current.reach * 2.5, current.body_height * 4.0)

	var best: Prey = null
	var best_dot := 0.82
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		var offset := prey.global_position - origin
		var distance := offset.length()
		if distance > range_limit or distance < 0.0001:
			continue
		var alignment := offset.normalized().dot(forward)
		if alignment > best_dot:
			best_dot = alignment
			best = prey
	return best


func _on_notice(text: String) -> void:
	notice.emit(text)
