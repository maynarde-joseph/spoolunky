class_name WebPull
extends Node3D

## A web on its way back to the spider, called in by the Pullback.
##
## It comes off its anchors and flies straight in, folding up as it comes, with
## whatever it was holding still in it. Everything loose it passes through on the
## way takes silk — as much as one shot of that web would put on it, so a strong
## web dragged through a weak thing takes it outright — and a web that lightning
## left live strikes what it passes through as well. When it reaches the spider it
## is gone, and what it held lands at the spider's feet, bundled: the same bargain
## as taking a web down by hand, from across the room.
##
## It hits on the way and does not catch: the web is [member WebStructure.called_back]
## while it flies, or one pull through a crowd would sweep up the lot.

## Reached the spider. [param took] is how many bundles it brought.
signal arrived(pull: WebPull, took: int)

const GROUP := "web_pulls"

## Close enough to the spider to count as there, in its body heights.
const ARRIVE := 0.8

## How small it folds as it comes, as a share of its own size, and how fast.
const FOLDED := 0.3
const FOLD_RATE := 2.5

## The web coming in.
var web: WebNet

## What it is coming to.
var spider: Node3D

## How fast it comes, in metres a second.
var speed := 20.0

## How far off its line it reaches things, in metres.
var sweep := 0.5

## How much of a shot's worth of silk it puts on what it passes through.
var share := 1.0

## How tall the spider is, for how close counts as arrived.
var body_height := 0.25

## Everything it has hit on the way, in order.
var hit: Array[Prey] = []

var _fold := 1.0


## Calls [param net] in to [param to] under [param host]. Null if there is no web.
static func call_in(host: Node, net: WebNet, to: Node3D, pace: float, reach: float,
		silk_share: float, height: float) -> WebPull:
	if host == null or net == null or not is_instance_valid(net) or to == null \
			or net.is_queued_for_deletion():
		return null
	var pull := WebPull.new()
	pull.name = "WebPull"
	pull.web = net
	pull.spider = to
	pull.speed = maxf(pace, 0.1)
	pull.sweep = maxf(reach, 0.01)
	pull.share = silk_share
	pull.body_height = maxf(height, 0.05)
	pull.add_to_group(GROUP)
	pull.add_to_group("spell_effects")
	host.add_child(pull)
	pull.global_position = net.signal_point()
	net.called_back = true
	return pull


func _physics_process(delta: float) -> void:
	if not is_instance_valid(web) or web.is_queued_for_deletion() \
			or not is_instance_valid(spider):
		queue_free()
		return
	var middle := web.signal_point()
	var to := _goal() - middle
	var step := speed * delta
	if to.length() <= step + body_height * ARRIVE:
		_arrive()
		return
	var move := to.normalized() * step
	# The web, and everything about it that says where it is: its node, which its
	# silk and its catches follow, and the anchors fire and lightning measure to.
	web.global_position += move
	for i in web.anchors.size():
		web.anchors[i] += move
	global_position = middle + move
	_fold = move_toward(_fold, FOLDED, FOLD_RATE * delta)
	if web.mesh_instance != null:
		web.mesh_instance.scale = Vector3.ONE * _fold
	_strike_along(middle, middle + move)


## Where it is making for: the spider's middle.
func _goal() -> Vector3:
	return spider.global_position


## Everything loose within [member sweep] of this frame's stretch takes its silk,
## once each.
func _strike_along(from: Vector3, to: Vector3) -> void:
	var charge := WebCharge.of(web)
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or not creature.is_loose() \
				or hit.has(creature):
			continue
		var near := Geometry3D.get_closest_point_to_segment(creature.global_position, from, to)
		if near.distance_to(creature.global_position) > sweep + creature.hit_radius():
			continue
		hit.append(creature)
		if charge != null:
			creature.shock(charge.stun, charge.harm)
		var wrapped := creature.bind(creature.bind_share(web.hold_strength()) * share)
		if wrapped:
			creature.bundle()
		SpellFlash.burst(get_parent(), creature.global_position, Color(0.9, 0.92, 1.0),
			creature.hit_radius() * 2.0, 0.25)


## Arrived: what it held comes down just short of the spider, on the side the web
## came in from — at its feet, not inside it, where the spider's own body would
## shove it away.
func _arrive() -> void:
	var toward := web.signal_point() - spider.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.000001:
		toward = Vector3.FORWARD
	var drop := spider.global_position + toward.normalized() * body_height * 1.2 \
		+ Vector3.UP * body_height * 0.3
	var took := web.collect(drop, body_height * 0.8)
	arrived.emit(self, took)
	queue_free()
