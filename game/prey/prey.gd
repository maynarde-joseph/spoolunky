class_name Prey
extends CharacterBody3D

## Something worth eating.
##
## Prey wanders a patch of the world, gets stuck in webs, struggles hard enough
## to tear them, and can be wrapped and drained by the spider. What kind of
## creature it is comes from a [PreySpecies] resource, so one scene and one
## script serve every creature in the game and a new one is a .tres.
##
## The species is copied into plain fields when it is applied rather than read
## through, so a level — or a test — can make one unusual individual without
## authoring a whole species for it.

signal snared(prey: Prey)
signal broke_free(prey: Prey)
signal eaten_by_spider(prey: Prey)

enum State {
	WANDER,    ## going about its business
	HUNTING,   ## coming for a spider it outclasses
	STUCK,     ## caught in silk, fighting it
	WRAPPED,   ## bundled up, going nowhere
	FLEEING,   ## just tore loose, getting out
	BUNDLED,   ## wrapped where it stood and dropped, out of any web
}

## How much better than a catch's total thrash a web has to be to keep it.
## Tuned so each web tier holds the prey tier below it: a sheet web keeps a
## fly, an orb web keeps a moth, a pressure snare keeps a wasp — and silk
## quality, which climbs with size, moves every one of those lines up.
const ESCAPE_MARGIN := 6.0

## How much binding a creature works off per second while it is loose.
##
## Without this you could chip anything down over an afternoon of pot shots from
## safety, which is the opposite of the point: a big catch should be a burst of
## commitment. But it has to lose to the shot cooldown or the mechanic cannot
## work at all, and that is a tighter constraint than it looks.
##
## A shot is [member WebBuilder.shot_cooldown] seconds apart — 3.5 as it stands —
## and one orb web hit is worth about 46% of a wasp. At 0.12 a second the wait
## costs 42% of that back, so each shot netted four points and nothing was ever
## catchable. At 0.025 the wait costs about a fifth of a hit, two hits carry you
## past what an orb web needs, and one hit's worth is gone in eighteen seconds if
## you walk away. `_test_silk_outlasts_the_wait` pins that against both numbers,
## because they live in different files and neither one looks like it owns this.
const BIND_SHRUG := 0.025

## How much binding venom works in per second while it lasts.
##
## Deliberately slower than shooting. A bolt lands about half a wasp at once on a
## three and a half second wait, which is roughly 0.13 a second; this nets 0.055
## after the shrug, so silk thrown from across the room stays the efficient way to
## soften something and a dose is what works on it while you are elsewhere.
##
## Venom Spit is what hands a dose out. See [method poison].
const VENOM_BIND := 0.08

## How much harder a fanged dose works than a plain one: Venom Spit from a spider
## with Hunting Fangs.
const FANG_VENOM := 2.2

## Slowest a creature gets from silk alone, as a share of its own speed. Wrapped
## all the way it is a bundle and not going anywhere regardless; short of that it
## always has something left.
const CRAWL := 0.15

## How long a hunter has in it before it breaks off, in seconds.
##
## Hunters move at [constant CHASE_DASH] times their own speed, which is faster
## than any spider that is small enough to be worth hunting. That is on purpose —
## something that has decided to attack you should read as having decided — but
## with nothing else on it, it means a hunt you cannot end by running, only by
## dealing with the thing or by outgrowing it. Giving up was distance-only
## (`hunt_range * 1.8`), which is a distance a creature faster than you never lets
## you reach, so the only real out was silk.
##
## Silk should stay the *good* answer, not the only one. So a hunt is a thing that
## runs out: it sprints, it tires, and then it breaks off and leaves you alone for
## a while. Running away buys you the last stretch of it, not safety.
const CHASE_STAMINA := 7.0

## How much faster than its own speed a hunter moves while it still has a sprint.
const CHASE_DASH := 1.5

## What is left of the sprint over the last stretch, as a share of its speed.
##
## Deliberately below any spider's pace: this is the window, and it has to be
## visible from behind. Something still gaining on you until the instant it turns
## around reads as a bug, however honest the timer underneath is.
const CHASE_SPENT := 0.45

## The share of [constant CHASE_STAMINA] spent at the full sprint. The rest is
## the wind-down at [constant CHASE_SPENT].
const CHASE_SECOND_WIND := 0.6

## How long a hunter that has broken off leaves you alone before it will come
## again. Without this it re-acquires on the next look, 0.9 seconds later, and
## breaking off means nothing.
const CHASE_COOLDOWN := 6.0

## How long a creature ignores the spider after it appears.
##
## Something that spawns already locked on gives you nothing to react to — the
## first you know of it is being bitten. A moment of it minding its own business
## is the difference between an ambush you walked into and one that was posted to
## you.
const SETTLE_IN := 2.5

## How much bigger the hitbox is than the body it stands for. A shade over one,
## so a shot that clips the edge of what you can see still counts — and no more
## than that, because the hitbox is what a bolt has to touch.
const HITBOX_SCALE := 1.15

