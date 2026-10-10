class_name SilkCaster
extends Node3D

## Left mouse: silk, and going with it.
##
## **Tap** and a web is thrown down the cross — see [ThrownWeb] — to stick where
## it lands: somewhere to walk on, something to catch a fly with, something to
## pull home with the Pullback.
##
## **Hold** and the same web is thrown with the spider on the line: it rides the
## web to wherever it sticks, or stops dead with it. A ride takes the grapple,
## which comes back on landing — see [Grapple] — so with it spent, a hold only
## throws.
##
## While the button is down a ball of silk winds up over the spider's back; it is
## full at [constant HOLD] seconds, and that is when a hold goes.

## How long left mouse has to be held for the spider to go with the web.
const HOLD := 0.18

## How wide a web is, from its middle to its rim, in metres.
const RADIUS := 1.7

## How fast a thrown web flies, and how far before it comes apart.
const SPEED := 22.0
const REACH := 22.0

## The least time between throws.
const COOLDOWN := 0.2

## The held ball's radius, in body heights, from the press to a full hold.
const HELD_BODIES := Vector2(0.12, 0.3)

var weaver: Weaver
var view: SpiderCamera

var charging := false

## How far through to a hold, 0 to 1.
var charge := 0.0

var _cooling := 0.0
var _held: MeshInstance3D
var _held_material: StandardMaterial3D


func setup(owner_weaver: Weaver, camera: SpiderCamera) -> void:
	weaver = owner_weaver
	view = camera
	_build_held()


## Left mouse went down: start winding up.
func begin() -> bool:
	if charging:
		return false
	charging = true
	charge = 0.0
	_held.visible = true
	return true


## Left mouse came up before the hold went: a tap, and a web thrown. The web, or
## null if none went.
func release() -> ThrownWeb:
	if not charging:
		return null
	return _go(false)


## Put the ball away without throwing.
func cancel() -> void:
	charging = false
	charge = 0.0
	if _held != null:
		_held.visible = false


## Throws, and with [param ride], puts the spider on the line to the web.
func _go(ride: bool) -> ThrownWeb:
	cancel()
	var web := throw()
	if web != null and ride:
		weaver.ride_web(web)
	return web


## Throws a web down the cross: what a tap does, and what a check calls to throw
## without a key. The web, or null if none went.
func throw() -> ThrownWeb:
	if _cooling > 0.0:
		return null
	if weaver.webs_left() <= 0:
		weaver.notify("No silk left — call your webs back (right mouse)")
		weaver.out_of_silk.emit()
		return null
	var from := view.aim_origin()
	var heading := view.aim_forward()
	var web := ThrownWeb.throw(weaver.web_container(), weaver, from, heading, SPEED, RADIUS, REACH)
	weaver.adopt_web(web)
	weaver.hang_after_throw()
	_cooling = COOLDOWN
	return web


## What a web thrown now would meet, within its reach: [code]{position, holds}[/code],
## [code]holds[/code] whether silk would stick there and bear the spider. Empty for
## nothing in reach.
func aimed() -> Dictionary:
	if view == null or weaver == null:
		return {}
	var from := view.aim_origin()
	var query := PhysicsRayQueryParameters3D.create(from, from + view.aim_forward() * REACH,
		GameLayers.WORLD, [weaver.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var what := hit.get("collider") as Node
	var holds := what != null and not Surfaces.is_slick(what) and not (what is LoosePanel)
	if holds and not SilkCutter.crossing(get_world_3d().direct_space_state, from,
			hit["position"]).is_empty():
		holds = false
	return {"position": hit["position"], "holds": holds}


func _process(delta: float) -> void:
	_cooling = maxf(0.0, _cooling - delta)
	if charging:
		charge = clampf(charge + delta / HOLD, 0.0, 1.0)
		if charge >= 1.0:
			_go(true)
	_update_held()


## How big the held ball is [param wound] of the way to a hold.
func ball_radius(wound: float) -> float:
	return Weaver.HEIGHT * lerpf(HELD_BODIES.x, HELD_BODIES.y, clampf(wound, 0.0, 1.0))


## Where the ball is held, or nowhere.
func held_ball() -> Node3D:
	return _held if _held != null and _held.visible else null


func _update_held() -> void:
	if _held == null or not _held.visible:
		return
	var wide := ball_radius(charge)
	var back := weaver.global_basis.y.normalized()
	_held.global_position = weaver.global_position + back * (Weaver.HEIGHT * 0.9 + wide)
	_held.scale = Vector3.ONE * maxf(wide, 0.005)
	_held_material.emission_energy_multiplier = lerpf(0.5, 2.2, charge)


func _build_held() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_held_material = WebGeometry.silk_material()
	_held_material.albedo_color = Color(0.12, 0.13, 0.16, 1.0)
	_held = MeshInstance3D.new()
	_held.name = "HeldSilk"
	_held.mesh = mesh
	_held.material_override = _held_material
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.top_level = true
	_held.visible = false
	add_child(_held)
