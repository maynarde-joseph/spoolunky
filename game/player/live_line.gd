class_name LiveLine
extends Node3D

## What silk does when it lands on something that is still alive.
##
## Left mouse has always meant one thing — *silk connects me to that* — and what
## happens next is read off the target rather than off a mode you are in. A wall
## is fixed, so the spider moves. A web off its anchors follows you home with
## whatever is in it. A wrapped catch is finished, so it comes to you. In every
## one of those the question of which end moves has an answer before the line
## lands.
##
## A creature still on its feet is the case with no answer: both ends can pull,
## and it is moving under its own power. This is where that case is decided, and
## there are two candidate answers in here at once because the only way to know
## which is the right one is to play them.
##
## [b]To switch between them:[/b] the [member move] property, below. It is an
## export, so it can be flipped on the Spider's `LiveLine` node in the Inspector
## without touching code — or changed here for the default.

## Said out loud to the player. The spider passes these through.
signal notice(text: String)

signal hitched(hitch: SilkHitch)
signal bailed(off: Node3D)

## What a click on something alive does.
##
## [b]HITCH[/b] ties it to the ground you are standing on: it keeps its legs, but
## only inside a radius, so a doorway or a web you already built becomes the
## thing that beats it. See [SilkHitch].
##
## [b]BAIL[/b] uses it as an anchor to throw yourself the other way. The only
## target in the game that pushes rather than pulls, and the answer to being
## chased by something faster than you.
##
## [b]NOTHING[/b] is the behaviour before either existed: the aim reads straight
## through the creature and the click grapples to whatever is behind it.
enum Move {
	HITCH,
	BAIL,
	NOTHING,
}

## ---------------------------------------------------------------------------
## THE SWITCH. Change this line (or the field on the Spider scene's LiveLine
## node) to try the other one.
## ---------------------------------------------------------------------------
@export var move: Move = Move.HITCH

## Seconds between uses. Both moves are strong against the thing that is hunting
## you, and neither is meant to be held down.
@export var cooldown := 2.5

## How much of silk's reach a hitch pays out, as the radius the creature is left
## with. A share rather than a number, so it grows with the spider like every
## other distance in the game.
@export_range(0.1, 1.0, 0.05) var hitch_span := 0.35

## How much silk a hitch is tied with, before the tier's quality scales it.
## Spent by what the creature can still thrash with, so anything you have already
## put silk on stays tied far longer. See [member SilkHitch.strength].
@export var hitch_hold := 30.0

## How hard a bail throws the spider, as a multiple of its own running speed.
@export var bail_push := 2.6

## How much of that is upward, as a share of the jump the tier already has.
##
## Flat, a bail skids you along the floor and into the next wall; this makes it an
## arc you can steer. A share of the jump rather than a number of body heights,
## which was the first cut and was wrong by a factor of five: body height is how
## *big* the spider is and jump velocity is how hard it can push, and at a
## spiderling's 0.25m the lift came out at 1.0m/s against a jump of 5.6 — a five
## centimetre hop, which read on screen as no lift at all.
##
## A whole jump's worth, because falling here runs at about three times the
## project's gravity: a full jump only clears half a metre, so anything less than
## all of it puts the top of the arc below the spider's own height and the bail
## looks like a shove along the floor.
@export_range(0.0, 1.5, 0.05) var bail_lift := 1.0

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
var _cooling := 0.0


func setup(spider: SpiderPlayer, growth: SpiderGrowth, view: SpiderCamera,
		climb: SpiderClimb, builder: WebBuilder) -> void:
	_spider = spider
	_growth = growth
	_view = view
	_climb = climb
	_builder = builder


func _physics_process(delta: float) -> void:
	if _cooling > 0.0:
		_cooling = maxf(0.0, _cooling - delta)


## The click, as far as live creatures are concerned. Returns whether it did
## anything — false means the click was not about a creature and the caller
## should carry on down its list.
func act() -> bool:
	if move == Move.NOTHING or _spider == null:
		return false
	var mark := aimed_creature()
	if mark == null:
		return false
	# The cooldown is checked inside each move rather than here, because each one
	# has preconditions of its own and a move that was not going to fire anyway
	# should not eat the click telling you to wait. A hitch in mid-air has nothing
	# to tie to; that click is an ordinary grapple, cooling or not.
	match move:
		Move.HITCH:
			return hitch(mark)
		Move.BAIL:
			return bail(mark)
		_:
			return false


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
		if mark.eaten or mark.wrapped or mark.is_stuck() or mark.is_bundled():
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
	if not _ready_to_go():
		return true

	var line := SilkHitch.tie(mark, _footing(), reach() * hitch_span,
		hitch_hold * _quality())
	if line == null:
		return false
	var level: Node = _spider.get_parent()
	if level == null:
		return false
	level.add_child(line)
	_cooling = cooldown
	hitched.emit(line)
	notice.emit("Hitched the %s — it is not leaving that spot" % mark.species)
	return true


## Throws the spider off it, the other way.
##
## Every other anchor pulls you in. This one pushes, which is the whole read: the
## thing chasing you is the thing you kick off. It costs the creature nothing —
## no silk lands on it — so what you have bought is distance, not safety, and
## the wasp is still coming.
func bail(mark: Prey) -> bool:
	if mark == null or _climb == null or _spider == null:
		return false
	if not _ready_to_go():
		return true
	var away := _spider.global_position - mark.global_position
	away.y = 0.0
	if away.length_squared() < 0.000001:
		away = -_view.aim_forward()
		away.y = 0.0
	if away.length_squared() < 0.000001:
		away = Vector3.FORWARD
	away = away.normalized()

	var thrown := away * _spider.speed * bail_push + Vector3.UP * _jump() * bail_lift
	_climb.fling(thrown)
	_cooling = cooldown
	bailed.emit(mark)
	notice.emit("Kicked off the %s" % mark.species)
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


## How far either move reaches. Silk's own reach, because there is exactly one
## answer to "how far can I put silk" in this game and a second one would make
## both unreadable.
func reach() -> float:
	if _builder == null:
		return _height() * 8.0
	return _builder.silk_reach()


func cooling() -> bool:
	return _cooling > 0.0


## Whether the move can go, and says why not if it cannot. Called once a move has
## decided it would otherwise have fired, so that the wait is reported only when
## the wait is genuinely the thing in the way.
func _ready_to_go() -> bool:
	if _cooling <= 0.0:
		return true
	notice.emit("Still spinning silk — %.1fs" % _cooling)
	return false


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


func _jump() -> float:
	return _growth.current_stage().jump_velocity if _growth != null else 4.5


func _quality() -> float:
	return _growth.current_stage().silk_quality if _growth != null else 1.0