## The one scene every creature is built from.
const SCENE_PATH := "res://game/prey/prey.tscn"


## What this is. Applied on the way into the tree, or by whatever spawned it.
@export var kind: PreySpecies

## Shown in HUD messages.
var species := "Fly"

## Biomass left in it. Draining takes this down rather than taking it all at
## once, so a meal interrupted is a meal half eaten and the rest is still on the
## end of your line.
var biomass := 8.0

## What it held when it was whole, for the readout — "half a wasp" only means
## something against a whole one.
var full_biomass := 8.0

## How big it is, against a web's mesh and the spider's bite power. 1 is
## fly-sized.
var size_class := 1

## How hard it fights a web. Tears silk and eventually pulls free.
var struggle_power := 1.0

## How long it fights for before it tires out. A catch is won or lost inside
## this window: if the web out-holds the whole thrash, it is still there when
## you come back, which is the only reason leaving a web is a plan and not a
## way to lose one.
var struggle_stamina := 5.0

## How hard a tired catch keeps pulling. Small on purpose — it means a full
## larder is a web slowly wearing out rather than a free store, without ever
## putting you on a stopwatch.
var settled_drain := 0.015

var move_speed := 1.6

## Flying prey ignores gravity and drifts; walking prey falls.
var flying := true

## Whether its flying is swimming: it goes nowhere above the top of the water it
## is in. See [member PreySpecies.swims].
var swims := false

## How far from its spawn point it will wander.
var wander_radius := 6.0

## Low and high limits above the spawn point, for fliers.
var wander_height := Vector2(0.3, 2.6)

## Seconds before it picks somewhere new to be, even if it hasn't arrived.
var wander_interval := 3.0

## How strongly it drifts toward a funnel lure it can smell.
var lure_susceptibility := 0.8

## Whether it comes for a spider it outclasses, and what that costs when it gets
## there. See [member PreySpecies.aggression] for the rule.
var aggression := 0.0
var hunt_range := 6.0
var bite_damage := 3.0
var bite_interval := 1.1


## How much silk is on it, 0 to 1. Saps what it can thrash with, so the way to
## take something a web could never hold is to put silk on it first — a shot that
## cannot wrap it outright still costs it some of its fight.
##
## At 1 it is bundled. Wrapping used to be all or nothing, which made a thrown web
## either a guaranteed catch or nothing at all, and left no move between the two.
var bound := 0.0

var wrapped := false
var eaten := false

## Killed by venom: drainable no matter how big it is.
var subdued := false

var _state: State = State.WANDER
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wander_timer := 0.0
var _web: WebStructure = null
var _stuck_point := Vector3.ZERO

## Where in the web it is caught, in the web's own space. Kept so a catch travels
## with its web instead of being held to the patch of air the web used to occupy —
## which is what lets a web be reeled in with its catches still in it.
var _hold_offset := Vector3.ZERO

## Seconds of venom still working through it, and how hard. Not the same thing as
## [member subdued], which is the instant kill a venom spur does — this is a slow
## drip that binds the creature from the inside while it runs.
var venom := 0.0
var venom_strength := 1.0
var _struggle := 0.0
var _fight_left := 0.0
var _snap_timer := 0.0
var _flee_timer := 0.0
var _recatch_cooldown := 0.0
var _marked_timer := 0.0
var _lure_timer := 0.0
var _hunt_timer := 0.0
var _chase_left := 0.0
var _chase_rest := 0.0
var _bite_timer := 0.0
var _quarry: Node3D = null
var _life := 0.0
var _marker: MeshInstance3D
var _cocoon: MeshInstance3D
var _wings: Array[Node3D] = []
var _applied := false
var _tow_pull := Vector3.ZERO

## The top of the water a swimmer is in, as high as its middle may go: its own
## body's depth under the surface, so none of it breaks the top. INF for anything
## that does not swim, and for a swimmer that was put down out of the water.
var _surface := INF
var _surface_found := false

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


## Builds one of a species, ready to be dropped into the world.
static func of(species: PreySpecies) -> Prey:
	# Loaded rather than preloaded: the scene this makes carries this very
	# script, and a preload of it from in here is a cycle.
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null or species == null:
		return null
	var prey := scene.instantiate() as Prey
	if prey == null:
		return null
	prey.apply_species(species)
	return prey


## Takes on a species: its numbers, its name and its body. Safe before the
## node is in the tree, which is where the spawner does it.
func apply_species(from: PreySpecies) -> void:
	if from == null:
		return
	kind = from
	name = from.display_name.replace(" ", "")
	species = from.display_name
	biomass = from.biomass
	full_biomass = from.biomass
	size_class = from.size_class
	struggle_power = from.struggle_power
	struggle_stamina = from.struggle_stamina
	settled_drain = from.settled_drain
	move_speed = from.move_speed
	flying = from.flying
	swims = from.swims
	_surface_found = false
	wander_radius = from.wander_radius
	wander_height = from.wander_height
	wander_interval = from.wander_interval
	lure_susceptibility = from.lure_susceptibility
	aggression = from.aggression
	hunt_range = from.hunt_range
	bite_damage = from.bite_damage
	bite_interval = from.bite_interval
	_applied = true
	if is_inside_tree():
		_build_body()


