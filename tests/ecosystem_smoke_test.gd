extends TestSuite

## Headless check on the ecosystem: what grows, who eats it, and what they do
## about being hungry.
##
##     godot --headless --path . --script res://tests/ecosystem_smoke_test.gd
##
## Every section gets a bare arena built in code — a floor, an [Ecosystem] with
## its clock stopped, and whatever patches and creatures the section puts down —
## so what is being checked is the living and not a level. The creatures are the
## game's own species, copied and given the diet a section wants, so a check does
## not change what the species is everywhere else.

var _arena: Node3D
var _world: Ecosystem


func run_checks() -> void:
	for section: Callable in _sections():
		await _fresh_arena(section != _test_no_ecosystem)
		await section.call()


func _sections() -> Array[Callable]:
	return [
		_test_no_ecosystem,
		_test_the_clock,
		_test_the_roster,
		_test_forage,
		_test_grazing,
		_test_searching,
		_test_errands_end,
		_test_a_full_creature_stays_put,
		_test_fliers_eat_from_above,
		_test_diets,
		_test_a_kill,
		_test_quarry_gone,
		_test_meat_first,
		_test_too_big_to_take,
		_test_carcasses,
		_test_scavengers,
		_test_flies_on_carcasses,
		_test_running_from_a_hunter,
		_test_wary_of_the_spider,
		_test_water_and_land,
		_test_a_den,
		_test_breeding,
		_test_a_meal_is_put_by,
		_test_recolonising,
		_test_starving,
		_test_resting_out_of_hours,
		_test_resting_in_the_open,
		_test_wounds,
		_test_limping_home,
		_test_turf_war,
		_test_no_war_at_home,
		_test_roaming,
		_test_day_and_night,
	]


# --- the world on its own --------------------------------------------------

## Without an ecosystem a creature has no needs: it is the creature every check
## written before there was one was written against.
func _test_no_ecosystem() -> void:
	check(Ecosystem.of(_arena) == null, "an arena with no ecosystem in it")
	var beetle := _creature("beetle", Vector3(0, 0.3, 0), PackedStringArray(["moss"]))
	var sun := _sky_and_sun()[1] as DirectionalLight3D
	var built := sun.global_basis
	var day := DayNight.new()
	_arena.add_child(day)
	await physics_frame
	await process_frame
	check(beetle.mind() == null, "has creatures with no minds — they only wander")
	check(day.moon == null and sun.global_basis.is_equal_approx(built),
		"and keeps no time: the sun stays where it was put")


func _test_the_clock() -> void:
	check(_world != null and Ecosystem.of(_arena) == _world, "an ecosystem to live in")
	_world.time_of_day = 0.5
	check(_world.is_day() and _world.daylight() > 0.95, "noon is day, and full light")
	check(_world.clock_text() == "12:00", "which the clock calls 12:00 (%s)" % _world.clock_text())
	check(_world.part_of_day() == "midday", "and midday (%s)" % _world.part_of_day())
	check(_world.awake(PreySpecies.Activity.DAY) and not _world.awake(PreySpecies.Activity.NIGHT),
		"something out by day is out, and something out by night is not")
	_world.time_of_day = 0.0
	check(not _world.is_day() and _world.daylight() < 0.05, "midnight is night, and dark")
	check(_world.awake(PreySpecies.Activity.NIGHT) and _world.awake(PreySpecies.Activity.ALWAYS),
		"the night creatures are out, and the ones out at all hours")
	check(_world.part_of_day() == "night", "which is night (%s)" % _world.part_of_day())
	_world.time_of_day = 0.25
	var dawn := _world.daylight()
	check(dawn > 0.2 and dawn < 0.8, "dawn is half light (%.2f)" % dawn)
	check(_world.part_of_day() == "dawn", "and called dawn (%s)" % _world.part_of_day())
	_world.day_length = 10.0
	_world.running = true
	var was := _world.time_of_day
	await run_frames(60)
	_world.running = false
	check(_world.time_of_day > was + 0.05,
		"and the day goes round (%.2f -> %.2f in a second of a ten-second day)"
		% [was, _world.time_of_day])


## Every species lives somewhere in the food web: it eats something, says what
## kind of creature it is, and every name in its diet is something there is.
func _test_the_roster() -> void:
	var everyone := PreyLibrary.load_species()
	var ids := {}
	var tags := {}
	for kind in everyone:
		ids[kind.id] = true
		for tag in kind.tags:
			tags[tag] = true
	var hungry := PackedStringArray()
	var nameless := PackedStringArray()
	var unknown := PackedStringArray()
	for kind in everyone:
		if kind.diet.is_empty():
			hungry.append(kind.id)
		if kind.tags.is_empty():
			nameless.append(kind.id)
		for entry in kind.diet:
			if not (Forage.KINDS.has(entry) or entry == "carrion" or ids.has(entry)
					or tags.has(entry)):
				unknown.append("%s eats %s" % [kind.id, entry])
	check(hungry.is_empty(), "every species eats something (%d species; %s do not)"
		% [everyone.size(), ", ".join(hungry) if not hungry.is_empty() else "none"])
	check(nameless.is_empty(), "and says what kind of creature it is (%s do not)"
		% (", ".join(nameless) if not nameless.is_empty() else "none"))
	check(unknown.is_empty(), "and every name in a diet is something there is (%s)"
		% ("; ".join(unknown) if not unknown.is_empty() else "all of them"))

