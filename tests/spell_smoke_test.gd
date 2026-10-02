extends WebSuite

## Headless smoke test for spells.
##
##     godot --headless --path . --script res://tests/spell_smoke_test.gd
##
## Opens the same sandbox the web suite uses and casts in it: the web as the
## first spell, what opens the others and what each one does — on its own, to
## the creatures it lands on, and to the other spells and the silk it meets.
## Exits non-zero if anything comes back wrong.

var spells: SpiderSpells


func run_checks() -> void:
	if not await open_sandbox():
		return
	spells = spider.spells
	if not check(spells != null, "the spider can cast"):
		return
	for section: Callable in _sections():
		await reset()
		await section.call()


## Every section, each handed a fresh arena by [method WebSuite.reset].
func _sections() -> Array[Callable]:
	return [
		_test_the_book,
		_test_silk_is_a_spell,
		_test_what_opens_a_spell,
		_test_the_strip,
		_test_a_lean_spider_casts_sooner,
		_test_water_spiral,
		_test_acid_water,
		_test_summon_lightning,
		_test_lightning_runs_through_silk,
		_test_lightning_and_water,
		_test_storm_and_paralysis,
		_test_firebolt,
		_test_fire_burns_silk,
		_test_the_whole_book_open,
	]


# --- the book -----------------------------------------------------------

func _test_the_book() -> void:
	var book := spells.book
	if not check(not book.is_empty(), "there is a book of spells (%d)" % book.size()):
		return
	var first := book[0]
	check(first.id == "silk" and first.form == SpiderSpell.Form.SILK,
		"and the web is the first spell in it")
	check(first.unlock_stage == 0 and first.keys.is_empty(), "open from the start")
	check(spells.current() == first, "and in hand to begin with")
	var ids := {}
	var nameless := PackedStringArray()
	for spell in book:
		if spell.id == "" or spell.display_name == "" or spell.description == "":
			nameless.append(spell.resource_path)
		ids[spell.id] = true
	check(nameless.is_empty(), "every spell has a name and says what it does %s" % nameless)
	check(ids.size() == book.size(), "and no two share an id")
	check(SpellLibrary.find("silk") != null, "the library finds one by id")
	for spell in book:
		for key in spell.keys:
			check(traits.by_id(key) != null,
				"%s is opened by a trait that exists (%s)" % [spell.display_name, key])
	check(spells.open_spells().size() == 1 and spells.open_spells()[0] == first,
		"a spiderling can cast silk and nothing else")


## Right mouse still throws a web, through the spells now: silk in hand is the
## web builder's own throw, wait and all.
func _test_silk_is_a_spell() -> void:
	check(InputMap.has_action("spell_next"), "there is a key for the next spell")
	var slab := add_slab(Vector3(60, 0.0, 60))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	var silk := spells.current()
	var before := web_count()
	var heard: Array = []
	var listen := func(spell: SpiderSpell, _at: Vector3) -> void: heard.append(spell.id)
	spells.cast.connect(listen)
	send_action(spider.input_shoot)
	await process_frame
	check(builder.aiming, "the key winds up a ball of silk, as it always did")
	release_action(spider.input_shoot)
	var landed: bool = await wait_until(func() -> bool: return web_count() > before, 120)
	spells.cast.disconnect(listen)
	check(landed, "and letting go throws a web (%d -> %d)" % [before, web_count()])
	check(heard == ["silk"], "cast as silk (%s)" % str(heard))
	check(spells.cooling(silk) and builder.cooling(),
		"and silk waits the web's wait (%.1fs)" % spells.cooldown_left(silk))
	check(spells.cooldown_progress(silk) < 1.0, "which the strip can show running down")
	check(not spells.cast_now(silk), "a second cast waits for it")


