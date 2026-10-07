class_name ThrownWeb
extends Node3D

## A web, thrown.
##
## Silk is cast the way it always was — hold to wind a ball of it up over the
## spider's back, let go to throw — but what leaves the spider now is the web
## itself, already spun, flying face first down the line it was thrown along. In
## the air it is something to grapple onto and ride. Where its middle meets
## something solid it stops and sticks, lying flat against that surface, and from
## then on it is ground: the spider cannot climb a wall, but it can walk on a web
## that is on one. Only its middle stops it; its rim passes through things, or a
## web thrown along a floor would stick to the floor the moment it left.
##
## Ridden to the end of its reach without finding anything, or onto slick metal, it
## stops dead and comes apart, and the rider drops where it is with none of its
## speed: a ride only goes somewhere if the web lands on something.
##
## A web on something that moves goes with it. A web on a slick surface does not
## stick at all — it slides off and comes apart, and the silk is the spider's
## again. Thrown at nothing, it goes as far as silk goes and comes apart there.
##
## The Pullback calls it home: it comes off whatever it was on and flies straight
## back to the spider through anything in the way, and anything it was stuck to
## — a crate — comes with it and is put down at the spider's feet.
##
## The web's face is its local XY plane, and its local +Z is the side facing
## back the way it came, and, once it is stuck, the side facing out from the
## surface.

## It stopped somewhere and is ground now.
signal stuck(web: ThrownWeb)

## It is no longer the spider's to stand on: it came apart, slid off, or came
## home. Its silk is free to throw again from this moment.
signal gone(web: ThrownWeb)

## Called home and arrived, with what it carried, if anything.
signal came_back(web: ThrownWeb, carried: Node3D)

enum State {
	FLYING,     ## thrown, and on its way
	STUCK,      ## stopped on something, and walkable
	RETURNING,  ## called back by the Pullback
	GONE,       ## coming apart; nothing to stand on
}

const GROUP := "thrown_webs"

## How thick the slab the spider walks on is, in metres.
const THICKNESS := 0.06

## How far off the surface a stuck web sits.
const CLEARANCE := 0.035

## How long a web takes to open out to its full size after it leaves the spider.
const UNFURL := 0.16

## How fast a web called back comes home, in metres a second.
const RETURN_SPEED := 44.0
## How long coming apart takes.
const FADE := 0.35

## What a web looks like: an orb web's spokes and spiral.
const PATTERN := preload("res://flies/web/orb_web.tres")

var state := State.FLYING

## How wide it is, from the middle to the rim, in metres.
var radius := 1.5

## How fast it is going, while it flies or comes home.
var velocity := Vector3.ZERO

## How much further it will fly before it comes apart.
var range_left := 36.0


## The spider that threw it.
var weaver: Node3D

## Whatever it is stuck to that it will bring home with it: a crate.
var carried: Node3D = null

## Whether it is stuck to a loose board, which holds silk but not the spider.
var loose := false

## Whether it ran out of reach, or slid off slick, with the spider riding it, and
## stopped dead first: its rider is left where it was, with none of its speed.
var stalled := false

## Changes whenever the web's face turns under the spider — it stuck at an angle to
## the way it was flying — so the spider riding it knows to find its footing again.
var turned := 0


var _age := 0.0
var _fade := 0.0
var _exclude: Array[RID] = []
var _walk: StaticBody3D
var _walk_shape: CylinderShape3D
var _look: Node3D
var _material: StandardMaterial3D
var _veil_material: StandardMaterial3D
var _carry_offset := Transform3D.IDENTITY
var _home_root: Node
var _spin := 0.0


## A web of [param web_radius] thrown from [param from] along [param heading] at
## [param speed], for [param reach] metres, by [param thrower], into
## [param container].
static func throw(container: Node, thrower: Node3D, from: Vector3, heading: Vector3,
		speed: float, web_radius: float, reach: float) -> ThrownWeb:
	var web := ThrownWeb.new()
	web.name = "Web"
	web.weaver = thrower
	web.radius = web_radius
	web.range_left = reach
	web.velocity = heading.normalized() * speed
	var thrower_body := thrower as CollisionObject3D
	if thrower_body != null:
		web._exclude.append(thrower_body.get_rid())
	container.add_child(web, true)
	web._home_root = container
	web.global_transform = Transform3D(_facing(-heading.normalized()), from)
	return web


func _ready() -> void:
	add_to_group(GROUP)
	_build()


## Which way its face points: the side the spider stands on.
func normal() -> Vector3:
	return global_basis.z.normalized()


## Whether there is anything to stand on.
func is_standing() -> bool:
	return state == State.FLYING or state == State.STUCK


func is_flying() -> bool:
	return state == State.FLYING


func is_stuck() -> bool:
	return state == State.STUCK


## Whether the spider can be on it: stuck, and not to a loose board.
func holds_weight() -> bool:
	return state == State.STUCK and not loose


