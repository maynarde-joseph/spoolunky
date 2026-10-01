class_name Checkpoints
extends Node

## The Hollows' memory of you: which shrine you lit last, and what happens when
## you are driven off.
##
## Driven off, you wake at the last [Shrine] you lit, whole and with nothing in
## your hands, and everything you put down is back on its feet — the bargain a
## souls-like makes, and one a hunting ground does not. Resting at a shrine
## strikes the same bargain on purpose: whole again, and so is everything else.
##
## Bosses are the exception both ways: one you have beaten stays beaten, and one
## that beat you is back at its post as though you never came. See
## [HostileSpawn]. Silk you put up stays where it is — it is the one thing you
## keep, and what makes scouting a lair worth the trip.

## You woke at [param shrine].
signal woke(shrine: Shrine)

## You rested at [param shrine].
signal rested(shrine: Shrine)

## Seconds between being driven off and waking: long enough to see it happen.
@export var wake_after := 1.4

## The shrine you wake at.
var shrine: Shrine = null

var _spider: SpiderPlayer = null
var _waking := 0.0


static func of(node: Node) -> Checkpoints:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("checkpoints") as Checkpoints


func _ready() -> void:
	add_to_group("checkpoints")
	_meet.call_deferred()


## Finds the spider and the shrines once everything is in the tree. The first lit
## shrine is where you wake until you light another.
func _meet() -> void:
	_spider = get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if _spider != null and not _spider.routed.is_connected(_on_routed):
		_spider.routed.connect(_on_routed)
	for node in get_tree().get_nodes_in_group("shrines"):
		watch(node as Shrine)


## Takes [param new_shrine] into account: lighting it makes it where you wake.
func watch(new_shrine: Shrine) -> void:
	if new_shrine == null:
		return
	if not new_shrine.kindled.is_connected(_on_kindled):
		new_shrine.kindled.connect(_on_kindled)
	if shrine == null and new_shrine.lit:
		shrine = new_shrine


func _process(delta: float) -> void:
	if _waking <= 0.0:
		return
	_waking -= delta
	if _waking <= 0.0:
		wake()


func _on_kindled(lit_shrine: Shrine) -> void:
	shrine = lit_shrine


func _on_routed() -> void:
	if _waking <= 0.0:
		_waking = wake_after


## Whether you are waiting to wake.
func is_waking() -> bool:
	return _waking > 0.0


## Wakes the spider at the last shrine it lit, and stirs everything else.
func wake() -> void:
	_waking = 0.0
	if _spider == null or shrine == null:
		return
	_spider.wake_at(shrine.wake_transform())
	stir()
	_spider.notice.emit("You wake at the %s" % shrine.display_name)
	woke.emit(shrine)


## Rests at [param at]: whole again, it is where you wake, and everything you put
## down is back where it stood. Not with something coming for you.
func rest_at(at: Shrine) -> bool:
	if _spider == null or at == null:
		return false
	if _hunted():
		_spider.notice.emit("You cannot rest with something coming for you")
		return false
	shrine = at
	_spider.vitals.fill()
	stir()
	_spider.notice.emit("You rest at the %s — and the Hollows stir" % at.display_name)
	rested.emit(at)
	return true


## Everything hostile back where it stood, and every lair as it was.
func stir() -> void:
	for node in get_tree().get_nodes_in_group("hostile_spawns"):
		(node as HostileSpawn).reset()
	for node in get_tree().get_nodes_in_group("boss_lairs"):
		if node.has_method("reset"):
			node.reset()


func _hunted() -> bool:
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and creature.is_hostile() and creature.is_hunting():
			return true
	return false
