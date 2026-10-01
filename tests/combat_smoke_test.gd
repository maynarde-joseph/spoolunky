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
		_test_a_hostile_must_see_you,
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
		_test_a_meal_mends_where_waiting_does_not,
		_test_waking_somewhere,
		_test_a_shrine_is_where_you_wake,
		_test_a_gate_opens_from_its_far_side,
		_test_a_hurt_thing_is_an_easier_catch,
		_test_a_boss_is_named_while_it_fights,
		_test_the_drill_mosquito,
		_test_the_blade_rat,
		_test_the_charger_beetle,
		_test_the_spitter_wasp,
		_test_the_tongue_frog,
		_test_the_screech_bat,
		_test_the_rat_king,
		_test_a_lair_seals_until_its_keeper_is_beaten,
		_test_the_hollow_wyrm,
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


## A hostile thing still has to know you are there. Behind a wall it does not
## come for you, however near; take the wall away and it does.
func _test_a_hostile_must_see_you() -> void:
	await _arena()
	var wall := add_slab(_centre() + Vector3(1.6, 1.5, 0.0), Vector3(0.4, 3.0, 16.0), _slab)
	await physics_frame
	var kind := _kind("biter", [_move(CreatureAttack.Kind.BITE, 0.9)])
	kind.wander_radius = 1.5
	var biter := _put(kind, Vector3(4.0, 0.3, 0.0))
	await run_frames(240)
	check(not biter.is_hunting(),
		"behind a wall, %.1fm off, it has not seen you" % _span(biter))
	wall.queue_free()
	var seen: bool = await wait_until(func() -> bool: return biter.is_hunting(), 120)
	check(seen, "and with the wall gone, it comes")


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


## Where nothing mends on its own, a meal does: a quiet spell gives nothing back,
## and drinking something you have wrapped does.
func _test_a_meal_mends_where_waiting_does_not() -> void:
	await _arena()
	spider.mends_on_its_own = false
	spider.drink_heals = 0.6
	spider.health = spider.max_stamina() * 0.4
	spider.vitals.quiet = 0.0
	var low := spider.health
	await run_frames(240)
	check(is_equal_approx(spider.health, low),
		"four quiet seconds give nothing back (%.1f)" % spider.health)
	var meal := spawn("cockroach", spider.global_position + Vector3(0.6, 0.2, 0.0))
	if not check(meal != null and meal.bundle(), "something wrapped to drink"):
		return
	await run_frames(20)
	var got: float = await eat(meal, 600)
	check(got > 0.0, "it goes down (+%.1f biomass)" % got)
	check(spider.health > low + got * 0.5,
		"and mends you as it does (%.1f -> %.1f)" % [low, spider.health])


## Waking somewhere puts you there whole, with nothing in hand, and makes it where
## you come back to if you fall out of the world.
func _test_waking_somewhere() -> void:
	await _arena()
	spider.health = spider.max_stamina() * 0.25
	spider.daze(5.0)
	var bed := Transform3D(Basis(Vector3.UP, PI * 0.5), _centre() + Vector3(-3.0, 0.6, 2.0))
	spider.wake_at(bed)
	await run_frames(30)
	check(spider.global_position.distance_to(bed.origin) < 1.0,
		"you wake where you were put (%.2fm off)" % spider.global_position.distance_to(bed.origin))
	check(is_equal_approx(spider.health, spider.max_stamina()), "whole")
	check(not spider.is_dazed(), "and clear-headed")
	spider.global_position = _centre() + Vector3(0.0, spider.kill_plane - 10.0 - _centre().y, 0.0)
	await run_frames(3)
	check(spider.global_position.distance_to(bed.origin) < 1.5,
		"and falling out of the world puts you back there too")