## A patch only knows how much is on it: it gives what it has, no more, and grows
## back.
func _test_forage() -> void:
	var moss := _patch("moss", Vector3(0, 0, 0), 40.0, 2.0)
	moss.regrow = 4.0
	await physics_frame
	check(is_equal_approx(moss.amount, moss.capacity), "a patch of moss starts full")
	check(_world.all_forage().has(moss), "and the ecosystem knows it is there")
	var full: Vector3 = moss._growth[0].scale
	check(is_equal_approx(moss.graze(15.0), 15.0), "it gives what is asked of it")
	check(is_equal_approx(moss.graze(100.0), 25.0), "and no more than it has left")
	check(moss.amount < 0.01 and not moss.worth_it(), "eaten bare, it is not worth going to")
	await run_frames(4)
	check(moss._growth[0].scale.length() < full.length() * 0.5,
		"and it looks it (%.2f against %.2f)" % [moss._growth[0].scale.length(), full.length()])
	await run_frames(60)
	check(moss.amount > 2.0, "it grows back (%.1f in a second)" % moss.amount)
	for kind in Forage.KINDS:
		var patch := _patch(kind, Vector3(8, 0, 0), 30.0, 2.0)
		await physics_frame
		check(patch._growth.size() > 0, "a patch of %s is drawn (%d parts)"
			% [kind, patch._growth.size()])
		patch.free()


## A hungry grazer goes to the nearest patch of what it eats, eats until it is
## full, and goes back to its own business.
##
## Near enough for a beetle — which walks under a metre a second — to get there
## well inside the wait, with its first thought and its getting going counted in.
func _test_grazing() -> void:
	var moss := _patch("moss", Vector3(5, 0, 0), 40.0, 2.0)
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray(["moss"]))
	await physics_frame
	var mind := beetle.mind()
	if not check(mind != null, "a beetle living in it has a mind"):
		return
	mind.hunger = 0.9
	var started := beetle.global_position.distance_to(moss.global_position)
	var feeding: bool = await wait_until(func() -> bool: return beetle.is_feeding(), 600)
	check(feeding, "hungry, it goes to the moss and starts eating")
	check(beetle.global_position.distance_to(moss.global_position) < started,
		"having walked to it (%.1f m -> %.1f m)"
		% [started, beetle.global_position.distance_to(moss.global_position)])
	var before := moss.amount
	var hungry := mind.hunger
	await run_frames(60)
	check(moss.amount < before, "the moss goes down (%.1f -> %.1f)" % [before, moss.amount])
	check(mind.hunger < hungry, "and so does its hunger (%.2f -> %.2f)" % [hungry, mind.hunger])
	var done: bool = await wait_until(func() -> bool: return not beetle.is_feeding(), 900)
	check(done and mind.hunger <= CreatureMind.SATED + 0.01,
		"full, it stops (%.2f hungry)" % mind.hunger)
	check(moss.amount > 0.0, "having eaten what it needed and left the rest (%.1f)" % moss.amount)


## Hungry, with nothing it eats in sight, a creature goes looking further off —
## further each time — and finds what it could not see from home.
func _test_searching() -> void:
	for i in 6:
		var turn := TAU * float(i) / 6.0
		_patch("moss", Vector3(cos(turn), 0.0, sin(turn)) * 24.0, 40.0, 3.0)
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray(["moss"]))
	beetle.kind.senses = 8.0
	beetle.move_speed = 4.0
	beetle.wander_radius = 6.0
	await physics_frame
	var mind := beetle.mind()
	check(mind.find_food() == null, "a beetle cannot see the moss 24 m off all round it")
	mind.hunger = 0.9
	mind.decide()
	check(beetle.is_on_errand(), "so hungry, it goes off to look")
	var first := beetle._errand_goal.distance_to(beetle.home())
	var looked: bool = await wait_until(func() -> bool: return mind._searches >= 2, 900)
	check(looked and beetle._errand_goal.distance_to(beetle.home()) > first,
		"looking further the second time (%.0f m out, then %.0f m)"
		% [first, beetle._errand_goal.distance_to(beetle.home())])
	var found: bool = await wait_until(func() -> bool: return beetle.is_feeding(), 3600)
	check(found, "and in the end finds some, and eats")


## An errand that cannot be finished is given up, rather than walked at for ever.
func _test_errands_end() -> void:
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray())
	await physics_frame
	beetle.go_to(Vector3(0, 40, 0), 0.5)
	check(beetle.is_on_errand(), "a beetle sent somewhere up in the air sets off")
	var given_up: bool = await wait_until(func() -> bool: return not beetle.is_on_errand(),
		roundi(Prey.ERRAND_TIME * 60.0) + 60)
	check(given_up, "and gives up on it in the end")
	beetle.go_to(beetle.global_position + Vector3(3, 2.5, 0), 0.5)
	var there: bool = await wait_until(func() -> bool: return not beetle.is_on_errand(), 400)
	check(there, "while somewhere a step up the ground counts as reached from beside it")


## Something that is not hungry leaves food alone.
func _test_a_full_creature_stays_put() -> void:
	var moss := _patch("moss", Vector3(3, 0, 0), 40.0, 2.0)
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray(["moss"]))
	await physics_frame
	beetle.mind().hunger = 0.1
	await run_frames(120)
	check(not beetle.is_feeding() and is_equal_approx(moss.amount, moss.capacity),
		"a beetle that has eaten does not go to the moss")
	check(beetle.mind().hunger > 0.1, "but is getting hungry (%.3f)" % beetle.mind().hunger)