## A spell opens the way a gate does: at its rung, or sooner with any trait it
## names. Checked on a pretend spell, so it holds whatever the book is.
func _test_what_opens_a_spell() -> void:
	var early := SpiderSpell.new()
	early.id = "test_early"
	early.display_name = "Test Early"
	early.description = "A spell for checking."
	early.form = SpiderSpell.Form.SILK
	early.unlock_stage = 2
	early.keys = PackedStringArray(["wing_buds"])
	early.order = 900
	spells.book.append(early)
	var heard: Array = []
	var listen := func(spell: SpiderSpell) -> void: heard.append(spell.id)
	spells.opened.connect(listen)

	check(not spells.is_open(early), "shut to a spiderling")
	var ways := spells.opens_with(early)
	check(ways.contains(spider.growth.stages[2].display_name) and ways.contains("Wing Buds"),
		"and says what opens it (%s)" % ways)
	check(not spells.cycle(1), "so Q has nothing else to take in hand")
	check(spells.current().id == "silk", "and silk stays there")

	grow_to_tier(2)
	check(spells.is_open(early), "its rung opens it")
	check(heard.has("test_early"), "and says so")
	# Whatever else has opened at that rung, Q gets there, and comes back round.
	var presses := 0
	while spells.current() != early and presses < spells.book.size():
		spells.cycle(1)
		presses += 1
	check(spells.current() == early, "Q takes it in hand (%d press(es))" % presses)
	presses = 0
	while spells.current().id != "silk" and presses < spells.book.size():
		spells.cycle(1)
		presses += 1
	check(spells.current().id == "silk", "and Q again comes round to silk")

	rewind_growth()
	await physics_frame
	check(not spells.is_open(early), "a spiderling again, it is shut again")
	heard.clear()
	check(traits.take(traits.by_id("wing_buds")), "wings grow")
	check(spells.is_open(early), "and a trait it names opens it before its rung")
	check(heard.has("test_early"), "which says so too")
	check(spells.select("test_early"), "it can be taken in hand")
	traits.owned.clear()
	traits.changed.emit()
	check(not spells.is_open(early), "without the wings it shuts")
	check(spells.current().id == "silk", "and the hand comes off it, back onto silk")

	spells.opened.disconnect(listen)
	spells.book.erase(early)
	spells.changed.emit()


## The strip down the right-hand side, and the readout over the bar.
func _test_the_strip() -> void:
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if not check(hud != null, "the level has a HUD"):
		return
	await process_frame
	var strip := hud.get_node_or_null(NodePath("SpellStrip")) as Control
	if not check(strip != null, "which has a strip of spells"):
		return
	check(hud._spell_chips.size() == spells.book.size(),
		"a chip for every spell in the book (%d)" % hud._spell_chips.size())
	var chip := hud._spell_chips.get("silk") as Control
	var state := chip.get_node_or_null(NodePath("Row/Lines/State")) as Label if chip != null \
		else null
	if check(state != null, "silk has a chip"):
		check(state.text == "in hand · ready", "which says it is in hand and ready (%s)"
			% state.text)
	check(hud.pattern_label.text.begins_with("Silk"),
		"the readout over the bar says what is in hand (%s)" % hud.pattern_label.text)
	check(hud.hint_label.text.contains("Right mouse"),
		"and what right mouse does with it (%s)" % hud.hint_label.text)
	for spell in spells.book:
		var shut := hud._spell_chips.get(spell.id) as Control
		if shut == null or spells.is_open(spell):
			continue
		var line := shut.get_node_or_null(NodePath("Row/Lines/State")) as Label
		check(line != null and line.text.begins_with("opens:"),
			"a shut spell says what opens it (%s)" % (line.text if line != null else "—"))

	# Throw one, and the chip counts the wait down.
	var slab := add_slab(Vector3(60, 0.0, -60))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	check(spells.cast_now(spells.current()), "a web thrown")
	await process_frame
	if state != null:
		check(state.text.begins_with("in hand · ") and state.text.ends_with("s"),
			"and the chip counts the wait down (%s)" % state.text)


## Hollow Frame is quicker with everything, silk included.
func _test_a_lean_spider_casts_sooner() -> void:
	var wings := traits.by_id("wing_buds")
	var lean := traits.by_id("hollow_frame")
	if not check(wings != null and lean != null, "wings and a lean frame to try"):
		return
	check(is_equal_approx(lean.cast_scale, 0.8), "a lean frame waits less between casts")
	check(lean.effect_line().contains("spell wait"),
		"and its card says so (%s)" % lean.effect_line())
	var slab := add_slab(Vector3(-60, 0.0, 60))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	var silk := spells.current()
	check(spells.cast_now(silk), "a web from a spider with no traits")
	var plain := builder._cooldown_span
	# One bolt at a time: let that one land before the next.
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 120)
	builder._cooling = 0.0
	traits.take(wings)
	traits.take(lean)
	check(is_equal_approx(traits.cast_scale(), 0.8), "the spider's waits are a fifth shorter")
	await physics_frame
	check(spells.cast_now(silk), "and one from a lean one")
	check(is_equal_approx(builder._cooldown_span, plain * 0.8),
		"which waits a fifth less (%.2fs against %.2fs)" % [builder._cooldown_span, plain])


# --- water ----------------------------------------------------------------

