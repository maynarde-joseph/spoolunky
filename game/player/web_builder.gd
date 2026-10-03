class_name WebBuilder
extends Node3D

## Build mode: aim, drop anchors, spin a web between them.
##
## The player never places a prefab. They shoot silk at real surfaces, and the
## shape of the web falls out of where those anchors landed — which is what
## makes a corner, a doorway and a drain all play differently.

signal state_changed()
signal notice(text: String)
signal web_built(web: WebStructure)

## Why the current aim point cannot be anchored.
enum Problem {
	NONE,
	NO_SURFACE,      ## nothing solid under the crosshair, or out of range
	TOO_FAR,         ## further from the last anchor than this size can span
	TOO_CLOSE,       ## practically on top of the last anchor
	FULL,            ## pattern has taken all the anchors it allows
	LOCKED,          ## pattern needs a bigger spider
}

## Where finished webs are parented. Defaults to a "Webs" node in the level.
@export var web_container_path: NodePath

## How many lines the spider may have up at once.
##
## This is what replaced the silk budget on lines. A line costs nothing to make
## and everything to keep, so the question stops being "can I afford this" and
## becomes "which three do I want" — which is a decision about the room you are
## in rather than about a number. Three is small enough to hold in your head
## while you are moving, which is the only time it matters.
const MAX_LINES := 3

## How many webs the world keeps standing for you.
##
## Higher than [constant MAX_LINES] on purpose, because the two are different
## things. A line is traversal, and three is a number you can hold in your head
## while moving. A web is a *site*, and running several is exactly what the game
## asks for — a web fills up and a full one catches nothing, so spreading out is
## the play. This is not a budget on that; it is here to stop the wall you were
## practising against ending up papered with the ones you shot and forgot.
const MAX_WEBS := 6

## Most anchors one run round a frame may have.
@export var max_chain := 12

## How far a grapple may reach, in metres. Zero means as far as you can see.
## The size tiers gate what you can hold and how much you can spin — not where
## you are allowed to go, because being stuck within three metres of yourself
## is what made getting about a chore.
@export var grapple_reach := 0.0

## How far silk reaches, in multiples of what one thread can span.
##
## Grappling and throwing both used to be effectively unlimited — anywhere you
## could see — and the report back was that the whole game felt too long ranged,
## which is what happens when nothing is out of reach: there is no distance left
## for growing to close. So reach is the body's, like everything else. A
## spiderling gets about thirteen metres and the Architect a hundred and twenty,
## off the same [member GrowthStage.max_strand_length] that already says how far
## one thread can go, and the room you could not cross yesterday is the reward
## for eating.
@export var silk_span := 4.0

## What a web spun at the far end of that reach is worth, against one spun at
## your feet.
##
## The other half of making distance mean something. A hard edge to the reach
## says where you may not throw; this says what it costs to throw far, which is
## the part that can be played around. Long shots still land — they land
## thinner.
@export_range(0.1, 1.0, 0.05) var far_quality := 0.55

## How long holding the place key takes to grow a web from its smallest to the
## biggest this size tier can spin.
@export var place_grow_time := 1.1

## Seconds between web shots.
##
## This is the whole cost of a web now. Silk used to be the thing that stopped
## you papering a room with them, and a budget is a poor tool for that job: it
## made a web something to be afraid of spending, and the fear was worst
## exactly when you had just missed. A wait is the opposite kind of limit — it
## costs you nothing you were saving, it comes back on its own, and a miss is
## over in a few seconds.
@export var shot_cooldown := 3.5

## How long winding a throw up to its full size takes, in seconds.
##
## This replaced a lock-on. Holding the crosshair on a creature for a second
## used to *guarantee* the catch, with the bolt steering itself in — which was
## no fun, because a promise removes the shot. Holding now makes the ball
## bigger, and a bigger ball is easier to hit with: the same second, the same
## reward for spending it, and you still have to aim.
@export var charge_time := 0.9

## How big the ball of silk is, as a radius in body heights, from a tap to a full
## wind-up.
##
## The hitbox at 1:1: the ball held over the spider's back, the bead in flight
## and what the bolt has to touch are all this one size, so a creature is caught
## when the ball you watched grow touches the creature you can see. It used to
## be a readout for a catch radius metres across, which meant the thing you were
## watching said nothing about whether you would hit.
@export var held_bodies := Vector2(0.12, 0.4)

## How far off the cross a creature can be and still be what a shot is thrown at,
## in degrees past the edge of the creature itself as the camera sees it.
## Negative turns picking off, and every shot goes straight down the cross.
##
## Picking is only half of it; the other half is where the silk goes once a
## creature is picked, which is where the creature will be when the silk gets
## there — see [method shot_lead]. Aimed at where a fly *is*, a tap never catches
## one that is moving: across five metres it has flown a metre by the time the
## silk arrives, more than twenty times its own width. The two degrees are there
## because a fly five metres off is about one degree across, and asking for that
## exactly is asking for a hairline again.
@export var shot_pick_angle := 2.0

## Pattern dragged between anchors when the chosen one is a net.
const FRAME_PATTERN := "frame_line"

## Stand-in for "no limit": further than any sane level is wide, so the ray
## stops at geometry rather than at a rule.
const UNLIMITED_REACH := 4096.0

## Corners on a placed web's rim. More than it takes to read as round, because
## they are what the shape of a gap gets recorded in.
const PLACE_SIDES := 16

## Closest a rim corner may sit to the middle. Silk can hug a corner tightly,
## but a web that reaches almost nowhere on one side is a sliver, not a trap.
const PLACE_MIN_SPAN := 0.18

## How far ahead the charge ghost sits when the crosshair has found nothing,
## so a throw at open sky still shows the size being wound up.
const CHARGE_GHOST_RANGE := 6.0

## How long a thrown web takes to spring out to full size. Looks only — the
## silk catches at its real size from the moment it lands.
const ARRIVAL_SPRING := 0.18

var patterns: Array[WebPattern] = []
var pattern_index := 0
var building := false

## Dial settings, kept per pattern so an orb web you like spun tight stays that
## way when you come back to it.
var tunings := {}

## How new webs are woven. A test switch: stretched webs take the shape you
## drew, inscribed ones keep an even spiral inside the frame.
var weave: WebGeometry.Weave = WebGeometry.Weave.STRETCHED

## Which dial the tuning keys are pointed at.
var selected_dial: WebTuning.Dial = WebTuning.Dial.TENSION

## Rigs the player has saved, and which one is on the end of the cursor.
var designs: Array[WebDesign] = []
var design_index := 0
var placing_design := false
var anchors := PackedVector3Array()

## Web waiting to be wired to something, while the player picks the other end.
var link_source: SilkNode = null

## Spinning a web where you are pointing: held down, it grows.
var placing := false
var place_radius := 0.0
var place_centre := Vector3.ZERO
var place_normal := Vector3.UP
var place_valid := false

## Stopped growing because the body cannot span any wider.
var place_capped := false

## Whether letting go throws a bolt of silk that opens where it lands, rather
## than putting the web straight down under the crosshair. A test switch while
## the two are being compared.
var throwing := false

## A bolt in flight, so a second press cannot send another.
var _shot: SilkShot = null

## True while the shoot key is held down and a ball is being wound up.
var aiming := false

## True while a spell other than silk is being wound up. The builder frames the
## aim for that the same way as for its own ball: it is the one owner of the
## framing, because two things easing one number is two things fighting over it.
var framing_held := false

## How far through the wind-up, 0 to 1. The size of the throw, and the size of
## the ball standing for it.
var charge := 0.0

var _cooling := 0.0
var _cooldown_span := 0.0
var _held: MeshInstance3D
var _held_material: StandardMaterial3D

## How many rim corners found something to hold onto, and how much the web
## would actually cover once the room has had its say.
var place_anchored := 0
var place_area := 0.0

## What the throw is aimed over, if anything — the web centres on it instead
## of on the surface behind it.
var place_target: Node3D = null

var aim_valid := false
var aim_point := Vector3.ZERO
var aim_normal := Vector3.UP
var problem := Problem.NONE

var _spider: CharacterBody3D
var _growth: SpiderGrowth
var _view: SpiderCamera
var _climb: SpiderClimb

## Frame strands laid on the way round the current chain.
var _chain: Array[WebStrand] = []

## Every line the grapple has left up, oldest first.
var _lines: Array[WebStrand] = []
var _webs: Array[WebNet] = []
var _pending_anchor := Vector3.ZERO
var _awaiting_grapple := false

## Whether the spider had hold of something when it fired. Silk has to start on
## something: a line launched in mid-air would hang from a point in empty space.
var _launch_anchored := false

## Where the spider pushed off from, so the line it drags has somewhere to
## start once it lands.
var _launched_from := Vector3.ZERO

## A line the current grapple is aimed at, to be ridden on arrival instead of
## having fresh silk laid out to it.
var _pending_ride: WebStrand = null

## Rings of silk the player could weave into, and what they were built from.
var _loops: Array = []
var _loop_source := 0
var _preview: MeshInstance3D
var _preview_mesh: ImmediateMesh
var _preview_material: StandardMaterial3D
var _cursor: MeshInstance3D
var _cursor_mesh: SphereMesh
var _cursor_material: StandardMaterial3D


func _ready() -> void:
	patterns = WebLibrary.load_patterns()
	designs = DesignLibrary.load_all()
	_select_first_spinnable()
	_build_preview_nodes()
	set_process(true)


## Wires the builder to the spider that owns it.
func setup(spider: CharacterBody3D, growth: SpiderGrowth,
		view: SpiderCamera, climb: SpiderClimb = null) -> void:
	_spider = spider
	_growth = growth
	_view = view
	_climb = climb
	if _climb != null:
		_climb.grappled.connect(_on_grappled)


