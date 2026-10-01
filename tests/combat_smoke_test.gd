extends WebSuite

## Headless smoke test for creatures that fight back.
##
##     godot --headless --path . --script res://tests/combat_smoke_test.gd
##
## Opens the same sandbox the web suite uses and puts hostile creatures in it, each
## section on a slab of its own well away from everything: that a hostile thing
## comes for the spider whatever its size, and that every kind of attack goes
## through its beats — a tell first, then the strike, then an opening — and does
## what it says to the spider and to the silk. The creatures are made here, with
## exactly the move a section is about, so a check never depends on the numbers a
## real species happens to have. Exits non-zero if anything comes back wrong.

const ARENA := Vector3(220.0, 0.0, 220.0)

var _slab: StaticBody3D


func run_checks() -> void:
	if not await open_sandbox():
		return
	for section: Callable in _sections():
		await reset()
		await section.call()
		if is_instance_valid(_slab):
			_slab.queue_free()
		await physics_frame


func _sections() -> Array[Callable]:
	return [
		_test_a_hostile_comes_whatever_its_size,
		_test_a_bite_is_told_first,
		_test_a_lunge_goes_where_you_were,
		_test_a_drill_sticks_in_the_wall,
		_test_a_spit_flies_and_a_web_stops_it,
		_test_a_spitter_keeps_its_distance,
		_test_a_tongue_drags_you_in,
		_test_a_burst_throws_and_dazes,
		_test_a_sweep_cuts_silk,
		_test_a_summon_calls_more,
		_test_a_stun_ends_an_attack,
		_test_the_drill_mosquito,
		_test_the_blade_rat,
		_test_the_charger_beetle,
	]


# --- sections -----------------------------------------------------------

## A hostile thing does not care how big you are. Something a Huntsman could eat
## in a mouthful still comes for it, from as far as it can see — where the same
## creature without the hostility leaves it alone.
func _test_a_hostile_comes_whatever_its_size() -> void:
	await _arena()
	var kind := _kind("biter", [_move(CreatureAttack.Kind.BITE, 0.9)])
	var calm := _kind("calm", [])
	calm.hostile = false
	calm.aggression = 1.0
	var biter := _put(kind, Vector3(3.0, 0.3, 0.0))
	var other := _put(calm, Vector3(-3.0, 0.3, 0.0))
	check(biter.size_class < spider.stage().bite_power,
		"it is small enough to eat (%d against a bite of %d)"
		% [biter.size_class, spider.stage().bite_power])
	check(biter.would_hunt(spider) and not other.would_hunt(spider),
		"and still the hostile one would hunt you, and the other would not")
	var noticed: bool = await wait_until(func() -> bool: return biter.is_hunting(), 300)
	check(noticed, "it comes for you on its own once it has seen you")
	check(not other.is_hunting(), "and the other one does not")
	check(biter.fighter != null, "with its moves to come for you with")


## Even a bite is told before it lands: a ring round the creature while it winds
## up, and nothing taken until the wind-up is over.
func _test_a_bite_is_told_first() -> void:
	await _arena()
	var bite := _move(CreatureAttack.Kind.BITE, 1.2, 0.5)
	bite.damage = 5.0
	var biter := _put(_kind("biter", [bite]), Vector3(0.7, 0.3, 0.0))
	biter.attack_spider(spider)
	var started: bool = await wait_until(func() -> bool:
		return biter.fighter.beat == CreatureFighter.Beat.WIND_UP, 60)
	if not check(started, "close enough to bite, it winds up"):
		return
	var health := spider.health
	check(_tells(biter) > 0, "and shows a tell while it does (%d)" % _tells(biter))
	await run_frames(10)
	check(is_equal_approx(spider.health, health), "nothing is taken during the tell")
	var struck: bool = await wait_until(func() -> bool:
		return biter.fighter.beat == CreatureFighter.Beat.RECOVER, 60)
	check(struck, "then it bites")
	check(spider.health < health - 4.0,
		"and the bite lands (%.1f -> %.1f)" % [health, spider.health])
	check(_tells(biter) == 0, "and the tell is gone with the wind-up")
	check(biter.fighter.cooling(bite) > 0.0, "and that bite has a wait before the next")