## Sent out from under the spider along the ground, the way the cross looks and as
## far as the wind-up sends it: everything it passes over is soaked and slowed, a
## wet flier cannot climb, and what is off its path or past its end is left alone.
## Wound up, it goes further; a wall in the way, it breaks there.
func _test_water_spiral() -> void:
	var spiral := spells.by_id("spiral")
	if not check(spiral != null and spiral.form == SpiderSpell.Form.SPIRAL,
			"there is a water spiral in the book"):
		return
	check(spells.opens_with(spiral).contains("Digestive Flood"),
		"a digestive flood would open it sooner (%s)" % spells.opens_with(spiral))
	grow_to_tier(spiral.unlock_stage)
	check(spells.select("spiral"), "a %s can send one out"
		% spider.growth.stages[spiral.unlock_stage].display_name)
	check(not spells.is_area(spiral), "it is sent out, not called down where you point")

	var slab := add_slab(Vector3(90, 0.0, -90), Vector3(60, 0.5, 60))
	await physics_frame
	var start := slab.global_position + Vector3(0, 0.25, 22.0)
	stand_on(start)
	await physics_frame
	var height := spider.stage().body_height
	var radius := spiral.size_at(0.0) * height
	var far := spells.spiral_reach(spiral, 0.0)
	var full := spells.spiral_reach(spiral, 1.0)
	check(far > height * 4.0 and full > far * 2.0,
		"a tap sends it %.1f m, a full wind-up %.1f m" % [far, full])
	var ahead := Vector3.FORWARD
	clear_prey_near(start + ahead * full * 0.5, full, null)
	var walker := spawn("beetle", start + ahead * far * 0.5 + Vector3(radius * 0.3, 0.2, 0.0))
	var flier := spawn("moth", start + ahead * far * 0.75
		+ Vector3(-radius * 0.2, radius * 0.8, 0.0))
	var aside := spawn("fly", start + ahead * far * 0.5 + Vector3(radius * 3.0, 0.3, 0.0))
	var beyond := spawn("beetle", start + ahead * (far + radius * 3.0) + Vector3(0.0, 0.2, 0.0))
	if not check(walker != null and flier != null and aside != null and beyond != null,
			"two beetles, a moth and a fly"):
		return
	for creature in [walker, flier, aside, beyond]:
		creature.aggression = 0.0
	for creature in [walker, aside, beyond]:
		creature.move_speed = 0.0
	await physics_frame
	aim_at(start + ahead * full * 2.0 + Vector3.DOWN * 0.25)
	var ends := {}
	check(spells.cast_now(spiral), "sent out")
	var whirl := _first_whirl()
	if not check(whirl != null, "and there it goes"):
		return
	whirl.spent.connect(func(gone: WaterSpiral, slowed: Array[Prey]) -> void:
		ends["travelled"] = gone.travelled
		ends["slowed"] = slowed.duplicate())
	var off := whirl.global_position - start
	check(Vector2(off.x, off.z).length() < radius * 0.5,
		"from under the spider (%.2f m off)" % Vector2(off.x, off.z).length())
	check(whirl.heading.dot(ahead) > 0.99, "the way the cross looks")
	check(spells.cooling(spiral), "and it waits its own wait (%.1fs)"
		% spells.cooldown_left(spiral))
	var done: bool = await wait_until(func() -> bool: return ends.has("travelled"), 300)
	if not check(done, "it runs its course"):
		return
	check(absf(float(ends["travelled"]) - far) < 0.05,
		"as far as a tap sends it (%.1f of %.1f m)" % [ends["travelled"], far])
	var slowed: Array = ends["slowed"]
	check(walker.is_wet() and walker.is_slowed() and slowed.has(walker),
		"the beetle on its path is soaked and slowed")
	check(is_instance_valid(flier) and flier.is_wet() and slowed.has(flier),
		"and so is the moth over it")
	check(not aside.is_wet() and not aside.is_slowed(), "the fly off to one side is not")
	check(not beyond.is_wet() and not beyond.is_slowed(), "nor the beetle past its end")
	walker.move_speed = 1.0
	check(is_equal_approx(walker.current_speed(), Prey.SLOWED),
		"slowed, the beetle goes at %d%% of its pace" % roundi(walker.current_speed() * 100.0))
	if is_instance_valid(flier) and flier.is_wet():
		await run_frames(10)
		var low := flier.global_position.y
		await run_frames(30)
		check(flier.global_position.y <= low + 0.01,
			"and the wet moth cannot climb (%.2f -> %.2f m)" % [low, flier.global_position.y])
	var dry: bool = await wait_until(func() -> bool: return not walker.is_slowed(), 400)
	check(dry and is_equal_approx(walker.current_speed(), 1.0),
		"and once it wears off, it has its pace back")

	# Wound up, it goes further; with a wall in its way, it breaks on the wall.
	spells.forget_waits()
	aim_at(start + ahead * full * 2.0 + Vector3.DOWN * 0.25)
	ends.clear()
	check(spells.cast_now(spiral, 1.0), "sent out again, wound up")
	whirl = _first_whirl()
	if whirl == null:
		return
	whirl.spent.connect(func(gone: WaterSpiral, _slowed: Array[Prey]) -> void:
		ends["travelled"] = gone.travelled)
	await wait_until(func() -> bool: return ends.has("travelled"), 400)
	check(ends.has("travelled") and absf(float(ends["travelled"]) - full) < 0.05,
		"and it goes all of %.1f m" % full)
	await wait_until(func() -> bool: return _first_whirl() == null, 120)
	spells.forget_waits()
	var wall_at := full * 0.5
	add_slab(start + ahead * wall_at + Vector3(0.0, 1.5, 0.0), Vector3(8.0, 3.0, 0.4))
	await physics_frame
	aim_at(start + ahead * wall_at * 0.5 + Vector3.DOWN * 0.25)
	ends.clear()
	check(spells.cast_now(spiral, 1.0), "and once more, at a wall")
	whirl = _first_whirl()
	if whirl == null:
		return
	whirl.spent.connect(func(gone: WaterSpiral, _slowed: Array[Prey]) -> void:
		ends["travelled"] = gone.travelled)
	await wait_until(func() -> bool: return ends.has("travelled"), 400)
	check(ends.has("travelled") and float(ends["travelled"]) < wall_at,
		"which it breaks on, %.1f m out of a %.1f m run" % [ends.get("travelled", -1.0), full])