## Something on the wing eats on the wing: over the flowers, where their heads are.
func _test_fliers_eat_from_above() -> void:
	var flowers := _patch("flowers", Vector3(0, 0, 6), 40.0, 2.0)
	var moth := _creature("moth", Vector3(0, 1.5, 0), PackedStringArray(["flowers"]))
	await physics_frame
	moth.mind().hunger = 0.9
	var feeding: bool = await wait_until(func() -> bool: return moth.is_feeding(), 600)
	if not check(feeding, "a hungry moth goes to the flowers"):
		return
	await run_frames(20)
	check(moth.global_position.y > flowers.global_position.y + flowers.size * 0.3,
		"and eats hovering over them (%.2f m up)"
		% (moth.global_position.y - flowers.global_position.y))
	check(flowers.amount < flowers.capacity, "from them (%.1f left)" % flowers.amount)


## A diet names forage, species, and kinds of creature.
func _test_diets() -> void:
	var fly := PreyLibrary.find("fly").duplicate() as PreySpecies
	fly.tags = PackedStringArray(["insect"])
	var moth := PreyLibrary.find("moth").duplicate() as PreySpecies
	moth.tags = PackedStringArray()
	var hunter := _creature("wasp", Vector3(0, 1, 0), PackedStringArray(["insect", "moth"]))
	await physics_frame
	var mind := hunter.mind()
	check(mind.eats(fly), "a diet of insects takes anything tagged an insect")
	check(mind.eats(moth), "and a species named outright")
	check(not mind.eats(PreyLibrary.find("rat")), "and nothing it does not name")
	check(mind.forage_kinds().is_empty(), "a hunter has no forage in its diet")
	var grazer := _creature("beetle", Vector3(4, 0.4, 0), PackedStringArray(["moss", "fungus"]))
	await physics_frame
	check(grazer.mind().forage_kinds() == PackedStringArray(["moss", "fungus"]),
		"a grazer's forage is what of its diet grows (%s)" % grazer.mind().forage_kinds())
	var idle := _creature("midge", Vector3(-4, 1, 0), PackedStringArray())
	await physics_frame
	var was := idle.mind().hunger
	await run_frames(30)
	check(not idle.mind().eats_anything() and is_equal_approx(idle.mind().hunger, was),
		"something with no diet never goes hungry")


# --- eating each other -----------------------------------------------------

## A hungry predator hunts what it eats, kills it, and eats the carcass where it
## fell.
func _test_a_kill() -> void:
	var wasp := _creature("wasp", Vector3(0, 1.0, 0), PackedStringArray(["fly"]))
	var fly := _creature("fly", Vector3(3, 1.0, 0), PackedStringArray())
	fly.move_speed = 0.0
	await physics_frame
	_world.sort_now()
	wasp.mind().hunger = 0.9
	var hunting: bool = await wait_until(func() -> bool: return wasp.is_hunting(), 120)
	check(hunting, "a hungry wasp goes after a fly")
	var killed: bool = await wait_until(func() -> bool:
		return not is_instance_valid(fly) or fly.is_dead(), 300)
	if not check(killed and is_instance_valid(fly), "catches it and kills it"):
		return
	check(wasp.is_feeding() and wasp.mind().kills == 1, "and eats it where it fell")
	var left := fly.biomass
	await run_frames(20)
	check(not is_instance_valid(fly) or fly.biomass < left,
		"the carcass going down as it does (%.1f)" % (fly.biomass if is_instance_valid(fly) else 0.0))


## Something that is eaten to nothing, or rots away, while it is being chased or
## between two sorts of the grid is simply gone: the hunter gives up, and nothing
## looking about finds it.
func _test_quarry_gone() -> void:
	var wasp := _creature("wasp", Vector3(0, 1.0, 0), PackedStringArray(["fly"]))
	var fly := _creature("fly", Vector3(20, 1.0, 0), PackedStringArray())
	fly.move_speed = 0.0
	await physics_frame
	_world.sort_now()
	wasp.hunt(fly)
	await physics_frame
	check(wasp.is_hunting(), "a wasp hunting a fly")
	fly.free()
	check(_world.creatures_near(Vector3(20, 1.0, 0), 5.0).is_empty(),
		"which is eaten to nothing: the grid does not find it, though it has not been sorted since")
	await run_frames(2)
	check(not wasp.is_hunting(), "and the wasp gives up the chase")


## A hunter that eats berries too goes for something to hunt over a bramble
## nearly as near.
func _test_meat_first() -> void:
	var bramble := _patch("berries", Vector3(5, 0, 0), 40.0, 2.0)
	var wasp := _creature("wasp", Vector3(0, 1.0, 0), PackedStringArray(["fly", "berries"]))
	var fly := _creature("fly", Vector3(-6.5, 1.0, 0), PackedStringArray())
	fly.move_speed = 0.0
	wasp.move_speed = 0.0
	await physics_frame
	_world.sort_now()
	check(wasp.mind().find_food() == fly,
		"a wasp goes after a fly over a bramble a little nearer (%.1f m against %.1f m)"
		% [wasp.global_position.distance_to(fly.global_position),
			wasp.global_position.distance_to(bramble.global_position)])
	fly.global_position = Vector3(-30, 1.0, 0)
	await physics_frame
	_world.sort_now()
	check(wasp.mind().find_food() == bramble, "but not over one far nearer")