func _ready() -> void:
	add_to_group("prey")
	collision_layer = GameLayers.PREY
	collision_mask = GameLayers.WORLD
	if kind != null and not _applied:
		apply_species(kind)
	_build_body()
	_home = global_position
	_pick_target()


func _physics_process(delta: float) -> void:
	_life += delta
	if _recatch_cooldown > 0.0:
		_recatch_cooldown -= delta
	if _marked_timer > 0.0:
		_marked_timer -= delta
		if _marked_timer <= 0.0:
			_set_marked(false)
	_flap()

	if _bite_timer > 0.0:
		_bite_timer -= delta
	if _chase_rest > 0.0:
		_chase_rest -= delta
	# Venom first, so a creature working off silk while venom puts it back on ends
	# the frame wherever the two of them leave it.
	if venom > 0.0 and not eaten and _state != State.BUNDLED:
		venom = maxf(0.0, venom - delta)
		bind(VENOM_BIND * venom_strength * delta)
	# Only while loose. Silk on something a web is holding is not going anywhere,
	# and neither is the creature.
	if bound > 0.0 and not is_stuck() and _state != State.BUNDLED:
		bound = maxf(0.0, bound - BIND_SHRUG * delta)
		_show_binding()

	match _state:
		State.BUNDLED:
			_fall(delta)
		State.HUNTING:
			_process_hunt(delta)
		State.STUCK, State.WRAPPED:
			_process_stuck(delta)
		State.FLEEING:
			_flee_timer -= delta
			if _flee_timer <= 0.0:
				_state = State.WANDER
				_pick_target()
			_steer(delta, current_speed() * 1.8)
		_:
			_process_wander(delta)


# --- being prey ---------------------------------------------------------

## Webs ask before catching, so prey that just tore loose gets a moment — and
## so that anything already caught is not caught again. Bundles matter here:
## one dropped inside the web that made it sits in that web's catch volume,
## and without this the web grabs it back on the next frame and pins it in
## mid-air instead of letting it fall.
func can_be_snared() -> bool:
	if eaten or wrapped or _state == State.STUCK:
		return false
	return _recatch_cooldown <= 0.0


## Called by a web that has caught this. [param snap_time] is the rigid hold
## from a sprung pressure snare.
func on_snared(web: WebStructure, point: Vector3, snap_time: float) -> void:
	_web = web
	_stuck_point = point
	_hold_offset = web.to_local(point) if is_instance_valid(web) else Vector3.ZERO
	_snap_timer = snap_time
	_struggle = 0.0
	_fight_left = struggle_stamina
	_state = State.STUCK
	# Whatever it was coming for, it is not coming for it now. This is the whole
	# reason a web is somewhere to stand and eat: something that meant to reach
	# you goes into the silk first, and even a web too weak to keep it has bought
	# you the seconds it spends tearing out — and paid for them in durability.
	_quarry = null
	velocity = Vector3.ZERO
	_set_marked(false)
	snared.emit(self)


## Called when the web holding this is destroyed.
func on_freed(_web_that_tore: WebStructure) -> void:
	if _state != State.STUCK:
		return
	_release_into_flight()


## Called by an alert web (tripline) that this walked through.
func on_tripped(_web: WebStructure, mark_time: float) -> void:
	_marked_timer = maxf(_marked_timer, mark_time)
	_set_marked(true)


## The web holding it, if one is. What the tether asks so that drinking something
## off a web on your line works at any length, the way drinking the creature
## itself already does.
func held_by() -> WebStructure:
	return _web if is_instance_valid(_web) else null


func is_stuck() -> bool:
	return _state == State.STUCK or _state == State.WRAPPED


## Wrapped and on the floor, out of any web. Something a thrown web took
## cleanly, waiting to be collected.
func is_bundled() -> bool:
	return _state == State.BUNDLED


## How fast it can still move, after the silk already on it.
##
## The same factor the fight uses, deliberately: silk on you costs you legs as
## well as struggle, and one number meaning one thing is easier to reason about
## than two that have to be kept in step.
##
## This is what makes softening something worth doing before you chase it. A
## fleeing wasp runs at 4.7 and the ladder tops out at 4.8, so without it nothing
## the player does ever makes a fast thing catchable — half-bound, that same wasp
## comes down to 2.3, which a spiderling can walk after.
##
## Never quite zero. Something pinned still where it stands but not yet wrapped is
## the pin mechanic arriving by the back door, and this is not that: it crawls.
func current_speed() -> float:
	return move_speed * maxf(1.0 - clampf(bound, 0.0, 1.0), CRAWL)