## A spider with Digestive Flood has acid water: everything its whirl passes over
## is dosed.
func _test_acid_water() -> void:
	var spiral := spells.by_id("spiral")
	if spiral == null:
		return
	grow_to_tier(spiral.unlock_stage)
	var slab := add_slab(Vector3(-90, 0.0, -90), Vector3(30, 0.5, 30))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 3.5))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	var radius := spiral.size_at(0.0) * spider.stage().body_height
	clear_prey_near(centre, radius * 4.0, null)
	for step in ["paralytic", "digestive"]:
		traits.take(traits.by_id(step))
	check(traits.acid_water(), "a digestive flood makes the spider's water acid")
	check(traits.by_id("digestive").effect_line().contains("acid spiral"),
		"which its card says")
	var ant := spawn("ant", centre + Vector3(-radius * 0.5, 0.2, 0.0))
	if not check(ant != null, "an ant"):
		return
	ant.aggression = 0.0
	ant.move_speed = 0.0
	await physics_frame
	spells.select("spiral")
	aim_at(centre)
	check(spells.cast_now(spiral), "a whirl sent over it")
	var eaten: bool = await wait_until(func() -> bool: return ant.is_poisoned(), 120)
	check(eaten, "and its water doses what it passes over")


func _first_whirl() -> WaterSpiral:
	for node in spider.get_tree().get_nodes_in_group(WaterSpiral.GROUP):
		var whirl := node as WaterSpiral
		if whirl != null and not whirl.is_queued_for_deletion():
			return whirl
	return null


func _square(centre: Vector3, half: float) -> Array[Vector3]:
	return [
		centre + Vector3(-half, -half, 0),
		centre + Vector3(half, -half, 0),
		centre + Vector3(half, half, 0),
		centre + Vector3(-half, half, 0),
	]


# --- lightning ------------------------------------------------------------

## Called down where the cross is: what it strikes is stunned, a hunter gives up
## the chase, a flier falls — and the spider is never struck by its own.
func _test_summon_lightning() -> void:
	var lightning := spells.by_id("lightning")
	if not check(lightning != null and lightning.form == SpiderSpell.Form.LIGHTNING,
			"there is lightning in the book"):
		return
	check(not spells.is_open(lightning), "shut to a spiderling")
	check(traits.take(traits.by_id("wing_buds")), "until wings grow")
	check(spells.is_open(lightning), "which open it long before a %s would"
		% spider.growth.stages[lightning.unlock_stage].display_name)
	traits.owned.clear()
	traits.changed.emit()
	grow_to_tier(lightning.unlock_stage)
	check(spells.select("lightning"), "a %s can call it down"
		% spider.growth.stages[lightning.unlock_stage].display_name)

	var slab := add_slab(Vector3(120, 0.0, 120), Vector3(30, 0.5, 30))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 4.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 12.0, null)
	var wasp := spawn("wasp", centre + Vector3(0.0, 0.8, 0.0))
	if not check(wasp != null, "a wasp"):
		return
	await physics_frame
	wasp._quarry = spider
	wasp._state = Prey.State.HUNTING
	wasp._chase_left = Prey.CHASE_STAMINA
	check(wasp.is_hunting(), "coming for the spider")
	var whole := spider.health
	aim_at(wasp.global_position)
	check(spells.cast_now(lightning), "struck")
	var strike := _last_strike()
	if not check(strike != null and strike.shocked.has(wasp), "and the wasp with it"):
		return
	check(is_equal_approx(wasp.stunned, lightning.duration.x),
		"stunned for a tap's %.1fs" % wasp.stunned)
	check(not wasp.is_hunting(), "it gives up the chase")
	check(is_equal_approx(spider.health, whole),
		"and the spider is not struck by its own lightning")
	check(spells.cooling(lightning), "which waits its own wait (%.1fs)"
		% spells.cooldown_left(lightning))
	var high := wasp.global_position.y
	await run_frames(20)
	check(wasp.global_position.y < high,
		"a stunned wasp falls (%.2f -> %.2f m)" % [high, wasp.global_position.y])
	var woke: bool = await wait_until(func() -> bool: return not wasp.is_stunned(), 400)
	check(woke, "and comes round in the end")


