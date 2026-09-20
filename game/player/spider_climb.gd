class_name SpiderClimb
extends Node3D

## Sticking to things.
##
## Takes over movement whenever the spider is touching a climbable surface, so
## a floor, a wall and a ceiling are all the same thing: a plane you walk on
## with your back to it. The body's up axis becomes the surface normal, gravity
## is replaced by a pull into the surface, and the camera comes along for the
## ride.
##
## It also owns the dragline: drop off a ceiling on a thread, pay it out, reel
## it back in, or let go.

enum Mode {
	## In the air, normal gravity, looking for something to grab.
	AIRBORNE,
	## Stuck to a surface, whatever angle it is.
	ATTACHED,
	## Swinging from a line of silk.
	HANGING,
}

signal mode_changed(mode: Mode)
signal surface_changed(normal: Vector3)
signal jumped()
signal line_dropped(anchor: Vector3)
signal line_cut()
signal notice(text: String)


@export_group("Climbing")

## How far the spider's feet reach for a surface, in body heights.
@export var stick_reach := 1.15

## Pull into the surface, in body heights per second. This is what stops a
## spider on a ceiling falling off.
@export var stick_force := 9.0

## How quickly the body rolls over onto a new surface.
@export var orientation_speed := 9.0

## Speed on a vertical or upside-down surface, against speed on the flat.
@export_range(0.1, 1.0, 0.05) var steep_speed_factor := 0.8

@export var acceleration := 14.0
@export var deceleration := 18.0

## Seconds after jumping before the spider may stick to anything again,
## so a jump off a wall actually leaves the wall.
@export var release_grace := 0.22

## Surfaces to climb. World geometry by default; silk bridges count too.
@export_flags_3d_physics var climbable_layers := 1

## Colliders in this group cannot be climbed — glass, grease, a hot pipe.
@export var no_climb_group := "no_climb"


@export_group("Dragline")

## Longest line the spider can pay out, in body heights.
@export var max_line_bodies := 40.0

## Pay-out and reel-in speed, in body heights per second.
@export var line_speed_bodies := 8.0

## Silk per metre of line, before the size tier's silk quality.
@export var line_silk_per_metre := 0.8

## Fraction of the silk cost recovered by reeling the line back in.
@export_range(0.0, 1.0, 0.05) var line_reel_refund := 0.5

## Sideways push while hanging, for swinging yourself somewhere useful.
@export var swing_force := 4.0

## Air drag on a swinging spider, so a pendulum eventually settles.
@export var swing_damping := 0.6

@export var line_color := Color(0.95, 0.96, 1, 0.92)


var mode: Mode = Mode.AIRBORNE
var surface_normal := Vector3.UP
var line_anchor := Vector3.ZERO
var line_length := 0.0

## Speed along the surface, for head bob and footsteps.
var tangent_velocity := Vector3.ZERO

var _spider: CharacterController3D
var _silk: SilkPool
var _growth: SpiderGrowth
var _facing := Vector3.FORWARD
var _current_up := Vector3.UP
var _grace := 0.0
var _silk_warning := 0.0
var _line_mesh: ImmediateMesh
var _line_instance: MeshInstance3D
var _line_material: StandardMaterial3D


func setup(spider: CharacterController3D, silk: SilkPool, growth: SpiderGrowth) -> void:
	_spider = spider
	_silk = silk
	_growth = growth
	_facing = -spider.global_basis.z
	_current_up = Vector3.UP
	surface_normal = Vector3.UP
	_build_line_visual()


## True while this component is driving the body. Water and free-fly are left
## to the character-controller template.
func handles_movement() -> bool:
	return _spider != null and not _spider.is_fly_mode() and not _in_water()


func is_attached() -> bool:
	return mode == Mode.ATTACHED


func is_hanging() -> bool:
	return mode == Mode.HANGING


## True when the spider is on something it could not stand on upright.
func on_steep_surface() -> bool:
	return mode == Mode.ATTACHED and surface_normal.dot(Vector3.UP) < 0.7


## Direction the body treats as up right now.
func body_up() -> Vector3:
	return _current_up


## Points the body at a direction, flattened onto whatever it is standing on.
func face(direction: Vector3) -> void:
	var flat := direction - _current_up * direction.dot(_current_up)
	if flat.length_squared() < 0.000001:
		return
	_facing = flat.normalized()


## Mouse look. Yaw turns around whatever the body is standing on, so looking
## around works the same on a ceiling as on the floor.
func add_yaw(amount: float) -> void:
	_facing = _facing.rotated(_current_up, amount).normalized()


