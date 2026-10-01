class_name LiveLine
extends Node3D

## What a click on something that is still on its feet does, if anything.
##
## Left mouse means *silk connects me to that*, and every other target answers
## "which end moves" before the line lands: a wall is fixed so the spider moves,
## a wrapped catch is finished so it comes to you, a web comes down with what is
## in it. A creature still standing is the one case where both ends can pull.
##
## It ships answering **nothing**, and that is a decision rather than a gap. A
## creature standing in front of a wall is a creature *and* a wall, so a click
## that reads the creature means one thing or the other depending on a couple of
## pixels — and the cost of that is not the move you did not get, it is that the
## grapple stops being trustworthy, and the grapple is how you get about.
##
## The hitch is here behind [member move] for when there is a way to be sure
## which you meant. It is a good mechanic sharing a bad button.

## Said out loud to the player. The spider passes these through.
signal notice(text: String)

signal hitched(hitch: SilkHitch)

## What a click on something alive does.
##
## [b]NOTHING[/b] — the default — is the plain reading: the aim goes straight
## through the creature and the click grapples to whatever is behind it, exactly
## as it does for a creature that is not there. One meaning for the button.
##
## [b]HITCH[/b] ties it to the ground you are standing on: it keeps its legs, but
## only inside a radius, so a doorway or a web you already built becomes the thing
## that beats it. See [SilkHitch]. It shares its click with the grapple, which is
## the unresolved part — a hitch you did not mean and a grapple you did not get
## are the same mis-click.
enum Move {
	NOTHING,
	HITCH,
}

## ---------------------------------------------------------------------------
## THE CLICK SWITCH. NOTHING or HITCH.
## ---------------------------------------------------------------------------
@export var move: Move = Move.NOTHING

## Seconds between hitches.
@export var hitch_cooldown := 2.5

## How much of silk's reach a hitch pays out, as the radius the creature is left
## with. A share rather than a number, so it grows with the spider like every
## other distance in the game.
@export_range(0.1, 1.0, 0.05) var hitch_span := 0.35

## How much silk a hitch is tied with, before the tier's quality scales it.
## Spent by what the creature can still thrash with, so anything you have already
## put silk on stays tied far longer. See [member SilkHitch.strength].
@export var hitch_hold := 30.0

## How far off the line of sight a creature can sit and still be what you meant,
## as a share of the distance to it. The same slice-of-the-screen rule the tether
## picks cargo with, and for the same reason: a creature is a small, deliberate
## target and a click that merely passed one is not a click at it.
@export_range(0.01, 0.2, 0.005) var aim_slice := 0.05

var _spider: SpiderPlayer
var _growth: SpiderGrowth
var _view: SpiderCamera
var _climb: SpiderClimb
var _builder: WebBuilder
var _hitch_cooling := 0.0


func setup(spider: SpiderPlayer, growth: SpiderGrowth, view: SpiderCamera,
		climb: SpiderClimb, builder: WebBuilder) -> void:
	_spider = spider
	_growth = growth
	_view = view
	_climb = climb
	_builder = builder


func _physics_process(delta: float) -> void:
	_hitch_cooling = maxf(0.0, _hitch_cooling - delta)


## The click, as far as live creatures are concerned. Returns whether it did
## anything — false means the click was not about a creature and the caller
## should carry on down its list.
func act() -> bool:
	if move == Move.NOTHING or _spider == null:
		return false
	var mark := aimed_creature()
	if mark == null:
		return false
	# The cooldown is checked inside the move rather than here, because it has
	# preconditions of its own and a move that was not going to fire anyway should
	# not eat the click telling you to wait. A hitch in mid-air has nothing to tie
	# to; that click is an ordinary grapple, cooling or not.
	return hitch(mark) if move == Move.HITCH else false


## Whether a click would be about a creature at all. What the crosshair is on,
## alive, and not already dealt with by something better — a catch in a web is
## the tether's, and it is asked first.
func aimed_creature() -> Prey:
	if _view == null or _spider == null:
		return null
	var origin := _view.aim_origin()
	var forward := _view.aim_forward()
	var limit := reach()
	var height := _height()

	var best: Prey = null
	var best_gap := INF
	for node in _spider.get_tree().get_nodes_in_group("prey"):
		var mark := node as Prey
		if mark == null or not is_instance_valid(mark):
			continue
		if mark.eaten or mark.wrapped or mark.is_stuck() or mark.is_bundled() or mark.is_dead():
			continue
		var offset := mark.global_position - origin
		var along := offset.dot(forward)
		if along <= 0.0 or along > limit:
			continue
		var gap := (offset - forward * along).length()
		var tolerance: float = clampf(along * aim_slice, height * 0.5, height * 2.0)
		if gap > tolerance or gap >= best_gap:
			continue
		best_gap = gap
		best = mark
	return best


## Ties it to the ground you are standing on.
##
## Needs ground: the anchor is the spider's own footing, so there has to be one.
## A line tied to nothing would haul the spider instead, and that is the tether,
## which already exists.
##
## Falling through quietly rather than refusing out loud is the point of
## returning false here: in mid-air the click goes on to be an ordinary grapple,
## which is what you wanted anyway if you are in the air aiming at something.
## A notice plus a grapple would say two contradictory things about one click.
func hitch(mark: Prey) -> bool:
	if mark == null or _climb == null or not _footed():
		return false
	if hitch_on(mark) != null:
		notice.emit("The %s is already on a line" % mark.species)
		return true
	if _hitch_cooling > 0.0:
		notice.emit("Still spinning silk — %.1fs" % _hitch_cooling)
		return true

	var line := SilkHitch.tie(mark, _footing(), reach() * hitch_span,
		hitch_hold * _quality())
	if line == null:
		return false
	var level: Node = _spider.get_parent()
	if level == null:
		return false
	level.add_child(line)
	_hitch_cooling = hitch_cooldown
	hitched.emit(line)
	notice.emit("Hitched the %s — it is not leaving that spot" % mark.species)
	return true


## The hitch already on something, if there is one.
func hitch_on(mark: Prey) -> SilkHitch:
	if mark == null or _spider == null:
		return null
	for node in _spider.get_tree().get_nodes_in_group("silk_hitches"):
		var hitch := node as SilkHitch
		if hitch != null and hitch.cargo == mark:
			return hitch
	return null


## How far a hitch reaches. Silk's own reach, because there is exactly one
## answer to "how far can I put silk" in this game and a second one would make
## both unreadable.
func reach() -> float:
	if _builder == null:
		return _height() * 8.0
	return _builder.silk_reach()


## Whether a hitch would be refused for having just been used.
func hitch_cooling() -> bool:
	return _hitch_cooling > 0.0


## Whether there is something under the spider worth tying a line to.
func _footed() -> bool:
	return _climb.is_attached() or _climb.is_hanging() or _climb.is_riding()


## Where the line is tied: the surface under the spider rather than its middle,
## so the anchor sits on the floor instead of floating at hip height.
func _footing() -> Vector3:
	var up := _climb.body_up() if _climb != null else Vector3.UP
	return _spider.global_position - up * _height() * 0.45


func _height() -> float:
	return _growth.current_stage().body_height if _growth != null else 0.35


func _quality() -> float:
	return _growth.current_stage().silk_quality if _growth != null else 1.0