## A strike on one web runs through the silk touching it and down every wire,
## and reaches everything they hold — here, a wasp well out of the strike's own
## reach, fighting a web it would otherwise have beaten.
func _test_lightning_runs_through_silk() -> void:
	var lightning := spells.by_id("lightning")
	if lightning == null:
		return
	grow_to_tier(lightning.unlock_stage)
	var slab := add_slab(Vector3(-120, 0.0, 120), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 6.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var height := spider.stage().body_height
	var radius := lightning.size_at(0.0) * height
	var half := radius * 0.6
	var lift := Vector3.UP * (half + height * 0.3)
	var first := _spin(centre + lift + Vector3(-half, 0, 0), half)
	var second := _spin(centre + lift + Vector3(half, 0, 0), half)
	var wired := _spin(centre + lift + Vector3(half * 9.0, 0, 0), half)
	if not check(first != null and second != null and wired != null,
			"two webs side by side, and a third across the room"):
		return
	check(second.link_to(wired), "wired to the second")

	var wasp := spawn("wasp", (second as WebNet).to_global((second as WebNet).centre_local))
	var fly := spawn("fly", (wired as WebNet).to_global((wired as WebNet).centre_local))
	var loose := spawn("fly", centre + Vector3(0, half * 2.0, -radius * 3.0))
	if not check(wasp != null and fly != null and loose != null, "a wasp, a fly and a stray"):
		return
	wasp.struggle_stamina = 30.0
	loose.move_speed = 0.0
	await physics_frame
	await physics_frame
	if not check(wasp.is_fighting() and fly.is_stuck(), "the wasp and the fly caught"):
		return
	var corner := centre + lift + Vector3(-half * 2.0, -half, 0)
	check(corner.distance_to(wasp.global_position) > radius + wasp.hit_radius(),
		"the far corner of the first web is out of the strike's reach of the wasp")
	var fight := wasp.fight_left()
	var strike := LightningStrike.call_down(level, corner, radius, lightning.duration.x, 0,
		height * 0.6)
	check(strike.charged.has(first) and strike.charged.has(second),
		"it runs from the web it struck into the one touching it")
	check(strike.charged.has(wired), "and down the wire to the one across the room")
	check(strike.shocked.has(wasp) and wasp.is_stunned(),
		"stunning the wasp the second web holds")
	check(wasp.fight_left() < fight - Prey.SHOCK_FIGHT * 0.9,
		"and taking the fight out of it (%d%% -> %d%%)"
		% [roundi(fight * 100.0), roundi(wasp.fight_left() * 100.0)])
	check(strike.shocked.has(fly), "and the fly the wired one holds")
	check(not strike.shocked.has(loose), "but not a fly nowhere near silk")
	await run_frames(30)
	check(wasp.is_stuck() and wasp.is_stunned(),
		"stunned in the silk, it is not fighting its way out")


## Water carries a strike: everything a whirl has hold of, twice as hard, and on
## from one wet thing to the next.
func _test_lightning_and_water() -> void:
	var lightning := spells.by_id("lightning")
	var spiral := spells.by_id("spiral")
	if lightning == null or spiral == null:
		return
	grow_to_tier(maxi(lightning.unlock_stage, spiral.unlock_stage))
	var slab := add_slab(Vector3(120, 0.0, -120), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 4.5))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var height := spider.stage().body_height
	var strike_radius := lightning.size_at(0.0) * height
	# Two beetles one behind the other on the whirl's road, close enough that it
	# has both at once on its way past.
	var whirl_radius := spiral.size_at(0.0) * height
	var beetles: Array[Prey] = []
	for i in 2:
		var beetle := spawn("beetle", centre + Vector3(0.0, 0.2, whirl_radius * (0.3 - 0.6 * i)))
		if beetle != null:
			beetle.aggression = 0.0
			beetle.move_speed = 0.0
			beetles.append(beetle)
	await physics_frame
	if not check(beetles.size() == 2, "two beetles in a row"):
		return
	spells.select("spiral")
	aim_at(centre)
	check(spells.cast_now(spiral), "a whirl sent at them")
	var whirl := _first_whirl()
	if whirl == null:
		return
	var whirl_id := whirl.get_instance_id()
	var over_both: bool = await wait_until(func() -> bool:
		var going := instance_from_id(whirl_id) as WaterSpiral
		return going != null and going.held().has(beetles[0]) and going.held().has(beetles[1]),
		120)
	if not check(over_both, "and it has both at once, wet"):
		return
	# Struck at its rim, from the side, with a strike too small to reach either.
	var small := whirl.radius * 0.15
	var side := whirl.heading.cross(Vector3.UP).normalized()
	var rim := whirl.global_position + side * whirl.radius * 0.95 + Vector3.UP * whirl.radius * 0.2
	var out_of_reach := true
	for beetle in beetles:
		out_of_reach = out_of_reach and \
			beetle.global_position.distance_to(rim) > small + beetle.hit_radius()
	check(out_of_reach, "the rim of the whirl is out of the strike's own reach of both")
	var strike := LightningStrike.call_down(level, rim, small, lightning.duration.x, 0,
		height * 0.6)
	check(strike.shocked.has(beetles[0]) and strike.shocked.has(beetles[1]),
		"a strike on the whirl reaches everything in it")
	check(is_equal_approx(beetles[0].stunned, lightning.duration.x * Prey.WET_SHOCK),
		"and wet, twice as hard (%.1fs stunned)" % beetles[0].stunned)

	# On from one wet thing to the next, and no further than the water goes.
	var flies: Array[Prey] = []
	for i in 4:
		var fly := spawn("fly", centre + Vector3(-strike_radius * 6.0 - float(i) * strike_radius
			* 1.3, height, -strike_radius * 4.0))
		if fly != null:
			fly.move_speed = 0.0
			flies.append(fly)
	await physics_frame
	if not check(flies.size() == 4, "four flies in a row"):
		return
	for i in 3:
		flies[i].soak(6.0)
	var chain := LightningStrike.call_down(level, flies[0].global_position, strike_radius,
		lightning.duration.x, 0, height * 0.6)
	check(chain.shocked.has(flies[1]) and chain.shocked.has(flies[2]),
		"water passes it from one wet fly to the next")
	check(not chain.shocked.has(flies[3]), "and stops at the dry one")