## How big it is right now: it opens out over its first moment in the air.
func current_radius() -> float:
	return radius * clampf(_age / UNFURL, 0.15, 1.0)


## The body the spider's feet and the crosshair find it by.
func walk_body() -> StaticBody3D:
	return _walk


## Comes off whatever it is on and flies home to [param to]. False if it is not
## something that can come back.
func call_back(to: Node3D) -> bool:
	if not is_standing() or to == null:
		return false
	weaver = to
	# What it is on feels the pull: a loose board is ripped away, a block on a rail
	# slides to the other end of it.
	var panel := get_parent() as LoosePanel
	var block := get_parent() as SlideBlock
	state = State.RETURNING
	gone.emit(self)
	_walk.collision_layer = 0
	var where := global_transform
	if get_parent() != _home_root and _home_root != null and is_instance_valid(_home_root):
		reparent(_home_root, true)
	global_transform = where
	if panel != null:
		panel.rip(to.global_position)
	if block != null:
		block.pull()
	if carried != null and is_instance_valid(carried):
		_carry_offset = global_transform.affine_inverse() * carried.global_transform
		var crate := carried as RigidBody3D
		if crate != null:
			crate.freeze = true
	velocity = Vector3.ZERO
	return true


func _physics_process(delta: float) -> void:
	_age += delta
	match state:
		State.FLYING:
			_fly(delta)
		State.RETURNING:
			_come_home(delta)
		State.GONE:
			_fade += delta
			var left := 1.0 - _fade / FADE
			_material.albedo_color.a = clampf(left, 0.0, 1.0)
			_veil_material.albedo_color.a = 0.07 * clampf(left, 0.0, 1.0)
			_look.scale = Vector3.ONE * (1.0 + (1.0 - left) * 0.25)
			if _fade >= FADE:
				queue_free()
	if state != State.GONE:
		var opened := current_radius()
		_look.scale = Vector3.ONE * (opened / radius)
		if not is_equal_approx(_walk_shape.radius, opened):
			_walk_shape.radius = opened


func _process(delta: float) -> void:
	# A slow turn in flight, so a web in the air reads as thrown rather than slid.
	if state == State.FLYING or state == State.RETURNING:
		_spin += delta * 5.0
		_look.rotation.z = _spin


# --- flying -------------------------------------------------------------

func _fly(delta: float) -> void:
	var step := velocity * delta
	var distance := step.length()
	if distance < 0.00001:
		return
	var from := global_position
	var hit := _first_hit(from, step)
	var cut := SilkCutter.crossing(get_world_3d().direct_space_state, from, from + step)
	if not cut.is_empty() and (hit.is_empty()
			or from.distance_to(cut["position"]) < from.distance_to(hit["position"])):
		_cut(cut["position"])
		return
	if not hit.is_empty():
		_land(hit)
		return
	global_position = from + step
	range_left -= distance
	if range_left <= 0.0:
		# Out of silk with nothing found. Ridden, it stops dead before it comes apart,
		# so the rider drops where it is with none of the web's speed: a ride only
		# goes somewhere if the web lands on something.
		stalled = _ridden()
		velocity = Vector3.ZERO
		_come_apart()


## Flown into a silk cutter: it comes apart there. Ridden, it stops dead first, and
## the rider drops where it was cut.
func _cut(at: Vector3) -> void:
	global_position = at
	stalled = _ridden()
	velocity = Vector3.ZERO
	if weaver != null and weaver.has_method("notify"):
		weaver.call("notify", "Cut — silk can't cross that")
	_come_apart()


func _ridden() -> bool:
	return weaver != null and weaver.has_method("standing_web") \
		and weaver.call("standing_web") == self


## What the web's middle meets this frame, if anything: a ray down its middle, so
## it sticks exactly where the cross was. Anything fatter catches the wall early on
## a throw along it — which is every throw up a wall from a web on it.
func _first_hit(from: Vector3, step: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, from + step, GameLayers.WORLD, _exclude)
	return space.intersect_ray(ray)




func _land(hit: Dictionary) -> void:
	var collider := hit.get("collider") as Node
	var at: Vector3 = hit.get("position", global_position)
	var surface: Vector3 = (hit.get("normal", -velocity.normalized()) as Vector3).normalized()
	if collider != null and Surfaces.is_slick(collider):
		# Nothing sticks to it. The web slides off and comes apart — under a rider,
		# stopping dead first, the same as at the end of its reach.
		global_position = at + surface * CLEARANCE
		stalled = _ridden()
		velocity = Vector3.ZERO
		if weaver != null and weaver.has_method("notify"):
			weaver.call("notify", "Slick — silk won't stick there")
		_come_apart()
		return
	var before := normal()
	global_transform = Transform3D(_facing(surface, global_basis.x), at + surface * CLEARANCE)
	if before.dot(surface) < 0.999:
		turned += 1
	velocity = Vector3.ZERO
	state = State.STUCK
	var body := collider as Node3D
	if body != null and (body is AnimatableBody3D or body is RigidBody3D
			or body is LoosePanel):
		# Goes with what it is on: a platform carries it, a crate is carried with it,
		# a loose board takes it when it goes.
		reparent(body, true)
		if body.is_in_group("crate"):
			carried = body
		loose = body is LoosePanel
	stuck.emit(self)