func _process(delta: float) -> void:
	_cooling = maxf(0.0, _cooling - delta)
	_update_held()
	_frame_the_aim(delta)
	if placing:
		_grow_placement(delta)
	elif placing_design:
		_update_design_aim()
	else:
		_update_aim()
	_draw_preview()


# --- spinning a web where you point -------------------------------------

## Start spinning. Held down the web grows; letting go puts it there.
##
## This replaced filling a ring the player had grappled around. That version
## read well and played badly: it asked you to enclose an area by accident and
## then go and find it again. Pointing at a spot and spinning a web there is
## what people actually try to do, so it is what the game does.
func begin_place() -> bool:
	if placing or placing_design:
		return false
	var pattern := current_pattern()
	if pattern == null:
		return false
	if pattern.shape != WebPattern.Shape.NET:
		notice.emit("%s is a line — grapple it across a gap instead"
			% pattern.display_name)
		return false
	if not _is_unlocked(pattern):
		notice.emit("%s needs a bigger spider" % pattern.display_name)
		return false
	placing = true
	place_capped = false
	place_radius = _min_place_radius()
	_update_placement()
	state_changed.emit()
	return true


## Let go: spin what the ghost was showing.
func commit_place() -> bool:
	if not placing:
		return false
	placing = false
	_update_placement()
	state_changed.emit()
	if throwing:
		return _throw_place()
	if not place_valid:
		notice.emit("Nothing to spin a web against")
		return false

	var pattern := current_pattern()
	var dials := tuning_for(pattern)
	var rim := place_rim()
	var smallest := _min_place_radius()
	if place_area < smallest * smallest:
		notice.emit("Too tight in there to get a web up")
		return false
	var web := WebNet.spin(dials.apply_to(pattern), rim, _quality(), weave, true)
	if web == null:
		notice.emit("No room for a web there")
		return false

	web.tuning = dials.copy()
	web.place_in(_resolve_container())
	_remember_web(web)
	_loop_source = -1
	web_built.emit(web)
	if web.bundled_on_arrival > 0 and web.snared_count() == 0:
		# The silk went round what it hit. There is nothing left to hang on a
		# wall, so the web goes with it rather than sitting there empty.
		notice.emit("%s thrown over %d — wrapped and dropped"
			% [pattern.display_name, web.bundled_on_arrival])
		# web_built has already gone out with this one, so anything that kept
		# hold of it is looking at a web that is about to stop existing. Every
		# listener in the game checks is_instance_valid before touching a web;
		# anything new must too, because reading a freed one is a crash rather
		# than an error.
		web.unlink_all()
		web.queue_free()
		return true
	if web.bundled_on_arrival > 0:
		notice.emit("%s thrown over %d, and still holding %d"
			% [pattern.display_name, web.bundled_on_arrival, web.snared_count()])
	elif web.caught_on_arrival > 0:
		notice.emit("%s caught %d on the way up, still fighting"
			% [pattern.display_name, web.caught_on_arrival])
	elif place_anchored > 0:
		notice.emit("%s spun into the gap, %.2f m2 on %d anchors"
			% [pattern.display_name, place_area, place_anchored])
	else:
		notice.emit("%s spun, %.2f m2" % [pattern.display_name, place_area])
	return true


# --- aim and shoot ------------------------------------------------------

## The web verb, and the only one the player has.
##
## No ghost, no held key, no check for somewhere valid to put it. Point, press,
## and a bolt of silk leaves the spider. It makes a web where it lands, wraps
## whatever it lands *on* if that thing is alive, and stops being a shot if it
## finds neither — because a shot at open sky that never expires is a node
## quietly flying out of the level for ever.
##
## The older way of making a web — hold to grow a ghost that fits the room — is
## still in this file below, still tested, and no longer reachable from the
## keyboard. It was the better idea on paper and the worse one to play.
func shoot() -> bool:
	if shot_in_flight() or _view == null:
		return false
	if cooling():
		notice.emit("Spinning more — %.1fs" % cooldown_left())
		return false
	var pattern := current_pattern()
	if pattern == null:
		pattern = _first_spinnable()
	if pattern == null:
		notice.emit("Nothing to spin")
		return false

	# Worked out once, at the trigger, and carried by the bolt, so a web cannot
	# change size in flight.
	var radius := shot_radius()

	var from := _view.aim_origin()
	var heading := _view.aim_forward()
	# Something alive under the cross is thrown at where it is going to be, and
	# the bolt flies straight there — nothing steers it once it has gone.
	var quarry := shot_target()
	if quarry != null:
		var lead := shot_lead(quarry) - from
		if lead.length_squared() > 0.000001:
			heading = lead.normalized()
	var shot := SilkShot.fire(from, heading, _stage().body_height, _exclusions())
	shot.catch_radius = catch_radius(radius)
	shot.limit_to(silk_reach())
	shot.landed.connect(_on_shot_landed.bind(pattern, radius, from))
	shot.fizzled.connect(func() -> void: _shot = null)
	shot.launch_from(_resolve_container(), _view.aim_origin())
	_shot = shot
	# Heavier silk takes longer to lay. Most patterns spin at 1.0, where this is
	# simply the base wait — and a trait can shorten it, the same as it shortens
	# every other spell's.
	_cooldown_span = shot_cooldown * maxf(pattern.spin_time, 0.1) * _cast_scale()
	_cooling = _cooldown_span
	return true


## What the spider's traits and what it has learned do to the wait between
## casts. See [method SpiderTraits.cast_scale] and [method SpellTree.wait_scale].
func _cast_scale() -> float:
	if _spider == null:
		return 1.0
	var scale := 1.0
	if "traits" in _spider:
		var traits := _spider.get("traits") as SpiderTraits
		scale *= traits.cast_scale() if traits != null else 1.0
	if "spell_tree" in _spider:
		var tree := _spider.get("spell_tree") as SpellTree
		scale *= tree.wait_scale("silk") if tree != null else 1.0
	return scale


## How far silk goes: one thread's span, times [member silk_span].
##
## The same number for grappling and for throwing, deliberately. Two verbs that
## both mean "put silk over there" with two different invisible limits is the
## fastest way to make a reach unreadable.
func silk_reach() -> float:
	if grapple_reach > 0.0:
		return grapple_reach
	return maxf(_stage().max_strand_length * silk_span, _stage().body_height * 4.0)


## The creature the next shot will be thrown at, or null.
##
## The one nearest the cross whose outline comes within [member shot_pick_angle]
## of it — measured as the camera sees it, because the cross is on the screen —
## inside the silk's reach, and in plain sight of the spider: silk that would hit
## a wall on the way is not a shot at what is behind the wall. One rule, asked by
## the shot, the crosshair and the readout alike, so none of them can promise what
## another will not do.
func shot_target() -> Prey:
	if _view == null or _view.camera == null or _spider == null or shot_pick_angle < 0.0:
		return null
	var eye := _view.camera.global_position
	var look := -_view.camera.global_basis.z.normalized()
	var from := _view.aim_origin()
	var reach := silk_reach()
	var best: Prey = null
	var best_slack := INF
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten or prey.wrapped:
			continue
		if prey.is_bundled() or prey.is_dead():
			continue
		var at := prey.global_position
		if from.distance_to(at) > reach:
			continue
		var sight := at - eye
		var distance := sight.length()
		if distance < 0.001:
			continue
		# How far outside its own outline the cross is, in degrees.
		var slack := rad_to_deg(look.angle_to(sight)) \
			- rad_to_deg(atan2(prey.hit_radius(), distance))
		if slack > shot_pick_angle or slack >= best_slack:
			continue
		if not _in_sight(from, prey):
			continue
		best_slack = slack
		best = prey
	return best


## Where a shot at [param prey] has to go to meet it: where it will be when the
## silk gets there, if it keeps going the way it is going. See
## [method SilkShot.intercept].
func shot_lead(prey: Prey) -> Vector3:
	if prey == null or _view == null:
		return aim_point
	return SilkShot.intercept(_view.aim_origin(), SilkShot.pace_for(_stage().body_height),
		prey.global_position, prey.velocity)


## Whether silk from [param from] gets to [param prey] without landing on
## something else first. Close counts: a fly stuck in a web sits in the web's
## own plank, and the silk that meets the web there meets the fly.
func _in_sight(from: Vector3, prey: Prey) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, prey.global_position,
		GameLayers.WORLD | GameLayers.WEB_WALK, _exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var stopped: Vector3 = hit.get("position", from)
	return stopped.distance_to(prey.global_position) <= prey.hit_radius() * 1.5


## True while the spider is still spinning the next one.
func cooling() -> bool:
	return _cooling > 0.0


func cooldown_left() -> float:
	return _cooling


## 0 to 1, for the readout. 1 means ready.
func cooldown_progress() -> float:
	if _cooldown_span <= 0.0:
		return 1.0
	return clampf(1.0 - _cooling / _cooldown_span, 0.0, 1.0)


## How big the ball carrying a web of [param web_radius] is — which is how close
## it has to pass to something alive, beyond that creature's own hitbox.
##
## The ball, and nothing more. It was bigger than the web it carried and never
## smaller than two and a half body lengths, which took anything within sixty
## centimetres of a spiderling's tap — a fly is five across — so every shot near a
## creature caught it and aiming stopped mattering. A hairline was the opposite
## mistake, and the one this was answering: nothing could be caught at all. A
## ball the size you can see, against a body the size you can see, sits between
## them, and winding up still buys a bigger one.
func catch_radius(web_radius: float) -> float:
	return ball_radius(_wound_for(web_radius))


## The ball's radius at [param wound], 0 for a tap to 1 for a full wind-up.
func ball_radius(wound: float) -> float:
	return _stage().body_height * lerpf(held_bodies.x, held_bodies.y,
		clampf(wound, 0.0, 1.0))


