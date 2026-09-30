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
		_test_venom_spit,
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


# --- venom ----------------------------------------------------------------

## A glob thrown like silk, that doses what it hits and softens it from the
## inside while you do something else.
func _test_venom_spit() -> void:
	var venom := spells.by_id("venom")
	if not check(venom != null and venom.form == SpiderSpell.Form.VENOM,
			"there is venom in the book"):
		return
	check(not spells.is_open(venom), "shut to a spiderling")
	check(spells.opens_with(venom).contains("Paralytic Bite"),
		"a paralytic bite would open it sooner (%s)" % spells.opens_with(venom))
	grow_to_tier(venom.unlock_stage)
	check(spells.is_open(venom), "a %s can spit it"
		% spider.growth.stages[venom.unlock_stage].display_name)
	check(spells.cycle(1) and spells.current() == venom, "Q takes it in hand")

	var slab := add_slab(Vector3(-60, 0.0, -60), Vector3(16, 0.5, 16))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 3.0))
	await physics_frame
	var wasp := spawn("wasp", spider.global_position + Vector3(0.0, 0.1, -2.0))
	if not check(wasp != null, "a wasp to spit at"):
		return
	wasp.move_speed = 0.0
	wasp.aggression = 0.0
	await physics_frame
	aim_at(wasp.global_position)

	# By the key, the way a player does it: held, it winds up.
	send_action(spider.input_shoot)
	await run_frames(4)
	check(spells.charging, "right mouse winds it up")
	check(spells._held != null and spells._held.visible,
		"with a glow of it over the spider's back")
	check(builder.framing_held, "framed the way a throw is")
	release_action(spider.input_shoot)
	await process_frame
	check(not spells.charging, "letting go spits it")
	check(spells.cooling(venom), "and starts its own wait (%.1fs)" % spells.cooldown_left(venom))
	check(not spells.cooling(spells.by_id("silk")), "which leaves the web ready")
	var dosed: bool = await wait_until(func() -> bool: return wasp.is_poisoned(), 120)
	if not check(dosed, "the glob lands on the wasp and doses it"):
		return
	check(wasp.venom > venom.duration.x * 0.8,
		"for about as long as a tap's dose (%.1fs)" % wasp.venom)
	var soft := wasp.bound
	await run_frames(60)
	check(wasp.bound > soft, "which softens it from the inside (%d%% -> %d%%)"
		% [roundi(soft * 100.0), roundi(wasp.bound * 100.0)])
	check(not spells.cast_now(venom), "and a second glob waits for the wait")

	# Fangs make every dose a fanged one.
	check(is_equal_approx(spells.venom_strength(), 1.0), "a plain dose without fangs")
	for step in ["paralytic", "digestive", "hunting_fangs"]:
		traits.take(traits.by_id(step))
	check(traits.has_fangs(), "fangs grown")
	check(is_equal_approx(spells.venom_strength(), Prey.FANG_VENOM),
		"and the dose is fanged now (%.1f)" % spells.venom_strength())
	check(traits.by_id("hunting_fangs").effect_line().contains("fanged venom"),
		"which the fangs' card says")
	spells.forget_waits()
	var second := spawn("wasp", spider.global_position + Vector3(1.2, 0.1, -2.0))
	if not check(second != null, "another wasp"):
		return
	second.move_speed = 0.0
	second.aggression = 0.0
	await physics_frame
	aim_at(second.global_position)
	check(spells.cast_now(venom), "spat")
	var fanged: bool = await wait_until(func() -> bool: return second.is_poisoned(), 120)
	check(fanged and is_equal_approx(second.venom_strength, Prey.FANG_VENOM),
		"and it lands fanged (%.1f)" % second.venom_strength)
