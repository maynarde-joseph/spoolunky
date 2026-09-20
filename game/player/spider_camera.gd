class_name SpiderCamera
extends Node3D

## The camera rig, and the only thing that decides where the player is looking.
##
## Look direction is kept in **world** yaw and pitch, deliberately not in the
## body's frame. When the spider is on a wall its body rolls onto that wall, but
## the mouse keeps meaning the same thing: left is left, up is up, and the
## horizon stays level. Deriving the view from the body instead — which is what
## this used to do — quietly remaps the mouse axes the moment you leave the
## floor, and that is what made looking around on a wall feel wrong.
##
## Movement asks this rig which way is forward, so walking is camera-relative
## the same way it is in any third-person game, and the body turns to follow.

signal mode_changed(third_person: bool)

## Start behind the spider rather than inside its head.
@export var third_person := true

## How far back the camera sits, in body heights.
@export var distance := 4.5

## How far above the spider the third-person pivot sits, in body heights.
@export var pivot_height := 1.4

## How far up and down you can look, in degrees.
@export var pitch_limit := 88.0

@export var sensitivity := 2.0

## What the arm refuses to pass through.
@export_flags_3d_physics var collide_with := 1

var yaw := 0.0
var pitch := 0.0

var camera: Camera3D
var _anchor: Node3D
var _body: Node3D


func setup(body: Node3D, first_person_anchor: Node3D) -> void:
	_body = body
	_anchor = first_person_anchor
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.top_level = true
	add_child(camera)
	camera.make_current()
	yaw = body.global_rotation.y


## Mouse look, in world terms.
func look(mouse_axis: Vector2) -> void:
	var scale := sensitivity / 1000.0
	yaw = wrapf(yaw - mouse_axis.x * scale, -PI, PI)
	var limit := deg_to_rad(pitch_limit)
	pitch = clampf(pitch - mouse_axis.y * scale, -limit, limit)


## Points the camera along a direction, keeping it level.
func face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	flat = flat.normalized()
	yaw = atan2(-flat.x, -flat.z)


func toggle_mode() -> void:
	third_person = not third_person
	mode_changed.emit(third_person)


## Places the camera for this frame. [param body_height] scales the rig so a
## coin-sized spider and a car-sized one both sit sensibly in frame.
func update(body_height: float) -> void:
	if camera == null or _body == null:
		return
	var look_basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var look := -look_basis.z

	if third_person:
		var pivot := _body.global_position + Vector3.UP * pivot_height * body_height
		var wanted := pivot - look * distance * body_height
		camera.global_position = _unobstructed(pivot, wanted, body_height)
	elif _anchor != null:
		camera.global_position = _anchor.global_position
	else:
		camera.global_position = _body.global_position

	camera.global_basis = look_basis
	camera.near = clampf(body_height * 0.02, 0.005, 0.05)


## Pulls the camera in if there is something between it and the spider, so it
## never ends up looking through a wall.
func _unobstructed(pivot: Vector3, wanted: Vector3, body_height: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var collider := _body as CollisionObject3D
	if collider != null:
		exclude.append(collider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(pivot, wanted, collide_with, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	var margin: float = maxf(body_height * 0.35, 0.05)
	var point: Vector3 = hit["position"]
	var back := (pivot - point)
	if back.length() <= margin:
		return pivot
	return point + back.normalized() * margin


func forward() -> Vector3:
	return -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z


func right() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)).x


func up() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)).y


## Where aiming starts. In third person that is the spider, not the camera,
## so you cannot anchor silk to something the spider could not reach.
func aim_origin() -> Vector3:
	if not third_person and camera != null:
		return camera.global_position
	if _anchor != null:
		return _anchor.global_position
	return _body.global_position if _body != null else global_position


## Where aiming points: through the crosshair, from the spider.
func aim_forward() -> Vector3:
	if camera == null:
		return forward()
	if not third_person:
		return forward()
	var target := camera.global_position + forward() * 200.0
	var offset := target - aim_origin()
	if offset.length_squared() < 0.000001:
		return forward()
	return offset.normalized()