## Rolls the body toward the surface it is on. Runs every frame, including the
## frames where the template is driving movement, so mouse look never stalls.
func update_orientation(delta: float) -> void:
	if _spider == null:
		return
	if mode == Mode.AIRBORNE:
		_blend_up(Vector3.UP, delta)
	elif mode == Mode.HANGING:
		var to_anchor := line_anchor - _spider.global_position
		_blend_up(to_anchor.normalized() if to_anchor.length() > 0.001 else Vector3.UP, delta)
	var target := _orientation_basis(_current_up)
	var current := _spider.global_basis.orthonormalized()
	var weight := clampf(orientation_speed * delta, 0.0, 1.0)
	_spider.global_basis = Basis(current.get_rotation_quaternion().slerp(
		target.get_rotation_quaternion(), weight))
	_draw_line()


## One step of spider movement.
func step(delta: float, input_axis: Vector2, want_jump: bool, want_sprint: bool,
		want_line_out: bool, want_line_in: bool, want_release: bool) -> void:
	if _spider == null:
		return
	_grace = maxf(0.0, _grace - delta)
	_silk_warning = maxf(0.0, _silk_warning - delta)
	if mode == Mode.HANGING:
		_step_hanging(delta, input_axis, want_line_out, want_line_in, want_release)
	else:
		_step_surface(delta, input_axis, want_jump, want_sprint, want_line_out)


## Drops everything and falls. Used when handing back to the template.
func release() -> void:
	if mode != Mode.AIRBORNE:
		_set_mode(Mode.AIRBORNE)
	line_length = 0.0
	if _spider != null:
		_spider.up_direction = Vector3.UP
	_draw_line()


# --- surfaces -----------------------------------------------------------

func _step_surface(delta: float, input_axis: Vector2, want_jump: bool,
		want_sprint: bool, want_line_out: bool) -> void:
	var height := _body_height()
	var wish := _wish_direction(input_axis, _current_up)
	var hit := _find_surface(height, wish)

	if hit.is_empty() or _grace > 0.0:
		_set_mode(Mode.AIRBORNE)
		_move_airborne(delta, input_axis)
		return

	_adopt_surface(hit["normal"])
	_set_mode(Mode.ATTACHED)

	if want_line_out:
		if _can_hang_from(hit):
			_drop_line(hit)
		else:
			_warn("Nothing overhead to hang from")
		return
	if want_jump:
		_leap(input_axis)
		return

	# Walking the surface: all the movement happens in its tangent plane, and
	# the only force is the one holding the spider onto it.
	wish = _wish_direction(input_axis, _current_up)
	var speed := _surface_speed(want_sprint)
	var velocity := _spider.velocity
	var tangent := velocity - _current_up * velocity.dot(_current_up)
	var target := wish * speed
	var rate: float = acceleration if target.dot(tangent) > 0.0 else deceleration
	tangent = tangent.lerp(target, clampf(rate * delta, 0.0, 1.0))

	_spider.velocity = tangent - _current_up * stick_force * height
	_spider.up_direction = _current_up
	_spider.move_and_slide()
	tangent_velocity = tangent


