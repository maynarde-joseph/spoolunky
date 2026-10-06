class_name FlyLine
extends Node3D

## The flies the spider has caught, wrapped, on a line behind it — the first on a
## line from the spider, each one after on a line from the one before, so the
## catch trails out behind like the tail of a kite and swings as the spider turns.
##
## A line is a rope, not a rod: walk back toward a fly and its line goes slack and
## sags; only stretched past its length does it pull. Each fly is a weight on the
## end of its line, falling and swinging and kept off the floor, and nothing else.
##
## At the exit they go in the bag: see [method pour_into].

## How long each line is, in metres.
const LINK := 0.85

## How quickly a swing dies away: what is kept of the last frame's movement.
const DAMPING := 0.985

const GRAVITY := 14.0

## How far a bundle keeps off the floor.
const FLOOR_GAP := 0.14

var weaver: Weaver

## The flies, in the order they were caught.
var flies: Array[Fly] = []

var _points: Array[Vector3] = []
var _was: Array[Vector3] = []
var _mesh: ImmediateMesh
var _paint: StandardMaterial3D
var _view: MeshInstance3D

## Where the catch is being poured to, and how far through, while it goes in.
var _pouring := false
var _pour_to := Vector3.ZERO
var _pour_time := 0.0


func setup(owner_weaver: Weaver) -> void:
	weaver = owner_weaver
	_mesh = ImmediateMesh.new()
	_paint = WebGeometry.silk_material()
	_paint.emission_energy_multiplier = 0.6
	_view = MeshInstance3D.new()
	_view.name = "Lines"
	_view.mesh = _mesh
	_view.material_override = _paint
	_view.top_level = true
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)


func count() -> int:
	return flies.size()


## Puts a caught fly on the end of the line, where it was caught.
func add(fly: Fly) -> void:
	if flies.has(fly):
		return
	flies.append(fly)
	_points.append(fly.global_position)
	_was.append(fly.global_position)


## Where the line leaves the spider: its spinnerets, at the back of the abdomen.
func hand() -> Vector3:
	return weaver.global_position + weaver.global_basis.z * Weaver.HEIGHT * 0.3 \
		+ weaver.global_basis.y * Weaver.HEIGHT * 0.1


## Which way the first line pulls on the spider, in the world, or zero.
func pull() -> Vector3:
	if _points.is_empty():
		return Vector3.ZERO
	return _points[0] - weaver.global_position


## Sends every fly on the line into [param point] — the bag.
func pour_into(point: Vector3) -> void:
	_pouring = true
	_pour_to = point
	_pour_time = 0.0


func is_poured() -> bool:
	return _pouring and _pour_time >= 0.7


func _physics_process(delta: float) -> void:
	if flies.is_empty():
		return
	if _pouring:
		_pour_time += delta
		for i in _points.size():
			var lag := float(i) * 0.06
			var t := clampf((_pour_time - lag) / 0.5, 0.0, 1.0)
			_points[i] = _points[i].lerp(_pour_to, t * t)
			if t >= 1.0 and flies[i].state != Fly.State.BAGGED:
				flies[i].bag()
		_place()
		return
	var space := get_world_3d().direct_space_state
	var fall := Vector3.DOWN * GRAVITY * delta * delta
	for i in _points.size():
		var now := _points[i]
		var drift := (now - _was[i]) * DAMPING
		_was[i] = now
		_points[i] = now + drift + fall
	# Rope, not rod: pulled in to its length when stretched, and left alone when
	# slack. Twice through, from the spider out, so the tail follows the head.
	for pass_count in 2:
		var anchor := hand()
		for i in _points.size():
			var offset := _points[i] - anchor
			var span := offset.length()
			if span > LINK:
				_points[i] = anchor + offset / span * LINK
			anchor = _points[i]
	for i in _points.size():
		var query := PhysicsRayQueryParameters3D.create(_points[i] + Vector3.UP * 0.4,
			_points[i] + Vector3.DOWN * FLOOR_GAP, GameLayers.WORLD, [weaver.get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var floor_y: float = hit["position"].y + FLOOR_GAP
			if _points[i].y < floor_y:
				_points[i].y = floor_y
				_was[i] = _was[i].lerp(_points[i], 0.5)
	_place()


func _place() -> void:
	for i in flies.size():
		if is_instance_valid(flies[i]):
			flies[i].global_position = _points[i]


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	_view.global_transform = Transform3D.IDENTITY
	if flies.is_empty() or _pouring:
		return
	var anchor := hand()
	for i in _points.size():
		_draw_link(anchor, _points[i] + Vector3.UP * Fly.SIZE * 1.2)
		anchor = _points[i] - Vector3.UP * Fly.SIZE * 1.2


## One line, sagging by however much slack it has.
func _draw_link(a: Vector3, b: Vector3) -> void:
	var slack := maxf(LINK - a.distance_to(b), 0.0)
	var sag := Vector3.DOWN * slack * 0.6
	var pieces := 5
	var last := a
	for k in range(1, pieces + 1):
		var t := float(k) / float(pieces)
		var point := a.lerp(b, t) + sag * 4.0 * t * (1.0 - t)
		WebGeometry.draw_line_into(_mesh, _paint, last, point, 0.018,
			Color(0.95, 0.96, 1.0, 0.9))
		last = point