## A lunge goes in a straight line at where you were, and throws you if it
## reaches you.
func _test_a_lunge_goes_where_you_were() -> void:
	await _arena()
	var lunge := _move(CreatureAttack.Kind.LUNGE, 5.0, 0.4)
	lunge.speed = 12.0
	lunge.knockback = 6.0
	lunge.damage = 4.0
	var diver := _put(_kind("diver", [lunge]), Vector3(3.5, 0.3, 0.0))
	diver.attack_spider(spider)
	var started: bool = await wait_until(func() -> bool:
		return diver.fighter.beat == CreatureFighter.Beat.WIND_UP, 60)
	if not check(started, "from across the slab it winds up a lunge"):
		return
	check(diver.fighter.get_child_count() >= 2, "its tell has a line to you as well as a ring")
	var health := spider.health
	var from := diver.global_position
	var landed: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(landed, "and comes at you, and hits (%.1f -> %.1f)" % [health, spider.health])
	check(diver.global_position.distance_to(from) > 2.0,
		"having crossed the gap (%.1fm)" % diver.global_position.distance_to(from))
	check(not spider.climb.is_attached() and spider.velocity.length() > 2.0,
		"and it throws you (%.1f m/s)" % spider.velocity.length())


## A drill that goes into a wall instead of into you is stuck there for a while,
## which is the window.
func _test_a_drill_sticks_in_the_wall() -> void:
	await _arena()
	add_slab(_centre() + Vector3(-1.8, 1.0, 0.0), Vector3(0.4, 3.0, 6.0), _slab)
	await physics_frame
	var drill := _move(CreatureAttack.Kind.LUNGE, 5.0, 0.4)
	drill.speed = 10.0
	drill.stuck_on_miss = 2.0
	var kind := _kind("drill", [drill])
	kind.flying = true
	kind.wander_height = Vector2(0.3, 0.4)
	var diver := _put(kind, Vector3(3.0, 0.5, 0.0))
	diver.attack_spider(spider)
	var going: bool = await wait_until(func() -> bool:
		return diver.fighter.beat == CreatureFighter.Beat.STRIKE, 120)
	if not check(going, "it dives"):
		return
	# Out of the way once it has committed: it goes on to where you were, and the
	# wall behind you.
	place(_centre() + Vector3(0.0, 0.5, 3.0))
	var stuck: bool = await wait_until(func() -> bool: return diver.fighter.is_stuck_fast(), 120)
	check(stuck, "missing you, it goes into the wall and sticks there")
	if stuck:
		var held := diver.global_position
		await run_frames(40)
		check(diver.global_position.distance_to(held) < 0.05,
			"and stays stuck (%.2fm)" % diver.global_position.distance_to(held))


## A spit is a glob that flies at where you were. In the open it hits; with a web
## strung between you and the spitter, the web takes it. And something that spits
## keeps its distance while it waits to spit again, rather than walking up to you.
func _test_a_spit_flies_and_a_web_stops_it() -> void:
	await _arena()
	var spit := _move(CreatureAttack.Kind.SPIT, 8.0, 0.3)
	spit.speed = 14.0
	spit.damage = 4.0
	spit.cooldown = 1.5
	var spitter := _put(_kind("spitter", [spit]), Vector3(4.0, 0.3, 0.0))
	var stands := spitter.global_position
	spitter.attack_spider(spider)
	var health := spider.health
	var hit: bool = await wait_until(func() -> bool: return spider.health < health, 180)
	check(hit, "in the open the spit hits (%.1f -> %.1f)" % [health, spider.health])

	# Now a web across the line of fire, while it waits to spit again.
	if not check(await _sheet_between(spitter) != null, "a web goes up between you"):
		return
	health = spider.health
	var again: bool = await wait_until(func() -> bool:
		return spitter.fighter.beat == CreatureFighter.Beat.WIND_UP, 240)
	check(again, "and it winds up to spit again")
	var thrown: bool = await wait_until(func() -> bool:
		return spitter.fighter.beat == CreatureFighter.Beat.RECOVER, 120)
	check(thrown, "and spits")
	await run_frames(40)
	check(is_equal_approx(spider.health, health),
		"and the web stops it (%.1f -> %.1f)" % [health, spider.health])
	check(spitter.is_hunting() and not spitter.is_stuck(),
		"having kept its distance rather than walk into your web")
	check(spitter.global_position.distance_to(stands) < 0.8,
		"near where it started (%.2fm)" % spitter.global_position.distance_to(stands))