## However hungry, a predator leaves alone what it cannot overpower.
func _test_too_big_to_take() -> void:
	var wasp := _creature("wasp", Vector3(0, 1.0, 0), PackedStringArray(["rat"]))
	var rat := _creature("rat", Vector3(3, 0.8, 0), PackedStringArray())
	rat.move_speed = 0.0
	await physics_frame
	_world.sort_now()
	wasp.mind().hunger = 1.0
	check(rat.size_class > wasp.size_class, "a rat is bigger than a wasp")
	await run_frames(120)
	check(not wasp.is_hunting() and not rat.is_dead(), "so a starving wasp leaves it be")


## Dead, a creature drops and lies still on its side, is no use to silk, and rots
## away in the end.
func _test_carcasses() -> void:
	var moth := _creature("moth", Vector3(0, 2.0, 0), PackedStringArray())
	await physics_frame
	var heard: Array = []
	moth.died.connect(func(who: Prey) -> void: heard.append(who))
	moth.die()
	check(moth.is_dead() and heard == [moth], "a moth dies, and says so")
	check(not moth.is_loose() and not moth.can_be_snared() and not moth.can_decide(),
		"and is no longer loose, catchable, or minding anything")
	var high := moth.global_position.y
	await run_frames(60)
	check(moth.global_position.y < high - 0.5, "it falls (%.2f -> %.2f m)"
		% [high, moth.global_position.y])
	var view := moth.get_node_or_null("Body") as CreatureView
	if view != null:
		check(view.motion.pose == CreatureMotion.Pose.SPENT, "and lies limp")
	check(not moth.shock(2.0), "lightning does nothing to it")
	moth.rot_after = 0.5
	var held: WeakRef = weakref(moth)
	var rotted: bool = await wait_until(func() -> bool: return held.get_ref() == null, 90)
	check(rotted, "and it rots away")


## Something that eats carrion eats whatever it finds dead, down to nothing.
func _test_scavengers() -> void:
	var dead := _creature("moth", Vector3(3, 0.3, 0), PackedStringArray())
	await physics_frame
	dead.die()
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray(["carrion"]))
	await run_frames(10)
	_world.sort_now()
	beetle.mind().hunger = 1.0
	var feeding: bool = await wait_until(func() -> bool: return beetle.is_feeding(), 900)
	check(feeding, "a hungry beetle finds a dead moth and eats it")
	var held: WeakRef = weakref(dead)
	var gone: bool = await wait_until(func() -> bool: return held.get_ref() == null, 900)
	check(gone, "down to nothing")


## Flies come off a carcass: a few, and no more.
func _test_flies_on_carcasses() -> void:
	var fly := PreyLibrary.find("fly").duplicate() as PreySpecies
	fly.diet = PackedStringArray(["carrion"])
	_world.fly_kind = fly
	var rat := _creature("rat", Vector3(0, 0.8, 0), PackedStringArray())
	await physics_frame
	rat.die()
	await run_frames(20)
	_world.sort_now()
	check(_world.carcasses().has(rat), "a dead rat is a carcass")
	for i in 30:
		_world._breed_flies()
		_world.sort_now()
	var around := 0
	for node in _arena.get_children():
		var other := node as Prey
		if other != null and other.kind == fly:
			around += 1
	check(around == Ecosystem.FLIES_PER_CARCASS,
		"flies come off it, as many as one carcass draws (%d)" % around)


# --- danger ---------------------------------------------------------------

## Something being hunted runs; something only passing is run from up close.
func _test_running_from_a_hunter() -> void:
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray())
	beetle.kind.tags = PackedStringArray(["insect"])
	beetle.move_speed = 0.0
	var sight := beetle.kind.senses * CreatureMind.FEAR
	var bird := _creature("wasp", Vector3(sight * 0.75, 1.0, 0), PackedStringArray(["insect"]))
	bird.move_speed = 0.0
	await physics_frame
	_world.sort_now()
	check(beetle.mind().threat() == null,
		"a wasp passing %.0f m off is no threat to a beetle" % beetle.global_position.distance_to(
			bird.global_position))
	bird.hunt(beetle)
	await physics_frame
	_world.sort_now()
	check(beetle.mind().threat() == bird, "a wasp hunting it is")
	var away: bool = await wait_until(func() -> bool:
		return beetle._state == Prey.State.FLEEING, 120)
	check(away, "and it runs")
	bird.break_off()
	bird.global_position = beetle.global_position + Vector3(sight * 0.3, 0.6, 0.0)
	await physics_frame
	_world.sort_now()
	check(beetle.mind().threat() == bird, "a wasp only passing is a threat up close")


## A wary creature keeps clear of a spider big enough to eat it, and only that.
func _test_wary_of_the_spider() -> void:
	var rat := _creature("rat", Vector3(0, 0.8, 0), PackedStringArray())
	rat.kind.wary = true
	var spider := PretendSpider.new()
	_arena.add_child(spider)
	spider.global_position = Vector3(1.5, 0.3, 0)
	await physics_frame
	spider.bite = 1
	check(rat.mind().threat() == null, "a rat does not mind a spider that cannot eat it")
	spider.bite = 9
	check(rat.mind().threat() == spider, "and keeps clear of one that can")
	rat.kind.wary = false
	check(rat.mind().threat() == null, "unless it is not the wary kind")
	spider.queue_free()