## How far through the wind-up a web of [param web_radius] is, 0 to 1 — the
## inverse of [method shot_radius], so a size can be traced back to the ball
## that carries it.
func _wound_for(web_radius: float) -> float:
	var span := _max_place_radius() - _min_place_radius()
	if span <= 0.000001:
		return 0.0
	return clampf((web_radius - _min_place_radius()) / span, 0.0, 1.0)


## How big the throw is: the smallest web this body can spin at a tap, up to the
## biggest it can spin at a full wind-up.
##
## The same span a held place grows through, on purpose — one rule for how big a
## web gets, whether it is spun by hand or thrown. And one number doing three
## jobs: how big the ball looks, how close the bolt has to pass to take
## something, and how big the web it opens ends up. That is what makes a wind-up
## legible — the thing you watch grow is the thing that got easier to hit with.
func shot_radius() -> float:
	return lerpf(_min_place_radius(), _max_place_radius(), clampf(charge, 0.0, 1.0))


## Landed. Something alive is wrapped where it stood; anything else gets a web
## built against it. No validity test either way — a shot that reached
## something has already earned its web.
func _on_shot_landed(at: Vector3, normal: Vector3, prey: Node3D, heading: Vector3,
		pattern: WebPattern, radius: float, from: Vector3) -> void:
	_shot = null
	var quality := throw_quality(from.distance_to(at))
	var caught := prey as Prey
	if caught != null and is_instance_valid(caught):
		_silk_onto(caught, pattern, from.distance_to(at))
		# And nothing else. A bolt that reaches a creature has found what it was
		# aimed at, and opening a web where it happened to be standing plants one
		# on the floor every time you shoot something low — which is not a web
		# anybody chose to put there. Enough silk wraps it; then it is a bundle to
		# put a line on and drag off.
		return
	_open_web_at(at, normal, _facing_from(heading, normal), prey, radius, quality)


## What one bolt does to the creature it hits.
##
## Silk, and only silk. Enough of it wraps the creature where it stands and the
## bundle drops; short of enough it goes on anyway, costing the thing some of its
## fight and some of its speed, and the next bolt starts from there.
func _silk_onto(caught: Prey, pattern: WebPattern, distance: float) -> void:
	if not caught.can_be_snared():
		notice.emit("The %s is already caught" % caught.species)
		return
	# What this bolt's silk is worth where it landed. A direct hit used to wrap
	# whatever it touched, which let a spiderling take a wasp in one shot and made
	# both of the other ways of catching things pointless.
	var hold := shot_hold(pattern, distance)
	if hold <= 0.0:
		# A line pattern has no hold in it at all, so there is nothing for it to
		# bind with and no reading worth printing.
		notice.emit("A %s has no hold in it — aim it at something solid"
			% pattern.display_name)
		return
	if caught.taken_cleanly_by(hold) or caught.bind(caught.bind_share(hold)):
		# Either the silk was up to it, or that was the hit that closed it.
		if caught.bundle():
			notice.emit("Wrapped the %s — put a line on it and drag it off"
				% caught.species)
			return
	notice.emit("Silk on the %s — %d%% wrapped, it will still fight"
		% [caught.species, roundi(caught.bound * 100.0)])


## What a bolt of [param pattern] is worth as a hold, landing [param distance]
## away. One place, so the readout can promise exactly what the landing delivers.
func shot_hold(pattern: WebPattern, distance: float) -> float:
	if pattern == null:
		return 0.0
	return pattern.hold_strength * throw_quality(distance)


## What a web is worth, thrown this far.
##
## Falls off across the reach and stops at [member far_quality] — it never
## reaches zero, because a throw that lands and builds nothing is a throw that
## reads as broken rather than as expensive.
func throw_quality(distance: float) -> float:
	var reach := silk_reach()
	if reach <= 0.0:
		return _quality()
	var out := clampf(distance / reach, 0.0, 1.0)
	return _quality() * lerpf(1.0, far_quality, out)


# --- taking aim ---------------------------------------------------------

## The shoot key went down. Starts winding a ball of silk up.
##
## A tap is still a tap: the second only matters if you spend it, so the fast
## shot is unchanged and the slow one is a thing you choose.
func begin_shot() -> bool:
	if aiming or _view == null:
		return false
	aiming = true
	charge = 0.0
	# The camera stays where it is. Taking aim used to drop to first person, on
	# the reasoning that third person has the cross and the silk leaving from
	# different places — true, and it turns out not to matter: a ball of silk is
	# thrown from the spider *toward whatever the cross is over*, which is what
	# the third-person aim already works out. What the flip cost was the one
	# thing worth having, which is watching the spider wind up.
	_show_held(true)
	state_changed.emit()
	return true


## Held down. Winds the ball up.
func track(delta: float) -> void:
	if not aiming:
		return
	charge = clampf(charge + delta / maxf(charge_time, 0.05), 0.0, 1.0)


## Let go. Throws whatever size the wind-up reached, straight down the cross.
func release_shot() -> bool:
	if not aiming:
		return false
	aiming = false
	_show_held(false)
	var fired := shoot()
	charge = 0.0
	state_changed.emit()
	return fired


## Gives up aiming without firing, for when the key was never released because
## something else took the input away.
func cancel_shot() -> void:
	if not aiming:
		return
	aiming = false
	charge = 0.0
	_show_held(false)
	state_changed.emit()


## The ball of silk the spider winds up while aiming, held over its back.
##
## A wizard holding a fireball: you can see the throw coming, and it grows and
## brightens as the wind-up fills, with silk's magic circle wrapped round it (see
## [method SpiderSpells._update_circle]). That is the point — the second you spend
## winding up has a reading in the world as well as one on the HUD, so you can
## judge the throw without looking away from the fly.
func _show_held(shown: bool) -> void:
	if shown and _held == null:
		_build_held()
	if _held != null:
		_held.visible = shown


## Keeps the ball over the spider and sized to how far the wind-up has come.
func _update_held() -> void:
	if _held == null or not _held.visible or _spider == null:
		return
	_held.global_position = held_centre()
	_held.scale = Vector3.ONE * maxf(ball_radius(charge), 0.005)
	if _held_material != null:
		# Brightening, but never so far that the circle wrapped round it — light on
		# dark — washes out on it.
		_held_material.emission_energy_multiplier = lerpf(0.25, 0.7, charge)


## Where the middle of the ball of silk is while it is wound up: over the spider's
## back, sitting on it however big it has grown.
func held_centre() -> Vector3:
	if _spider == null:
		return global_position
	return _spider.global_position + held_up() * (_stage().body_height * 0.9
		+ ball_radius(charge))


## Which way the spider's back faces, which the ball of silk sits over: world up
## put the ball inside the wall or the ceiling the spider was stuck to, out of
## reach of the front legs that hold it.
func held_up() -> Vector3:
	return _climb.view_up() if _climb != null else Vector3.UP


## Brings the camera in over the shoulder while winding up, and lets it back
## out after. Eased, and independently of the charge, so letting go at half a
## wind-up does not jerk the view back from halfway.
func _frame_the_aim(delta: float) -> void:
	if _view == null:
		return
	var wanted := 1.0 if aiming or framing_held else 0.0
	_view.aim_blend = move_toward(_view.aim_blend, wanted, delta * 4.0)


func _build_held() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_held_material = WebGeometry.silk_material()
	_held_material.albedo_color = Color(0.12, 0.13, 0.16, 1.0)
	# Solid, unlike silk in a web: the half of the circle wrapped round the far side
	# of the ball is behind it, and should look it.
	_held_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_held = MeshInstance3D.new()
	_held.name = "HeldSilk"
	_held.mesh = mesh
	_held.material_override = _held_material
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.visible = false
	add_child(_held)


## Whatever this tier can actually spin, for when nothing is selected — the
## wheel is gone, so the builder picks for itself.
func _first_spinnable() -> WebPattern:
	for pattern in patterns:
		if pattern.shape == WebPattern.Shape.NET and _growth.stage_index >= pattern.unlock_stage:
			return pattern
	return null


## Sends a bolt of silk off to open out wherever it lands. The size the throw
## was charged to travels with it, so holding still decides how big the web is
## — you just find out where it went a moment later.
func _throw_place() -> bool:
	if shot_in_flight():
		return false
	var pattern := current_pattern()
	if pattern == null or _view == null:
		return false
	var charged := place_radius
	var from := _view.aim_origin()
	var shot := SilkShot.fire(from, _view.aim_forward(),
		_stage().body_height, _exclusions())
	shot.catch_radius = catch_radius(charged)
	shot.limit_to(silk_reach())
	shot.landed.connect(func(at: Vector3, normal: Vector3, prey: Node3D,
			heading: Vector3) -> void:
		_open_web_at(at, normal, _facing_from(heading, normal), prey, charged,
			throw_quality(from.distance_to(at))))
	shot.fizzled.connect(func() -> void: notice.emit("The silk went wide"))
	# Straight from where aiming starts, with no head start down the barrel. An
	# offset looks tidier and tunnels: aiming starts at the spider's own body in
	# third person, so a body length forward is through the floor it is standing
	# on. The sweep covers that first stretch anyway, and the spider is excluded
	# from it.
	shot.launch_from(_resolve_container(), _view.aim_origin())
	_shot = shot
	notice.emit("%s thrown" % pattern.display_name)
	return true