## Hurt, a thing is an easier catch: the lower its health, the more of the way one
## hit of silk gets you, until with nothing left one hit takes it outright. And a
## hostile wears both numbers over its head while there is anything to say.
func _test_a_hurt_thing_is_an_easier_catch() -> void:
	await _arena()
	var rat := _put(_species("blade_rat"), Vector3(5.0, 0.3, 0.0))
	await run_frames(3)
	var hold := builder.shot_hold(pattern_named("orb_web"), 2.0)
	var whole := rat.bind_share(hold)
	check(is_equal_approx(rat.health(), 1.0) and not rat.taken_cleanly_by(hold),
		"whole, one orb shot does not take it (%d%% of the way)" % roundi(whole * 100.0))
	rat.wound(0.6)
	var hurt := rat.bind_share(hold)
	check(hurt > whole * 1.8, "at %d%% health one shot does twice as much (%d%%)"
		% [roundi(rat.health() * 100.0), roundi(hurt * 100.0)])
	rat.wound(1.0)
	check(rat.health() <= 0.0 and rat.taken_cleanly_by(hold),
		"and with nothing left, one shot takes it outright")
	rat.wounded = 0.0

	var bar := rat.get_node_or_null("Bar") as CreatureBar
	if not check(bar != null, "it wears a bar over its head"):
		return
	await run_frames(2)
	check(not bar.visible, "which says nothing while it is whole and minding its own business")
	rat.attack_spider(spider)
	await run_frames(2)
	check(bar.visible, "and shows once it comes for you")
	rat.bundle()
	await run_frames(2)
	check(not bar.visible, "and is gone once it is wrapped")


## A boss is named across the foot of the screen while it comes for you, with its
## health and how much of it is wrapped under its name — and gone from there once
## it is not.
func _test_a_boss_is_named_while_it_fights() -> void:
	await _arena()
	var hud := level.get_node("HUD")
	var kind := _kind("champion", [_move(CreatureAttack.Kind.BITE, 0.9)])
	kind.boss = true
	kind.display_name = "The Champion"
	var champion := _put(kind, Vector3(4.0, 0.3, 0.0))
	await run_frames(5)
	check(hud.boss_on_you() == null, "not yet coming for you, it is not named")
	champion.attack_spider(spider)
	await run_frames(5)
	check(hud.boss_on_you() == champion, "coming for you, it is")
	var bar := hud.get_node("BossBar") as Control
	check(bar.visible and (bar.get_node("BossName") as Label).text == "The Champion",
		"by name, across the foot of the screen")
	champion.bind(0.4)
	champion.wound(0.3)
	await run_frames(2)
	var health := (bar.get_node("BossHealth") as ProgressBar).value
	var wrapped := (bar.get_node("BossWrap") as ProgressBar).value
	check(health > 0.65 and health < 0.75,
		"with its health under its name (%d%%)" % roundi(health * 100.0))
	check(wrapped > 0.3 and wrapped < 0.45,
		"and how much of it is wrapped under that (%d%%)" % roundi(wrapped * 100.0))
	champion.bundle()
	await run_frames(3)
	check(not bar.visible, "and gone once it is wrapped")