## Two traits that work on lightning: Paralytic Bite stuns for half as long again,
## and Storm Rider makes a strike jump on to what is near, wet or not.
func _test_storm_and_paralysis() -> void:
	var lightning := spells.by_id("lightning")
	if lightning == null:
		return
	grow_to_tier(lightning.unlock_stage)
	spells.select("lightning")
	var slab := add_slab(Vector3(-120, 0.0, -120), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 4.5))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var paralytic := traits.by_id("paralytic")
	check(paralytic.effect_line().contains("+50% stun"),
		"a paralytic bite's card says it stuns longer (%s)" % paralytic.effect_line())
	traits.take(paralytic)
	var target := spawn("beetle", centre + Vector3(0, 0.2, 0))
	var near := spawn("beetle", centre + Vector3(0, 0.2, 0))
	if not check(target != null and near != null, "two beetles"):
		return
	var radius := lightning.size_at(0.0) * spider.stage().body_height
	near.global_position = centre + Vector3(radius * 1.3, 0.2, 0.0)
	for beetle in [target, near]:
		beetle.aggression = 0.0
		beetle.move_speed = 0.0
	await physics_frame
	aim_at(target.global_position)
	check(spells.cast_now(lightning), "struck")
	check(is_equal_approx(target.stunned, lightning.duration.x * 1.5),
		"and stunned half as long again (%.2fs)" % target.stunned)
	check(not near.is_stunned(), "a dry beetle out of reach is left alone")

	var storm := traits.by_id("storm_rider")
	check(storm.effect_line().contains("+2 lightning arcs"),
		"a storm rider's card says it arcs (%s)" % storm.effect_line())
	for step in ["wing_buds", "hollow_frame", "storm_rider"]:
		traits.take(traits.by_id(step))
	check(traits.arc_bonus() == 2, "two arcs")
	await wait_until(func() -> bool: return not target.is_stunned(), 600)
	spells.forget_waits()
	radius = lightning.size_at(0.0) * spider.stage().body_height
	var far := spawn("beetle", centre + Vector3(0, 0.2, 0))
	if not check(far != null, "a third beetle"):
		return
	near.global_position = centre + Vector3(radius * 1.3, 0.2, 0.0)
	far.global_position = centre + Vector3(radius * 2.6, 0.2, 0.0)
	far.aggression = 0.0
	far.move_speed = 0.0
	await physics_frame
	aim_at(target.global_position)
	check(spells.cast_now(lightning), "struck again, with a storm rider's wings")
	var strike := _last_strike()
	check(strike != null and strike.shocked.has(near) and strike.shocked.has(far),
		"and it jumps on to both beetles near it, dry as they are")