## What it can thrash with right now, after the silk already on it.
func thrash_power() -> float:
	return struggle_power * (1.0 - clampf(bound, 0.0, 1.0))


## Everything it will throw at a web before it tires itself out: the number a
## web has to beat to keep hold of it. Falls as it is bound.
func total_thrash() -> float:
	return thrash_power() * struggle_stamina


## Whether silk of this strength takes it outright, rather than leaving it hanging
## there fighting.
##
## The rule a web uses to decide whether a catch stays put at all, so it is the
## same one for a web left standing, a web thrown over something, and a bolt that
## hits it square. Those three used to disagree: the bolt wrapped anything it
## touched, which let a spiderling take a wasp in one shot and made the other two
## paths pointless.
func taken_cleanly_by(hold: float) -> bool:
	return total_thrash() <= hold * ESCAPE_MARGIN


## How much of the way towards being wrapped one hit of this silk gets you.
##
## Deliberately derived rather than tuned: it is the same two numbers that decide
## a clean take, so "how many shots does this need" answers itself and there is no
## third figure to keep in step. A wasp needs two softening hits before an orb web
## can take it, and five before a sheet web can.
func bind_share(hold: float) -> float:
	var whole := struggle_power * struggle_stamina
	if whole <= 0.0:
		return 1.0
	return clampf(hold * ESCAPE_MARGIN / whole, 0.0, 1.0)


## Dosed. Venom works silk into it from the inside for [param seconds].
##
## It does not stack: a second dose sets the clock to whichever is longer rather
## than running two at once. Stacking would make the answer to everything "dose it
## again", and a drip that stacks outruns the bolt it is meant to sit behind.
##
## Venom Spit is what calls it now. It was the lunge's once, and the lunge was
## cut for being a second way to spend [member bound] on an animal whose only
## offensive verb was meant to be wrapping; the machinery was kept, tuned and
## tested because "a dose that softens something over the next several seconds"
## was a shape a thrown spell would want, and one did. A venom spur does not use
## it — that is [method envenom], an outright kill, and a different thing.
func poison(seconds: float, strength := 1.0) -> bool:
	if eaten or _state == State.BUNDLED or seconds <= 0.0:
		return false
	venom = maxf(venom, seconds)
	venom_strength = maxf(venom_strength, strength) if venom > 0.0 else strength
	return true


## Whether venom is still working through it.
func is_poisoned() -> bool:
	return venom > 0.0


## Puts silk on it. Returns true if that was the hit that wrapped it.
func bind(amount: float) -> bool:
	if eaten or _state == State.BUNDLED or amount <= 0.0:
		return false
	bound = clampf(bound + amount, 0.0, 1.0)
	_show_binding()
	return bound >= 1.0


## Still fighting, and still able to get free. This is the only window in which
## a catch can be lost, so it is the window worth running back for.
func is_fighting() -> bool:
	return _state == State.STUCK and _fight_left > 0.0


## Caught for keeps: tired out or wrapped. It will hang there until you come
## and take it, or until the web gives out under it.
func is_secured() -> bool:
	return _state == State.BUNDLED or (is_stuck() and not is_fighting())


## Killed outright by venom: it stops fighting, and it can be drained whatever
## size it is, which is what makes a venom spur worth carrying.
func envenom() -> bool:
	if eaten or subdued:
		return false
	subdued = true
	# Something dead in open air is not something that hovers. Killed in a web
	# it hangs there wrapped, which is what a web holding something is for;
	# killed anywhere else it drops, like any other bundle.
	#
	# This used to set WRAPPED whatever was true, without ever recording a
	# point to hang from — and the stuck handler drags the body towards that
	# point every frame, which for anything poisoned in open air is the world
	# origin. It sailed off across the level wearing a cocoon.
	if not is_stuck() or not is_instance_valid(_web):
		bundle()
		return true
	wrapped = true
	_state = State.WRAPPED
	bound = 1.0
	_stuck_point = global_position
	_struggle = 0.0
	_set_marked(false)
	_set_cocoon(true)
	return true


## Wrapped on the spot and cut loose: the silk goes round it where it is and
## the bundle drops. This is what a web thrown over something does when the
## silk is good enough to take it outright, rather than leaving it hanging
## there fighting.
func bundle() -> bool:
	if eaten or _state == State.BUNDLED:
		return false
	# Bundling something that was in a web takes it out of that web, by your
	# hand, which is what ends a web once it is the last one in there.
	if is_instance_valid(_web):
		_web.on_prey_taken(self)
	_web = null
	wrapped = true
	_struggle = 0.0
	_fight_left = 0.0
	_snap_timer = 0.0
	_recatch_cooldown = 0.0
	_state = State.BUNDLED
	bound = 1.0
	_set_marked(false)
	_set_cocoon(true)
	velocity = Vector3.ZERO
	_tow_pull = Vector3.ZERO
	# Whatever it was before, a bundle is a thing that falls: floating bodies
	# never report standing on anything, so it would never settle.
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	return true