## What swims keeps to the water and everything else keeps out of it: a fish
## grazes the weed under the surface and not the moss on the bank, a beetle the
## other way about, and neither hunts nor runs from the other.
func _test_water_and_land() -> void:
	WorldKit.water(_arena, "Pond", Vector3(12, 4, 12), Transform3D(Basis.IDENTITY,
		Vector3(-12, 2, 0)), "pond")
	var weed := _patch("moss", Vector3(-12, 0.2, 0), 40.0, 2.0)
	var bank := _patch("moss", Vector3(-2, 0, 0), 40.0, 2.0)
	var fish := _creature("fish", Vector3(-6.5, 1.5, 0), PackedStringArray(["moss", "beetle"]))
	var beetle := _creature("beetle", Vector3(-5, 0.3, 3), PackedStringArray(["moss", "fish"]))
	fish.move_speed = 0.0
	beetle.move_speed = 0.0
	# Each big enough to take the other, so only the water is in the way.
	fish.kind.size_class = 9
	beetle.kind.size_class = 9
	beetle.size_class = 9
	fish.size_class = 9
	await run_frames(2)
	_world.sort_now()
	check(weed.is_underwater() and not bank.is_underwater(),
		"a patch under the water knows it is, and one on the bank knows it is not")
	var near := fish.global_position.distance_to(bank.global_position) \
		< fish.global_position.distance_to(weed.global_position)
	check(near and fish.mind().find_food() == weed,
		"a fish goes for the weed, though the moss on the bank is nearer")
	near = beetle.global_position.distance_to(fish.global_position) \
		< beetle.global_position.distance_to(bank.global_position)
	check(near and beetle.mind().find_food() == bank,
		"and a beetle for the moss, though the fish is nearer")
	check(not fish.mind().can_take(beetle) and not beetle.mind().can_take(fish),
		"neither hunts the other, each big enough to and eating the other")
	check(beetle.mind().threat() == null and fish.mind().threat() == null,
		"nor runs from it")

## Something in the spider's group, with a bite of a check's choosing.
class PretendSpider extends Node3D:
	var bite := 1

	func _ready() -> void:
		add_to_group("spider")

	func stage() -> GrowthStage:
		var tier := GrowthStage.new()
		tier.bite_power = bite
		tier.body_height = 0.4
		return tier


# --- dens -----------------------------------------------------------------

## A den puts its first creatures out as it opens, and they live there.
func _test_a_den() -> void:
	var den := _den("beetle", Vector3(0, 0, 0), PackedStringArray(["moss"]), 3, 5)
	await physics_frame
	check(den.count() == 3 and den.born == 3, "a den of beetles opens with three (%d)"
		% den.count())
	var home := true
	for beetle in den.members:
		home = home and beetle.den == den and beetle.mind() != null \
			and beetle.mind().den == den and beetle.get_parent() == den \
			and beetle.global_position.distance_to(den.global_position) < den.spread + 0.5
	check(home, "each of them living there, and put down near it")


## Meals put by are how a den grows: one born for every so many, no faster than
## it can raise them, and never more than it holds. A den that is not eating does
## not grow at all.
func _test_breeding() -> void:
	var den := _den("beetle", Vector3(0, 0, 0), PackedStringArray(["moss"]), 1, 3)
	den.meals_per_birth = 2.0
	den.breed_every = 1.0
	await run_frames(90)
	check(den.count() == 1 and den.bred == 0, "a den with nothing put by has no young (%d)"
		% den.count())
	den.ate()
	await run_frames(5)
	check(den.count() == 1, "nor with one meal put by, when it takes two")
	den.ate()
	await run_frames(5)
	check(den.count() == 2 and den.bred == 1, "two meals, and one is born (%d)" % den.count())
	den.ate()
	den.ate()
	await run_frames(5)
	check(den.count() == 2, "but not another straight after")
	await run_frames(70)
	check(den.count() == 3 and den.bred == 2, "only once it has had time to (%d)" % den.count())
	for i in 6:
		den.ate()
	await run_frames(150)
	check(den.count() == 3 and den.bred == 2, "and never more than the den holds (%d of %d)"
		% [den.count(), den.capacity])
	var young := den.members[den.members.size() - 1]
	check(young.den == den and young.get_parent() == den, "the young living there like the rest")


## A meal one of its creatures finishes is put by at home.
func _test_a_meal_is_put_by() -> void:
	var den := _den("beetle", Vector3(0, 0, 0), PackedStringArray(["moss"]), 1, 3)
	den.meals_per_birth = 5.0
	var moss := _patch("moss", Vector3(2.5, 0, 0), 40.0, 2.0)
	await physics_frame
	var beetle := den.members[0]
	beetle.mind().hunger = 0.9
	var ate: bool = await wait_until(func() -> bool: return beetle.mind().meals == 1, 1500)
	check(ate and moss.amount < moss.capacity, "a beetle from the den eats its fill of moss")
	check(is_equal_approx(den.larder, 1.0), "and the meal is put by at the den (%.1f)" % den.larder)


## A den hunted out is not empty for ever: one of its kind wanders in, in time.
func _test_recolonising() -> void:
	var den := _den("beetle", Vector3(0, 0, 0), PackedStringArray(["moss"]), 1, 3)
	den.recolonise = 1.0
	await physics_frame
	var last := den.members[0]
	last.die()
	await run_frames(20)
	check(den.count() == 0, "a den whose last beetle has died is empty")
	var back: bool = await wait_until(func() -> bool: return den.count() == 1, 120)
	check(back and den.born == 2, "until another wanders in (%d born)" % den.born)
	check(back and den.members[0] != last, "a new one, not the dead one back")