## Something that would rather fight from off you keeps off you. Too close for its
## spit, it gives ground until it has room rather than come in with its sting; it
## does not walk up to you while the spit cools; and only if you come to it does it
## sting.
func _test_a_spitter_keeps_its_distance() -> void:
	await _arena()
	var spit := _move(CreatureAttack.Kind.SPIT, 8.0, 0.3)
	spit.min_reach = 2.5
	spit.speed = 14.0
	spit.cooldown = 2.0
	var sting := _move(CreatureAttack.Kind.BITE, 0.9, 0.3)
	sting.id = "sting"
	sting.chases = false
	sting.cooldown = 1.0
	var spitter := _put(_kind("spitter", [sting, spit]), Vector3(1.5, 0.3, 0.0))
	spitter.attack_spider(spider)
	var started: bool = await wait_until(func() -> bool:
		return spitter.fighter.is_attacking(), 240)
	if not check(started, "close in, it still gets an attack off"):
		return
	check(spitter.fighter.attack == spit,
		"and it is the spit, not the sting (%s)" % spitter.fighter.attack.id)
	check(_span(spitter) > 2.3,
		"from far enough off for one, having given ground (%.1fm, from 1.5m)" % _span(spitter))
	await wait_until(func() -> bool: return not spitter.fighter.is_attacking(), 120)
	var nearest := INF
	for i in 60:
		await physics_frame
		nearest = minf(nearest, _span(spitter))
	check(nearest > 2.0,
		"and while it waits to spit again it does not come in (nearest %.1fm)" % nearest)

	# Come to it, though, and it stings.
	await wait_until(func() -> bool: return not spitter.fighter.is_attacking(), 120)
	var beside := spitter.global_position + (spider.global_position
		- spitter.global_position).normalized() * 0.7
	place(Vector3(beside.x, spider.global_position.y, beside.z))
	var stung: bool = await wait_until(func() -> bool:
		return spitter.fighter.attack == sting, 60)
	check(stung, "but walk up to it and it stings")


## A tongue goes out to you in a straight line and reels you in to be bitten.
func _test_a_tongue_drags_you_in() -> void:
	await _arena()
	var tongue := _move(CreatureAttack.Kind.TONGUE, 5.0, 0.3)
	tongue.speed = 10.0
	tongue.strike_time = 1.2
	tongue.damage = 3.0
	var frog := _put(_kind("tongue", [tongue], 0.35), Vector3(3.5, 0.3, 0.0))
	frog.attack_spider(spider)
	var from := spider.global_position
	var health := spider.health
	var dragged: bool = await wait_until(func() -> bool: return spider.is_dragged(), 120)
	check(dragged, "the tongue gets hold of you")
	var bitten: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(bitten, "and you are bitten when it has you (%.1f -> %.1f)" % [health, spider.health])
	check(spider.global_position.distance_to(frog.global_position)
		< from.distance_to(frog.global_position) - 1.5,
		"having been reeled in (%.1fm from it, from %.1fm)"
		% [spider.global_position.distance_to(frog.global_position),
		from.distance_to(frog.global_position)])


## A burst takes in everything round it at once: inside its ring you are hurt,
## thrown and dazed, and a dazed spider does nothing it is told.
func _test_a_burst_throws_and_dazes() -> void:
	await _arena()
	var burst := _move(CreatureAttack.Kind.BURST, 2.0, 0.4)
	burst.radius = 2.0
	burst.knockback = 5.0
	burst.daze = 1.5
	burst.damage = 3.0
	var screecher := _put(_kind("screecher", [burst]), Vector3(1.2, 0.3, 0.0))
	screecher.attack_spider(spider)
	var health := spider.health
	var hit: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(hit, "inside its ring, the burst catches you")
	check(spider.is_dazed(), "and dazes you")
	check(not spider.accepts_input(), "so the keys do nothing for now")
	check(not spider.climb.is_attached(), "and throws you")
	await run_frames(110)
	check(not spider.is_dazed(), "and the daze wears off")


