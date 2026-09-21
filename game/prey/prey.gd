class_name Prey
extends CharacterBody3D

## Something worth eating.
##
## Prey wanders a patch of the world, gets stuck in webs, struggles hard enough
## to tear them, and can be wrapped and drained by the spider. Everything about
## a species is exported, so a rat is this script with bigger numbers.

signal snared(prey: Prey)
signal broke_free(prey: Prey)
signal eaten_by_spider(prey: Prey)

enum State {
	WANDER,    ## going about its business
	STUCK,     ## caught in silk, fighting it
	WRAPPED,   ## bundled up, going nowhere
	FLEEING,   ## just tore loose, getting out
}


@export_group("Species")

## Shown in HUD messages.
@export var species := "Fly"

## Biomass gained by draining it.
@export var biomass := 8.0

## Silk recovered by draining it.
@export var silk_return := 7.0

## How big it is, against the spider's bite power. 1 is fly-sized.
@export var size_class := 1

## How hard it fights a web. Tears silk and eventually pulls free.
@export var struggle_power := 1.0


@export_group("Movement")

@export var move_speed := 1.6

## Flying prey ignores gravity and drifts; walking prey falls.
@export var flying := true

## How far from its spawn point it will wander.
@export var wander_radius := 6.0

## Low and high limits above the spawn point, for fliers.
@export var wander_height := Vector2(0.3, 2.6)

## Seconds before it picks somewhere new to be, even if it hasn't arrived.
@export var wander_interval := 3.0

## How strongly it drifts toward a funnel lure it can smell.
@export_range(0.0, 1.0, 0.05) var lure_susceptibility := 0.8


var wrapped := false
var eaten := false

## Killed by venom: drainable no matter how big it is.
var subdued := false

var _state: State = State.WANDER
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wander_timer := 0.0
var _web: WebStructure = null
var _stuck_point := Vector3.ZERO
var _struggle := 0.0
var _snap_timer := 0.0
var _flee_timer := 0.0
var _recatch_cooldown := 0.0
var _marked_timer := 0.0
var _lure_timer := 0.0
var _life := 0.0
var _marker: MeshInstance3D
var _cocoon: MeshInstance3D
var _wings: Array[Node3D] = []

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("prey")
	collision_layer = GameLayers.PREY
	collision_mask = GameLayers.WORLD
	_home = global_position
	_pick_target()
	for child in get_children():
		if child.name.begins_with("Wing"):
			_wings.append(child)


func _physics_process(delta: float) -> void:
	_life += delta
	if _recatch_cooldown > 0.0:
		_recatch_cooldown -= delta
	if _marked_timer > 0.0:
		_marked_timer -= delta
		if _marked_timer <= 0.0:
			_set_marked(false)
	_flap()

	match _state:
		State.STUCK, State.WRAPPED:
			_process_stuck(delta)
		State.FLEEING:
			_flee_timer -= delta
			if _flee_timer <= 0.0:
				_state = State.WANDER
				_pick_target()
			_steer(delta, move_speed * 1.8)
		_:
			_process_wander(delta)


# --- being prey ---------------------------------------------------------

## Webs ask before catching, so prey that just tore loose gets a moment.
func can_be_snared() -> bool:
	return not eaten and _recatch_cooldown <= 0.0 and _state != State.STUCK and _state != State.WRAPPED


## Called by a web that has caught this. [param snap_time] is the rigid hold
## from a sprung pressure snare.
func on_snared(web: WebStructure, point: Vector3, snap_time: float) -> void:
	_web = web
	_stuck_point = point
	_snap_timer = snap_time
	_struggle = 0.0
	_state = State.STUCK
	velocity = Vector3.ZERO
	_set_marked(false)
	snared.emit(self)


## Called when the web holding this is destroyed.
func on_freed(_web_that_tore: WebStructure) -> void:
	if _state != State.STUCK:
		return
	_release_into_flight()


## Called by an alert web (tripline) that this walked through.
func on_tripped(_web: WebStructure, mark_time: float) -> void:
	_marked_timer = maxf(_marked_timer, mark_time)
	_set_marked(true)


func is_stuck() -> bool:
	return _state == State.STUCK or _state == State.WRAPPED


## Silk needed to bundle this up so it stops wrecking the web.
func wrap_cost() -> float:
	return 1.0 + biomass * 0.25


## Killed outright by venom: it stops fighting, and it can be drained whatever
## size it is, which is what makes a venom spur worth carrying.
func envenom() -> bool:
	if eaten or subdued:
		return false
	subdued = true
	wrapped = true
	_state = State.WRAPPED
	_struggle = 0.0
	_set_marked(false)
	_set_cocoon(true)
	return true


## Bundles it: no more struggling, no more damage to the web.
func wrap() -> void:
	if not is_stuck():
		return
	wrapped = true
	_state = State.WRAPPED
	_struggle = 0.0
	_set_marked(false)
	_set_cocoon(true)