## A bolt landed. Open it out there, at the size it was charged to, fitted to
## whatever it found — which is the same fitting a placed web gets.
func _open_web_at(at: Vector3, surface: Vector3, facing: Vector3, prey: Node3D,
		charged: float, quality := -1.0) -> void:
	_shot = null
	var pattern := current_pattern()
	if pattern == null:
		return
	place_radius = charged
	# The plane the silk arrived through, not the plane of the wall it hit.
	#
	# Aligning a shot's web to the surface normal is what made corners worse
	# than the old placer: flat against a wall, the sixteen rim rays run
	# *parallel* to that wall and find nothing, so every web came out a plain
	# disc plastered on flat stone. Facing it back the way the bolt came is what
	# the held placer always did — it faced the player — and in a corner that is
	# the plane where the rays reach both walls and the rim fits the gap.
	place_normal = facing
	# Clearance is the surface's business, along the surface's own normal: the
	# plane can be near enough parallel to a wall, and pushing along it then
	# moves the web sideways rather than off the stone.
	place_centre = at + surface * _silk_clearance()
	if prey != null:
		# Over the thing rather than off the skin of it: a catch volume is a thin
		# slab around the web's own plane, so any clearance at all would catch
		# nothing. The plane is still the bolt's, not wherever the camera is
		# pointing now — it may have turned while the silk was in the air.
		place_centre = at
	place_valid = true
	place_target = prey

	var dials := tuning_for(pattern)
	var rim := place_rim()
	var spun: float = quality if quality > 0.0 else _quality()
	var web := WebNet.spin(dials.apply_to(pattern), rim, spun, weave, true)
	if web == null:
		notice.emit("It landed somewhere a web will not hold")
		return

	web.tuning = dials.copy()
	web.place_in(_resolve_container())
	_remember_web(web)
	_loop_source = -1
	web_built.emit(web)
	if web.bundled_on_arrival > 0 and web.snared_count() == 0:
		notice.emit("Caught it mid-air — wrapped and dropped")
		web.unlink_all()
		web.queue_free()
		return
	web.play_arrival(ARRIVAL_SPRING)
	notice.emit("%s opened out, %.2f m2" % [pattern.display_name, place_area])


## Switches between putting the web down where you point and throwing a bolt
## of silk that opens out where it lands.
func toggle_throwing() -> void:
	throwing = not throwing
	state_changed.emit()
	notice.emit("Webs: %s" % throw_name())


func throw_name() -> String:
	if throwing:
		return "thrown — a bolt that opens where it lands"
	return "placed — straight down where you point"


## True while a bolt is still in the air.
func shot_in_flight() -> bool:
	return _shot != null and is_instance_valid(_shot)


func cancel_place() -> void:
	if not placing:
		return
	placing = false
	place_valid = false
	state_changed.emit()


## The outline a placed web would have: a ring facing you at the aim point,
## with every corner run out until it meets something.
##
## Holding the key sets how far a corner is *allowed* to reach, and the room
## decides where it actually stops. So the same press gives you a wide circle
## in open air and a web that fills the angle when you point into a corner —
## the shape is the space, not a disc dropped into it.
func place_rim() -> PackedVector3Array:
	var rim := PackedVector3Array()
	if not place_valid:
		return rim
	var right := place_normal.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = place_normal.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(place_normal).normalized()

	var space := get_world_3d().direct_space_state
	var exclude := _exclusions()
	var floor_span: float = maxf(place_radius * PLACE_MIN_SPAN, 0.05)
	# Silk is drawn as crossed quads with real thickness, so a corner sitting
	# exactly on the surface it found buries half of itself in the wall. Stop
	# just shy of it instead, by enough to clear the strand.
	var pattern := current_pattern()
	var inset := 0.002
	if pattern != null:
		inset = maxf(pattern.strand_thickness * sqrt(_quality()) * 0.75, 0.002)
	place_anchored = 0
	for i in PLACE_SIDES:
		var angle := TAU * float(i) / float(PLACE_SIDES)
		var direction := (right * cos(angle) + up * sin(angle)).normalized()
		# Reaching exactly as far as it is allowed to, so open air gives the
		# full held size and anything solid cuts the corner short where it is.
		var span := place_radius
		var query := PhysicsRayQueryParameters3D.create(place_centre,
			place_centre + direction * place_radius, GameLayers.WORLD, exclude)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			span = maxf(place_centre.distance_to(hit["position"]) - inset, floor_span)
			place_anchored += 1
		rim.append(place_centre + direction * span)
	place_area = _polygon_area(rim)
	return rim


## The ghost for a throw. Which room the bolt lands in is not known yet, so
## this is the plain size being wound up rather than a rim fitted to whatever
## the crosshair happens to be resting on — the fitting happens on arrival.
## It also has to draw with nothing under the crosshair at all, because a
## throw at open sky is a throw, not an error.
func place_charge_ring() -> PackedVector3Array:
	var ring := PackedVector3Array()
	if _view == null:
		return ring
	var normal := -_view.aim_forward()
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	normal = normal.normalized()
	var right := normal.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = normal.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(normal).normalized()
	var centre := place_charge_centre()
	for i in PLACE_SIDES:
		var angle := TAU * float(i) / float(PLACE_SIDES)
		ring.append(centre + (right * cos(angle) + up * sin(angle)) * place_radius)
	return ring


## Middle of a charge ghost: on the crosshair when it found something, and a
## fixed distance ahead when it did not.
func place_charge_centre() -> Vector3:
	if place_valid or _view == null:
		return place_centre
	return _view.aim_origin() + _view.aim_forward() * CHARGE_GHOST_RANGE


## Where the web would go and which way it would face: straight out from the
## crosshair, turned to face you, so what you see is what you get.
func _update_placement() -> void:
	place_valid = false
	if _view == null:
		return
	if not _cast_surface(UNLIMITED_REACH):
		return
	var facing := -_view.aim_forward()
	if facing.length_squared() < 0.000001:
		facing = aim_normal
	place_normal = facing.normalized()
	# Point at something and the web goes over *it*, not onto the wall behind
	# it. Without this, throwing silk at a moth puts a web a metre past the
	# moth and catches nothing, because a catch volume is a thin slab around
	# the web's own plane.
	place_target = _prey_under_crosshair()
	if place_target != null:
		place_centre = place_target.global_position
	else:
		place_centre = aim_point
	# Never let the middle of a web sit inside whatever the crosshair found.
	var least := _silk_clearance()
	var clearance := place_normal.dot(place_centre - aim_point)
	if clearance < least:
		place_centre += place_normal * (least - clearance)
	place_valid = true

	# Fit the rim to the room. This used to happen by accident, as the argument
	# to the call that priced the web, and deleting the price took the fitting
	# with it — the ghost stayed a plain disc and every corner stopped looking
	# for a wall. Geometry that something else was computing on the way past is
	# geometry nobody owns, so it is called for its own sake here.
	place_rim()


## Grows the web while the key is held, up to what the body can span.
func _grow_placement(delta: float) -> void:
	if place_capped or place_radius >= _max_place_radius():
		place_capped = true
		_update_placement()
		return
	place_radius = minf(place_radius + _place_growth_rate() * delta,
		_max_place_radius())
	_update_placement()


## Whatever prey is sitting on the line of sight, nearer than the surface the
## crosshair found. Generous about alignment, the way every other pick in the
## game is, because a fly is a small thing to have to centre exactly.
func _prey_under_crosshair() -> Node3D:
	if _view == null or _spider == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var limit := from.distance_to(aim_point)
	var tolerance: float = maxf(_stage().body_height, 0.3)

	var best: Node3D = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		if prey.is_bundled() or prey.is_stuck():
			continue
		var offset := prey.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > limit:
			continue
		var off_axis := (offset - direction * along).length()
		if off_axis > tolerance or off_axis >= best_score:
			continue
		best_score = off_axis
		best = prey
	return best


## Smallest web worth spinning at this size.
func _min_place_radius() -> float:
	return maxf(_stage().body_height * 1.2, 0.2)


## Biggest, before silk has its say. A strand limit is how far one thread can
## span, so a web that wide across is the natural reading of it — using it as
## a radius gave a Huntsman a ten-metre web it could never have paid for.
func _max_place_radius() -> float:
	return maxf(_stage().max_strand_length * 0.5, _min_place_radius() * 2.0)


func _place_growth_rate() -> float:
	return (_max_place_radius() - _min_place_radius()) / maxf(place_grow_time, 0.05)


# --- build mode ---------------------------------------------------------

func toggle() -> void:
	if building:
		stop()
	else:
		start()


func start() -> void:
	if building:
		return
	building = true
	_end_chain()
	if not _is_unlocked(current_pattern()):
		_select_first_unlocked()
	notice.emit("Build mode: %s" % _pattern_name())
	state_changed.emit()


func stop() -> void:
	if not building:
		return
	building = false
	_end_chain()
	problem = Problem.NONE
	state_changed.emit()


## Go to wherever the crosshair is, trailing silk. This is the game's main
## verb and it has no mode around it: moving and building are the same act, so
## the web ends up being a record of where you went.
func place() -> void:
	if placing_design:
		place_design()
		return
	if _awaiting_grapple:
		return
	if current_pattern() == null:
		return
	_update_aim()
	# A line under the cross is taken whatever is behind it, or with nothing behind
	# it at all — strung across open air, there is no surface for the cross to find,
	# and none is needed to take hold of silk that is already there.
	_pending_ride = aimed_line()
	if problem != Problem.NONE and (_pending_ride == null or problem == Problem.LOCKED):
		_pending_ride = null
		notice.emit(problem_text())
		return

	_launched_from = _line_start()
	_launch_anchored = _anchored()
	if _pending_ride != null:
		# Joining a line rather than laying one: no new silk, you just take hold.
		aim_point = aimed_line_point(_pending_ride)
		aim_normal = Vector3.UP
	if not building and _climb != null and _climb.shoots_lines():
		_shoot_line()
		return
	if _climb != null and _climb.grapple_to(aim_point, aim_normal):
		_pending_anchor = aim_point
		_awaiting_grapple = true
		return
	_arrive_at(aim_point)