## A sweep cuts the silk in front of it, and only in front.
func _test_a_sweep_cuts_silk() -> void:
	await _arena()
	var sweep := _move(CreatureAttack.Kind.SWEEP, 1.6, 0.4)
	sweep.radius = 1.8
	sweep.arc = 120.0
	sweep.cuts_silk = true
	var slasher := _put(_kind("slasher", [sweep]), Vector3(1.0, 0.3, 0.0))
	var line_pattern := pattern_named("frame_line")
	var floor_y := spider.global_position.y - 0.2
	var at := slasher.global_position
	# One line between it and you, and one behind it.
	var ahead := WebStrand.spin(line_pattern, Vector3(at.x - 0.6, floor_y, at.z - 1.0),
		Vector3(at.x - 0.6, floor_y, at.z + 1.0), 1.0)
	var behind := WebStrand.spin(line_pattern, Vector3(at.x + 1.2, floor_y, at.z - 1.0),
		Vector3(at.x + 1.2, floor_y, at.z + 1.0), 1.0)
	ahead.place_in(webs)
	behind.place_in(webs)
	await physics_frame
	slasher.attack_spider(spider)
	var struck: bool = await wait_until(func() -> bool:
		return slasher.fighter.beat == CreatureFighter.Beat.RECOVER, 120)
	check(struck, "it sweeps")
	await run_frames(2)
	check(not is_instance_valid(ahead) or ahead.is_queued_for_deletion(),
		"and the line in front of it is cut")
	check(is_instance_valid(behind) and not behind.is_queued_for_deletion(),
		"and the one behind it is not")


## A summon calls more of a kind, which come for you — and no more than it says.
func _test_a_summon_calls_more() -> void:
	await _arena()
	# A spiderling, so that what is called — wasps — would come for it anyway.
	spider.growth.start_stage = 0
	spider.growth.apply_initial()
	await run_frames(10)
	var call := _move(CreatureAttack.Kind.SUMMON, 8.0, 0.3)
	call.summons = "wasp"
	call.summon_count = 2
	call.cooldown = 0.5
	var caller := _put(_kind("caller", [call]), Vector3(3.0, 0.3, 0.0))
	caller.attack_spider(spider)
	var called: bool = await wait_until(func() -> bool:
		return _named("Wasp").size() >= 2, 180)
	check(called, "it calls up wasps (%d)" % _named("Wasp").size())
	await run_frames(150)
	check(_named("Wasp").size() == 2, "and never more than it may have out (%d)"
		% _named("Wasp").size())
	var hunting := 0
	for wasp in _named("Wasp"):
		if wasp.is_hunting():
			hunting += 1
	check(hunting > 0, "and they come for you (%d of them)" % hunting)


## Anything that takes the creature out of the fight mid-attack ends the attack:
## stunned in its wind-up, it does not bite when it comes round, and the tell goes.
func _test_a_stun_ends_an_attack() -> void:
	await _arena()
	var bite := _move(CreatureAttack.Kind.BITE, 1.2, 0.8)
	var biter := _put(_kind("biter", [bite]), Vector3(0.7, 0.3, 0.0))
	biter.attack_spider(spider)
	var started: bool = await wait_until(func() -> bool:
		return biter.fighter.beat == CreatureFighter.Beat.WIND_UP, 60)
	if not check(started, "it winds up"):
		return
	var health := spider.health
	biter.stun(1.0)
	await run_frames(3)
	check(not biter.fighter.is_attacking(), "stunned, the attack is off")
	check(_tells(biter) == 0, "and so is the tell")
	await run_frames(30)
	check(is_equal_approx(spider.health, health), "and the bite never comes")


# --- the hostiles -------------------------------------------------------
#
# The species themselves, as the game ships them: each one's own move, at the
# range it is meant for, doing what its description says it does.

## The Drill Mosquito keeps out of reach of its own bite and dives from there,
## hard enough to throw a Huntsman.
func _test_the_drill_mosquito() -> void:
	await _arena()
	var kind := _species("drill_mosquito")
	if not _kit(kind, "drill_dive", CreatureAttack.Kind.LUNGE):
		return
	var mosquito := _put(kind, Vector3(4.5, 1.0, 0.0))
	var from := mosquito.global_position
	mosquito.attack_spider(spider)
	var health := spider.health
	var dove: bool = await wait_until(func() -> bool:
		return _using(mosquito, "drill_dive"), 120)
	if not check(dove, "from across the slab, it dives"):
		return
	var hit: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(hit and health - spider.health > 5.0,
		"and the dive lands hard (%.1f -> %.1f)" % [health, spider.health])
	check(mosquito.global_position.distance_to(from) > 3.0,
		"having come the whole way in one go (%.1fm)" % mosquito.global_position.distance_to(from))
	check(not spider.climb.is_attached(), "and it throws you")