## Dragged by something outside — a tether. Kept as a pull to be spent rather
## than applied on the spot, because whatever is towing this runs in its own
## physics step and the movement belongs in ours.
func tow(pull: Vector3) -> void:
	_tow_pull += pull


## A bundle is dead weight: it falls whether or not the thing inside it could
## fly, and stays where it lands until you come and drain it — unless something
## is dragging it, in which case it comes along and keeps the swing.
func _fall(delta: float) -> void:
	var pull := _tow_pull
	_tow_pull = Vector3.ZERO
	if is_on_floor() and pull.length_squared() < 0.000001:
		velocity = Vector3.ZERO
		return
	# A towed bundle scrapes along rather than gliding: enough friction that it
	# trails behind you, not so much that it refuses to come.
	var slow: float = 4.0 if pull.length_squared() < 0.000001 else 1.2
	velocity.x = move_toward(velocity.x, 0.0, delta * slow)
	velocity.z = move_toward(velocity.z, 0.0, delta * slow)
	velocity.y -= _gravity * delta
	velocity += pull
	move_and_slide()


## Bundles it: no more struggling, no more damage to the web.
func wrap() -> void:
	if not is_stuck():
		return
	wrapped = true
	_state = State.WRAPPED
	bound = 1.0
	_struggle = 0.0
	_set_marked(false)
	_set_cocoon(true)


## Takes a mouthful. Returns what was actually in it, which is less than was
## asked for on the last swallow.
##
## Eating used to be one keypress and instant, which is what made a web
## pointless: if a meal costs nothing but a click, there is no reason to drag
## anything anywhere, and nowhere is safer than anywhere else. A meal that takes
## a few seconds is a few seconds you are standing still for, and that is what
## gives the trip home a point.
func drain(amount: float) -> float:
	if eaten or amount <= 0.0:
		return 0.0
	var taken: float = minf(amount, biomass)
	biomass -= taken
	if biomass <= 0.001:
		biomass = 0.0
		consume()
	return taken


## How much of it is left, 0 to 1.
func drained() -> float:
	if full_biomass <= 0.0:
		return 0.0
	return clampf(1.0 - biomass / full_biomass, 0.0, 1.0)


## Whether anything has been taken out of it without finishing it.
func part_eaten() -> bool:
	return not eaten and biomass < full_biomass - 0.001


## Finished. Emptied by draining, or taken outright by something that does not
## need to sip — venom, a device, a test.
func consume() -> void:
	if eaten:
		return
	eaten = true
	biomass = 0.0
	if is_instance_valid(_web):
		_web.on_prey_taken(self)
	eaten_by_spider.emit(self)
	queue_free()


# --- behaviour ----------------------------------------------------------

func _process_stuck(delta: float) -> void:
	# Read off the web every frame rather than remembered from the catch. A web
	# that does not move gives the same answer it always did; one being dragged
	# home brings what it is holding along.
	if is_instance_valid(_web):
		_stuck_point = _web.to_global(_hold_offset)
	var pull: float = 12.0 if _snap_timer > 0.0 else 5.0
	var jitter := Vector3.ZERO
	if _state == State.STUCK and _snap_timer <= 0.0:
		var wobble: float = _stuck_wobble()
		jitter = Vector3(sin(_life * 23.0), sin(_life * 17.0 + 1.3), cos(_life * 19.0)) * wobble
	global_position = global_position.lerp(_stuck_point + jitter, clampf(pull * delta, 0.0, 1.0))
	velocity = Vector3.ZERO

	if _snap_timer > 0.0:
		_snap_timer -= delta
		return
	if _state == State.WRAPPED:
		# Wrapped is finished business, and finished business obeys gravity.
		# With nothing holding it up — the web came down, or something has a
		# line on it and is dragging it out — it is a bundle, and bundles fall.
		# Left as it was, the cocoon hung in the air where the web used to be.
		if not is_instance_valid(_web) or _tow_pull.length_squared() > 0.000001:
			bundle()
		return
	if not is_instance_valid(_web):
		_release_into_flight()
		return

	if _fight_left <= 0.0:
		# Fought itself out. It is not getting free on its own any more, so it
		# keeps until you come for it — still hanging there pulling, which is
		# what eventually costs you the web if you never do.
		_web.take_damage(settled_drain * delta)
		return

	_fight_left -= delta
	# Silk already on it is silk it is fighting through, so a bound creature both
	# tears more slowly and does less damage on the way.
	var power := thrash_power()
	_struggle += power * delta
	_web.take_damage(power * delta * 0.6)
	if _struggle >= _web.hold_strength() * ESCAPE_MARGIN:
		var torn_from := _web
		torn_from.on_prey_escaped(self)
		_release_into_flight()
		broke_free.emit(self)


