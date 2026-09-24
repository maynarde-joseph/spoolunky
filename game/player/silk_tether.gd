class_name SilkTether
extends Node3D

## A line from the spider to something it is dragging along.
##
## Catching things and moving things were separate problems until this: a
## bundle used to be a thing you walked back to, which meant the larder had to
## come to you or you had to eat where you stood. A tether makes a catch into
## cargo. Hook it, and it comes with you — over walls, along silk, off the end
## of a zipline.
##
## It is a rope, not a rod. Slack does nothing at all: walk towards the thing
## you are towing and the line sags and drags on the floor. Only past its
## length does it pull, and then it pulls rather than snaps the cargo to a
## fixed distance, so the weight swings behind you and keeps swinging when you
## stop. That is the whole feel of the thing, and it is why the rope is
## simulated rather than drawn as a straight line between two points.

signal hooked(cargo: Node3D)
signal released(cargo: Node3D)
signal notice(text: String)

## As far as the crosshair is ever asked to look for a wall.
const WALL_REACH := 4096.0

## How far away something can be hooked. Zero is as far as you can see, which
## is what grappling already is: aiming at a thing you have caught and firing
## silk at it should not stop working because it is across the room.
@export var reach := 0.0

## How much line is left paid out once it is reeled in, in body heights. Past
## this the cargo is hauled along.
@export var rope_bodies := 6.0

## How fast a long shot is wound back in, in metres per second. Hooking
## something across the room does not snap it to your feet; it comes in.
@export var reel_speed := 7.0

## Overstretch this many times the rope's length and the silk gives way. High
## on purpose: the line is meant to drag things through corners, not to be a
## tripwire that punishes a long grapple.
@export var snap_strain := 3.5

## How hard the cargo is pulled back to the end of its line, per second.
@export var haul_force := 9.0

## How much the cargo slows you down, per size class over the first. Towing a
## wasp home should be a decision, not a free ride.
@export_range(0.0, 0.5, 0.01) var haul_drag := 0.13

@export var rope_segments := 12
@export var rope_iterations := 6
@export var rope_gravity := 7.0
@export_range(0.5, 1.0, 0.01) var rope_damping := 0.96
@export var rope_color := Color(0.92, 0.94, 1.0, 0.85)

var cargo: Node3D = null

var _spider: SpiderPlayer
var _growth: SpiderGrowth
var _view: SpiderCamera
var _climb: SpiderClimb
var _rope := PackedVector3Array()
var _previous := PackedVector3Array()
var _rope_length := 0.0
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _view_node: MeshInstance3D


## Handed its parts by the spider. Not read off the parent in _ready(), because
## a child is ready before its parent is and the spider's own pieces are not
## assigned yet at that point — which reads as a null silk pool the first time
## anything asks the line to cost something.
func setup(spider: SpiderPlayer, growth: SpiderGrowth,
		view: SpiderCamera, climb: SpiderClimb) -> void:
	_spider = spider
	_growth = growth
	_view = view
	_climb = climb


func _ready() -> void:
	_build_view()


func _physics_process(delta: float) -> void:
	if cargo == null:
		return
	if not _still_there():
		_let_go("The line came back empty")
		return

	var hand := _hand()
	var tail := cargo.global_position
	var span := hand.distance_to(tail)
	if span > _rope_length * snap_strain:
		_let_go("The line snapped")
		return
	# A shot fired across the room pays out the whole distance, then winds
	# back to a length you can walk with. That is what makes hooking something
	# at range a harpoon rather than a yank.
	_rope_length = move_toward(_rope_length, _resting_length(), reel_speed * delta)

	_haul(delta, hand, tail)
	_simulate_rope(delta, hand, cargo.global_position)
	_draw()


# --- hooking ------------------------------------------------------------

## Hooks whatever is under the crosshair, or cuts the line if already towing.
func toggle() -> bool:
	if cargo != null:
		var was := cargo
		_let_go("Let the %s go" % _label(was))
		return true
	var target := aimed_cargo()
	if target == null:
		notice.emit("Nothing to put a line on — wrap it first")
		return false
	return hook(target)