func silk_value() -> float:
	return silk_return * (1.5 if wrapped else 1.0)


## Drained by the spider.
func consume() -> void:
	if eaten:
		return
	eaten = true
	if is_instance_valid(_web):
		_web.on_prey_escaped(self)
	eaten_by_spider.emit(self)
	queue_free()


# --- behaviour ----------------------------------------------------------

func _process_stuck(delta: float) -> void:
	var pull: float = 12.0 if _snap_timer > 0.0 else 5.0
	var jitter := Vector3.ZERO
	if _state == State.STUCK and _snap_timer <= 0.0:
		var wobble: float = _stuck_wobble()
		jitter = Vector3(sin(_life * 23.0), sin(_life * 17.0 + 1.3), cos(_life * 19.0)) * wobble
	global_position = global_position.lerp(_stuck_point + jitter, clampf(pull * delta, 0.0, 1.0))
	velocity = Vector3.ZERO

	if _snap_timer > 0.0:
		_snap_timer -= delta
		return
	if _state == State.WRAPPED:
		return
	if not is_instance_valid(_web):
		_release_into_flight()
		return

	_struggle += struggle_power * delta
	_web.take_damage(struggle_power * delta * 0.6)
	if _struggle >= _web.hold_strength() * 2.5:
		var torn_from := _web
		torn_from.on_prey_escaped(self)
		_release_into_flight()
		broke_free.emit(self)


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	_lure_timer -= delta
	if _lure_timer <= 0.0:
		_lure_timer = 0.75
		_sniff_for_lures()
	if _wander_timer <= 0.0 or global_position.distance_to(_target) < _arrival_distance():
		_pick_target()
	_steer(delta, move_speed)


func _steer(delta: float, speed: float) -> void:
	var to_target := _target - global_position
	if to_target.length() < 0.001:
		return
	var desired := to_target.normalized() * speed
	if not flying:
		desired.y = velocity.y - _gravity * delta
	velocity = velocity.lerp(desired, clampf(3.0 * delta, 0.0, 1.0))
	move_and_slide()
	if is_on_wall():
		_pick_target()


func _pick_target() -> void:
	_wander_timer = wander_interval * randf_range(0.6, 1.4)
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	offset *= wander_radius * randf_range(0.2, 1.0)
	_target = _home + offset
	if flying:
		_target.y = _home.y + randf_range(wander_height.x, wander_height.y)


## Funnel lures bend a wanderer's path toward them — that's the whole point.
func _sniff_for_lures() -> void:
	if lure_susceptibility <= 0.0:
		return
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("silk_lures"):
		var lure := node as SilkNode
		if lure == null:
			continue
		var distance := global_position.distance_to(lure.global_position)
		if distance > lure.lure_radius() or distance >= best_distance:
			continue
		best_distance = distance
		best = lure
	if best == null:
		return
	if randf() > lure_susceptibility:
		return
	_target = best.global_position + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
	_wander_timer = wander_interval


func _release_into_flight() -> void:
	var escape_from := _stuck_point
	_web = null
	_struggle = 0.0
	_snap_timer = 0.0
	wrapped = false
	_set_cocoon(false)
	_state = State.FLEEING
	_flee_timer = 2.0
	_recatch_cooldown = 2.5
	var away := (global_position - escape_from)
	if away.length() < 0.01:
		away = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))
	_target = global_position + away.normalized() * wander_radius * 0.5 + Vector3.UP * 0.4


func _arrival_distance() -> float:
	return maxf(0.25, wander_radius * 0.05)


func _stuck_wobble() -> float:
	return clampf(struggle_power * 0.01, 0.002, 0.05)


func _flap() -> void:
	if _wings.is_empty():
		return
	var angle := 0.0
	if _state != State.WRAPPED:
		angle = sin(_life * 70.0) * 0.9
	for i in _wings.size():
		var wing := _wings[i]
		var sign_value: float = 1.0 if i % 2 == 0 else -1.0
		wing.rotation.z = angle * sign_value


## Silk bundle drawn around wrapped prey.
func _set_cocoon(active: bool) -> void:
	if active and _cocoon == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.26
		mesh.radial_segments = 10
		mesh.rings = 5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.93, 0.93, 0.9, 0.9)
		material.roughness = 0.9
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cocoon = MeshInstance3D.new()
		_cocoon.name = "Cocoon"
		_cocoon.mesh = mesh
		_cocoon.material_override = material
		_cocoon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cocoon)
	if _cocoon != null:
		_cocoon.visible = active


## Highlight for prey that has tripped an alert web.
func _set_marked(active: bool) -> void:
	if active and _marker == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		mesh.radial_segments = 8
		mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.45, 0.3, 0.28)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_marker = MeshInstance3D.new()
		_marker.name = "TripMarker"
		_marker.mesh = mesh
		_marker.material_override = material
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
	if _marker != null:
		_marker.visible = active