func _move_airborne(delta: float, input_axis: Vector2) -> void:
	var wish := _wish_direction(input_axis, Vector3.UP)
	var velocity := _spider.velocity
	velocity.y -= _spider.gravity * delta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := wish * _spider.speed
	horizontal = horizontal.lerp(target, clampf(acceleration * _spider.air_control * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_spider.velocity = velocity
	_spider.up_direction = Vector3.UP
	_spider.move_and_slide()
	tangent_velocity = Vector3(velocity.x, 0.0, velocity.z)


func _leap(input_axis: Vector2) -> void:
	var wish := _wish_direction(input_axis, _current_up)
	_spider.velocity = _current_up * _spider.jump_height + wish * _spider.speed * 0.5
	_grace = release_grace
	_set_mode(Mode.AIRBORNE)
	jumped.emit()


## Picks what to stick to. The surface already underfoot wins ties, so brushing
## past a wall doesn't throw the spider onto it — you have to walk into it.
func _find_surface(height: float, wish: Vector3) -> Dictionary:
	var space := _spider.get_world_3d().direct_space_state
	var origin := _spider.global_position
	var reach := height * stick_reach
	var up := _current_up
	var forward := _facing
	var right := forward.cross(up)
	if right.length_squared() < 0.000001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()

	var directions: Array[Vector3] = [
		-up, forward, -forward, right, -right, up,
		-up + forward, -up - forward, -up + right, -up - right,
	]

	var best := {}
	var best_score := INF
	var same := {}
	var same_score := INF
	var exclude: Array[RID] = [_spider.get_rid()]

	for direction in directions:
		var dir := direction.normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach,
			climbable_layers, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		if normal.dot(dir) > -0.1:
			continue
		var collider := hit.get("collider") as Node
		if collider != null and collider.is_in_group(no_climb_group):
			continue
		var distance: float = origin.distance_to(hit["position"])
		if distance < best_score:
			best_score = distance
			best = hit
		if normal.dot(up) > 0.85 and distance < same_score:
			same_score = distance
			same = hit

	if best.is_empty():
		return best
	if mode != Mode.ATTACHED or same.is_empty():
		return best

	# Still on the old surface. Only change allegiance if the player is
	# actively pushing into the new one.
	var candidate: Vector3 = best.get("normal", Vector3.UP)
	if candidate.dot(up) > 0.85:
		return same
	if wish.length_squared() > 0.01 and wish.normalized().dot(-candidate) > 0.2:
		return best
	return same


## Moves the body's idea of up onto a new surface, carrying the facing
## direction with it.
func _adopt_surface(normal: Vector3) -> void:
	if normal.dot(_current_up) > 0.999:
		surface_normal = normal
		_current_up = normal
		return
	var along := _facing.dot(normal)
	var new_facing: Vector3
	if absf(along) > 0.95:
		# Walked straight into the surface (face up it) or over an edge onto
		# its far side (face down it).
		new_facing = _current_up * (-1.0 if along > 0.0 else 1.0)
	else:
		new_facing = _facing - normal * along
	new_facing = new_facing - normal * new_facing.dot(normal)
	if new_facing.length_squared() < 0.000001:
		new_facing = normal.cross(Vector3.RIGHT)
		if new_facing.length_squared() < 0.000001:
			new_facing = normal.cross(Vector3.FORWARD)
	_facing = new_facing.normalized()
	_current_up = normal
	surface_normal = normal
	surface_changed.emit(normal)


func _surface_speed(want_sprint: bool) -> float:
	var speed := _spider.speed
	if want_sprint:
		speed *= _spider.sprint_speed_multiplier
	var steepness := clampf(1.0 - maxf(0.0, _current_up.dot(Vector3.UP)), 0.0, 1.0)
	return speed * lerpf(1.0, steep_speed_factor, steepness)


# --- dragline -----------------------------------------------------------

## True if the surface is steep or overhead — you cannot dangle from the floor
## you are standing on.
func _can_hang_from(surface_hit: Dictionary) -> bool:
	var normal: Vector3 = surface_hit.get("normal", Vector3.UP)
	return normal.dot(Vector3.UP) < 0.7


func _drop_line(surface_hit: Dictionary) -> void:
	var height := _body_height()
	var start_length := height * 0.9
	var cost := start_length * line_silk_per_metre * _growth.current_stage().silk_quality
	if not _silk.spend(cost):
		_warn("Not enough silk for a line")
		return
	line_anchor = surface_hit.get("position", _spider.global_position + _current_up * height * 0.5)
	line_length = start_length
	_spider.velocity = Vector3.ZERO
	_set_mode(Mode.HANGING)
	line_dropped.emit(line_anchor)


func _cut_line() -> void:
	if mode != Mode.HANGING:
		return
	_grace = release_grace
	_set_mode(Mode.AIRBORNE)
	line_cut.emit()


func _step_hanging(delta: float, input_axis: Vector2, want_out: bool, want_in: bool,
		want_release: bool) -> void:
	if want_release:
		_cut_line()
		return

	var height := _body_height()
	var quality := _growth.current_stage().silk_quality
	var travel := height * line_speed_bodies * delta

	if want_out:
		var room: float = height * max_line_bodies - line_length
		var amount := minf(travel, maxf(room, 0.0))
		var cost := amount * line_silk_per_metre * quality
		if amount <= 0.0:
			_warn("The line is fully paid out")
		elif _silk.spend(cost):
			line_length += amount
		else:
			_warn("Out of silk for the line")
	elif want_in:
		var amount := minf(travel, line_length - height * 0.9)
		if amount > 0.0:
			line_length -= amount
			_silk.refill(amount * line_silk_per_metre * quality * line_reel_refund)
		else:
			# Back at the top — grab whatever the line is anchored to.
			var wish_up := _wish_direction(input_axis, Vector3.UP)
			var hit := _find_surface(height, wish_up)
			if not hit.is_empty():
				_adopt_surface(hit["normal"])
				_set_mode(Mode.ATTACHED)
				return

	var velocity := _spider.velocity
	velocity.y -= _spider.gravity * delta

	# Swing: push sideways relative to where you are looking.
	var wish := _wish_direction(input_axis, Vector3.UP)
	velocity += wish * swing_force * height * delta * 10.0
	velocity = velocity.lerp(Vector3.ZERO, clampf(swing_damping * delta, 0.0, 1.0))

	# Rope constraint: nothing beyond the length of silk paid out.
	var to_anchor := line_anchor - _spider.global_position
	var distance := to_anchor.length()
	if distance > line_length and distance > 0.001:
		var rope := to_anchor / distance
		var outward := velocity.dot(-rope)
		if outward > 0.0:
			velocity += rope * outward
		velocity += rope * (distance - line_length) / maxf(delta, 0.0001) * 0.5

	_spider.velocity = velocity
	_spider.up_direction = Vector3.UP
	_spider.move_and_slide()
	tangent_velocity = Vector3.ZERO

	# Swung into something climbable while pushing towards it? Grab it.
	if wish.length_squared() > 0.01:
		var reach_hit := _find_surface(height, wish)
		if not reach_hit.is_empty():
			var normal: Vector3 = reach_hit.get("normal", Vector3.UP)
			if wish.normalized().dot(-normal) > 0.2:
				_adopt_surface(normal)
				_set_mode(Mode.ATTACHED)
				line_cut.emit()


func _warn(text: String) -> void:
	if _silk_warning > 0.0:
		return
	_silk_warning = 2.0
	notice.emit(text)


# --- helpers ------------------------------------------------------------

func _wish_direction(input_axis: Vector2, up: Vector3) -> Vector3:
	if input_axis.length_squared() < 0.01:
		return Vector3.ZERO
	var forward := _facing - up * _facing.dot(up)
	if forward.length_squared() < 0.000001:
		return Vector3.ZERO
	forward = forward.normalized()
	var right := forward.cross(up).normalized()
	return (forward * input_axis.y - right * input_axis.x).normalized()


func _orientation_basis(up: Vector3) -> Basis:
	var back := -_facing
	var right := up.cross(back)
	if right.length_squared() < 0.000001:
		right = up.cross(Vector3.FORWARD)
		if right.length_squared() < 0.000001:
			right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	back = right.cross(up).normalized()
	return Basis(right, up, back)


func _blend_up(target: Vector3, delta: float) -> void:
	if target.length_squared() < 0.000001:
		return
	var blended := _current_up.slerp(target, clampf(orientation_speed * delta, 0.0, 1.0))
	if blended.length_squared() > 0.000001:
		_current_up = blended.normalized()


func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	var leaving_surface := mode == Mode.ATTACHED
	mode = new_mode
	if leaving_surface:
		# Drop the pull that was holding us on, or we launch into the floor.
		var into := _spider.velocity.dot(-_current_up)
		if into > 0.0:
			_spider.velocity += _current_up * into
	if new_mode != Mode.HANGING:
		line_length = 0.0
	mode_changed.emit(new_mode)


func _body_height() -> float:
	if _growth == null:
		return 0.25
	return _growth.current_stage().body_height


func _in_water() -> bool:
	var swim := _spider.swim_ability
	if swim == null:
		return false
	var ray := swim.get_node_or_null("RayCast3D") as RayCast3D
	return ray != null and ray.is_colliding()


func _build_line_visual() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.vertex_color_use_as_albedo = true
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line_mesh = ImmediateMesh.new()
	_line_instance = MeshInstance3D.new()
	_line_instance.name = "Dragline"
	_line_instance.mesh = _line_mesh
	_line_instance.material_override = _line_material
	_line_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line_instance.top_level = true
	add_child(_line_instance)
	_line_instance.transform = Transform3D.IDENTITY


func _draw_line() -> void:
	if _line_mesh == null:
		return
	_line_mesh.clear_surfaces()
	if mode != Mode.HANGING:
		return
	var height := _body_height()
	var attach := _spider.global_position + _current_up * height * 0.45
	WebGeometry.draw_line_into(_line_mesh, _line_material, line_anchor, attach,
		maxf(height * 0.05, 0.004), line_color)