## Whether this would come for that spider, or be eaten by it.
##
## One comparison, and it is the whole difficulty curve: a creature inside the
## spider's bite is food, a creature outside it and aggressive is a problem. Grow
## and the same wasp changes sides.
func would_hunt(spider: Node3D) -> bool:
	if aggression <= 0.0 or eaten or wrapped:
		return false
	if spider == null or not is_instance_valid(spider):
		return false
	if _state == State.STUCK or _state == State.WRAPPED or _state == State.BUNDLED:
		return false
	var bite: int = spider.stage().bite_power if spider.has_method("stage") else 99
	return size_class > bite


## Whether it is coming for someone right now.
func is_hunting() -> bool:
	return _state == State.HUNTING


## Gives up on whatever it was chasing and goes back to its own business, and
## will not come for anyone again for [constant CHASE_COOLDOWN] seconds.
##
## Every way out of a hunt goes through here — the chase running out, losing the
## spider over distance, the spider growing past it, being put back on its post —
## so that breaking off always means the same thing and always sticks. The three
## call sites used to set the state back by hand and none of them set a cooldown,
## which is why a hunter put back where it belonged simply turned round and came
## again 0.9 seconds later.
func break_off() -> void:
	_quarry = null
	_chase_left = 0.0
	_chase_rest = CHASE_COOLDOWN
	if _state == State.HUNTING:
		_state = State.WANDER
	_pick_target()


## Looks for a spider small enough to be worth attacking. Cheap, and only every
## so often, because there is exactly one spider and no need to check per frame.
func _look_for_a_spider() -> void:
	_hunt_timer = 0.9
	if aggression <= 0.0 or _life < SETTLE_IN or _chase_rest > 0.0:
		return
	var spiders := get_tree().get_nodes_in_group("spider")
	if spiders.is_empty():
		return
	var spider := spiders[0] as Node3D
	if not would_hunt(spider):
		return
	if global_position.distance_to(spider.global_position) > hunt_range:
		return
	if randf() > aggression:
		return
	_quarry = spider
	_chase_left = CHASE_STAMINA
	_state = State.HUNTING


## Coming for you. Steers at the spider and bites when it arrives.
##
## Losing track of it is deliberate: anything that stops being worth attacking —
## because it grew, or got away, or because silk took hold of the hunter — drops
## straight back to wandering rather than following you round the level for ever.
func _process_hunt(delta: float) -> void:
	if not would_hunt(_quarry):
		break_off()
		return
	var span := global_position.distance_to(_quarry.global_position)
	if span > hunt_range * 1.8:
		break_off()
		return

	# The chase runs out whether or not it gets anywhere. See
	# [constant CHASE_STAMINA] for why distance alone was not enough of an out.
	_chase_left -= delta
	if _chase_left <= 0.0:
		break_off()
		return

	_target = _quarry.global_position
	# Faster than it wanders while the sprint lasts: something that has decided to
	# attack you should read as having decided, and a hunter you can simply walk
	# away from is not pressure, it is scenery. Then it tires, and the last
	# stretch is the window — slow enough that you can see you are pulling away.
	var winded := _chase_left < CHASE_STAMINA * (1.0 - CHASE_SECOND_WIND)
	_steer(delta, current_speed() * (CHASE_SPENT if winded else CHASE_DASH))

	# Off the spider's size, not the hunter's: what has to be true is that it has
	# reached *you*, and a wasp closing on a spiderling covers the last few
	# centimetres in one frame.
	#
	# Six of its own widths is a margin for a wasp and the far side of the lake for a
	# shark, so for anything big it is the edge of its body instead: something the
	# size of a dog has reached you when it is touching you.
	var girth: float = kind.body_radius if kind != null else 0.05
	var bite_reach: float = maxf(minf(girth * 6.0, girth * HITBOX_SCALE + _quarry_reach()),
		_quarry_reach())
	if span > bite_reach or _bite_timer > 0.0:
		return
	_bite_timer = bite_interval
	if _quarry.has_method("take_bite"):
		_quarry.take_bite(bite_damage, self)


## How close counts as having reached the spider, from the spider's own size.
func _quarry_reach() -> float:
	if _quarry == null or not is_instance_valid(_quarry) or not _quarry.has_method("stage"):
		return 0.4
	return maxf(_quarry.stage().body_height * 1.6, 0.35)


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	_lure_timer -= delta
	_hunt_timer -= delta
	if _hunt_timer <= 0.0:
		_look_for_a_spider()
		if _state == State.HUNTING:
			return
	if _lure_timer <= 0.0:
		_lure_timer = 0.75
		_sniff_for_lures()
	if _wander_timer <= 0.0 or global_position.distance_to(_target) < _arrival_distance():
		_pick_target()
	_steer(delta, current_speed())


