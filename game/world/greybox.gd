class_name Greybox
extends RefCounted

## Whitebox geometry: boxes that are both something to see and something to
## stand on.
##
## Everything here is built from a pair of opposite corners rather than a
## centre and a size, because a prototype is mostly the job of making rooms
## meet each other — and "this wall runs from here to there" is a question you
## can answer by reading two numbers, while "this wall is centred at X and is
## Y across" is one you have to do arithmetic for every time.
##
## One shared material, no colour, no detail. Form comes from the lights.

## Off the pure white by a hair. A perfectly white surface under a white light
## shows no shading at all on the faces nearest the source, which is the
## opposite of what greyboxing is for.
const ALBEDO := Color(0.92, 0.92, 0.93, 1.0)

static var _shared: StandardMaterial3D = null


## The one material everything in the world uses.
static func material() -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.albedo_color = ALBEDO
		_shared.roughness = 0.9
		_shared.metallic = 0.0
	return _shared


## A solid box between two opposite corners. Collides as world, so silk sticks
## to it and the spider walks on it with no further ceremony.
static func span(parent: Node3D, lo: Vector3, hi: Vector3, part_name: String) -> StaticBody3D:
	var low := Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z))
	var high := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	var size := high - low
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return null
	var body := _box(parent, size, part_name)
	body.global_position = (low + high) * 0.5
	return body


## A walkable surface running from one point to another, so a prototype can
## have a slope. Thickness is vertical and width is across the fall line, which
## is what makes it a ramp rather than a wall.
##
## Rotation is the one thing [method span] cannot do, and a world where nothing
## sits on the diagonal is a world that never tests the diagonal — every surface
## square to an axis is a surface whose normal is exactly (1,0,0).
static func ramp(parent: Node3D, from: Vector3, to: Vector3, width: float,
		thickness: float, part_name: String) -> StaticBody3D:
	return _turned(parent, from, to, Vector3(width, thickness, 0.0), part_name)


## A wall running from one point to another, thin across and tall. The two ends
## give its line on the ground; it stands [param height] up from them.
static func fence(parent: Node3D, from: Vector3, to: Vector3, height: float,
		thickness: float, part_name: String) -> StaticBody3D:
	var flat_from := Vector3(from.x, from.y + height * 0.5, from.z)
	var flat_to := Vector3(to.x, to.y + height * 0.5, to.z)
	return _turned(parent, flat_from, flat_to, Vector3(thickness, height, 0.0), part_name)


## The shared part: a box of [param cross] section (z is filled in from the
## distance) whose length runs from one point to the other.
static func _turned(parent: Node3D, from: Vector3, to: Vector3, cross: Vector3,
		part_name: String) -> StaticBody3D:
	var along := to - from
	var length := along.length()
	if length <= 0.001 or cross.x <= 0.0 or cross.y <= 0.0:
		return null
	var body := _box(parent, Vector3(cross.x, cross.y, length), part_name)
	# looking_at puts -Z along the direction, which is the box's own length. A
	# direction that is already straight up leaves no room for UP to be the
	# other axis, so that case picks a different one.
	var up := Vector3.UP
	if absf(along.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.FORWARD
	body.global_transform = Transform3D(Basis.looking_at(along, up), (from + to) * 0.5)
	return body


static func _box(parent: Node3D, size: Vector3, part_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = part_name
	body.collision_layer = GameLayers.WORLD
	body.collision_mask = 0

	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)

	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.name = "Mesh"
	view.mesh = mesh
	view.material_override = material()
	body.add_child(view)

	parent.add_child(body)
	return body


## A hollow box: six slabs with the named interior. The walls sit *outside* the
## interior, so the space you asked for is the space you get to stand in.
static func room(parent: Node3D, lo: Vector3, hi: Vector3, wall: float,
		room_name: String, skip: Array[String] = []) -> Node3D:
	var shell := Node3D.new()
	shell.name = room_name
	parent.add_child(shell)
	if not skip.has("floor"):
		span(shell, Vector3(lo.x - wall, lo.y - wall, lo.z - wall),
			Vector3(hi.x + wall, lo.y, hi.z + wall), "Floor")
	if not skip.has("ceiling"):
		span(shell, Vector3(lo.x - wall, hi.y, lo.z - wall),
			Vector3(hi.x + wall, hi.y + wall, hi.z + wall), "Ceiling")
	if not skip.has("west"):
		span(shell, Vector3(lo.x - wall, lo.y, lo.z - wall),
			Vector3(lo.x, hi.y, hi.z + wall), "WallWest")
	if not skip.has("east"):
		span(shell, Vector3(hi.x, lo.y, lo.z - wall),
			Vector3(hi.x + wall, hi.y, hi.z + wall), "WallEast")
	if not skip.has("north"):
		span(shell, Vector3(lo.x, lo.y, lo.z - wall),
			Vector3(hi.x, hi.y, lo.z), "WallNorth")
	if not skip.has("south"):
		span(shell, Vector3(lo.x, lo.y, hi.z),
			Vector3(hi.x, hi.y, hi.z + wall), "WallSouth")
	return shell


## A flat panel with a rectangular hole in it, built as the four pieces around
## the hole. [param thin] is which axis is the panel's thickness — 0 for a wall
## facing along X, 1 for a floor or ceiling, 2 for a wall facing along Z — and
## the hole is placed in the other two axes, in ascending order: a floor's hole
## is given as (x, z), a Z-facing wall's as (x, y).
static func panel_with_hole(parent: Node3D, lo: Vector3, hi: Vector3, thin: int,
		hole_lo: Vector2, hole_hi: Vector2, part_name: String) -> Node3D:
	var frame := Node3D.new()
	frame.name = part_name
	parent.add_child(frame)

	var axes: Array[int] = []
	for i in 3:
		if i != thin:
			axes.append(i)
	var a := axes[0]
	var b := axes[1]

	# Clamped, so a hole asked for outside the panel simply stops at its edge
	# rather than producing a slab with a negative side.
	var ha_lo: float = clampf(hole_lo.x, lo[a], hi[a])
	var ha_hi: float = clampf(hole_hi.x, lo[a], hi[a])
	var hb_lo: float = clampf(hole_lo.y, lo[b], hi[b])
	var hb_hi: float = clampf(hole_hi.y, lo[b], hi[b])

	_piece(frame, lo, hi, a, b, lo[a], ha_lo, lo[b], hi[b], "Before")
	_piece(frame, lo, hi, a, b, ha_hi, hi[a], lo[b], hi[b], "After")
	_piece(frame, lo, hi, a, b, ha_lo, ha_hi, lo[b], hb_lo, "Under")
	_piece(frame, lo, hi, a, b, ha_lo, ha_hi, hb_hi, hi[b], "Over")
	return frame


static func _piece(parent: Node3D, lo: Vector3, hi: Vector3, a: int, b: int,
		a_lo: float, a_hi: float, b_lo: float, b_hi: float, part_name: String) -> void:
	if a_hi - a_lo <= 0.001 or b_hi - b_lo <= 0.001:
		return
	var low := lo
	var high := hi
	low[a] = a_lo
	high[a] = a_hi
	low[b] = b_lo
	high[b] = b_hi
	span(parent, low, high, part_name)


## Something to grapple to and hang webs from. A room of bare walls is a room
## with nothing to build in.
static func clutter(parent: Node3D, at: Vector3, size: Vector3, part_name: String) -> void:
	span(parent, at - size * 0.5, at + size * 0.5, part_name)