## Puts a line on something.
func hook(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or cargo != null:
		return false
	if _spider == null:
		return false
	if not can_carry(target):
		notice.emit("Not something you can drag along")
		return false
	# Paid out to wherever it is. A long shot is a long line, and then it reels.
	_rope_length = maxf(_resting_length(), _hand().distance_to(target.global_position))
	cargo = target
	_reset_rope(_hand(), target.global_position)
	notice.emit("Hooked the %s" % _label(target))
	hooked.emit(target)
	return true


## Cuts the line, leaving the cargo where it is.
func cut() -> void:
	if cargo == null:
		return
	_let_go("Let the %s go" % _label(cargo))


func is_towing() -> bool:
	return cargo != null and is_instance_valid(cargo)


func cargo_name() -> String:
	return _label(cargo) if is_towing() else ""


## How slack the line is right now, as a fraction of its length. One is dead
## slack, zero is drawn tight. The HUD reads it so you can feel the pull.
func slack() -> float:
	if not is_towing() or _rope_length <= 0.0:
		return 0.0
	var span := _hand().distance_to(cargo.global_position)
	return clampf(1.0 - span / _rope_length, 0.0, 1.0)


## What the spider's speed is multiplied by while hauling. Nothing towed is
## free of it, and something three sizes up is a genuine haul.
func drag_factor() -> float:
	if not is_towing():
		return 1.0
	return 1.0 / (1.0 + maxf(_weight_of(cargo) - 1.0, 0.0) * haul_drag)


## Anything already dealt with — a bundle, a wrapped catch, a catch that has
## worn itself out — and anything you put down yourself. A thing still fighting
## is not cargo: wrap it first, which is what the wrapping is for.
func can_carry(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var prey := target as Prey
	if prey != null:
		return not prey.eaten and (prey.wrapped or prey.is_secured())
	return target is SilkDevice


## The thing worth hooking along the line of sight, near or far.
##
## Picked by how close it sits to the line rather than by a cone, and the
## tolerance is a slice of the screen with a ceiling on it — the same shape as
## the line pick, and for the same reason. A bundle is a small deliberate
## target, so a click that merely passed one on its way to a wall is a grapple
## and must stay one.
func aimed_cargo() -> Node3D:
	if _view == null or _spider == null:
		return null
	var origin := _view.aim_origin()
	var forward := _view.aim_forward()
	var wall := _wall_distance(origin, forward)
	var height := _height()

	var best: Node3D = null
	var best_gap := INF
	for group in ["prey", "silk_devices"]:
		for node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if target == null or not can_carry(target):
				continue
			var offset := target.global_position - origin
			var along := offset.dot(forward)
			if along <= 0.0 or along > wall:
				continue
			if reach > 0.0 and along > reach:
				continue
			var gap := (offset - forward * along).length()
			var tolerance: float = clampf(along * 0.05, height * 0.5, height * 2.0)
			if gap > tolerance or gap >= best_gap:
				continue
			best_gap = gap
			best = target
	return best


## Hooks whatever the crosshair is on, and says whether it did. This is what
## the grapple asks first: firing silk at something you have already caught
## should put a line on it, not haul you over to stand next to it.
func grab_aimed() -> bool:
	if cargo != null:
		return false
	var target := aimed_cargo()
	return target != null and hook(target)


## How far the crosshair gets before it meets something solid. Cargo behind a
## wall is not cargo you can see, let alone hook.
func _wall_distance(origin: Vector3, forward: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if _spider != null:
		exclude.append(_spider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * WALL_REACH,
		GameLayers.WORLD, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return WALL_REACH
	return origin.distance_to(hit["position"]) + _height()


func _resting_length() -> float:
	return _height() * rope_bodies


# --- the rope -----------------------------------------------------------

## The cargo is pulled only once it is further away than the line is long, and
## it is pulled rather than placed, so it swings in behind you instead of
## snapping to a fixed distance.
func _haul(delta: float, hand: Vector3, tail: Vector3) -> void:
	var offset := hand - tail
	var span := offset.length()
	if span <= _rope_length or span < 0.0001:
		return
	var along := offset / span
	var pull := along * (span - _rope_length) * haul_force
	var prey := cargo as Prey
	if prey != null:
		prey.tow(pull * delta)
		return
	# A device has no physics of its own, so it simply comes along.
	cargo.global_position = tail + along * (span - _rope_length)


func _simulate_rope(delta: float, hand: Vector3, tail: Vector3) -> void:
	if _rope.size() != rope_segments + 1:
		_reset_rope(hand, tail)
	var fall := Vector3.DOWN * rope_gravity * delta * delta
	for i in range(1, _rope.size() - 1):
		var current := _rope[i]
		var drift := (current - _previous[i]) * rope_damping
		_previous[i] = current
		_rope[i] = current + drift + fall
	_rope[0] = hand
	_rope[_rope.size() - 1] = tail

	# Rope, not rod: a segment shorter than its rest length is slack and is
	# left alone, so the line sags between you and whatever you are dragging
	# and only goes taut when it is actually holding something back.
	var rest: float = _rope_length / float(rope_segments)
	for iteration in rope_iterations:
		for i in _rope.size() - 1:
			var a := _rope[i]
			var b := _rope[i + 1]
			var between := b - a
			var distance := between.length()
			if distance <= rest or distance < 0.0001:
				continue
			var fix := between * ((distance - rest) / distance) * 0.5
			if i > 0:
				_rope[i] = a + fix
			if i + 1 < _rope.size() - 1:
				_rope[i + 1] = b - fix
		_rope[0] = hand
		_rope[_rope.size() - 1] = tail


func _reset_rope(hand: Vector3, tail: Vector3) -> void:
	_rope.resize(rope_segments + 1)
	_previous.resize(rope_segments + 1)
	for i in _rope.size():
		var along := float(i) / float(rope_segments)
		var point := hand.lerp(tail, along)
		_rope[i] = point
		_previous[i] = point


func _let_go(text: String) -> void:
	var was := cargo
	cargo = null
	_rope.clear()
	_previous.clear()
	_draw()
	if text != "":
		notice.emit(text)
	released.emit(was)


# --- odds and ends ------------------------------------------------------

func _still_there() -> bool:
	if not is_instance_valid(cargo) or cargo.is_queued_for_deletion():
		return false
	var prey := cargo as Prey
	if prey != null and prey.eaten:
		return false
	var device := cargo as SilkDevice
	return device == null or not device.is_queued_for_deletion()


## Where the line leaves the spider — a little above where it stands, so the
## rope does not start inside the floor.
func _hand() -> Vector3:
	var up := _climb.body_up() if _climb != null else Vector3.UP
	return _spider.global_position + up * _height() * 0.4


func _label(target: Node3D) -> String:
	if target == null:
		return "thing"
	var prey := target as Prey
	if prey != null:
		return prey.species
	var device := target as SilkDevice
	return device.label() if device != null else target.name


func _weight_of(target: Node3D) -> float:
	var prey := target as Prey
	return float(prey.size_class) if prey != null else 1.0


func _height() -> float:
	return _growth.current_stage().body_height if _growth != null else 0.35


func _quality() -> float:
	return _growth.current_stage().silk_quality if _growth != null else 1.0


func _build_view() -> void:
	_material = WebGeometry.silk_material()
	_mesh = ImmediateMesh.new()
	_view_node = MeshInstance3D.new()
	_view_node.name = "TetherLine"
	_view_node.mesh = _mesh
	_view_node.material_override = _material
	_view_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view_node.top_level = true
	add_child(_view_node)
	_view_node.transform = Transform3D.IDENTITY


func _draw() -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	if _rope.size() < 2:
		return
	var width: float = maxf(_height() * 0.045, 0.004)
	for i in _rope.size() - 1:
		WebGeometry.draw_line_into(_mesh, _material, _rope[i], _rope[i + 1],
			width, rope_color)
