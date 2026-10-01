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
		_test_forage,
		_test_grazing,
		_test_a_full_creature_stays_put,
		_test_fliers_eat_from_above,
		_test_diets,
		_test_a_kill,
		_test_too_big_to_take,
		_test_carcasses,
		_test_scavengers,
		_test_flies_on_carcasses,
		_test_running_from_a_hunter,
		_test_wary_of_the_spider,
	]


# --- the world on its own --------------------------------------------------

## Without an ecosystem a creature has no needs: it is the creature every check
## written before there was one was written against.
func _test_no_ecosystem() -> void:
	check(Ecosystem.of(_arena) == null, "an arena with no ecosystem in it")
	var beetle := _creature("beetle", Vector3(0, 0.3, 0), PackedStringArray(["moss"]))
	await physics_frame
	check(beetle.mind() == null, "has creatures with no minds — they only wander")


func _test_the_clock() -> void:
	check(_world != null and Ecosystem.of(_arena) == _world, "an ecosystem to live in")
	_world.time_of_day = 0.5
	check(_world.is_day() and _world.daylight() > 0.95, "noon is day, and full light")
	check(_world.clock_text() == "12:00", "which the clock calls 12:00 (%s)" % _world.clock_text())
	check(_world.awake(PreySpecies.Activity.DAY) and not _world.awake(PreySpecies.Activity.NIGHT),
		"something out by day is out, and something out by night is not")
	_world.time_of_day = 0.0
	check(not _world.is_day() and _world.daylight() < 0.05, "midnight is night, and dark")
	check(_world.awake(PreySpecies.Activity.NIGHT) and _world.awake(PreySpecies.Activity.ALWAYS),
		"the night creatures are out, and the ones out at all hours")
	_world.time_of_day = 0.25
	var dawn := _world.daylight()
	check(dawn > 0.2 and dawn < 0.8, "dawn is half light (%.2f)" % dawn)
	_world.day_length = 10.0
	_world.running = true
	var was := _world.time_of_day
	await run_frames(60)
	_world.running = false
	check(_world.time_of_day > was + 0.05,
		"and the day goes round (%.2f -> %.2f in a second of a ten-second day)"
		% [was, _world.time_of_day])


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
func _test_grazing() -> void:
	var moss := _patch("moss", Vector3(8, 0, 0), 40.0, 2.0)
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
	var hunter := _creature("wasp", Vector3(0, 1, 0), PackedStringArray(["insect", "moth"]))
	await physics_frame
	var mind := hunter.mind()
	check(mind.eats(fly), "a diet of insects takes anything tagged an insect")
	check(mind.eats(PreyLibrary.find("moth")), "and a species named outright")
	check(not mind.eats(PreyLibrary.find("bee")), "and nothing it does not name")
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