# --- fire ---------------------------------------------------------------------

## Silk burns. Fire takes a little of something bare, more of something half
## wrapped and all it is worth of something a web holds; a firebolt thrown at a
## creature bursts on it and burns it; and what it burns low is an easy catch.
func _test_firebolt() -> void:
	var fire := spells.by_id("fire")
	if not check(fire != null and fire.form == SpiderSpell.Form.FIRE,
			"there is fire in the book"):
		return
	check(not spells.is_open(fire), "shut to a spiderling")
	grow_to_tier(fire.unlock_stage)
	check(spells.is_open(fire), "a %s can throw it"
		% spider.growth.stages[fire.unlock_stage].display_name)
	var slab := add_slab(Vector3(60, 0.0, -120), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 8.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)

	# The rule, on three of a kind: one bare, one half wrapped, one in a web.
	var height := spider.stage().body_height
	var half := height * 1.2
	var web := _spin(centre + Vector3(-height * 6.0, half + height * 0.3, 0.0), half)
	if not check(web != null, "a web to hold one"):
		return
	var bare := spawn("wasp", centre + Vector3(height * 6.0, height, 0.0))
	var halfway := spawn("wasp", centre + Vector3(0.0, height, -height * 6.0))
	var held := spawn("wasp", (web as WebNet).to_global((web as WebNet).centre_local))
	if not check(bare != null and halfway != null and held != null, "three wasps"):
		return
	for wasp in [bare, halfway, held]:
		wasp.move_speed = 0.0
		wasp.aggression = 0.0
		wasp.struggle_stamina = 30.0
	halfway.bind(0.5)
	await physics_frame
	await physics_frame
	if not check(held.is_stuck(), "one of them held by the web"):
		return
	var power := 0.5
	var from_bare := bare.burn(power)
	var from_half := halfway.burn(power)
	var from_held := held.burn(power)
	check(is_equal_approx(from_bare, power * Prey.BARE_BURN),
		"bare, it takes a little (%d%%)" % roundi(from_bare * 100.0))
	check(from_half > from_bare * 2.0 and from_half < from_held,
		"half wrapped, a good deal more (%d%%)" % roundi(from_half * 100.0))
	check(is_equal_approx(from_held, power),
		"and held in a web, all it is worth (%d%%)" % roundi(from_held * 100.0))

	# Thrown, the way a player does it.
	clear_prey_near(centre, 20.0, null)
	var target := spawn("wasp", spider.global_position + Vector3(0.0, 0.1, -3.0))
	if not check(target != null, "a wasp to throw it at"):
		return
	target.move_speed = 0.0
	target.aggression = 0.0
	# A tough one, so that one shot is not already the whole catch.
	target.struggle_power = 12.0
	target.struggle_stamina = 30.0
	target.bind(0.6)
	await physics_frame
	var hold := builder.shot_hold(pattern_named("orb_web"), 3.0)
	var share := target.bind_share(hold)
	aim_at(target.global_position)
	check(spells.select("fire") and spells.cast_now(fire, 1.0), "thrown")
	var burned: bool = await wait_until(func() -> bool: return target.health() < 0.999, 120)
	if not check(burned, "it lands on the wasp and burns it"):
		return
	var expected := fire.power_at(1.0) * lerpf(Prey.BARE_BURN, 1.0, target.bound)
	check(target.health() < 1.0 - expected * 0.8,
		"for about what its silk says (%d%% of it left)" % roundi(target.health() * 100.0))
	check(target.bind_share(hold) > share * 1.3,
		"and burned low, it is an easier catch (%d%% a shot -> %d%%)"
		% [roundi(share * 100.0), roundi(target.bind_share(hold) * 100.0)])
	check(spells.cooling(fire), "and fire has its own wait (%.1fs)" % spells.cooldown_left(fire))

	var wrapped := spawn("fly", centre + Vector3(height * 3.0, height, height * 6.0))
	if check(wrapped != null and wrapped.bundle(), "something already caught"):
		check(is_zero_approx(wrapped.burn(power)), "is left be: it is caught")