## Something that can find nothing it eats starves in the end — and is a carcass,
## like anything else that dies.
func _test_starving() -> void:
	var beetle := _creature("beetle", Vector3(0, 0.4, 0), PackedStringArray(["moss"]))
	beetle.kind.starve_after = 1.0
	await physics_frame
	var mind := beetle.mind()
	mind.hunger = 1.0
	await run_frames(30)
	check(not beetle.is_dead(), "a beetle with nothing to eat holds on a while")
	mind.hunger = 0.5
	await physics_frame
	mind.hunger = 1.0
	await run_frames(40)
	check(not beetle.is_dead(), "and a mouthful buys it time (%.2f s starving)" % mind.starving)
	var starved: bool = await wait_until(func() -> bool: return beetle.is_dead(), 90)
	check(starved, "but in the end it starves")
	await run_frames(5)
	check(_world.carcasses().has(beetle), "and lies there, for whatever eats carrion")
	var full := _creature("beetle", Vector3(4, 0.4, 0), PackedStringArray())
	full.kind.starve_after = 0.5
	await run_frames(60)
	check(not full.is_dead() and full.mind().hunger == 0.0,
		"something that eats nothing is never hungry, and never starves")


## Out of its hours a creature goes home to rest — out of sight underground, for
## something that lives in a burrow, where nothing can see it or get at it — and
## comes out again when its time comes round. Hungry enough, it gets up whatever
## the hour.
func _test_resting_out_of_hours() -> void:
	var den := _den("rat", Vector3(0, 0, 0), PackedStringArray(["moss"]), 3, 4)
	den.species.active = PreySpecies.Activity.DAY
	await physics_frame
	for rat in den.members:
		rat.mind().hunger = 0.2
	_world.time_of_day = 0.5
	await run_frames(60)
	check(den.members.all(func(rat: Prey) -> bool: return not rat.is_resting()),
		"rats that are out by day are out at noon")
	_world.time_of_day = 0.0
	var home: bool = await wait_until(func() -> bool:
		return den.members.all(func(rat: Prey) -> bool: return rat.is_sheltered()), 600)
	check(home, "at midnight they go home, and down the burrow")
	var hidden := true
	for rat in den.members:
		hidden = hidden and not rat.visible and rat.collision_layer == 0 \
			and not rat.is_in_group("prey")
	check(hidden, "where they cannot be seen, touched, or found")
	_world.sort_now()
	check(_world.creatures_near(den.global_position, 20.0).is_empty(),
		"and nothing looking for something to eat finds them")
	var hungry := den.members[0]
	var before := hungry.mind().hunger
	await run_frames(60)
	var rate := (hungry.mind().hunger - before) / (hungry.kind.hunger_rate * 1.0)
	check(rate > 0.05 and rate < 0.5, "resting, they get hungry slowly (%.2f of the waking rate)"
		% rate)
	hungry.mind().hunger = 0.95
	var up: bool = await wait_until(func() -> bool: return not hungry.is_sheltered(), 120)
	check(up and hungry.visible and hungry.is_in_group("prey"),
		"one hungry enough comes up whatever the hour")
	_world.time_of_day = 0.5
	var out: bool = await wait_until(func() -> bool:
		return den.members.all(func(rat: Prey) -> bool:
			return not rat.is_sheltered() and not rat.is_resting()), 120)
	check(out, "and at noon they are all out again")
	check(den.members.all(func(rat: Prey) -> bool:
		return rat.visible and rat.collision_layer == GameLayers.PREY and rat.is_in_group("prey")),
		"to be seen, and caught, like anything else")


## A den that does not shelter — a roost, a nest out in the open — is somewhere to
## rest, not somewhere to hide.
func _test_resting_in_the_open() -> void:
	var den := _den("rat", Vector3(0, 0, 0), PackedStringArray(["moss"]), 1, 2)
	den.species.active = PreySpecies.Activity.NIGHT
	den.shelters = false
	await physics_frame
	var rat := den.members[0]
	rat.mind().hunger = 0.2
	_world.time_of_day = 0.5
	var resting: bool = await wait_until(func() -> bool: return rat.is_resting(), 600)
	check(resting, "a rat out by night rests at noon")
	check(not rat.is_sheltered() and rat.visible and rat.is_in_group("prey"),
		"where it can still be got at, in a den that does not shelter it")
	_world.sort_now()
	check(_world.creatures_near(den.global_position, 20.0).has(rat),
		"and found by anything that looks")


# --- big creatures -----------------------------------------------------------

## A wound slows a creature and takes the fight out of it, and heals — faster at
## rest.
func _test_wounds() -> void:
	var wolf := _creature("wolf", Vector3(0, 3, 0), PackedStringArray())
	await physics_frame
	var speed := wolf.current_speed()
	var fight := wolf.thrash_power()
	wolf.wound(0.5)
	check(wolf.current_speed() < speed * 0.85 and wolf.thrash_power() < fight * 0.8,
		"a wounded wolf is slower and fights a web less (%.1f -> %.1f, %.1f -> %.1f)"
		% [speed, wolf.current_speed(), fight, wolf.thrash_power()])
	check(is_equal_approx(wolf.weakness(), 0.5), "and is as weak as it is hurt")
	await run_frames(60)
	var awake_heal := 0.5 - wolf.wounded
	check(awake_heal > 0.0, "it heals (%.4f in a second)" % awake_heal)
	wolf.rest()
	var was := wolf.wounded
	await run_frames(60)
	check(was - wolf.wounded > awake_heal * 3.0, "and heals faster at rest (%.4f)"
		% (was - wolf.wounded))