## The line grapple's whole move: silk from your feet to the cross, and you
## hanging from its near end. Nothing takes you anywhere — W zips you along it, and
## Space or Q lets go.
##
## A line pointed at another line is laid to it, the same as to a wall: with this
## grapple a line is the only way of getting anywhere, so joining one still takes
## one. Fired from the air, the near end is where you are, and you are hanging from
## it — silk is sticky, and a line that left you falling would be no line at all.
func _shoot_line() -> void:
	_pending_ride = null
	var from := _climb.feet() if _launch_anchored else _launched_from
	if from.distance_to(aim_point) < 0.01:
		return
	var strand := _lay_line(from, aim_point)
	if strand == null:
		return
	_climb.clip_on(strand, from)
	_remember_line(strand)
	_loop_source = -1
	state_changed.emit()


func _on_grappled(_point: Vector3, _normal: Vector3) -> void:
	if not _awaiting_grapple:
		return
	_awaiting_grapple = false
	_arrive_at(_pending_anchor)


## Landed. The line behind is the silk dragged on the way, which is all there
## is to building now — no anchor list to keep in your head, no mode to be in.
func _arrive_at(point: Vector3) -> void:
	if _pending_ride != null:
		var line := _pending_ride
		_pending_ride = null
		# You joined a line rather than laying one, so no new silk: you arrive
		# hanging from it, and W zips you along it.
		if is_instance_valid(line) and _climb != null and _climb.clip_on(line, point):
			return
	if building:
		# The scripted run: saved designs and the test suite still walk an
		# explicit ring and weave it with finish().
		add_anchor(point)
		return
	if not _launch_anchored:
		# Fired with nothing under you. The grapple still takes you there — that is
		# the move, and taking it away mid-fall would be taking the controls off
		# you — but there is nothing to tie the near end to, so no line is left.
		_loop_source = -1
		state_changed.emit()
		return
	if _launched_from.distance_to(point) > 0.01:
		_remember_line(_lay_line(_launched_from, point))
	_loop_source = -1
	state_changed.emit()


## Whether the spider has hold of something silk could be tied to: a surface, or
## a line it is already on. Falling and swinging are not the same thing — a swing
## is hanging off silk, which is an anchor.
func _anchored() -> bool:
	if _climb == null:
		return true
	return _climb.is_attached() or _climb.is_hanging() or _climb.is_riding()


## How many lines are up.
func line_count() -> int:
	_forget_dead()
	return _lines.size()


## The lines that are up, oldest first.
func lines() -> Array[WebStrand]:
	_forget_dead()
	return _lines.duplicate()


## The webs that are up, oldest first.
func webs() -> Array[WebNet]:
	_forget_dead_webs()
	return _webs.duplicate()


## Files a line the grapple just left, and takes the oldest down if that put us
## over the limit.
##
## Only grappled lines are counted. The parked frame-walking builder lays its
## own lines through the same function and is allowed a whole frame's worth,
## because a frame is one thing being built rather than a network being kept.
func _remember_line(strand: WebStrand) -> void:
	if strand == null:
		return
	_lines.append(strand)
	_forget_dead()
	var underfoot := _climb.holding_line() if _climb != null else null
	while _lines.size() > MAX_LINES:
		var oldest := _oldest_droppable(underfoot)
		if oldest < 0:
			return
		var going: WebStrand = _lines[oldest]
		_lines.remove_at(oldest)
		going.demolish()
		notice.emit("The oldest line came down")
	state_changed.emit()


## How many webs are standing.
func web_count() -> int:
	_forget_dead_webs()
	return _webs.size()


## Files a web and takes down the oldest **empty** one if that put us over.
##
## Never one with something in it. A web you filled is the thing you went away
## and came back for, and taking it down to make room loses you the catch rather
## than the silk. So if every web is working, none goes: being at the limit
## because all of them are full is a good problem, and not one to answer by
## throwing a meal away.
##
## Oldest first, which is also what makes a saved design safe — its pieces are
## all new, so they are the last things that would ever be dropped, and placing a
## four-piece design clears room ahead of itself rather than eating itself.
func _remember_web(piece: WebStructure) -> void:
	# Nets only. A design can have strand pieces in it, and a strand is a road
	# rather than a site — the frame-walking builder's own lines are already
	# outside the line cap for the same reason, and counting them here would let
	# one design's scaffolding evict another design's larder.
	var web := piece as WebNet
	if web == null:
		return
	_webs.append(web)
	_forget_dead_webs()
	while _webs.size() > MAX_WEBS:
		var going := -1
		for i in _webs.size():
			if _webs[i].snared_count() == 0:
				going = i
				break
		if going < 0:
			return
		var old_web: WebNet = _webs[going]
		_webs.remove_at(going)
		old_web.demolish()
		notice.emit("The oldest empty web came down")
	state_changed.emit()


func _forget_dead_webs() -> void:
	var living: Array[WebNet] = []
	for web in _webs:
		if is_instance_valid(web) and not web.is_queued_for_deletion():
			living.append(web)
	_webs = living


## Drops lines that are already gone — torn, or pulled down by hand.
func _forget_dead() -> void:
	var living: Array[WebStrand] = []
	for strand in _lines:
		if is_instance_valid(strand) and not strand.is_queued_for_deletion():
			living.append(strand)
	_lines = living


## The oldest line that is not the one holding the spider up. Dropping the
## floor out from under the player is the game taking the controls off them,
## which is the one thing it must not do — so the line underfoot is skipped
## however old it is, and the next one goes instead.
func _oldest_droppable(underfoot: WebStrand) -> int:
	for i in _lines.size():
		if _lines[i] != underfoot:
			return i
	return -1


## How far silk sits off the surface it is anchored to.
##
## Enough that a strand drawn with real thickness does not bury half of itself
## in the stone, and no more. It used to be eight per cent of the body on the
## anchor and a fifth of the web's radius on top of that, which put a
## Huntsman's web a third of a metre off the wall it was supposedly stuck to —
## the gap you could see from across the room.
func _silk_clearance() -> float:
	var pattern := current_pattern()
	if pattern == null:
		return 0.004
	return clampf(pattern.strand_thickness * sqrt(_quality()) * 1.5, 0.003, 0.03)


## The plane a web thrown along [param heading] opens in. Faces back the way the
## silk came, unless that is so nearly edge-on to the surface that the web would
## stand out of it like a flag, in which case it leans onto the surface instead.
func _facing_from(heading: Vector3, surface: Vector3) -> Vector3:
	var back := -heading
	if back.length_squared() < 0.000001:
		return surface
	back = back.normalized()
	var square := back.dot(surface)
	if square < 0.2:
		# A grazing hit. Lean it toward the wall so the rim has stone to find.
		back = (back + surface * (0.2 - square) * 2.0).normalized()
	return back


## Where a dragged line starts: the end of a scripted run, or simply where the
## spider is standing.
func _line_start() -> Vector3:
	if building and anchors.size() > 0:
		return anchors[anchors.size() - 1]
	if _spider != null:
		return _spider.global_position
	return aim_point


## Drops an anchor at an explicit world point, laying silk from the last one.
## Grappling calls this on arrival; tests and scripted builds can call it
## directly to skip the journey.
func add_anchor(point: Vector3) -> bool:
	var pattern := current_pattern()
	if not building or pattern == null:
		return false
	if anchors.size() >= max_chain:
		notice.emit("That is as long a run as this silk will take")
		return false
	if anchors.size() > 0:
		if _lay_line(anchors[anchors.size() - 1], point) == null:
			return false
	anchors.append(point)
	state_changed.emit()
	# Came back round to where it started: that encloses something.
	if anchors.size() >= 3 and pattern.shape == WebPattern.Shape.NET \
			and point.distance_to(anchors[0]) <= _snap_radius():
		finish()
	return true


## Strings one frame line and charges for it. This is what walking the frame
## costs — the inside of a web is priced separately, when it is woven.
func _lay_line(from: Vector3, to: Vector3) -> WebStrand:
	var pattern := drag_pattern()
	if pattern == null:
		return null
	var dials := tuning_for(pattern)
	var strand := WebStrand.spin(dials.apply_to(pattern), from, to, _quality())
	if strand == null:
		notice.emit("That line has nowhere to go")
		return null
	strand.tuning = dials.copy()
	strand.place_in(_resolve_container())
	_chain.append(strand)
	_loop_source = -1
	web_built.emit(strand)
	return strand


## What gets dragged between anchors: the chosen pattern if it is a strand,
## otherwise plain frame line waiting to be woven into.
func drag_pattern() -> WebPattern:
	var pattern := current_pattern()
	if pattern != null and pattern.shape == WebPattern.Shape.STRAND:
		return pattern
	return _pattern_by_id(FRAME_PATTERN)


## Takes the last anchor back, pulling its line down, or leaves build mode.
func undo() -> void:
	if placing_design:
		toggle_design_mode()
		return
	if not building:
		return
	if anchors.is_empty():
		stop()
		notice.emit("Build mode off")
		return
	if not _chain.is_empty():
		var strand: WebStrand = _chain.pop_back()
		if is_instance_valid(strand):
			strand.demolish()
	anchors.remove_at(anchors.size() - 1)
	state_changed.emit()