func _steer(delta: float, speed: float) -> void:
	# Whatever has a line on this is spent here, not where it was added: the thing
	# doing the towing runs in its own physics step and the movement belongs in
	# ours. See [method tow].
	#
	# This is the living half of that, and until a hitch wanted it there was no
	# such half — [method _fall] spent the pull and nothing else did, so `tow()`
	# on anything still on its feet simply vanished. It never showed, because the
	# only thing towing was the tether and the tether will not hook a creature
	# that is not already finished.
	var pull := _tow_pull
	_tow_pull = Vector3.ZERO
	var ceiling := _water_ceiling()
	# A swimmer's business is under the surface, whatever it is steering at: a lure on
	# the bank, a spider on a boat. It follows along underneath instead.
	_target.y = minf(_target.y, ceiling)
	var to_target := _target - global_position
	var going := to_target.length() >= 0.001
	if not going and pull.length_squared() < 0.000001:
		return
	# Standing on its target and being dragged: no steering to do, but it still
	# has to come.
	var desired := to_target.normalized() * speed if going else velocity
	if not flying:
		desired.y = velocity.y - _gravity * delta
	velocity = velocity.lerp(desired, clampf(3.0 * delta, 0.0, 1.0)) + pull
	move_and_slide()
	if global_position.y > ceiling:
		global_position.y = ceiling
		velocity.y = minf(velocity.y, 0.0)
	if is_on_wall():
		_pick_target()


## How high a swimmer's middle may go: the top of the water it is in, less its own
## depth. Looked up the first time it is wanted rather than when it arrives,
## because whatever puts a creature down puts it in the tree first and where it
## belongs after.
func _water_ceiling() -> float:
	if not swims:
		return INF
	if not _surface_found:
		_surface_found = true
		_surface = INF
		var top := water_top_at(self, global_position)
		if top < INF:
			_surface = top - hit_radius()
	return _surface


## The top of the water at [param point], or INF if it is not in any: the highest
## point of the area on the water layer that holds it.
static func water_top_at(from: Node3D, point: Vector3) -> float:
	if from == null or not from.is_inside_tree():
		return INF
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = GameLayers.WATER
	var top := INF
	for hit in from.get_world_3d().direct_space_state.intersect_point(query, 8):
		var pool := hit.get("collider") as Area3D
		if pool == null:
			continue
		for child in pool.get_children():
			var volume := child as CollisionShape3D
			if volume == null or volume.shape == null:
				continue
			var box := volume.global_transform * volume.shape.get_debug_mesh().get_aabb()
			var high := box.position.y + box.size.y
			top = high if top == INF else maxf(top, high)
	return top


func _pick_target() -> void:
	_wander_timer = wander_interval * randf_range(0.6, 1.4)
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	offset *= wander_radius * randf_range(0.2, 1.0)
	_target = _home + offset
	if flying:
		_target.y = _home.y + randf_range(wander_height.x, wander_height.y)


## Funnel lures bend a wanderer's path toward them — that's the whole point.
func _sniff_for_lures() -> void:
	if lure_susceptibility <= 0.0:
		return
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("silk_lures"):
		var lure := node as SilkNode
		if lure == null:
			continue
		var distance := global_position.distance_to(lure.global_position)
		if distance > lure.lure_radius() or distance >= best_distance:
			continue
		best_distance = distance
		best = lure
	if best == null:
		return
	if randf() > lure_susceptibility:
		return
	var wobble := Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2),
		randf_range(-0.2, 0.2))
	_target = best.global_position + wobble
	_wander_timer = wander_interval


func _release_into_flight() -> void:
	var escape_from := _stuck_point
	_web = null
	_struggle = 0.0
	_fight_left = 0.0
	_snap_timer = 0.0
	wrapped = false
	# The silk it was fighting in stays on it. Tearing out of a web is not shaking
	# off what is already stuck to you, and keeping it is what makes a second
	# attempt on the same creature worth making.
	_show_binding()
	_state = State.FLEEING
	_flee_timer = 2.0
	_recatch_cooldown = 2.5
	var away := (global_position - escape_from)
	if away.length() < 0.01:
		away = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))
	_target = global_position + away.normalized() * wander_radius * 0.5 + Vector3.UP * 0.4


func _arrival_distance() -> float:
	return maxf(0.25, wander_radius * 0.05)


## Fades out as it tires, so you can read a web across the room: still things
## are yours, thrashing things are about to not be.
func _stuck_wobble() -> float:
	return clampf(struggle_power * 0.01, 0.002, 0.05) * fight_left()


## How much of its fight it has left, 0 to 1: all of it when it is first caught,
## none once it has tired itself out. What its body thrashes with.
func fight_left() -> float:
	return clampf(_fight_left / maxf(struggle_stamina, 0.001), 0.0, 1.0)


func _flap() -> void:
	if _wings.is_empty():
		return
	var angle := 0.0
	if _state != State.WRAPPED:
		angle = sin(_life * 70.0) * 0.9
	for i in _wings.size():
		var wing := _wings[i]
		var sign_value: float = 1.0 if i % 2 == 0 else -1.0
		wing.rotation.z = angle * sign_value