## The Blade Rat's slash goes through your silk as well as through you: a line
## between you is no shield from it.
func _test_the_blade_rat() -> void:
	await _arena()
	var kind := _species("blade_rat")
	if not _kit(kind, "slash", CreatureAttack.Kind.SWEEP):
		return
	var at := _centre() + Vector3(1.4, 0.0, 0.0)
	var floor_y := spider.global_position.y - 0.2
	var line := WebStrand.spin(pattern_named("frame_line"),
		Vector3(at.x - 0.7, floor_y, at.z - 1.0), Vector3(at.x - 0.7, floor_y, at.z + 1.0), 1.0)
	line.place_in(webs)
	await physics_frame
	var rat := _put(kind, Vector3(1.4, 0.3, 0.0))
	rat.attack_spider(spider)
	var health := spider.health
	var slashed: bool = await wait_until(func() -> bool:
		return _using(rat, "slash") and rat.fighter.beat == CreatureFighter.Beat.RECOVER, 120)
	if not check(slashed, "a step off, it slashes"):
		return
	await run_frames(2)
	check(spider.health < health - 4.0,
		"and the slash lands (%.1f -> %.1f)" % [health, spider.health])
	check(not is_instance_valid(line) or line.is_queued_for_deletion(),
		"and goes through the line between you on the way")


## The Charger Beetle comes from a long way off in a straight line and throws you
## a long way. A web across its path stops it dead.
func _test_the_charger_beetle() -> void:
	await _arena()
	var kind := _species("charger_beetle")
	if not _kit(kind, "horn_charge", CreatureAttack.Kind.LUNGE):
		return
	var beetle := _put(kind, Vector3(6.0, 0.3, 0.0))
	var from := beetle.global_position
	beetle.attack_spider(spider)
	var health := spider.health
	var charged: bool = await wait_until(func() -> bool:
		return _using(beetle, "horn_charge"), 120)
	if not check(charged, "from six metres off, it charges"):
		return
	var hit: bool = await wait_until(func() -> bool: return spider.health < health, 180)
	check(hit and health - spider.health > 6.0,
		"and it lands (%.1f -> %.1f)" % [health, spider.health])
	check(beetle.global_position.distance_to(from) > 4.0,
		"having crossed the gap (%.1fm)" % beetle.global_position.distance_to(from))
	check(spider.velocity.length() > 5.0,
		"and it throws you hard (%.1f m/s)" % spider.velocity.length())

	# Another, from the other side, with a web across its path.
	beetle.queue_free()
	stand_on(_centre())
	await run_frames(20)
	var other := _put(kind, Vector3(-6.0, 0.3, 0.0))
	await run_frames(10)
	if not check(await _sheet_between(other) != null, "a web goes up between you and another"):
		return
	health = spider.health
	other.attack_spider(spider)
	var again: bool = await wait_until(func() -> bool:
		return _using(other, "horn_charge") \
			and other.fighter.beat == CreatureFighter.Beat.STRIKE, 180)
	if not check(again, "which charges too"):
		return
	var caught: bool = await wait_until(func() -> bool: return other.is_stuck(), 120)
	check(caught, "into the web, which stops it dead")
	await run_frames(2)
	check(not other.fighter.is_attacking(), "and that is the end of the charge")
	check(is_equal_approx(spider.health, health),
		"which never reaches you (%.1f -> %.1f)" % [health, spider.health])


# --- helpers ------------------------------------------------------------

## A slab of its own, far from everything, with a whole Huntsman standing on it.
func _arena() -> void:
	_slab = add_slab(ARENA, Vector3(16, 0.5, 16))
	await physics_frame
	clear_prey_near(ARENA, 30.0, null)
	spider.growth.start_stage = 2
	spider.growth.apply_initial()
	stand_on(ARENA + Vector3(0, 0.25, 0))
	spider.view.pitch = 0.0
	await run_frames(20)
	spider.health = spider.max_stamina()
	spider.vitals.quiet = 0.0


