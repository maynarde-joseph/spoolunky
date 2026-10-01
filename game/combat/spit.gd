class_name Spit
extends Node3D

## A glob a creature throws at the spider: venom, acid, a pellet.
##
## It flies straight at where the spider was when it was thrown, so stepping out
## of its way is an answer. A web is the other: silk in the way stops it, which is
## what a web strung across a doorway is for when something on the far side spits.
## The world stops it too. Anything else it passes straight through.

## Seconds before a glob that hit nothing is gone.
const LIFE := 3.0

var attack: CreatureAttack
var thrower: Node3D
var velocity := Vector3.ZERO

var _life := LIFE
var _exclude: Array[RID] = []


## Throws one from [param from] at [param at], for [param move] — its speed, what it
## does and its colour — by [param by].
static func throw(parent: Node, from: Vector3, at: Vector3, move: CreatureAttack,
		by: CollisionObject3D) -> Spit:
	if parent == null or move == null:
		return null
	var spit := Spit.new()
	spit.name = "Spit"
	spit.attack = move
	spit.thrower = by
	var run := at - from
	spit.velocity = run.normalized() * move.speed if run.length_squared() > 0.000001 \
		else Vector3.FORWARD * move.speed
	if by != null:
		spit._exclude = [by.get_rid()]
	parent.add_child(spit)
	spit.global_position = from
	spit._build()
	return spit


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to,
		GameLayers.WORLD | GameLayers.PLAYER | GameLayers.WEB, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	var target := hit.get("collider") as Node
	if target != null and target.is_in_group("spider"):
		_land(target)
	queue_free()


func _land(spider: Node) -> void:
	if spider.has_method("take_bite") and attack.damage > 0.0:
		spider.take_bite(attack.damage, thrower)
	if attack.knockback > 0.0 and spider.has_method("fling"):
		var flat := Vector3(velocity.x, 0.0, velocity.z).normalized()
		spider.fling(flat * attack.knockback + Vector3.UP * attack.knockback * 0.45)
	if attack.daze > 0.0 and spider.has_method("daze"):
		spider.daze(attack.daze)


func _build() -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	ball.radial_segments = 10
	ball.rings = 6
	var view := MeshInstance3D.new()
	view.mesh = ball
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = attack.tell_colour
	view.material_override = paint
	add_child(view)