## Hurt, or bound in silk it tore out of, a creature limps home and rests until it
## is over it.
func _test_limping_home() -> void:
	var den := _den("wolf", Vector3(0, 0, 0), PackedStringArray(), 1, 1)
	den.species.active = PreySpecies.Activity.ALWAYS
	den.shelters = false
	await physics_frame
	var wolf := den.members[0]
	wolf.global_position = Vector3(20, 3, 0)
	await physics_frame
	wolf.wound(0.8)
	var home: bool = await wait_until(func() -> bool: return wolf.is_resting(), 900)
	check(home, "a badly hurt wolf limps home to rest")
	var off := wolf.global_position - den.global_position
	off.y = 0.0
	check(off.length() < wolf.hit_radius() * 3.0 + den.spread,
		"at its den (%.1f m off, for something %.1f m across)"
		% [off.length(), wolf.hit_radius() * 2.0])
	wolf.wounded = 0.3
	await run_frames(60)
	check(wolf.is_resting(), "and stays there while it is still getting over it")
	wolf.wounded = 0.05
	var up: bool = await wait_until(func() -> bool: return not wolf.is_resting(), 120)
	check(up, "getting up once it has")
	wolf.wounded = 0.0
	wolf.bound = 0.75
	var again: bool = await wait_until(func() -> bool: return wolf.is_resting(), 900)
	check(again, "and silk it has torn out of sends it home the same way")


## Two creatures that fight for ground square up when they meet: the weaker one
## comes off badly and runs, and the stronger is a little hurt and stays.
func _test_turf_war() -> void:
	var boar := _creature("boar", Vector3(0, 4, 0), PackedStringArray())
	var wolf := _creature("wolf", Vector3(14, 3, 0), PackedStringArray())
	boar.kind.territorial = true
	wolf.kind.territorial = true
	# Much the weaker, so that luck does not decide it.
	wolf.size_class = 3
	boar.move_speed = 0.0
	await run_frames(2)
	_world.sort_now()
	boar.mind().turf_rest = 0.0
	wolf.mind().turf_rest = 0.0
	check(boar.mind().find_rival() == wolf, "a boar sees a wolf as a rival for the ground")
	boar.mind().decide()
	check(boar.is_clashing() and wolf.is_clashing() and boar.rival() == wolf
		and wolf.rival() == boar, "and they square up to each other")
	var over: bool = await wait_until(func() -> bool:
		return not boar.is_clashing() and not wolf.is_clashing(), 400)
	check(over, "for a few seconds")
	check(wolf.wounded > boar.wounded and wolf.wounded > 0.3,
		"the wolf comes off worse (%.2f hurt, against %.2f)" % [wolf.wounded, boar.wounded])
	check(wolf._state == Prey.State.FLEEING and boar._state != Prey.State.FLEEING,
		"and runs, and the boar stays")
	check(boar.mind().turf_rest > 0.0 and boar.mind().find_rival() == null,
		"and neither picks another fight for a while")


## Two from the same den live together; and nothing squares up to what it would
## sooner eat.
func _test_no_war_at_home() -> void:
	var den := _den("boar", Vector3(0, 0, 0), PackedStringArray(), 2, 2)
	den.species.territorial = true
	await run_frames(2)
	_world.sort_now()
	var one := den.members[0]
	one.mind().turf_rest = 0.0
	den.members[1].mind().turf_rest = 0.0
	check(one.mind().find_rival() == null, "two boars from one den do not fight")
	var wolf := _creature("wolf", one.global_position + Vector3(10, 0, 0),
		PackedStringArray(["boar"]))
	wolf.kind.territorial = true
	await run_frames(2)
	_world.sort_now()
	wolf.mind().turf_rest = 0.0
	check(wolf.mind().find_rival() == null, "and a wolf that eats boars hunts them instead")


## Something that roams goes from one of its haunts to another, and wanders about
## whichever it is at.
func _test_roaming() -> void:
	var east := Haunt.new()
	east.species_ids = PackedStringArray(["deer"])
	east.radius = 6.0
	_arena.add_child(east)
	east.global_position = Vector3(30, 0, 0)
	var west := Haunt.new()
	west.radius = 6.0
	_arena.add_child(west)
	west.global_position = Vector3(-30, 0, 0)
	var elsewhere := Haunt.new()
	elsewhere.species_ids = PackedStringArray(["wolf"])
	_arena.add_child(elsewhere)
	elsewhere.global_position = Vector3(0, 0, 40)
	var stag := _creature("deer", Vector3(0, 4.5, 0), PackedStringArray())
	stag.kind.roams = true
	await physics_frame
	var mind := stag.mind()
	mind.roam_in = 0.0
	mind.decide()
	var first := mind.haunt
	check(first == east or first == west, "a roaming stag goes off to one of its haunts")
	var there: bool = await wait_until(func() -> bool:
		return Vector2(stag.global_position.x, stag.global_position.z).distance_to(
			Vector2(first.global_position.x, first.global_position.z)) < first.radius, 900)
	check(there, "and gets there")
	check(stag._home.distance_to(first.global_position) < 0.01, "and wanders about it")
	mind.roam_in = 0.0
	mind.decide()
	check(mind.haunt != first and mind.haunt != elsewhere and mind.haunt != null,
		"moving on, in time, to another — never one that is not its kind's")


# --- day and night ----------------------------------------------------------

