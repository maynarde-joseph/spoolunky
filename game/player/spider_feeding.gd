class_name SpiderFeeding
extends Node

## Drinking a creature dry, a mouthful a frame while the key is held.
##
## Lived inside [SpiderPlayer] until now, which made it the one subsystem that was
## not a component — climbing, growing, the camera, the bag, the tether, the
## builder and the traits are all their own node, and this was two hundred lines
## in the middle of the player. It is the loop the whole game hangs off, so it is
## worth being able to read on its own.

## Said out loud to the player. The spider passes these through.
signal notice(text: String)

## Biomass swallowed per second, at a bite power of one.
##
## A meal is a few seconds you spend standing still, and that is the whole point
## of it: eating used to be one click and instantly over, which meant nowhere was
## safer than anywhere else and a web was decoration.
##
## Scaled by the *square root* of bite power rather than by bite power, so a meal
## stays a few seconds the whole way up the ladder. Scaled linearly it cancelled
## out against the bigger prey a bigger spider eats and then overtook it — an
## Architect swallowed a beetle in under a second, and the loop this exists to
## create quietly dissolved at the top of the game.
@export var feed_rate := 3.4

@export var input_interact := "interact"

## How long a bite's venom works for, in seconds.
@export var venom_time := 8.0

## How close the fangs have to get. A share of how far silk reaches, so it grows
## with the spider like everything else — and short enough that closing the
## distance is the move rather than a formality.
@export_range(0.1, 1.0, 0.05) var lunge_reach := 0.7

## What is being drunk, or null. A meal now spans frames, so this is state rather
## than the result of a call.
var meal: Prey = null

var _spider: SpiderPlayer
var _growth: SpiderGrowth
var _traits: SpiderTraits
var _view: SpiderCamera
var _tether: SilkTether
var _taken := 0.0
var _species := ""

## What this lunge was aimed at, while the spider is still in the air.
var _quarry: Prey = null


func setup(spider: SpiderPlayer, growth: SpiderGrowth, traits: SpiderTraits,
		view: SpiderCamera, tether: SilkTether) -> void:
	_spider = spider
	_growth = growth
	_traits = traits
	_view = view
	_tether = tether
	if _spider.climb != null and not _spider.climb.grappled.is_connected(_on_landed):
		_spider.climb.grappled.connect(_on_landed)


## How far the fangs go. One definition, because it used to be written out twice —
## once for picking what the crosshair is on and once for deciding whether a meal
## is still in reach — and two copies of a number that has to agree is one copy
## too many.
func fang_reach() -> float:
	var current := _spider.stage()
	return maxf(current.reach * 2.5, current.body_height * 4.0)


## What the crosshair is on, if it is on a creature at all.
##
## [param within] defaults to fang reach, which is what eating wants. A lunge
## looks further, because the point of it is to cross the gap.
func aimed_prey(within := -1.0) -> Prey:
	var origin := _view.aim_origin()
	var forward := _view.aim_forward()
	var limit: float = within if within > 0.0 else fang_reach()

	var best: Prey = null
	var best_dot := 0.82
	for node in _spider.get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		var offset := prey.global_position - origin
		var distance := offset.length()
		if distance > limit or distance < 0.0001:
			continue
		var alignment := offset.normalized().dot(forward)
		if alignment > best_dot:
			best_dot = alignment
			best = prey
	return best


## What the interact key does: eat what you are looking at, or reset a sprung
## snare, or say there is nothing there.
func interact() -> void:
	var prey := aimed_prey()
	if prey != null:
		handle(prey)
		return

	var web := _spider.web_builder.aimed_web()
	if web != null and web.needs_rearm():
		web.rearm()
		notice.emit("Snare set again")
		return

	notice.emit("Nothing in reach")


## One press against one creature. Which of the three things it does depends on
## how big the creature is and whether it is already caught.
func handle(prey: Prey) -> void:
	var current := _spider.stage()
	if prey.size_class > current.bite_power and not prey.subdued:
		notice.emit("The %s is too big for you — grow first" % prey.species)
		return

	if prey.wrapped:
		begin(prey)
		return

	if prey.is_stuck():
		prey.wrap()
		notice.emit("Wrapped the %s" % prey.species)
		return

	# Much bigger than it? Then you can simply take it. Fangs halve what
	# "much" means: anything inside your bite power goes down where it stands,
	# which is the whole point of the venom branch — a kill that needs no web.
	var margin := 1 if _traits != null and _traits.has_fangs() else 2
	if current.bite_power >= prey.size_class * margin:
		begin(prey)
		return

	notice.emit("The %s isn't caught — get it into a web" % prey.species)


## Starts a meal. It finishes when the creature is empty or when you let go.
func begin(prey: Prey) -> bool:
	if prey == null or not is_instance_valid(prey) or prey.eaten:
		return false
	meal = prey
	_taken = 0.0
	_species = prey.species
	# Said on the way in, because a tap now takes a mouthful rather than the
	# whole creature, and without this a tap would look like nothing happened.
	notice.emit("Feeding on the %s — hold to drink" % prey.species)
	return true