## A shrine is where you wake. Touching it lights it; resting at it makes you whole
## and puts back everything you put down; driven off, you wake at it, whole, and
## everything is put back again. A boss is back at its post if it beat you, and
## stays down once you have beaten it.
func _test_a_shrine_is_where_you_wake() -> void:
	await _arena()
	var keeper := Checkpoints.new()
	keeper.wake_after = 0.5
	_slab.add_child(keeper)
	var shrine := Shrine.make(_slab, "Test Shrine", _centre() + Vector3(-6.0, 0.0, -5.0),
		Vector3.RIGHT)
	var mark := _mark("blade_rat", Vector3(6.5, 0.4, 6.5))
	var lair := _mark("charger_beetle", Vector3(-6.5, 0.4, 6.5))
	lair.stays_beaten = true
	await run_frames(5)
	check(mark.creature != null and lair.creature != null, "each mark stands its creature up")
	check(not shrine.lit and keeper.shrine == null, "the shrine is cold until you come to it")

	stand_on(shrine.wake_transform().origin - Vector3(0.0, 0.6, 0.0))
	var lit: bool = await wait_until(func() -> bool: return shrine.lit, 30)
	check(lit, "standing at it lights it")
	check(keeper.shrine == shrine, "and it is where you will wake")

	var first := mark.creature
	first.bundle()
	await physics_frame
	check(mark.is_down(), "put the one at the mark down")
	spider.health = spider.max_stamina() * 0.3
	check(keeper.rest_at(shrine), "and rest")
	await physics_frame
	check(is_equal_approx(spider.health, spider.max_stamina()), "whole again")
	check(mark.creature != null and mark.creature != first and not mark.is_down(),
		"and a fresh one is back on its feet at the mark")

	place(_centre() + Vector3(1.0, 0.6, -6.0))
	spider.take_bite(spider.max_stamina() + 1.0)
	check(keeper.is_waking(), "driven off, you are on your way back")
	await wait_until(func() -> bool: return not keeper.is_waking(), 120)
	await run_frames(10)
	var off := spider.global_position.distance_to(shrine.wake_transform().origin)
	check(off < 1.0, "you wake at the shrine (%.2fm off)" % off)
	check(is_equal_approx(spider.health, spider.max_stamina()), "whole")
	check(not lair.is_down(), "and a boss you have not beaten is still at its post")

	lair.creature.bundle()
	await run_frames(2)
	check(lair.beaten, "beaten, a boss is beaten for good")
	keeper.stir()
	await physics_frame
	check(lair.creature == null, "and stays down when the Hollows stir")

	# Put down in the very moment the place stirs, it still counts — and says so.
	var other := _mark("charger_beetle", Vector3(6.5, 0.4, -6.5))
	other.stays_beaten = true
	await run_frames(3)
	var heard := [0]
	other.beaten_for_good.connect(func(_mark: HostileSpawn) -> void: heard[0] += 1)
	other.creature.bundle()
	keeper.stir()
	await physics_frame
	check(other.beaten and other.creature == null and heard[0] == 1,
		"a boss put down as you rest is beaten all the same, and heard to be (%d)" % heard[0])


## A shortcut gate is a wall from the near side and opens from the far one: touch
## its lever and it rises out of the way, and stays out of it.
func _test_a_gate_opens_from_its_far_side() -> void:
	await _arena()
	var gate := ShortcutGate.make(_slab, "Test Gate", _centre() + Vector3(2.0, 0.0, -2.5),
		_centre() + Vector3(2.4, 3.0, 2.5), _centre() + Vector3(4.5, 0.0, 0.0))
	await physics_frame
	var through := func() -> bool:
		var query := PhysicsRayQueryParameters3D.create(_centre() + Vector3(0.0, 1.0, 0.0),
			_centre() + Vector3(4.0, 1.0, 0.0), GameLayers.WORLD)
		return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	check(not through.call(), "shut, it fills the way")
	await run_frames(30)
	check(not gate.open, "and from the near side nothing opens it")
	stand_on(gate.lever_at + Vector3(0.6, 0.0, 0.0))
	var opened: bool = await wait_until(func() -> bool: return gate.open, 30)
	check(opened, "touch the lever on the far side and it opens")
	var clear: bool = await wait_until(func() -> bool: return gate.is_clear(), 180)
	check(clear, "rising all the way out of the way")
	check(through.call(), "and the way through is open")


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


## The Spitter Wasp spits from well off and stays well off: it hits you from across
## the slab and does not come in after you while it waits to spit again.
func _test_the_spitter_wasp() -> void:
	await _arena()
	var kind := _species("spitter_wasp")
	if not _kit(kind, "venom_spit", CreatureAttack.Kind.SPIT):
		return
	var wasp := _put(kind, Vector3(6.0, 1.2, 0.0))
	wasp.attack_spider(spider)
	var health := spider.health
	var spat: bool = await wait_until(func() -> bool: return _using(wasp, "venom_spit"), 120)
	if not check(spat, "from six metres off, it spits"):
		return
	var hit: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(hit, "and the spit hits you (%.1f -> %.1f)" % [health, spider.health])
	var nearest := INF
	for i in 150:
		await physics_frame
		nearest = minf(nearest, _span(wasp))
	check(nearest > 3.0, "and it keeps its distance after (nearest %.1fm)" % nearest)


