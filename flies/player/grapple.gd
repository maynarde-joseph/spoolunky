class_name Grapple
extends Node3D

## Left mouse: a line to a web you point at, and you are pulled along it to land on
## it — or to a fly, which is caught at the end of the pull and hopped off.
##
## Only silk and flies hold the line: a web stuck to something, or one still in the
## air, which the line follows wherever it goes until the spider lands on it and
## rides it; and a fly, followed the same way along its path. Stone, slick metal and
## everything else give it nothing to bite — so silk makes the anchors, the grapple
## spends them, and the Pullback brings them back to make again; flies are the
## anchors a level puts there itself, each good once.
##
## A fly is small, so the grapple meets you more than halfway: it takes a fly within
## [constant FLY_CONE] degrees of the cross, past the fly's own size, and once it has
## one it keeps it out to [constant FLY_KEEP] — so a fly drifting along its path does
## not flicker in and out of the lock. Hold Shift and it takes the fly the spider has
## locked on to, wherever the cross is. The fly it would take wears gold brackets.
##
## One pull in the air: the line is spent the moment it goes and comes
## back when the spider lands, on the ground or on a web that has stuck. A web still
## flying gives it back once, until the spider next lands.
##
## This node finds the web the line would hold, keeps hold of it while the spider is
## pulled, and draws the line. The pulling itself is the spider's — see
## [method Weaver.start_grapple].

## How far a line reaches, in metres. A thrown web goes further, which is what a
## web you can ride is for.
const REACH := 24.0

## How fast the spider is pulled, in metres a second — and quicker on a long line,
## so that no pull takes longer than [constant LONGEST].
const SPEED := 18.2
const LONGEST := 1.1

## How generously a web in flight is picked out, past its own rim, in metres. It is
## moving, and it is the thing you are trying to catch.
const WEB_SLACK := 0.9

## How far off the cross a fly can be, in degrees past its outline, and still be
## what the grapple takes — and how far once it has been picked.
const FLY_CONE := 4.0
const FLY_KEEP := 6.0

var weaver: Weaver
var view: SpiderCamera

## The web the line is on while it pulls, and where on it — or the fly.
var web: ThrownWeb = null
var fly: Fly = null
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
## The fly last picked, kept while it stays within [constant FLY_KEEP].
var _locked: Fly = null


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
## point, [code]web[/code] — the web the line would hold, or null where the cross is
## on something that is not silk — and [code]fly[/code], when it is a fly. Empty for
## nothing in reach.
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
	# A fly near the cross, generously, and nearer than whatever the cross is on.
	var picked := aimed_fly(best_along)
	if picked != null:
		return {"position": picked.global_position, "web": null, "fly": picked}
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


## The fly the grapple would take now: the one nearest the cross within
## [constant FLY_CONE] degrees past its outline — [constant FLY_KEEP] for the one
## already picked, or the locked one while Shift is held — in reach, in plain sight of the spider, and nearer than
## [param before] along the line of sight. Null if none.
func aimed_fly(before := INF) -> Fly:
	if view == null or view.camera == null or weaver == null:
		return null
	var eye := view.camera.global_position
	var look := -view.camera.global_basis.z.normalized()
	# Shift held: the locked fly, wherever the cross is, if the line reaches it.
	if weaver.locking:
		var held := weaver.lock_target
		if held != null and weaver.global_position.distance_to(held.global_position) <= REACH:
			_locked = held
			return held
	var space := get_world_3d().direct_space_state
	var best: Fly = null
	var best_slack := INF
	for node in get_tree().get_nodes_in_group(Fly.GROUP):
		var candidate := node as Fly
		if candidate == null or not candidate.is_free():
			continue
		var at := candidate.global_position
		if weaver.global_position.distance_to(at) > REACH:
			continue
		var sight := at - eye
		var distance := sight.length()
		if distance < 0.01 or sight.dot(look) <= 0.0 or sight.dot(look) > before + 0.5:
			continue
		var slack := rad_to_deg(look.angle_to(sight)) \
			- rad_to_deg(atan2(Fly.HIT_RADIUS, distance))
		var allowed := FLY_KEEP if candidate == _locked else FLY_CONE
		if slack > allowed or slack >= best_slack:
			continue
		var check := PhysicsRayQueryParameters3D.create(weaver.global_position, at,
			GameLayers.WORLD, [weaver.get_rid()])
		if not space.intersect_ray(check).is_empty():
			continue
		best_slack = slack
		best = candidate
	_locked = best
	return best


## Puts the line on the web or fly aimed at. False if there is none.
func fire() -> bool:
	var target := aimed()
	if target.is_empty():
		return false
	fly = target.get("fly") as Fly
	if fly != null:
		web = null
		var reach := weaver.global_position.distance_to(fly.global_position)
		speed = maxf(SPEED, reach / LONGEST)
		active = true
		return true
	web = target.get("web") as ThrownWeb
	if web == null:
		_refused = 0.25
		_refused_at = target["position"]
		if _warned <= 0.0:
			weaver.notify("The grapple only holds silk and flies — throw a web there first")
			_warned = 2.0
		return false
	local_point = web.to_local(target["position"])
	local_point.z = 0.0
	var span := weaver.global_position.distance_to(target["position"])
	speed = maxf(SPEED, span / LONGEST)
	active = true
	return true


## Where the line is pulling to now: a point on the web, or the fly, wherever it
## has gone.
func target_point() -> Vector3:
	if fly != null and is_instance_valid(fly):
		return fly.global_position
	if web != null and is_instance_valid(web):
		return web.to_global(local_point)
	return weaver.global_position


## Whether what the line was on has gone: a web that came apart, or a fly something
## else took first.
func lost() -> bool:
	if fly != null:
		return not is_instance_valid(fly) or not fly.is_free()
	return web == null or not is_instance_valid(web) or not web.is_standing()


func end() -> void:
	active = false
	web = null
	fly = null


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
