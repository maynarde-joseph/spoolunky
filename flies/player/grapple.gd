class_name Grapple
extends Node3D

## Left mouse: a line to a web you point at, and you are pulled along it.
##
## Hold the button through the pull and you land on the web. Let go of it before
## the pull arrives and you come off the web with the pull's speed, carried on along
## whatever the web is stuck to — and a jump in the pull's last moment kicks off
## the web's face and up as well. Landing gives the grapple back; flying off does
## not. See [method Weaver._launch].
##
## Only silk holds the line: a web stuck to something, or one still in the air,
## which the line follows wherever it goes until the spider lands on it and rides
## it. Stone, slick metal and everything else give it nothing to bite — so silk
## makes the anchors, the grapple spends them, and the Pullback brings them back to
## make again.
##
## One pull in the air: the line is spent the moment it goes and comes back when
## the spider lands, on the ground or on a web that has stuck. A web still flying
## gives it back once, until the spider next lands.
##
## This node finds the web the line would hold, keeps hold of it while the spider is
## pulled, and draws the line. The pulling itself is the spider's — see
## [method Weaver.start_grapple].

## How far a line reaches, in metres. A thrown web goes further, which is what a
## web you can ride is for.
const REACH := 16.0

## How fast the spider is pulled, in metres a second — and quicker on a long line,
## so that no pull takes longer than [constant LONGEST].
const SPEED := 18.2
const LONGEST := 1.1

## How generously a web in flight is picked out, past its own rim, in metres. It is
## moving, and it is the thing you are trying to catch.
const WEB_SLACK := 0.9

var weaver: Weaver
var view: SpiderCamera

## The web the line is on while it pulls, and where on it.
var web: ThrownWeb = null
var local_point := Vector3.ZERO
var active := false

## The pull's own speed, set when it goes.
var speed := SPEED

var _line: MeshInstance3D
var _mesh: ImmediateMesh
var _paint: StandardMaterial3D
## A flicker of red line where a grapple found no silk, for a moment.
var _refused := 0.0
var _refused_at := Vector3.ZERO
var _warned := 0.0


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


## What the cross is on, as far as the grapple is concerned: a dictionary with the
## point and [code]web[/code] — the web the line would hold, or null where the cross
## is on something that is not silk. Empty for nothing in reach.
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
		var under := ThrownWeb.of(hit.get("collider"))
		best = {"position": hit["position"], "web": under if under != null
			and under.is_standing() else null}
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
		best = {"position": centre, "web": thrown}
	if best.is_empty():
		return {}
	var at: Vector3 = best["position"]
	var from := weaver.global_position
	if from.distance_to(at) > REACH:
		return {}
	# The line runs from the spider, not the camera: something solid in the way of
	# that is what it meets, and that is not silk.
	if best["web"] != null:
		var check := PhysicsRayQueryParameters3D.create(from, at, GameLayers.WORLD, exclude)
		var blocked := space.intersect_ray(check)
		if not blocked.is_empty() and blocked["position"].distance_to(at) > 0.3:
			best = {"position": blocked["position"], "web": null}
	return best


## Puts the line on the web aimed at. False if there is none.
func fire() -> bool:
	var target := aimed()
	if target.is_empty():
		return false
	web = target.get("web") as ThrownWeb
	if web == null:
		_refused = 0.25
		_refused_at = target["position"]
		if _warned <= 0.0:
			weaver.notify("The grapple only holds silk — throw a web there first")
			_warned = 2.0
		return false
	local_point = web.to_local(target["position"])
	local_point.z = 0.0
	var span := weaver.global_position.distance_to(target["position"])
	speed = maxf(SPEED, span / LONGEST)
	active = true
	return true


## Where the line is pulling to now: a point on the web, wherever it has gone.
func target_point() -> Vector3:
	if web != null and is_instance_valid(web):
		return web.to_global(local_point)
	return weaver.global_position


## Whether the web the line was on has gone: come apart, or called home.
func lost() -> bool:
	return web == null or not is_instance_valid(web) or not web.is_standing()


func end() -> void:
	active = false
	web = null


func _process(delta: float) -> void:
	_warned = maxf(0.0, _warned - delta)
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