# --- coming home --------------------------------------------------------

func _come_home(delta: float) -> void:
	if weaver == null or not is_instance_valid(weaver):
		_come_apart()
		return
	var goal := weaver.global_position
	var to := goal - global_position
	var step := RETURN_SPEED * delta
	var from := global_position
	if to.length() <= step + 0.9:
		_arrive()
		return
	velocity = to.normalized() * RETURN_SPEED
	global_position = from + to.normalized() * step
	# Face first, the way it flies.
	global_basis = _facing(-to.normalized(), global_basis.x)
	_carry()


func _carry() -> void:
	if carried != null and is_instance_valid(carried):
		carried.global_transform = global_transform * _carry_offset
		carried.global_basis = carried.global_basis.orthonormalized()


## Home. Whatever it brought is put down just in front of the spider, at its feet.
func _arrive() -> void:
	var brought := carried
	if brought != null and is_instance_valid(brought):
		var ahead := -weaver.global_basis.z
		ahead.y = 0.0
		if ahead.length_squared() < 0.0001:
			ahead = Vector3.FORWARD
		var drop := weaver.global_position + ahead.normalized() * 1.1 + Vector3.UP * 0.35
		brought.global_transform = Transform3D(Basis(Vector3.UP, brought.rotation.y), drop)
		var crate := brought as RigidBody3D
		if crate != null:
			crate.freeze = false
			crate.linear_velocity = Vector3.ZERO
			crate.angular_velocity = Vector3.ZERO
	carried = null
	came_back.emit(self, brought)
	queue_free()


## Used up — on a board ripped away — it comes apart where it is, and its silk is
## the spider's again.
func spend() -> void:
	_come_apart()


## Comes apart where it is: nothing to stand on any more, and the silk is the
## spider's again at once.
func _come_apart() -> void:
	if state == State.GONE:
		return
	var was := state
	state = State.GONE
	_walk.collision_layer = 0
	if carried != null and is_instance_valid(carried):
		var crate := carried as RigidBody3D
		if crate != null:
			crate.freeze = false
	carried = null
	if was != State.RETURNING:
		gone.emit(self)


# --- building -------------------------------------------------------------

## A basis whose +Z is [param face], keeping [param across] as its X where it can.
static func _facing(face: Vector3, across := Vector3.ZERO) -> Basis:
	var z := face.normalized()
	var x := across - z * across.dot(z)
	if x.length_squared() < 0.0001:
		var helper := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		x = helper.cross(z)
	x = x.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


func _build() -> void:
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)

	var rim := PackedVector3Array()
	for i in 18:
		var angle := TAU * float(i) / 18.0
		rim.append(Vector3(cos(angle), sin(angle), 0.0) * radius)
	var layout := WebGeometry.layout_net(rim, PATTERN, Vector3.ZERO, 1.0)
	var silk := MeshInstance3D.new()
	silk.name = "Silk"
	silk.mesh = WebGeometry.build_mesh(layout.strands, Color(0.94, 0.95, 1.0, 0.95),
		2.2 + radius * 0.6)
	_material = WebGeometry.silk_material()
	_material.emission_energy_multiplier = 0.55
	silk.material_override = _material
	silk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(silk)

	# A faint sheet behind the silk, so a web reads as somewhere to stand.
	var veil := MeshInstance3D.new()
	veil.name = "Veil"
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.005
	disc.radial_segments = 24
	disc.rings = 1
	veil.mesh = disc
	veil.rotation.x = PI * 0.5
	_veil_material = StandardMaterial3D.new()
	_veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_veil_material.albedo_color = Color(0.85, 0.9, 1.0, 0.07)
	_veil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil.material_override = _veil_material
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(veil)

	_walk = StaticBody3D.new()
	_walk.name = "Walk"
	_walk.collision_layer = GameLayers.WEB_WALK
	_walk.collision_mask = 0
	_walk_shape = CylinderShape3D.new()
	_walk_shape.radius = radius
	_walk_shape.height = THICKNESS
	var shape := CollisionShape3D.new()
	shape.shape = _walk_shape
	shape.rotation.x = PI * 0.5
	_walk.add_child(shape)
	add_child(_walk)


## The web a collider belongs to, if it is one.
static func of(collider: Variant) -> ThrownWeb:
	var node := collider as Node
	while node != null:
		if node is ThrownWeb:
			return node
		node = node.get_parent()
	return null