## And the silk burns with it: fire thrown into a web takes the web, and what it
## held drops out burned as hard as fire burns anything; fire thrown at a line
## goes to the line and not the wall behind it, and burns it; and silk out of the
## burst's reach is left standing.
func _test_fire_burns_silk() -> void:
	var fire := spells.by_id("fire")
	if fire == null:
		return
	grow_to_tier(fire.unlock_stage)
	spells.select("fire")
	var slab := add_slab(Vector3(-60, 0.0, -120), Vector3(60, 0.5, 60))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 8.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 30.0, null)
	var height := spider.stage().body_height
	var half := height * 1.2
	var web := _spin(centre + Vector3(-height * 4.0, half + height * 0.3, 0.0), half)
	var far := _spin(centre + Vector3(height * 8.0, half + height * 0.3, 0.0), half)
	if not check(web != null and far != null, "a web to burn, and one well away from it"):
		return
	var wasp := spawn("wasp", (web as WebNet).signal_point())
	if not check(wasp != null, "a wasp"):
		return
	wasp.move_speed = 0.0
	wasp.aggression = 0.0
	wasp.struggle_stamina = 30.0
	await physics_frame
	await physics_frame
	if not check(wasp.is_stuck(), "held by the web"):
		return
	aim_at(wasp.global_position)
	await process_frame
	# Waited on by id: a lambda that holds the web itself complains once it is freed.
	var web_id := web.get_instance_id()
	check(spells.cast_now(fire), "fire thrown into the web")
	var gone: bool = await wait_until(func() -> bool: return not is_instance_id_valid(web_id),
		120)
	check(gone, "and the web burns away")
	check(is_instance_valid(wasp) and not wasp.is_stuck(), "dropping the wasp out of it")
	if is_instance_valid(wasp):
		check(wasp.health() < 1.0 - fire.power_at(0.0) * 0.95,
			"burned as hard as fire burns anything held in silk (%d%% of it left)"
			% roundi(wasp.health() * 100.0))
	check(is_instance_valid(far) and not far.is_queued_for_deletion(),
		"and the web out of the burst's reach still stands")

	# A line across the room, with a wall a long way behind it: the cross just off
	# the line is on the line, and that is where the fire goes.
	spells.forget_waits()
	clear_prey_near(centre, 30.0, null)
	var a := centre + Vector3(-height * 3.0, height, 2.0)
	var b := centre + Vector3(height * 3.0, height, 2.0)
	var line := WebStrand.spin(pattern_named("frame_line"), a, b, 1.0)
	add_slab(centre + Vector3(0.0, height * 2.0, -4.0), Vector3(40.0, height * 6.0, 0.5))
	if not check(line != null, "a line"):
		return
	line.place_in(webs)
	await physics_frame
	aim_at((a + b) * 0.5 + Vector3.UP * height * 0.15)
	await process_frame
	check(builder.aimed_line() == line, "the cross is on the line")
	var line_id := line.get_instance_id()
	check(spells.cast_now(fire), "fire thrown at it")
	var burned: bool = await wait_until(func() -> bool: return not is_instance_id_valid(line_id),
		120)
	check(burned, "and the line burns away")
	check(is_instance_valid(far) and not far.is_queued_for_deletion(),
		"and the far web stands still")


## A level can hand the spider the whole book at once: every spell open to a
## spiderling, and shut again when it takes the book back.
func _test_the_whole_book_open() -> void:
	check(spells.open_spells().size() == 1, "a spiderling has silk and nothing else")
	spells.open_all = true
	check(spells.open_spells().size() == spells.book.size(),
		"with the whole book open, it has all %d" % spells.book.size())
	check(spells.cycle(1) and spells.current().id != "silk", "and Q takes the next in hand")
	spells.open_all = false
	check(spells.open_spells().size() == 1 and spells.current().id == "silk",
		"shut again, it is back to silk")


func _last_strike() -> LightningStrike:
	var found: LightningStrike = null
	for node in spider.get_tree().get_nodes_in_group(LightningStrike.GROUP):
		var strike := node as LightningStrike
		if strike != null and not strike.is_queued_for_deletion():
			found = strike
	return found


## A sheet web standing up, [param half] either side of [param middle].
func _spin(middle: Vector3, half: float) -> WebStructure:
	select_pattern("sheet_web")
	builder.start()
	for point in _square(middle, half):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	return newest_web("sheet_web")