## The Tongue Frog sits where it is, and from a few metres off its tongue reels you
## in to its mouth. Silk between you takes the tongue instead.
func _test_the_tongue_frog() -> void:
	await _arena()
	var kind := _species("tongue_frog")
	if not _kit(kind, "tongue_lash", CreatureAttack.Kind.TONGUE):
		return
	var frog := _put(kind, Vector3(5.0, 0.3, 0.0))
	await run_frames(10)
	var sits := frog.global_position
	var web := await _sheet_between(frog)
	if not check(web != null, "a web goes up between you"):
		return
	frog.attack_spider(spider)
	var health := spider.health
	var lashed: bool = await wait_until(func() -> bool:
		return _using(frog, "tongue_lash") and frog.fighter.beat == CreatureFighter.Beat.RECOVER,
		120)
	if not check(lashed, "from five metres off, its tongue comes out"):
		return
	check(not spider.is_dragged() and is_equal_approx(spider.health, health),
		"and the web takes it")

	# The same again with nothing in the way.
	web.demolish()
	await physics_frame
	var dragged: bool = await wait_until(func() -> bool: return spider.is_dragged(), 400)
	check(dragged, "with the web gone, the next one gets hold of you")
	check(frog.global_position.distance_to(sits) < 1.5,
		"having waited about where it sat rather than come to you (%.2fm)"
		% frog.global_position.distance_to(sits))
	var bitten: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(bitten, "and reels you in to be bitten (%.1f -> %.1f)" % [health, spider.health])
	check(_span(frog) < 2.0, "right up to its mouth (%.1fm)" % _span(frog))


## The Screech Bat's screech takes in everything round it: inside the ring you are
## thrown and dazed. The ring is shown first, and outside it when it comes you are
## not touched.
func _test_the_screech_bat() -> void:
	await _arena()
	var kind := _species("screech_bat")
	if not _kit(kind, "screech", CreatureAttack.Kind.BURST):
		return
	var bat := _put(kind, Vector3(1.8, 1.0, 0.0))
	bat.attack_spider(spider)
	var health := spider.health
	var screeching: bool = await wait_until(func() -> bool: return _using(bat, "screech"), 120)
	if not check(screeching, "close over you, it screeches"):
		return
	check(_tells(bat) > 0, "its ring shown first")
	var hit: bool = await wait_until(func() -> bool: return spider.health < health, 120)
	check(hit, "and inside the ring you are caught (%.1f -> %.1f)" % [health, spider.health])
	check(spider.is_dazed() and not spider.climb.is_attached(), "thrown and dazed")

	# The next one, stepped out of while the ring shows.
	var again: bool = await wait_until(func() -> bool:
		return _using(bat, "screech") and bat.fighter.beat == CreatureFighter.Beat.WIND_UP, 480)
	if not check(again, "it screeches again"):
		return
	var away := spider.global_position - bat.global_position
	away.y = 0.0
	var out := bat.global_position + away.normalized() * (bat.fighter.attack.radius + 1.0)
	place(Vector3(out.x, spider.global_position.y, out.z))
	health = spider.health
	await wait_until(func() -> bool: return bat.fighter.beat != CreatureFighter.Beat.WIND_UP, 120)
	await run_frames(2)
	check(is_equal_approx(spider.health, health) and not spider.is_dazed(),
		"and outside the ring it does nothing to you (%.1f -> %.1f)" % [health, spider.health])