## Closes the loop and weaves the inside of it. The frame is already up — the
## spider walked it — so only the silk inside is spun and paid for here.
func finish() -> void:
	if not building:
		return
	var pattern := current_pattern()
	if pattern == null:
		return

	if pattern.shape == WebPattern.Shape.STRAND:
		var laid := _chain.size()
		_end_chain()
		notice.emit("%d line%s laid" % [laid, "" if laid == 1 else "s"])
		return

	if anchors.size() < 3:
		# Not walking a run: weave whatever ring is under the crosshair instead.
		if fill_aimed_loop():
			_end_chain()
			return
		notice.emit("Walk three anchors, or look at a ring of silk")
		return

	# Close the ring if the spider has not already walked back to the start.
	var last := anchors[anchors.size() - 1]
	if last.distance_to(anchors[0]) > _snap_radius():
		if _lay_line(last, anchors[0]) == null:
			return

	var dials := tuning_for(pattern)
	var web := WebNet.spin(dials.apply_to(pattern), anchors, _quality(), weave, false)
	if web == null:
		notice.emit("Nothing to weave in there")
		_end_chain()
		return

	web.tuning = dials.copy()
	web.place_in(_resolve_container())
	_remember_web(web)
	_end_chain()
	state_changed.emit()
	web_built.emit(web)
	notice.emit("%s woven" % pattern.display_name)


## Area the current chain encloses, or zero if it does not enclose anything.
func enclosed_area() -> float:
	if anchors.size() < 3:
		return 0.0
	var normal := WebGeometry.plane_normal(anchors)
	var total := Vector3.ZERO
	for i in anchors.size():
		total += anchors[i].cross(anchors[(i + 1) % anchors.size()])
	return absf(total.dot(normal)) * 0.5


func _end_chain() -> void:
	anchors.clear()
	_chain.clear()
	_awaiting_grapple = false


func cycle(step: int) -> void:
	if placing_design:
		cycle_design(step)
		return
	var available := unlocked_patterns()
	if available.size() <= 1:
		return
	var current := current_pattern()
	var index := available.find(current)
	index = wrapi(index + step, 0, available.size())
	pattern_index = patterns.find(available[index])
	anchors.clear()
	state_changed.emit()
	notice.emit(_pattern_name())


## Dials for a pattern, made on demand the first time it is asked for.
func tuning_for(pattern: WebPattern) -> WebTuning:
	if pattern == null:
		return WebTuning.new()
	if not tunings.has(pattern.id):
		tunings[pattern.id] = WebTuning.new()
	return tunings[pattern.id]


## Dials for the pattern on the end of the cursor.
func current_tuning() -> WebTuning:
	return tuning_for(current_pattern())


## Flips between the two ways of weaving the inside of a web.
func toggle_weave() -> void:
	weave = WebGeometry.Weave.INSCRIBED if weave == WebGeometry.Weave.STRETCHED \
		else WebGeometry.Weave.STRETCHED
	state_changed.emit()
	notice.emit("Weave: %s" % weave_name())


func weave_name() -> String:
	if weave == WebGeometry.Weave.INSCRIBED:
		return "inscribed — even spiral inside the frame"
	return "stretched — the web is the shape you drew"


## Points the tuning keys at the next dial along.
func cycle_dial(step: int) -> void:
	var count := WebTuning.DIAL_NAMES.size()
	selected_dial = wrapi(selected_dial + step, 0, count) as WebTuning.Dial
	state_changed.emit()
	notice.emit(WebTuning.DIAL_HINTS[selected_dial])


## Turns the selected dial. Every one of them costs something to gain
## something, so there is no setting that is simply better.
func adjust_dial(step: int) -> void:
	var pattern := current_pattern()
	if pattern == null:
		return
	var tuning := tuning_for(pattern)
	if not tuning.nudge(selected_dial, step):
		notice.emit("%s is as far as it goes" % WebTuning.DIAL_NAMES[selected_dial])
		return
	state_changed.emit()
	notice.emit("%s   %s" % [tuning.bar(selected_dial), tuning.hint(selected_dial)])


## Puts every dial on this pattern back to the middle.
func reset_dials() -> void:
	var pattern := current_pattern()
	if pattern == null:
		return
	tunings[pattern.id] = WebTuning.new()
	state_changed.emit()
	notice.emit("%s dials back to standard" % pattern.display_name)


## The pattern as it would actually be spun right now, dials included.
func tuned_pattern() -> WebPattern:
	var pattern := current_pattern()
	if pattern == null:
		return null
	return tuning_for(pattern).apply_to(pattern)


func current_pattern() -> WebPattern:
	if patterns.is_empty():
		return null
	return patterns[clampi(pattern_index, 0, patterns.size() - 1)]


func unlocked_patterns() -> Array[WebPattern]:
	var available: Array[WebPattern] = []
	for pattern in patterns:
		if _is_unlocked(pattern):
			available.append(pattern)
	return available


# --- saved designs ------------------------------------------------------

func current_design() -> WebDesign:
	if designs.is_empty():
		return null
	return designs[clampi(design_index, 0, designs.size() - 1)]


## Records the rig under the crosshair — the web plus everything wired to it —
## as a design that can be put down again anywhere.
func save_aimed_design() -> WebDesign:
	var web := aimed_web()
	if web == null:
		notice.emit("Look at a web to keep it as a design")
		return null
	var design := DesignLibrary.capture(web, _facing(), _growth.stage_index)
	if design == null:
		notice.emit("Nothing there worth keeping")
		return null
	design.display_name = _unique_design_name(design.display_name)
	if not DesignLibrary.store(design):
		notice.emit("Could not save that design")
		return null
	designs.append(design)
	design_index = designs.size() - 1
	state_changed.emit()
	notice.emit("Kept \"%s\" — %d web%s" % [design.display_name, design.piece_count(),
		"" if design.piece_count() == 1 else "s"])
	return design


func toggle_design_mode() -> void:
	if placing_design:
		placing_design = false
		state_changed.emit()
		notice.emit("Designs away")
		return
	if designs.is_empty():
		notice.emit("No saved designs yet — look at a web and press B to keep one")
		return
	stop()
	placing_design = true
	state_changed.emit()
	notice.emit(current_design().summary())


func cycle_design(step: int) -> void:
	if designs.size() <= 1:
		return
	design_index = wrapi(design_index + step, 0, designs.size())
	state_changed.emit()
	notice.emit(current_design().summary())


## Where the selected design would land right now: turned to face the way the
## player is looking, and pushed clear of the surface rather than half inside it.
func design_transform() -> Transform3D:
	var design := current_design()
	var frame := DesignLibrary.yaw_basis(_facing())
	if design == null:
		return Transform3D(frame, aim_point)
	var local_normal := frame.transposed() * aim_normal
	var origin := aim_point + aim_normal * design.extent_along(local_normal)
	return Transform3D(frame, origin)


## Spins a whole saved rig where the player is looking, wiring included.
## Nothing is charged, and nothing is placed, unless all of it can be built.
func place_design() -> bool:
	var design := current_design()
	if design == null:
		return false
	if not aim_valid:
		notice.emit("Nowhere to put that")
		return false

	var placement := design_transform()
	var quality := _quality()
	var spun: Array[WebStructure] = []
	var centres := PackedVector3Array()
	var total := 0.0

	for piece in design.piece_count():
		var pattern := _pattern_by_id(design.pattern_ids[piece])
		if pattern == null:
			return _abandon(spun, "That design uses silk you no longer have a recipe for")
		if not _is_unlocked(pattern):
			return _abandon(spun, "%s needs a bigger spider" % pattern.display_name)
		var points := PackedVector3Array()
		var centre := Vector3.ZERO
		for local in design.anchors_for(piece):
			var world: Vector3 = placement * local
			points.append(world)
			centre += world
		if points.size() < pattern.min_anchors:
			return _abandon(spun, "That design is missing anchors")
		centres.append(centre / float(points.size()))

		var dials := design.tuning_for(piece)
		var tuned := dials.apply_to(pattern)
		var web: WebStructure = null
		if tuned.shape == WebPattern.Shape.STRAND:
			web = WebStrand.spin(tuned, points[0], points[1], quality)
		else:
			web = WebNet.spin(tuned, points, quality, design.weave_for(piece))
		if web == null:
			return _abandon(spun, "That design won't hold together there")
		web.tuning = dials
		spun.append(web)

	var container := _resolve_container()
	for web in spun:
		web.place_in(container)
	for i in design.link_count():
		spun[design.link_from[i]].link_to(spun[design.link_to[i]])
	# After the links, not during placement: pruning mid-design could take down a
	# piece the next line is about to wire something to.
	for web in spun:
		_remember_web(web)

	notice.emit("%s spun (%d silk)" % [design.display_name, roundi(total)])
	web_built.emit(spun[0])
	return true


## Throws away a half-built rig without charging for it.
func _abandon(spun: Array[WebStructure], reason: String) -> bool:
	for web in spun:
		web.free()
	notice.emit(reason)
	return false


func _pattern_by_id(id: String) -> WebPattern:
	for pattern in patterns:
		if pattern.id == id:
			return pattern
	return null


func _unique_design_name(base: String) -> String:
	var taken := PackedStringArray()
	for design in designs:
		taken.append(design.display_name)
	if not taken.has(base):
		return base
	var suffix := 2
	while taken.has("%s %d" % [base, suffix]):
		suffix += 1
	return "%s %d" % [base, suffix]


## Direction the player is looking, flattened later into the design's forward.
func _facing() -> Vector3:
	return _view.aim_forward() if _view != null else Vector3.FORWARD


# --- rings of silk ------------------------------------------------------

## Every area the player's silk currently encloses, anywhere in the world.
## Lines count as joined where they cross as well as where they share an end,
## so three strands slung across a gap enclose the triangle in the middle.
func loops() -> Array:
	var strands: Array = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand != null and not strand.is_queued_for_deletion():
			strands.append(strand)
	if strands.size() != _loop_source:
		_loop_source = strands.size()
		_loops = WebGraph.find_loops(strands, _merge_radius())
	return _loops


