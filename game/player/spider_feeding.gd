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

## A mouthful went down: how much biomass it was worth.
signal drank(food: float)

## A meal was drunk to the end: what it was.
signal finished(kind: PreySpecies)

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

## How many sizes past the spider's bite the meal was when it began. Noted then
## rather than at the end, because a big enough meal grows you part-way through,
## and what it was worth is what it was when you took it on.
var _past := 0


func setup(spider: SpiderPlayer, growth: SpiderGrowth, traits: SpiderTraits,
		view: SpiderCamera, tether: SilkTether) -> void:
	_spider = spider
	_growth = growth
	_traits = traits
	_view = view
	_tether = tether


## How far the fangs go. One definition, because it used to be written out twice —
## once for picking what the crosshair is on and once for deciding whether a meal
## is still in reach — and two copies of a number that has to agree is one copy
## too many.
func fang_reach() -> float:
	var current := _spider.stage()
	return maxf(current.reach * 2.5, current.body_height * 4.0)


## What the crosshair is on, if it is on a creature at all, within fang reach.
func aimed_prey() -> Prey:
	var origin := _view.aim_origin()
	var forward := _view.aim_forward()
	var limit := fang_reach()

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
## whether it is already caught, and how big it is next to you.
##
## Anything you can hold, you can eat. Size used to be a wall here — anything
## past your bite power was too big, caught or not, and the answer was always to
## grow first. What size decides now is how you get hold of it: something past
## your bite has to be beaten by the silk before it can be wrapped. A web that
## held it until it fought itself out has done that; so has one that bundled it
## outright, or venom. While it is still fighting, it is not yours yet.
func handle(prey: Prey) -> void:
	var current := _spider.stage()
	# Something already dead is food for whatever finds it, the spider included.
	if prey.wrapped or prey.is_dead():
		begin(prey)
		return

	if prey.is_stuck():
		if prey.size_class > current.bite_power and prey.is_fighting():
			notice.emit("The %s is still fighting the silk — let it tire" % prey.species)
			return
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
	# Carrion was taken down by something else, so there is nothing hard about it.
	_past = 0 if prey.is_dead() else prey.size_class - _spider.stage().bite_power
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
	drank.emit(food)
	# Banked as it comes, not at the end, so half a meal is half a meal. Fed
	# quietly: a notice a frame would bury everything else the HUD has to say.
	if _growth.feed(food, _species) > 0:
		_taken = 0.0
	# The larder counts creatures, not mouthfuls, so it is paid on the last one —
	# and so is the chance that what you ate changes you. That is rolled once the
	# meal is over, so that news of it is the last thing said.
	if meal.eaten:
		var kind := meal.kind
		stop()
		finished.emit(kind)
		if _traits != null:
			_traits.record(kind)
			_traits.digest(kind, _growth.stage_index, _past)


## How much faster a bigger mouth drinks: the square root of its bite, so the
## curve flattens instead of running away. See [member feed_rate].
func gulp() -> float:
	return sqrt(maxf(_spider.stage().bite_power, 1))


## Whether a meal is close enough to keep drinking. On the line counts at any
## length; anything else has to be within reach of the fangs.
##
## There used to be a third case — a catch inside a *web* on the line — from when
## a web could be dragged home on a rope. Collecting one brings its catches to
## your feet as bundles instead, so what is in reach is the bundle itself, by the
## ordinary rule.
func within_reach(prey: Prey) -> bool:
	if _tether != null and _tether.cargo == prey:
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