func _centre() -> Vector3:
	return ARENA + Vector3(0, 0.25, 0)


func _kind(id: String, moves: Array, radius := 0.3) -> PreySpecies:
	var kind := PreySpecies.new()
	kind.id = id
	kind.display_name = id.capitalize()
	kind.hostile = true
	kind.aggression = 1.0
	kind.hunt_range = 12.0
	kind.size_class = 1
	kind.body_radius = radius
	kind.move_speed = 3.0
	kind.flying = false
	kind.wander_height = Vector2(0.0, 0.2)
	kind.struggle_power = 2.0
	kind.struggle_stamina = 5.0
	var typed: Array[CreatureAttack] = []
	for move in moves:
		typed.append(move)
	kind.attacks = typed
	return kind


func _move(kind: CreatureAttack.Kind, reach: float, wind_up := 0.3) -> CreatureAttack:
	var move := CreatureAttack.new()
	move.id = CreatureAttack.Kind.keys()[kind].to_lower()
	move.kind = kind
	move.reach = reach
	move.wind_up = wind_up
	move.recover = 0.4
	move.cooldown = 30.0
	move.damage = 4.0
	return move


func _put(kind: PreySpecies, offset: Vector3) -> Prey:
	var creature := Prey.of(kind)
	level.add_child(creature)
	creature.global_position = _centre() + offset
	return creature


## A sheet web stood across the way halfway between the spider and [param creature].
func _sheet_between(creature: Prey) -> WebStructure:
	var middle := spider.global_position.lerp(creature.global_position, 0.5)
	var across := creature.global_position - spider.global_position
	across.y = 0.0
	var side := across.normalized().cross(Vector3.UP)
	select_pattern("sheet_web")
	builder.start()
	for corner in [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(0.9, 0.9), Vector2(-0.9, 0.9)]:
		builder.add_anchor(middle + side * corner.x + Vector3.UP * corner.y)
	builder.finish()
	builder.stop()
	await run_frames(3)
	return newest_web("sheet_web")


## One of the game's own hostiles, as it ships.
func _species(id: String) -> PreySpecies:
	return load(CreatureFighter.HOSTILES_DIR.path_join(id + ".tres")) as PreySpecies


## That [param kind] is a hostile as one should be: hostile whatever its size, a
## bite of some sort to fall back on, the move it is known for, and a fight an orb
## web wins in a few shots — not one, and not a siege. Returns whether there is
## enough of it to go on with.
func _kit(kind: PreySpecies, signature: String, of_kind: CreatureAttack.Kind) -> bool:
	if not check(kind != null, "it is one of the hostiles"):
		return false
	check(kind.hostile, "the %s is hostile" % kind.display_name)
	var bite: CreatureAttack = null
	var move: CreatureAttack = null
	for each in kind.attacks:
		if each.kind == CreatureAttack.Kind.BITE and bite == null:
			bite = each
		if each.id == signature:
			move = each
	check(bite != null, "with a bite to fall back on (%s)" % (bite.id if bite != null else "none"))
	if not check(move != null and move.kind == of_kind, "and its own %s, a %s"
			% [signature, String(CreatureAttack.Kind.keys()[of_kind]).to_lower()]):
		return false
	var hold := builder.shot_hold(pattern_named("orb_web"), 2.0)
	var shots := ceili(kind.total_thrash() / maxf(hold * Prey.ESCAPE_MARGIN, 0.001))
	check(shots >= 2 and shots <= 4,
		"and an orb web takes it in %d shots: more than one, and not a siege" % shots)
	return true


## Whether [param creature] is in the middle of the move called [param move_id].
func _using(creature: Prey, move_id: String) -> bool:
	return creature.fighter != null and creature.fighter.attack != null \
		and creature.fighter.attack.id == move_id


func _span(creature: Prey) -> float:
	return creature.global_position.distance_to(spider.global_position)


func _tells(creature: Prey) -> int:
	var count := 0
	for child in creature.fighter.get_children():
		if child is MeshInstance3D and not child.is_queued_for_deletion():
			count += 1
	return count


func _named(display_name: String) -> Array[Prey]:
	var found: Array[Prey] = []
	for node in level.get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and creature.species == display_name \
				and not creature.is_queued_for_deletion():
			found.append(creature)
	return found