## A mouthful a frame, while the key is held.
##
## What is being drained is either what the crosshair is on or **whatever is on
## your line**, at any distance: silk is a straw, and drinking down your own
## dragline is what makes eating on the move possible at all. That is the whole
## loop — take it, tether it, run, and drink on the way.
func drink(delta: float) -> void:
	if meal == null:
		return
	if not is_instance_valid(meal) or meal.eaten:
		stop()
		return
	if not _spider.accepts_input() or not Input.is_action_pressed(input_interact):
		stop()
		return
	if not within_reach(meal):
		stop("Out of reach — it has to be on your line or under the cross")
		return

	var yield_scale := _traits.drain_scale() if _traits != null else 1.0
	var swallowed := meal.drain(feed_rate * gulp() * delta)
	if swallowed <= 0.0:
		return
	var food := swallowed * yield_scale
	_taken += food
	# Banked as it comes, not at the end, so half a meal is half a meal. Fed
	# quietly: a notice a frame would bury everything else the HUD has to say.
	if _growth.feed(food, _species) > 0:
		_taken = 0.0
	# The larder counts creatures, not mouthfuls, so it is paid on the last one.
	if meal.eaten:
		if _traits != null:
			_traits.record(meal.kind)
		stop()


## How much faster a bigger mouth drinks: the square root of its bite, so the
## curve flattens instead of running away. See [member feed_rate].
func gulp() -> float:
	return sqrt(maxf(_spider.stage().bite_power, 1))


## Whether a meal is close enough to keep drinking. On the line counts at any
## length; anything else has to be within reach of the fangs.
##
## A web on the line counts too, for everything caught in it. That is what reeling
## one in is for: you pull the larder to somewhere safe and drink it there, rather
## than standing out in the open next to it.
func within_reach(prey: Prey) -> bool:
	if _tether == null:
		return _spider.global_position.distance_to(prey.global_position) <= fang_reach()
	if _tether.cargo == prey:
		return true
	var web := prey.held_by()
	if web != null and _tether.cargo == web:
		return true
	return _spider.global_position.distance_to(prey.global_position) <= fang_reach()


## Ends the meal, and says what came of it unless [param reason] says why it was
## cut short instead.
func stop(reason := "") -> void:
	var species := _species
	var got := _taken
	var finished := meal == null or not is_instance_valid(meal) or meal.eaten
	meal = null
	_taken = 0.0
	if reason != "":
		notice.emit(reason)
		return
	if got < 0.05:
		return
	if finished:
		notice.emit("Drained the %s  +%d biomass" % [species, roundi(got)])
	else:
		notice.emit("Half a %s  +%d biomass — the rest is still there"
			% [species, roundi(got)])


# --- going after it -------------------------------------------------------

## Throws the spider at what the crosshair is on and bites it on arrival.
##
## The third way into the same loop. A bolt softens something from across the room
## on a wait; this softens it by hand, with no wait at all, and the price is that
## you are now standing next to the thing — which for anything that hunts you is
## the whole cost, because stamina and being driven off are already built.
##
## No cooldown on purpose. A wait on top of the risk is a double cost, and a move
## that is both dangerous and rationed either goes unused or has to be made strong
## enough to be the mandatory opener. What gates this instead is range: it only
## reaches so far, so anything faster than you has to be slowed before you can get
## to it, which is exactly what silk already does.
func lunge() -> bool:
	if _spider == null or _spider.climb == null:
		return false
	var mark := aimed_quarry()
	if mark == null:
		return false
	var span := _spider.global_position.distance_to(mark.global_position)
	if span > lunge_range():
		notice.emit("The %s is too far to reach — get closer or slow it down"
			% mark.species)
		return false
	# Where it is now, not where it will be. The grapple travels to a point, so a
	# creature that moves in the meantime is one you land beside rather than on —
	# a miss you can see the reason for beats a lunge that cannot miss.
	var toward := (_spider.global_position - mark.global_position).normalized()
	if not _spider.climb.grapple_to(mark.global_position, toward):
		return false
	_quarry = mark
	return true


## The creature worth throwing yourself at: what the crosshair is on, alive, and
## not already wrapped up and going nowhere.
func aimed_quarry() -> Prey:
	var mark := aimed_prey(lunge_range())
	if mark == null or mark.eaten or mark.wrapped or mark.is_bundled():
		return null
	return mark


## How far a lunge reaches.
func lunge_range() -> float:
	if _spider.web_builder == null:
		return fang_reach()
	return maxf(_spider.web_builder.silk_reach() * lunge_reach, fang_reach())


## Landed. Bites whatever it was thrown at, if it is still there to bite.
func _on_landed(_point: Vector3, _normal: Vector3) -> void:
	var mark := _quarry
	_quarry = null
	if mark == null or not is_instance_valid(mark) or mark.eaten:
		return
	if _spider.global_position.distance_to(mark.global_position) > fang_reach():
		notice.emit("Missed the %s — it moved while you were in the air" % mark.species)
		return

	var fanged: bool = _traits != null and _traits.has_fangs()
	var strength := Prey.FANG_VENOM if fanged else 1.0
	# Fangs take the small outright, which is what the venom branch has always
	# promised: a kill that needs no web. Anything bigger gets the slow version.
	if fanged and mark.size_class <= _spider.stage().bite_power and mark.envenom():
		notice.emit("Fangs into the %s — it is finished" % mark.species)
		return
	if not mark.poison(venom_time, strength):
		return
	notice.emit("Bit the %s — the venom is working" % mark.species)