## The ring under the crosshair, if there is one.
func aimed_loop():
	if _view == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var reach := _stage().anchor_range * 4.0
	var best = null
	var best_score := 1.0
	for loop in loops():
		var offset: Vector3 = loop.centre - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > reach:
			continue
		var miss := (offset - direction * along).length()
		var score: float = miss / maxf(loop.radius, 0.001)
		if score < best_score:
			best_score = score
			best = loop
	return best


## Weaves the ring under the crosshair. The silk around it is already up, so
## only the inside is spun and charged for.
func fill_aimed_loop() -> bool:
	var loop = aimed_loop()
	if loop == null:
		return false
	var pattern := current_pattern()
	if pattern == null or pattern.shape != WebPattern.Shape.NET:
		return false
	var dials := tuning_for(pattern)
	var web := WebNet.spin(dials.apply_to(pattern), loop.points, _quality(), weave, false)
	if web == null:
		notice.emit("Nothing to weave in there")
		return false
	web.tuning = dials.copy()
	web.place_in(_resolve_container())
	_remember_web(web)
	_loop_source = -1
	state_changed.emit()
	web_built.emit(web)
	notice.emit("%s woven into the ring" % pattern.display_name)
	return true


## How close two bits of silk have to be to count as touching.
func _merge_radius() -> float:
	return maxf(_stage().body_height * 0.5, 0.05)


# --- trigger links ------------------------------------------------------

## Wires one web to another, a press at each end. A web that is wired up sets
## off whatever hangs off it — a tripline across a doorway springing a snare on
## the other side of the room — which is how a pile of webs becomes a machine.
func toggle_link() -> void:
	var node := aimed_node()

	if link_source == null:
		if node == null:
			notice.emit("Look at a web or a device to wire it up")
			return
		if not node.can_signal():
			notice.emit("A %s never has anything to report" % node.label())
			return
		link_source = node
		notice.emit("Wiring from the %s — now look at what it should set off"
			% node.label())
		state_changed.emit()
		return

	var source := link_source
	link_source = null
	state_changed.emit()

	if node == null or node == source:
		notice.emit("Wiring cancelled")
		return
	link_nodes(source, node)


## Runs a signal line between two specific things, skipping the aiming. Both
## ends are [SilkNode]s, so a web setting off a device and a device setting off
## a web cost and behave exactly the same. Returns false, and spends nothing,
## if the pair cannot be wired or cannot be paid for.
func link_nodes(source: SilkNode, target: SilkNode) -> bool:
	if source == null or not is_instance_valid(source):
		notice.emit("That end of the line is gone")
		return false
	if target == null or not is_instance_valid(target):
		notice.emit("Nothing there to set off")
		return false
	if not source.can_signal():
		notice.emit("A %s never has anything to report" % source.label())
		return false
	if not target.can_receive_signal():
		notice.emit("A %s can't do anything with a signal" % target.label())
		return false
	if not source.can_link_to(target):
		notice.emit("Those two are already wired together")
		return false

	source.link_to(target)
	notice.emit("%s now sets off the %s" % [source.label(), target.label()])
	return true


## Forgets a half-finished wiring job.
func cancel_link() -> void:
	if link_source == null:
		return
	link_source = null
	state_changed.emit()
	notice.emit("Wiring cancelled")


func is_linking() -> bool:
	return link_source != null and is_instance_valid(link_source)


# --- existing webs ------------------------------------------------------

## A line under the crosshair, close enough to grapple onto and ride. Silk is
## thin, so this is a proximity-to-the-ray pick like every other one.
##
## Measured along the crosshair's own ray — the one through the pivot, see
## [method SpiderCamera.aim_pivot] — because that is the ray you see the line
## under. Nothing stops on a line, so the aim runs on through it to whatever is
## behind, and in third person the spider sees that from below the camera:
## measured from the spider, a line with the floor a long way behind it sat a body
## height or more over the aim, and the cross on it picked nothing. Held, still,
## to lines in front of the surface the cross is on, and in silk's reach of the
## spider.
func aimed_line() -> WebStrand:
	if _view == null or building:
		# A scripted anchor run is placing anchors, not looking for a lift.
		return null
	var eye := _view.aim_pivot()
	var look := _view.forward()
	var height := _stage().body_height
	var reach := silk_reach()
	var span := _crosshair_span(eye, look, reach)
	var spider_at := _view.aim_origin()

	var best: WebStrand = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand == null or not is_instance_valid(strand) or strand.is_queued_for_deletion():
			continue
		var pair := Geometry3D.get_closest_points_between_segments(
			eye, eye + look * span, strand.point_a, strand.point_b)
		var along := (pair[0] - eye).dot(look)
		if along <= height or spider_at.distance_to(pair[1]) > reach:
			continue
		# Silk is a couple of centimetres across, so a fixed tolerance is either
		# impossible to aim at or steals every grapple. Scale it with distance
		# instead: a fixed slice of the screen, roughly a crosshair's width, which
		# is how wide the line actually looks when you are pointing at it.
		# Capped, though, or a fixed slice of the screen turns into metres of world
		# space at range: at forty metres 5.5% is over two metres, and a click meant
		# for the wall behind a line would be quietly stolen by the line.
		var tolerance: float = clampf(along * 0.055, height * 0.5, height * 2.0)
		var gap := pair[0].distance_to(pair[1])
		if gap > tolerance or gap >= best_score:
			continue
		best_score = gap
		best = strand
	return best


## Where on [param line] the cross is: the point of it nearest the crosshair's ray.
func aimed_line_point(line: WebStrand) -> Vector3:
	if _view == null or line == null:
		return aim_point
	var eye := _view.aim_pivot()
	var look := _view.forward()
	var pair := Geometry3D.get_closest_points_between_segments(eye,
		eye + look * _crosshair_span(eye, look, silk_reach()), line.point_a, line.point_b)
	return pair[1]


## How far down the crosshair's ray from [param eye] a line can be and still be
## what the cross is on: up to the first surface on it — a body height past, for a
## line tied to that surface — and no further than [param reach] past the spider.
func _crosshair_span(eye: Vector3, look: Vector3, reach: float) -> float:
	var longest := eye.distance_to(_view.aim_origin()) + reach
	var query := PhysicsRayQueryParameters3D.create(eye, eye + look * longest,
		GameLayers.WORLD | GameLayers.WEB_WALK, _exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return longest
	return minf(eye.distance_to(hit["position"]) + _stage().body_height, longest)


## The wireable thing under the crosshair — a device if one is right there,
## otherwise a web. Devices win ties on purpose: they are small and deliberately
## placed, so if one is under the crosshair you meant it, even sitting on a web.
func aimed_node() -> SilkNode:
	if _view == null:
		return null
	var device := SilkDevice.aimed_from(get_tree(), _view.aim_origin(),
		_view.aim_forward(), _stage().anchor_range,
		maxf(_stage().body_height * 0.8, 0.25))
	if device != null:
		return device
	return aimed_web()


## The web the player is looking at, if any. Tolerant, because silk is thin.
func aimed_web() -> WebStructure:
	if _view == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var reach := _stage().anchor_range

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach,
		GameLayers.WEB, _exclusions())
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var web := _web_from(hit.get("collider"))
		if web != null:
			return web

	# Fall back to the closest web near the line of sight.
	var best: WebStructure = null
	var best_score := INF
	var tolerance: float = maxf(0.35, _stage().body_height)
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null:
			continue
		var offset := web.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > reach:
			continue
		var distance := (offset - direction * along).length()
		var span := tolerance
		var net := web as WebNet
		if net != null:
			span += net.radius
		if distance > span:
			continue
		if distance < best_score:
			best_score = distance
			best = web
	return best


## Pulls down the web under the crosshair. True if there was one.
func demolish_aimed() -> bool:
	var web := aimed_web()
	if web == null:
		notice.emit("Nothing to pull down")
		return false
	var label := web.pattern.display_name
	web.demolish()
	_loop_source = -1
	notice.emit("%s pulled down" % label)
	return true


# --- aiming -------------------------------------------------------------

func _update_aim() -> void:
	var pattern := current_pattern()
	aim_valid = false
	problem = Problem.NO_SURFACE
	if pattern == null:
		return
	if not _is_unlocked(pattern):
		problem = Problem.LOCKED
		return

	var stage := _stage()
	# A scripted run stays inside the tier's anchor range; free grappling gets
	# the silk reach, which is the same distance a throw travels.
	var reach := stage.anchor_range if building else silk_reach()
	if not _cast_surface(reach):
		return
	problem = Problem.NONE

	if building and anchors.size() >= pattern.max_anchors:
		problem = Problem.FULL
		return
	# A scripted run measures from its last anchor and is held to the span
	# limit. Free grappling measures from the spider, and the cast above already
	# held it to the reach.
	if building and anchors.is_empty():
		return

	var span := _line_start().distance_to(aim_point)
	if building and span > stage.max_strand_length:
		problem = Problem.TOO_FAR
		return
	if span < stage.body_height * 0.25:
		problem = Problem.TOO_CLOSE
		return




## Design placement only needs somewhere solid to sit against, not the anchor
## rules that govern spinning a web by hand.
func _update_design_aim() -> void:
	aim_valid = false
	problem = Problem.NO_SURFACE
	var design := current_design()
	if design == null:
		return
	if not _cast_surface(_stage().anchor_range):
		return
	problem = Problem.NONE


## Raycast down the crosshair for a surface. Fills in the aim fields.
func _cast_surface(reach: float) -> bool:
	if _view == null:
		return false
	var from := _view.aim_origin()
	var to := from + _view.aim_forward() * reach
	var space := get_world_3d().direct_space_state
	# Silk is something to anchor to as well as something to stand on.
	var query := PhysicsRayQueryParameters3D.create(from, to,
		GameLayers.WORLD | GameLayers.WEB_WALK, _exclusions())
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	aim_point = hit["position"]
	aim_normal = hit.get("normal", Vector3.UP)
	# Off the surface by the width of a strand, so silk does not z-fight the
	# wall — and by no more than that, so it reads as stuck to it.
	aim_point += aim_normal * _silk_clearance()
	aim_valid = true
	return true