## Body, wings and hitbox, all from the species. Built in code rather than
## authored per creature, so a new one really is a .tres and nothing else.
##
## A species with a [member PreySpecies.body] gets that: a skeleton and a mesh,
## posed by a [CreatureView] that watches this node to know what to do. One
## without gets the placeholder, a ball with a pair of flat wings.
func _build_body() -> void:
	var radius := 0.045
	var colour := Color(0.13, 0.12, 0.15, 1.0)
	var sheen := Color(0.45, 0.3, 0.08, 1.0)
	var winged := true
	var shape: CreatureBody = null
	if kind != null:
		radius = maxf(kind.body_radius, 0.008)
		colour = kind.colour
		sheen = kind.sheen
		winged = kind.winged
		shape = kind.body

	if shape != null:
		var view := shape.make_view()
		view.scale = Vector3.ONE * radius
		_replace_child("Body", view)
		winged = false
	else:
		_replace_child("Body", _make_body(radius, colour, sheen))
	_replace_child("Hitbox", _make_hitbox(radius))
	_wings.clear()
	if winged:
		_replace_child("WingLeft", _make_wing(radius, 1.0))
		_replace_child("WingRight", _make_wing(radius, -1.0))
		for wing_name in ["WingLeft", "WingRight"]:
			var wing := get_node_or_null(NodePath(wing_name)) as Node3D
			if wing != null:
				_wings.append(wing)
	else:
		_drop_child("WingLeft")
		_drop_child("WingRight")

	# A cocoon drawn for the old body is the wrong size for this one.
	if _cocoon != null:
		_cocoon.queue_free()
		_cocoon = null
	if _marker != null:
		_marker.queue_free()
		_marker = null


func _make_body(radius: float, colour: Color, sheen: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.4
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = sheen
	material.emission_energy_multiplier = 0.6
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	return view


func _make_wing(radius: float, side: float) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(radius * 2.4, maxf(radius * 0.06, 0.002), radius * 1.1)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.9, 1.0, 0.35)
	material.roughness = 0.1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var view := MeshInstance3D.new()
	view.name = "Mesh"
	view.mesh = mesh
	view.material_override = material
	view.position = Vector3(radius * 1.2 * side, radius * 0.45, 0.0)
	var pivot := Node3D.new()
	pivot.add_child(view)
	return pivot


## How far from its middle something still touches it: the radius of the hitbox,
## which is also what the crosshair's ray stops on. A bolt that passes further
## off than this, plus its own size, has missed.
func hit_radius() -> float:
	var body: float = kind.body_radius if kind != null else 0.045
	return maxf(body, 0.008) * HITBOX_SCALE


func _make_hitbox(radius: float) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius * HITBOX_SCALE
	var hit := CollisionShape3D.new()
	hit.shape = shape
	return hit


func _replace_child(child_name: String, node: Node) -> void:
	_drop_child(child_name)
	node.name = child_name
	add_child(node)


func _drop_child(child_name: String) -> void:
	var existing := get_node_or_null(NodePath(child_name))
	if existing == null:
		return
	remove_child(existing)
	existing.queue_free()


## Silk bundle drawn around wrapped prey.
## Silk showing on the creature, as much of it as there is: a wisp on something
## part-bound and the full bundle at the end of it. The point is that you can tell
## from across the room whether another shot is worth taking.
func _show_binding() -> void:
	var share := clampf(bound, 0.0, 1.0)
	if share <= 0.02:
		_set_cocoon(false)
		return
	_set_cocoon(true)
	if _cocoon == null:
		return
	_cocoon.scale = Vector3.ONE * lerpf(0.45, 1.0, share)
	var material := _cocoon.material_override as StandardMaterial3D
	if material != null:
		var tint := material.albedo_color
		tint.a = lerpf(0.3, 0.9, share)
		material.albedo_color = tint


func _set_cocoon(active: bool) -> void:
	if active and _cocoon == null:
		var radius: float = kind.body_radius if kind != null else 0.045
		var mesh := SphereMesh.new()
		mesh.radius = radius * 2.0
		mesh.height = radius * 5.8
		mesh.radial_segments = 10
		mesh.rings = 5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.93, 0.93, 0.9, 0.9)
		material.roughness = 0.9
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cocoon = MeshInstance3D.new()
		_cocoon.name = "Cocoon"
		_cocoon.mesh = mesh
		_cocoon.material_override = material
		_cocoon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cocoon)
	if _cocoon != null:
		_cocoon.visible = active


## Highlight for prey that has tripped an alert web.
func _set_marked(active: bool) -> void:
	if active and _marker == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		mesh.radial_segments = 8
		mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.45, 0.3, 0.28)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_marker = MeshInstance3D.new()
		_marker.name = "TripMarker"
		_marker.mesh = mesh
		_marker.material_override = material
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
	if _marker != null:
		_marker.visible = active
