class_name BoatRing
extends Node3D

## Boats going round the lake.
##
## Every [AnimatableBody3D] under this node is a boat. They are spaced evenly round
## a circle of [member radius] about it and go round it at [member speed], each
## facing the way it is going and riding up and down a little on the water. They
## are the lake's ground that moves: the physics already knows how to carry
## something standing on a moving platform, so a spider in a boat goes round with
## it and nothing here has to help.
##
## Silk is the part that has to be told. A web is spun in the world where it is,
## and left alone it would hang there while its boat sailed off. So every step,
## silk is looked at against the boats: a web or a line whose every end is on one
## boat goes round with that boat, and one tied to a boat at one end and to
## anything else at the other — the jetty, the island, another boat — snaps,
## because nothing tied to both could do anything else. A line the spider is
## hanging from a boat by goes round with the boat too.

## How far out from the middle the boats go round, and how fast, in metres and
## metres a second along the way.
@export var radius := 88.0
@export var speed := 5.0

## How far a boat rides up and down on the water, and how far it rocks, in
## metres and degrees.
@export var bob := 0.25
@export var rock := 2.0

@export var clockwise := false

## How close to a boat an end of silk has to be to count as tied to it, in metres
## past the boat's own size.
@export var reach := 0.4

## Where the boats have got to: a turn from where they started, in radians.
@export var angle := 0.0

var _boats: Array[AnimatableBody3D] = []
var _hulls: Array[AABB] = []
var _clock := 0.0

## Where each boat was last put. A boat that moves in step with the physics says
## it is where it was until the step it moves in has run, so what it reports
## straight after being moved is where it was before — which is no use for
## working out how far the silk on it has to go. This is where it is going.
var _placed: Array[Transform3D] = []


func _ready() -> void:
	for child in get_children():
		var boat := child as AnimatableBody3D
		if boat != null:
			_boats.append(boat)
			_hulls.append(_hull_of(boat))
	for i in _boats.size():
		_placed.append(boat_transform(i))
		_boats[i].global_transform = _placed[i]


func _physics_process(delta: float) -> void:
	if _boats.is_empty():
		return
	var before := _placed.duplicate()
	_clock += delta
	angle = fposmod(angle + speed / maxf(radius, 0.001) * delta * _way(), TAU)
	for i in _boats.size():
		_placed[i] = boat_transform(i)
		_boats[i].global_transform = _placed[i]
	_carry_silk(before)


## The boats going round, in order.
func boats() -> Array[AnimatableBody3D]:
	return _boats.duplicate()


## Where boat [param index] is now: its place on the circle, bow first along it.
func boat_transform(index: int) -> Transform3D:
	var count := maxi(_boats.size(), 1)
	var turn := angle + TAU * float(index) / float(count)
	var out := Vector3(cos(turn), 0.0, sin(turn))
	var ahead := Vector3(-sin(turn), 0.0, cos(turn)) * _way()
	var facing := Basis.looking_at(ahead, Vector3.UP)
	var roll := sin(_clock * 0.9 + float(index) * 1.3) * deg_to_rad(rock)
	var rise := sin(_clock * 1.3 + float(index) * 1.7) * bob
	return Transform3D(facing * Basis(Vector3.BACK, roll),
		global_position + out * radius + Vector3.UP * rise)


## Which boat [param point] is on, going by where the boats were at [param at],
## or -1 for none.
func boat_under(point: Vector3, at: Array[Transform3D]) -> int:
	for i in mini(_boats.size(), at.size()):
		var local := at[i].affine_inverse() * point
		if _hulls[i].grow(reach).has_point(local):
			return i
	return -1


func _way() -> float:
	return -1.0 if clockwise else 1.0


## Moves what is tied to a boat along with it, and snaps what is tied between a
## boat and anything else.
func _carry_silk(before: Array[Transform3D]) -> void:
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null or web.is_queued_for_deletion() or web.anchors.is_empty():
			continue
		var on := -1
		var mixed := false
		for i in web.anchors.size():
			var boat := boat_under(web.anchors[i], before)
			if i == 0:
				on = boat
			elif boat != on:
				mixed = true
				break
		if mixed:
			web.tear()
		elif on >= 0:
			_carry(web, _placed[on] * before[on].affine_inverse())

	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if spider != null and spider.climb != null and spider.climb.is_hanging():
		var boat := boat_under(spider.climb.line_anchor, before)
		if boat >= 0:
			spider.climb.line_anchor = _placed[boat] * before[boat].affine_inverse() \
				* spider.climb.line_anchor


## Takes [param web] along by [param moved]: where it hangs, and every point it
## keeps in the world.
func _carry(web: WebStructure, moved: Transform3D) -> void:
	web.global_transform = moved * web.global_transform
	for i in web.anchors.size():
		web.anchors[i] = moved * web.anchors[i]
	var strand := web as WebStrand
	if strand != null:
		strand.point_a = moved * strand.point_a
		strand.point_b = moved * strand.point_b


## The room a boat takes up in its own space: everything it draws, boxed.
func _hull_of(boat: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in _every(boat):
		var view := node as MeshInstance3D
		if view == null or view.mesh == null:
			continue
		var part := (boat.global_transform.affine_inverse() * view.global_transform) \
			* view.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _every(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_every(child))
	return found
