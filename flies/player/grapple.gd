class_name Grapple
extends Node3D

## Left mouse: a line to where you point, and you are pulled along it.
##
## Anything solid that is not slick holds the line, and so does a web — one stuck
## to a wall, or one still in the air, which the line follows wherever it goes
## until the spider lands on it and rides it. One pull in the air: the line is
## spent the moment it goes and comes back when the spider lands, on the ground or
## on a web. On the ground it is always there.
##
## This node finds what the line would hold, keeps hold of it while the spider is
## pulled, and draws the line. The pulling itself is the spider's — see
## [method Weaver.start_grapple].

## How far a line reaches, in metres. A thrown web goes further, which is what a
## web you can ride is for.
const REACH := 24.0

## How fast the spider is pulled, in metres a second — and quicker on a long line,
## so that no pull takes longer than [constant LONGEST].
const SPEED := 34.0
const LONGEST := 0.6

## How generously a web in flight is picked out, past its own rim, in metres. It is
## moving, and it is the thing you are trying to catch.
const WEB_SLACK := 0.9

var weaver: Weaver
var view: SpiderCamera

## What the line is on while it pulls: a web, or a point on something.
var web: ThrownWeb = null
var body: Node3D = null
var local_point := Vector3.ZERO
var local_normal := Vector3.UP
var point := Vector3.ZERO
var normal := Vector3.UP
var active := false

## The pull's own speed, set when it goes.
var speed := SPEED

var _line: MeshInstance3D
var _mesh: ImmediateMesh
var _paint: StandardMaterial3D
## A flicker of red line where a grapple was refused, for a moment.
var _refused := 0.0
var _refused_at := Vector3.ZERO


func setup(owner_weaver: Weaver, camera: SpiderCamera) -> void:
	weaver = owner_weaver
	view = camera
	_mesh = ImmediateMesh.new()
	_paint = WebGeometry.silk_material()
	_paint.emission_energy_multiplier = 0.8
	_line = MeshInstance3D.new()
	_line.name = "Line"
	_line.mesh = _mesh
	_line.material_override = _paint
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)


## What the line would hold if it went now: a dictionary with the point, the
## surface's normal, the collider and the web, if it is one — or empty for
## nothing in reach. [code]slick[/code] is set on something it would slip off.
func aimed() -> Dictionary:
	if view == null or weaver == null:
		return {}
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [weaver.get_rid()]
	var eye := view.aim_pivot()
	var look := view.forward()
	var far := eye + look * (REACH + 30.0)
	var query := PhysicsRayQueryParameters3D.create(eye, far,
		GameLayers.WORLD | GameLayers.WEB_WALK, exclude)
	var hit := space.intersect_ray(query)
	var best := {}
	var best_along := INF
	if not hit.is_empty():
		best_along = (hit["position"] - eye).dot(look)
		best = hit
	# A web in the air, picked generously: it is small and fast, and catching one is
	# the move.
	for node in get_tree().get_nodes_in_group(ThrownWeb.GROUP):
		var thrown := node as ThrownWeb
		if thrown == null or not thrown.is_flying():
			continue
		var centre := thrown.global_position
		var along := (centre - eye).dot(look)
		if along <= 0.0 or along >= best_along:
			continue
		var off := (centre - (eye + look * along)).length()
		if off > thrown.current_radius() + WEB_SLACK:
			continue
		best_along = along
		best = {"position": centre, "normal": thrown.normal(), "collider": thrown.walk_body()}
	if best.is_empty():
		return {}
	# The line runs from the spider, not the camera: whatever is in the way of that
	# is what it holds.
	var from := weaver.global_position
	var at: Vector3 = best["position"]
	var target_web := ThrownWeb.of(best.get("collider"))
	if target_web == null:
		var check := PhysicsRayQueryParameters3D.create(from, at + (at - from).normalized() * 0.05,
			GameLayers.WORLD | GameLayers.WEB_WALK, exclude)
		var blocked := space.intersect_ray(check)
		if not blocked.is_empty() and blocked["position"].distance_to(at) > 0.3:
			best = blocked
			at = best["position"]
			target_web = ThrownWeb.of(best.get("collider"))
	if from.distance_to(at) > REACH:
		return {}
	best["web"] = target_web
	best["slick"] = target_web == null and Surfaces.is_slick(best.get("collider"))
	return best


## Puts the line on whatever is aimed at. False if nothing holds it.
func fire() -> bool:
	var target := aimed()
	if target.is_empty():
		return false
	if target.get("slick", false):
		_refused = 0.25
		_refused_at = target["position"]
		weaver.notify("Slick — the line won't hold")
		return false
	web = target.get("web") as ThrownWeb
	normal = (target.get("normal", Vector3.UP) as Vector3).normalized()
	point = target["position"]
	if web == null:
		# The pull ends with the spider against the surface, not its middle in it: a
		# long pull to a floor otherwise scrapes along the near edge and falls short.
		point += normal * (Weaver.RADIUS + 0.05)
	body = null
	if web != null:
		local_point = web.to_local(point)
		local_point.z = 0.0
	else:
		var hit_body := target.get("collider") as Node3D
		if hit_body is AnimatableBody3D or hit_body is RigidBody3D:
			body = hit_body
			local_point = body.to_local(point)
			local_normal = body.global_basis.inverse() * normal
	var span := weaver.global_position.distance_to(point)
	speed = maxf(SPEED, span / LONGEST)
	active = true
	return true


## Where the line is pulling to now: it follows a web, or whatever moving thing it
## is on.
func target_point() -> Vector3:
	if web != null and is_instance_valid(web):
		return web.to_global(local_point)
	if body != null and is_instance_valid(body):
		return body.to_global(local_point)
	return point


func target_normal() -> Vector3:
	if web != null and is_instance_valid(web):
		return web.normal()
	if body != null and is_instance_valid(body):
		return (body.global_basis * local_normal).normalized()
	return normal


## Whether what the line was on has gone out from under it: a web that came apart.
func lost() -> bool:
	return web != null and (not is_instance_valid(web) or not web.is_standing())


func end() -> void:
	active = false
	web = null
	body = null


func _process(delta: float) -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	_line.global_transform = Transform3D.IDENTITY
	var from := weaver.global_position + weaver.global_basis.y * 0.1
	if active:
		WebGeometry.draw_line_into(_mesh, _paint, from, target_point(), 0.035,
			Color(0.95, 0.96, 1.0, 0.95))
	elif _refused > 0.0:
		_refused -= delta
		WebGeometry.draw_line_into(_mesh, _paint, from, from.lerp(_refused_at, 0.7), 0.03,
			Color(1.0, 0.35, 0.3, clampf(_refused * 4.0, 0.0, 1.0)))