## The Rat King spins where it stands and cuts every thread round it, in front and
## behind; and calls its blade rats out of the walls.
func _test_the_rat_king() -> void:
	await _arena()
	var kind := _species("rat_king")
	if not _kit(kind, "whirl", CreatureAttack.Kind.SWEEP, Vector2i(4, 9)):
		return
	var moves := {}
	for each in kind.attacks:
		moves[each.id] = each
	check(kind.boss and moves.has("rally") and moves.has("pounce"),
		"a boss, with a rally and a pounce besides")
	var at := _centre() + Vector3(2.4, 0.0, 0.0)
	var floor_y := spider.global_position.y - 0.2
	var line := pattern_named("frame_line")
	var ahead := WebStrand.spin(line, Vector3(at.x - 1.2, floor_y, at.z - 1.2),
		Vector3(at.x - 1.2, floor_y, at.z + 1.2), 1.0)
	var behind := WebStrand.spin(line, Vector3(at.x + 1.6, floor_y, at.z - 1.2),
		Vector3(at.x + 1.6, floor_y, at.z + 1.2), 1.0)
	ahead.place_in(webs)
	behind.place_in(webs)
	await physics_frame
	var king := _put(kind, Vector3(2.4, 0.4, 0.0))
	# One thing at a time: the rally waits while the whirl is looked at.
	king.fighter._cooling[moves["rally"]] = 60.0
	king.attack_spider(spider)
	var whirled: bool = await wait_until(func() -> bool:
		return _using(king, "whirl") and king.fighter.beat == CreatureFighter.Beat.RECOVER, 180)
	if not check(whirled, "close by, it whirls"):
		return
	await run_frames(2)
	var gone := func(strand: Variant) -> bool:
		return not is_instance_valid(strand) or (strand as Node).is_queued_for_deletion()
	check(gone.call(ahead) and gone.call(behind), "and every thread round it is cut, before and behind")

	king.fighter._cooling[moves["rally"]] = 0.0
	var rallied: bool = await wait_until(func() -> bool:
		return _named("Blade Rat").size() >= 2, 360)
	check(rallied, "then it calls its blade rats (%d)" % _named("Blade Rat").size())


## A lair seals behind you while its keeper lives. Lifted when you are driven off,
## it seals again when you come back; beat the keeper and it is open for good, and
## what it kept is yours.
func _test_a_lair_seals_until_its_keeper_is_beaten() -> void:
	await _arena()
	var lair := BossLair.make(_slab, "The Test Hall", _centre() + Vector3(1.5, -0.5, -8.0),
		_centre() + Vector3(8.0, 4.0, 8.0), "rat_king", _centre() + Vector3(6.0, 0.4, 0.0),
		"wing_buds")
	lair.add_veil(_centre() + Vector3(0.8, 0.0, -8.0), _centre() + Vector3(1.2, 4.0, 8.0))
	lair.add_veil(_centre() + Vector3(7.6, 0.0, -2.0), _centre() + Vector3(8.0, 4.0, 2.0), true)
	await run_frames(5)
	check(lair.keeper.creature != null, "its keeper is at its post")
	var way_on := func() -> bool:
		var query := PhysicsRayQueryParameters3D.create(_centre() + Vector3(6.0, 1.0, 0.0),
			_centre() + Vector3(9.0, 1.0, 0.0), GameLayers.WORLD)
		return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	check(not lair.way_on_open() and not way_on.call(), "and the way on is shut")
	var veiled := func() -> bool:
		var query := PhysicsRayQueryParameters3D.create(_centre() + Vector3(0.0, 1.0, 0.0),
			_centre() + Vector3(3.0, 1.0, 0.0), GameLayers.WORLD)
		return not level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	check(not lair.is_sealed() and not veiled.call(), "open while you are outside it")
	place(_centre() + Vector3(3.0, 0.6, 0.0))
	var shut: bool = await wait_until(func() -> bool: return lair.is_sealed(), 30)
	check(shut and veiled.call(), "step in and it seals behind you")
	check(lair.keeper.creature.is_hunting(), "and the keeper comes for you")
	lair.reset()
	check(not lair.is_sealed() and not veiled.call(), "driven off, it is open again")
	var sealed_again: bool = await wait_until(func() -> bool: return lair.is_sealed(), 30)
	check(sealed_again, "and seals when you are back in it")
	lair.keeper.creature.bundle()
	await run_frames(3)
	check(lair.beaten and not lair.is_sealed() and not veiled.call(),
		"beat the keeper and it is open for good")
	check(lair.way_on_open() and way_on.call(), "and so is the way on")
	check(spider.traits.has("wing_buds"), "and what it kept is yours")
	await run_frames(10)
	check(not lair.is_sealed(), "and it never seals again")


