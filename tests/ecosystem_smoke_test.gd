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