## The light follows the clock: the sun overhead at noon, down at midnight with
## the moon up in its place, and an orange sky at either end of the day.
func _test_day_and_night() -> void:
	var lights := _sky_and_sun()
	var sky := lights[0] as WorldEnvironment
	var sun := lights[1] as DirectionalLight3D
	var material := sky.environment.sky.sky_material as ProceduralSkyMaterial
	var noon_top := material.sky_top_color
	var noon_ambient := sky.environment.ambient_light_energy
	var day := DayNight.new()
	_arena.add_child(day)
	await physics_frame
	check(day.sky == sky and day.sun == sun and day.moon != null,
		"a day and night finds the sky and the sun, and puts up a moon")
	check(not day.moon in _arena.get_children(), "a moon no bake would save")
	check(sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		and day.sun_disc.sky_mode == DirectionalLight3D.SKY_MODE_SKY_ONLY
		and day.moon_disc.sky_mode == DirectionalLight3D.SKY_MODE_SKY_ONLY,
		"and discs to draw the sun and the moon in the sky, apart from their light")
	_world.time_of_day = 0.5
	day.show_hour()
	var shining := -sun.global_basis.z
	check(shining.y < -0.8, "at noon the sun is high (shining %.2f down)" % -shining.y)
	check(is_equal_approx(sun.light_energy, 1.0) and day.moon.light_energy < 0.01,
		"and as bright as the level made it, with no moon")
	check(sun.shadow_enabled and not day.moon.shadow_enabled, "the sun casting the shadows")
	check(material.sky_top_color.is_equal_approx(noon_top), "under the sky the level was built with")
	_world.time_of_day = 0.0
	day.show_hour()
	check(sun.light_energy < 0.01 and day.moon.light_energy > 0.2,
		"at midnight the sun is down and the moon up (%.2f)" % day.moon.light_energy)
	check(-day.moon.global_basis.z.y < -0.8, "high in the sky")
	check(day.moon.shadow_enabled and not sun.shadow_enabled, "the moon casting the shadows")
	check(material.sky_top_color.v < noon_top.v * 0.3, "under a dark sky (%.2f against %.2f)"
		% [material.sky_top_color.v, noon_top.v])
	var night_ambient := sky.environment.ambient_light_energy
	check(night_ambient < noon_ambient and night_ambient > noon_ambient * 0.3,
		"dimmer all round, but not so dark nothing can be seen (%.2f against %.2f)"
		% [night_ambient, noon_ambient])
	check(sky.environment.glow_intensity > 0.5, "and what glows, glowing")
	_world.time_of_day = 0.26
	day.show_hour()
	var horizon := material.sky_horizon_color
	check(horizon.r > horizon.b * 1.3, "at sunrise the sky is warm at the horizon (%s)" % horizon)
	check(sun.light_color.b < sun.light_color.r * 0.7 and sun.light_energy > 0.05,
		"and the sun low and orange")
	check(day.sun_disc.light_energy > 0.9 and day.sun_disc.light_color == sun.light_color,
		"its disc as bright as at noon, so it does not go down as a dark hole")
	_world.time_of_day = 0.2
	day.show_hour()
	check(day.sun_disc.light_energy < 0.01, "and gone once it is under the horizon")
	check(day.toward_sun(0.27).x > 0.9 and day.toward_sun(0.73).x < -0.9,
		"coming up in the east and going down in the west")
	_world.time_of_day = 0.4
	_world.day_length = 20.0
	_world.running = true
	day.show_hour()
	var then := -sun.global_basis.z
	await run_frames(30)
	_world.running = false
	check((-sun.global_basis.z).angle_to(then) > deg_to_rad(3.0),
		"and it goes over as the day goes round (%.1f° in half a second of a twenty-second day)"
		% rad_to_deg((-sun.global_basis.z).angle_to(then)))


# --- building the arena ----------------------------------------------------

func _fresh_arena(with_world := true) -> void:
	_arena = Node3D.new()
	_arena.name = "Arena"
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = GameLayers.WORLD
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 0.2, 200.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	_arena.add_child(floor_body)
	_world = null
	if with_world:
		_world = Ecosystem.new()
		_world.name = "Ecosystem"
		_world.running = false
		_arena.add_child(_world)
	await stage(_arena)


func _patch(kind: String, at: Vector3, capacity := 40.0, size := 2.0) -> Forage:
	var patch := Forage.new()
	patch.kind = kind
	patch.capacity = capacity
	patch.size = size
	patch.regrow = 0.0
	_arena.add_child(patch)
	patch.global_position = at
	return patch


## One of a species, copied so the diet given here stays here.
func _creature(id: String, at: Vector3, diet: PackedStringArray) -> Prey:
	var kind := PreyLibrary.find(id).duplicate() as PreySpecies
	kind.diet = diet
	kind.senses = 30.0
	var creature := Prey.of(kind)
	_arena.add_child(creature)
	creature.global_position = at
	return creature


## A den of one of a species, copied as [method _creature] copies it. What a check
## wants of it is set before it arrives, because it puts its first creatures out
## as it does.
func _den(id: String, at: Vector3, diet: PackedStringArray, start := 2, capacity := 4) -> Den:
	var kind := PreyLibrary.find(id).duplicate() as PreySpecies
	kind.diet = diet
	kind.senses = 30.0
	var den := Den.new()
	den.species = kind
	den.start = start
	den.capacity = capacity
	den.spread = 1.5
	den.position = at
	_arena.add_child(den)
	return den


## A sky and a sun, the way a level has them: a day sky, an ambient light, one
## sun with shadows.
func _sky_and_sun() -> Array:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.36, 0.56, 0.84)
	material.sky_horizon_color = Color(0.74, 0.81, 0.88)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = material
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.76, 0.8)
	environment.ambient_light_energy = 0.35
	var sky := WorldEnvironment.new()
	sky.environment = environment
	_arena.add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	_arena.add_child(sun)
	sun.look_at_from_position(Vector3(0, 50, 0), Vector3(10, 0, 8), Vector3.UP)
	return [sky, sun]