## The Hollow Wyrm keeps to no room: it goes the rounds of its beat, moving on from
## each point after a while there.
func _test_the_hollow_wyrm() -> void:
	await _arena()
	var kind := _species("hollow_wyrm")
	if not _kit(kind, "dive", CreatureAttack.Kind.LUNGE, Vector2i(4, 9)):
		return
	var moves := {}
	for each in kind.attacks:
		moves[each.id] = each
	check(kind.boss and kind.flying, "a boss, and a flier")
	check(moves.has("gust") and moves.has("fire") and moves.has("tail"),
		"with a gust, fire and a tail besides")
	check(moves.has("gust") and (moves["gust"] as CreatureAttack).cuts_silk,
		"and its gust tears silk down")
	# Somewhere it will not see you, so it keeps to its rounds.
	var far := add_slab(ARENA + Vector3(0.0, 0.0, 60.0), Vector3(6, 0.5, 6), _slab)
	await physics_frame
	stand_on(far.global_position + Vector3(0.0, 0.25, 0.0))
	var mark := HostileSpawn.new()
	mark.species_id = "hollow_wyrm"
	mark.route = PackedVector3Array([_centre() + Vector3(-5.0, 2.0, -5.0),
		_centre() + Vector3(5.0, 2.0, 5.0)])
	mark.dwell = 1.0
	_slab.add_child(mark)
	mark.global_position = mark.route[0]
	await run_frames(5)
	check(mark.creature != null and mark.creature.home().distance_to(mark.route[0]) < 0.1,
		"it starts about the first point of its beat")
	var moved: bool = await wait_until(func() -> bool:
		return mark.creature.home().distance_to(mark.route[1]) < 0.1, 180)
	check(moved, "and after a while there, moves on to the next")
	mark.dwell = 60.0
	var flat := func(a: Vector3, b: Vector3) -> float:
		return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var flew: bool = await wait_until(func() -> bool:
		var at: Vector3 = mark.creature.global_position
		return flat.call(at, mark.route[1]) < flat.call(at, mark.route[0]) - 4.0, 300)
	check(flew, "and goes there (%.1fm across from it)"
		% flat.call(mark.creature.global_position, mark.route[1]))


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


## A mark for one of the hostiles, on the arena, at [param offset] from its middle.
func _mark(species_id: String, offset: Vector3) -> HostileSpawn:
	var mark := HostileSpawn.new()
	mark.species_id = species_id
	_slab.add_child(mark)
	mark.global_position = _centre() + offset
	return mark


## One of the game's own hostiles, as it ships.
func _species(id: String) -> PreySpecies:
	return load(CreatureFighter.HOSTILES_DIR.path_join(id + ".tres")) as PreySpecies


## That [param kind] is a hostile as one should be: hostile whatever its size, a
## bite of some sort to fall back on, the move it is known for, and a fight an orb
## web wins in [param shots_to_take] shots — a few for most, more for a boss, and
## never a siege. Returns whether there is enough of it to go on with.
func _kit(kind: PreySpecies, signature: String, of_kind: CreatureAttack.Kind,
		shots_to_take := Vector2i(2, 4)) -> bool:
	if not check(kind != null, "it is one of the hostiles"):
		return false
	check(kind.hostile, "it is hostile (%s)" % kind.display_name)
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
	check(shots >= shots_to_take.x and shots <= shots_to_take.y,
		"and an orb web takes it in %d shots: no fewer than %d, and not a siege"
		% [shots, shots_to_take.x])
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


## Every creature of that name on the arena — not elsewhere in the sandbox, where
## its own spawners keep putting things.
func _named(display_name: String) -> Array[Prey]:
	var found: Array[Prey] = []
	for node in level.get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature != null and creature.species == display_name \
				and not creature.is_queued_for_deletion() \
				and creature.global_position.distance_to(ARENA) < 30.0:
			found.append(creature)
	return found