func _polygon_area(points: PackedVector3Array) -> float:
	var normal := WebGeometry.plane_normal(points)
	var total := Vector3.ZERO
	for i in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return absf(total.dot(normal)) * 0.5


# --- text for the HUD ---------------------------------------------------

func problem_text() -> String:
	match problem:
		Problem.NO_SURFACE:
			# With the number, because the number is the thing that grows. "No
			# surface in reach" reads as a broken click; "nothing within thirteen
			# metres" reads as somewhere to come back to when you are bigger.
			return "Nothing within %.0fm — grow to reach further" % silk_reach()
		Problem.TOO_FAR:
			return "Too far to span — %.1fm limit" % _stage().max_strand_length
		Problem.TOO_CLOSE:
			return "Too close to the last anchor"
		Problem.FULL:
			return "Anchors full — press F to spin"
		Problem.LOCKED:
			return "%s needs a bigger spider" % _pattern_name()
	return ""


func hint_text() -> String:
	if placing_design:
		return "Left mouse to spin it here, wheel to change design, right mouse to put it away"
	if not building:
		return ""
	var pattern := current_pattern()
	if pattern == null:
		return ""
	if pattern.shape == WebPattern.Shape.STRAND:
		return "Click to grapple across, dragging %s   ·   F to stop" % pattern.display_name
	if anchors.size() < 3:
		var ring = aimed_loop()
		if ring != null:
			return "F to weave this ring — %.2f m² enclosed" % ring.area
		return "Click to grapple — %d anchor%s of 3" % [anchors.size(),
			"" if anchors.size() == 1 else "s"]
	return "Encloses %.2f m² — F to weave, or grapple back to the first anchor" \
		% enclosed_area()


# --- internals ----------------------------------------------------------

func _pattern_name() -> String:
	var pattern := current_pattern()
	return pattern.display_name if pattern != null else "—"


func _stage() -> GrowthStage:
	if _growth == null:
		return GrowthStage.new()
	return _growth.current_stage()


func _quality() -> float:
	return _stage().silk_quality


func _is_unlocked(pattern: WebPattern) -> bool:
	if pattern == null:
		return false
	if _growth == null:
		return pattern.unlock_stage == 0
	return pattern.is_unlocked_at(_growth.stage_index)


## The wheel has to start on something Q can actually spin. It used to start
## on whatever sorted first — frame line, which is a strand — and entering
## build mode was what quietly fixed that. Taking build mode away left the
## wheel parked on a pattern the place key refuses, so holding Q did nothing
## whatsoever and said so in a toast that is easy to miss.
func _select_first_spinnable() -> void:
	for i in patterns.size():
		if patterns[i].shape == WebPattern.Shape.NET and _is_unlocked(patterns[i]):
			pattern_index = i
			return
	_select_first_unlocked()


func _select_first_unlocked() -> void:
	for i in patterns.size():
		if _is_unlocked(patterns[i]):
			pattern_index = i
			return


func _snap_radius() -> float:
	return maxf(_stage().body_height * 0.8, _stage().max_strand_length * 0.12)


func _exclusions() -> Array[RID]:
	var list: Array[RID] = []
	if _spider != null:
		list.append(_spider.get_rid())
	return list


func _web_from(collider: Variant) -> WebStructure:
	var node := collider as Node
	while node != null:
		var web := node as WebStructure
		if web != null:
			return web
		node = node.get_parent()
	return null


func _resolve_container() -> Node3D:
	var container := get_node_or_null(web_container_path) as Node3D
	if container != null:
		return container

	# Otherwise keep webs tidy under a "Webs" node in the level, making one if
	# the level hasn't got around to providing it.
	var host := get_tree().current_scene
	if host == null and _spider != null:
		host = _spider.get_parent()
	if host == null:
		host = get_parent()

	container = host.get_node_or_null("Webs") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Webs"
		host.add_child(container)
	return container


func _build_preview_nodes() -> void:
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.vertex_color_use_as_albedo = true
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.no_depth_test = true
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_preview_mesh = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.name = "BuildPreview"
	_preview.mesh = _preview_mesh
	_preview.material_override = _preview_material
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.top_level = true
	add_child(_preview)
	_preview.transform = Transform3D.IDENTITY

	_cursor_material = StandardMaterial3D.new()
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_material.no_depth_test = true
	_cursor_mesh = SphereMesh.new()
	_cursor_mesh.radial_segments = 8
	_cursor_mesh.rings = 4
	_cursor = MeshInstance3D.new()
	_cursor.name = "AnchorCursor"
	_cursor.mesh = _cursor_mesh
	_cursor.material_override = _cursor_material
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.top_level = true
	add_child(_cursor)
	_cursor.visible = false


func _draw_preview() -> void:
	_preview_mesh.clear_surfaces()
	if placing:
		_draw_place_ghost()
		return
	if placing_design:
		_draw_design_ghost()
		return
	var pattern := current_pattern()
	if pattern == null:
		return

	var good := pattern.color
	good.a = 1.0
	var bad := Color(1.0, 0.35, 0.3, 1.0)
	var line_color := good if problem == Problem.NONE else bad
	var tick: float = maxf(_stage().body_height * 0.35, 0.03)

	# Nothing being walked: show the ring under the crosshair instead.
	if anchors.is_empty() and pattern.shape == WebPattern.Shape.NET:
		var ring = aimed_loop()
		if ring != null:
			_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
			var ring_colour := Color(0.6, 1.0, 0.7, 1.0)
			for i in ring.points.size():
				_line(ring.points[i], ring.points[(i + 1) % ring.points.size()], ring_colour)
				_line(ring.centre, ring.points[i], Color(0.6, 1.0, 0.7, 0.3))
			_preview_mesh.surface_end()

	var points := anchors.duplicate()
	if points.is_empty() and not building and aim_valid:
		# Free grappling: the line you would leave runs from where you stand.
		points.append(_line_start())
	if aim_valid:
		points.append(aim_point)

	# One lone aim point draws no lines — only the cursor below — and opening an
	# empty surface is an error.
	if points.size() >= 2 or anchors.size() >= 1:
		_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
		for i in range(points.size() - 1):
			var colour := line_color if i == points.size() - 2 else good
			_line(points[i], points[i + 1], colour)
		if pattern.shape == WebPattern.Shape.NET and points.size() >= 3:
			var closing := good
			closing.a = 0.4
			_line(points[points.size() - 1], points[0], closing)
		for anchor in anchors:
			_cross(anchor, tick, good)
		_preview_mesh.surface_end()

	_cursor.visible = aim_valid
	if aim_valid:
		_cursor_mesh.radius = tick * 0.5
		_cursor_mesh.height = tick
		_cursor_material.albedo_color = Color(line_color.r, line_color.g, line_color.b, 0.7)
		_cursor.global_position = aim_point


## The web about to be spun, growing while the key is held.
func _draw_place_ghost() -> void:
	_cursor.visible = false
	if not place_valid and not throwing:
		return
	var rim := place_charge_ring() if throwing else place_rim()
	if rim.size() < 3:
		return
	var pattern := current_pattern()
	var tint: Color = pattern.color if pattern != null else Color(1, 1, 1, 1)
	tint.a = 1.0
	var spoke := Color(tint.r, tint.g, tint.b, 0.35)
	var hub := place_charge_centre() if throwing else place_centre
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
	for i in rim.size():
		_line(rim[i], rim[(i + 1) % rim.size()], tint)
		_line(hub, rim[i], spoke)
	_preview_mesh.surface_end()


## Ghost of a saved rig where it would land, so the player can line it up
## before spending anything.
func _draw_design_ghost() -> void:
	var design := current_design()
	_cursor.visible = aim_valid and design != null
	if design == null or not aim_valid:
		return

	var placement := design_transform()
	var color := Color(0.85, 0.95, 1.0, 1.0)
	if problem != Problem.NONE:
		color = Color(1.0, 0.35, 0.3, 1.0)
	var faint := Color(color.r, color.g, color.b, 0.3)

	var centres := PackedVector3Array()
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
	for piece in design.piece_count():
		var world := PackedVector3Array()
		var centre := Vector3.ZERO
		for local in design.anchors_for(piece):
			var point: Vector3 = placement * local
			world.append(point)
			centre += point
		if world.is_empty():
			centres.append(placement.origin)
			continue
		centre /= float(world.size())
		centres.append(centre)
		if world.size() == 2:
			_line(world[0], world[1], color)
			continue
		for i in world.size():
			_line(world[i], world[(i + 1) % world.size()], color)
			_line(centre, world[i], faint)
	for i in design.link_count():
		_line(centres[design.link_from[i]], centres[design.link_to[i]],
			Color(0.5, 0.8, 1.0, 0.7))
	_preview_mesh.surface_end()

	var tick: float = maxf(_stage().body_height * 0.35, 0.03)
	_cursor_mesh.radius = tick * 0.5
	_cursor_mesh.height = tick
	_cursor_material.albedo_color = Color(color.r, color.g, color.b, 0.7)
	_cursor.global_position = aim_point


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_preview_mesh.surface_set_color(color)
	_preview_mesh.surface_add_vertex(a)
	_preview_mesh.surface_set_color(color)
	_preview_mesh.surface_add_vertex(b)


func _cross(point: Vector3, size: float, color: Color) -> void:
	_line(point - Vector3.RIGHT * size, point + Vector3.RIGHT * size, color)
	_line(point - Vector3.UP * size, point + Vector3.UP * size, color)
	_line(point - Vector3.BACK * size, point + Vector3.BACK * size, color)
