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
		_test_learning_a_spell,
		_test_ranks,
		_test_the_tree,
		_test_the_tree_screen,
		_test_the_strip,
		_test_number_keys,
		_test_spells_leave_through_circles,
		_test_a_lean_spider_casts_sooner,
		_test_douse,
		_test_gust,
		_test_the_whirl,
		_test_acid_water,
		_test_summon_lightning,
		_test_lightning_runs_through_silk,
		_test_a_struck_web_stays_live,
		_test_live_silk_and_lines,
		_test_lightning_and_water,
		_test_storm_and_paralysis,
		_test_fire_geyser,
		_test_fire_burns_silk,
		_test_pullback,
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
	check(spells.is_open(first) and spells.key_for(first) == 1, "known from the start, on key 1")
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
	# Every spell but silk is learned in the tree, and the tree only teaches what
	# there is.
	var tree := spider.spell_tree
	var unlearnable := PackedStringArray()
	for spell in book:
		if spell.form == SpiderSpell.Form.SILK:
			continue
		var taught := false
		for skill in tree.skills:
			taught = taught or (skill.kind == SpellSkill.Kind.SPELL and skill.spell == spell.id)
		if not taught:
			unlearnable.append(spell.id)
	check(unlearnable.is_empty(), "every other spell has a skill that teaches it %s" % unlearnable)
	var strays := PackedStringArray()
	for skill in tree.skills:
		if not skill.spell.is_empty() and spells.by_id(skill.spell) == null:
			strays.append("%s: %s" % [skill.id, skill.spell])
		for needed in skill.requires:
			if tree.by_id(needed) == null:
				strays.append("%s needs %s" % [skill.id, needed])
	check(strays.is_empty(),
		"and every skill is about a spell, and stands on skills, that exist %s" % strays)
	check(spells.open_spells().size() == 1 and spells.open_spells()[0] == first,
		"an Apprentice who has learned nothing casts silk and nothing else")


## Right mouse still throws a web, through the spells now: silk in hand is the
## web builder's own throw, wait and all.
func _test_silk_is_a_spell() -> void:
	check(InputMap.has_action("spell_next"), "the wheel turns the book")
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


## A spell is learned in the tree, with the points an Apprentice starts with, in a
## row its rank has opened. Learned, it says so, goes on the next key and the wheel
## takes it in hand; forgotten, the hand comes off it, back onto silk.
func _test_learning_a_spell() -> void:
	var tree := spider.spell_tree
	var douse := spells.by_id("douse")
	var skill := tree.by_id("douse")
	if not check(douse != null and skill != null, "Douse, and the skill that teaches it"):
		return
	var heard: Array = []
	var listen := func(spell: SpiderSpell) -> void: heard.append(spell.id)
	spells.opened.connect(listen)
	check(not spells.is_open(douse), "not known to begin with")
	check(spells.opens_with(douse).contains(tree.rank_name(skill.row)),
		"and it says where it is learned (%s)" % spells.opens_with(douse))
	check(not spells.cycle(1), "so the wheel has nothing else to take in hand")
	check(tree.points() == SpellTree.POINTS_PER_RANK,
		"an Apprentice has %d points to spend (%d)" % [SpellTree.POINTS_PER_RANK, tree.points()])
	check(tree.learn(skill), "learned")
	check(spells.is_open(douse) and heard.has("douse"), "and it is known, and says so")
	check(spells.key_for(douse) == 2, "on the first key after silk's (%d)" % spells.key_for(douse))
	check(tree.points() == SpellTree.POINTS_PER_RANK - skill.cost, "for its point")
	check(spells.cycle(1) and spells.current() == douse, "the wheel takes it in hand")
	check(spells.cycle(1) and spells.current().id == "silk", "and comes round to silk again")
	check(spells.take(2) and spells.current() == douse, "and so does its key")
	tree.forget_all()
	check(not spells.is_open(douse) and spells.current().id == "silk",
		"forgotten, it is shut, and the hand comes off it, back onto silk")
	spells.opened.disconnect(listen)


## Catching and eating earn ranks: a catch is worth its size, more for something
## that fights back, and a meal half that again — and a practice target nothing.
## Each rank opens its row of the tree and two more points, and says so.
func _test_ranks() -> void:
	var tree := spider.spell_tree
	check(tree.rank == 0 and tree.rank_name() == "Apprentice Spooder",
		"an Apprentice Spooder to begin with")
	check(SpellTree.RANKS[SpellTree.RANKS.size() - 1] == "Grand Spooder",
		"with a Grand Spooder at the top")
	check(tree.points() == SpellTree.POINTS_PER_RANK and tree.row_open(0) and not tree.row_open(1),
		"two points to spend, and the first row of the tree open")
	var beetle := PreyLibrary.find("beetle")
	var blade := load(CreatureFighter.HOSTILES_DIR.path_join("blade_rat.tres")) as PreySpecies
	var post := load(TrainingDummy.SPECIES_DIR.path_join("dummy_post.tres")) as PreySpecies
	if not check(beetle != null and blade != null and post != null,
			"a beetle, a blade rat and a post"):
		return
	check(is_equal_approx(tree.catch_worth(beetle), SpellTree.CATCH_XP * beetle.size_class),
		"a beetle caught is worth its size (%d)" % roundi(tree.catch_worth(beetle)))
	check(tree.catch_worth(blade) > SpellTree.CATCH_XP * blade.size_class,
		"something that fights back, more (%d)" % roundi(tree.catch_worth(blade)))
	check(is_zero_approx(tree.catch_worth(post)), "and a practice target, nothing")
	check(is_equal_approx(tree.meal_worth(beetle), tree.catch_worth(beetle) * 0.5),
		"a meal is worth half what the catch was (%d)" % roundi(tree.meal_worth(beetle)))

	# Through the game's own paths: bundled by silk, then drunk to the end.
	var slab := add_slab(Vector3(30, 0.0, 180), Vector3(20, 0.5, 20))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await physics_frame
	clear_prey_near(spider.global_position, 10.0, null)
	var ranks: Array = []
	var listen := func(rank: int) -> void: ranks.append(rank)
	tree.ranked_up.connect(listen)
	var said: Array = []
	var hear := func(text: String) -> void: said.append(text)
	spider.notice.connect(hear)
	var wasp := spawn("wasp", spider.global_position + Vector3(0.3, 0.2, 0.0))
	if not check(wasp != null, "a wasp"):
		return
	wasp.move_speed = 0.0
	wasp.aggression = 0.0
	await physics_frame
	var before := tree.xp
	wasp.bundle()
	# Kept rather than read off the wasp: once it is eaten, there is no wasp.
	var kind := wasp.kind
	var caught := tree.catch_worth(kind)
	check(is_equal_approx(tree.xp - before, caught),
		"bundled, it is caught: +%d" % roundi(tree.xp - before))
	wasp.credit_catch()
	check(is_equal_approx(tree.xp - before, caught), "and a catch counts once")
	spider.tether.hook(wasp)
	await eat(wasp, 900)
	check(is_equal_approx(tree.xp - before, caught + tree.meal_worth(kind)),
		"and drunk to the end, a meal: +%d in all" % roundi(tree.xp - before))
	if spider.tether.is_towing():
		spider.tether.cut()

	# Held in a web until it has no fight left is caught too. Stunned, so it does
	# not tear out while its fight runs down, and with only a moment of it left.
	var web := _spin(spider.global_position + Vector3(0.0, 1.5, -2.0), 0.4)
	# A frame for the web to be in the world before anything flies into it.
	await physics_frame
	before = tree.xp
	var held := spawn("wasp", (web as WebNet).signal_point()) if web != null else null
	if held != null:
		held.move_speed = 0.0
		held.aggression = 0.0
		held.struggle_stamina = 30.0
		held.stun(5.0)
	await physics_frame
	await physics_frame
	if check(held != null and web != null and held.is_fighting(), "a wasp held in a web"):
		check(is_equal_approx(tree.xp, before), "which is not caught yet")
		held._fight_left = 0.05
		var out: bool = await wait_until(func() -> bool: return tree.xp > before, 120)
		check(out and held.is_secured()
			and is_equal_approx(tree.xp - before, tree.catch_worth(held.kind)),
			"fought out in it, it is caught: +%d" % roundi(tree.xp - before))

	# Enough of it is the next rank.
	tree.earn(tree.xp_to_next())
	check(tree.rank == 1 and ranks == [1], "enough of it is the next rank (%s)" % str(ranks))
	check(tree.points() == 2 * SpellTree.POINTS_PER_RANK - 0, "two more points (%d)" % tree.points())
	check(tree.row_open(1) and not tree.row_open(2), "and the next row of the tree")
	var told := false
	for line in said:
		told = told or str(line).begins_with("Adept Spooder")
	check(told, "and the spider says so")
	tree.earn(100000.0)
	check(tree.is_top_rank() and tree.rank_name() == "Grand Spooder" and is_equal_approx(
		tree.rank_progress(), 1.0), "and at the top, a Grand Spooder")
	check(ranks.size() == SpellTree.RANKS.size() - 1, "having passed every rank on the way (%s)"
		% str(ranks))
	tree.ranked_up.disconnect(listen)
	spider.notice.disconnect(hear)


## What the tree teaches and how: a skill needs its row open, what it stands on and
## the points; a tier makes its spell bigger; a cut shortens the waits, silk's too;
## five spells fill the loadout and the tree moves them; and with everything open
## every spell is on a key.
func _test_the_tree() -> void:
	var tree := spider.spell_tree
	for row in SpellTree.RANKS.size():
		check(tree.row(row).size() >= 2,
			"%s has a row of its own (%d)" % [SpellTree.RANKS[row], tree.row(row).size()])
	var total := 0
	var kinds := {}
	for skill in tree.skills:
		total += skill.cost
		kinds[skill.kind] = true
		check(skill.effect_line() != "" and skill.description != "",
			"%s says what it does (%s)" % [skill.display_name, skill.effect_line()])
	check(total > SpellTree.RANKS.size() * SpellTree.POINTS_PER_RANK,
		"there is more to learn (%d points) than the ranks hand out (%d): a rank is a choice"
		% [total, SpellTree.RANKS.size() * SpellTree.POINTS_PER_RANK])
	check(kinds.size() == SpellSkill.Kind.size(),
		"spells, tiers, interactions and shorter waits, all of them in it")

	var douse := tree.by_id("douse")
	var lightning := tree.by_id("lightning")
	var wet := tree.by_id("wet_silk")
	var deluge := tree.by_id("deluge")
	var fire := tree.by_id("fire")
	check(tree.why_not(lightning).begins_with("opens at Adept"),
		"a skill in a row not reached yet is shut (%s)" % tree.why_not(lightning))
	check(not tree.learn(lightning), "and cannot be learned")
	tree.earn(tree.xp_to_next())
	check(tree.why_not(wet) == "needs Douse",
		"one that stands on another needs it first (%s)" % tree.why_not(wet))
	check(tree.learn(douse) and tree.learn(wet) and tree.learn(lightning),
		"learned in order, with the points for them")
	check(tree.points() == 1, "one point left of four (%d)" % tree.points())
	tree.earn(tree.xp_to_next())
	check(tree.learn(fire) and tree.points() == 1, "Fire Geyser, for two of three")
	check(tree.why_not(tree.by_id("live_lines")).begins_with("opens at"),
		"and Live Lines waits for its rank")
	tree.earn(tree.xp_to_next())
	tree.earn(tree.xp_to_next())
	check(tree.points() == 5, "a Grand Spooder, with five to spend (%d)" % tree.points())
	check(tree.why_not(tree.by_id("live_lines")) == "needs Live Silk",
		"where Live Lines still stands on Live Silk (%s)" % tree.why_not(tree.by_id("live_lines")))
	var before := tree.points()
	check(tree.grant("live_silk") and tree.points() == before,
		"a skill given costs no points (%d)" % tree.points())

	# A tier makes its spell bigger.
	var spell := spells.by_id("douse")
	var reach := spells.fan_reach(spell, 0.0)
	check(tree.learn(deluge), "Deluge learned")
	check(is_equal_approx(spells.fan_reach(spell, 0.0), reach * deluge.size_scale),
		"Douse throws further (%.1f -> %.1f m)" % [reach, spells.fan_reach(spell, 0.0)])
	check(is_equal_approx(spells.duration_of(spell, 0.0), spell.duration_at(0.0)
		* deluge.duration_scale), "and the ground stays wet longer")
	check(deluge.effect_line().contains("%"), "and its card says so (%s)" % deluge.effect_line())

	# A cut makes the waits shorter, silk's too.
	var slab := add_slab(Vector3(-30, 0.0, 180))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 0))
	await process_frame
	var silk := spells.by_id("silk")
	check(spells.cast_now(silk), "a web thrown")
	var plain_silk := builder._cooldown_span
	await wait_until(func() -> bool: return not builder.shot_in_flight(), 120)
	builder._cooling = 0.0
	var plain := spells.wait_for(spell)
	check(tree.grant("steady_hands"), "Steady Hands")
	check(is_equal_approx(spells.wait_for(spell), plain * 0.85),
		"every spell waits 15%% less (%.1fs -> %.1fs)" % [plain, spells.wait_for(spell)])
	check(spells.cast_now(silk), "and another web")
	check(is_equal_approx(builder._cooldown_span, plain_silk * 0.85),
		"silk's included (%.2fs -> %.2fs)" % [plain_silk, builder._cooldown_span])

	# Five on the keys, and the tree moves them. A sixth spell, made up for the
	# purpose: the book has only five beside silk.
	tree.forget_all()
	tree.earn(100000.0)
	for spell_id in ["douse", "gust", "pullback", "lightning", "fire"]:
		tree.learn(tree.by_id(spell_id))
	check(tree.loadout.size() == SpellTree.LOADOUT_SIZE and spells.hand().size() == 6,
		"five spells fill the loadout, on keys 2 to 6 (%s)" % str(tree.loadout))
	var extra := SpiderSpell.new()
	extra.id = "test_extra"
	extra.display_name = "Test Extra"
	extra.description = "A spell for checking."
	extra.form = SpiderSpell.Form.DOUSE
	extra.order = 900
	spells.book.append(extra)
	var teaches := SpellSkill.new()
	teaches.id = "test_extra"
	teaches.display_name = "Test Extra"
	teaches.kind = SpellSkill.Kind.SPELL
	teaches.spell = "test_extra"
	tree.skills.append(teaches)
	check(tree.grant("test_extra") and spells.is_open(extra) and spells.key_for(extra) == 0,
		"a sixth is known, but not on a key: the loadout is full")
	check(not tree.slot("test_extra"), "and there is no room for it")
	check(tree.unslot("gust") and tree.slot("test_extra"), "until one comes off")
	check(spells.key_for(extra) == 6 and spells.key_for(spells.by_id("pullback")) == 3,
		"then it goes on the last key, and the rest move up (%d, %d)"
		% [spells.key_for(extra), spells.key_for(spells.by_id("pullback"))])
	check(spells.select("douse") and tree.unslot("douse") and spells.current().id == "silk",
		"a spell taken off the keys while in hand leaves silk in hand")
	spells.open_all = true
	check(spells.hand().size() == spells.book.size(),
		"with everything open, every spell is on a key, past the five (%d)" % spells.hand().size())
	spells.open_all = false
	spells.book.erase(extra)
	tree.skills.erase(teaches)
	tree.forget_all()


## [E] opens the spell tree: the ranks down the page and a card for every skill,
## each saying where it stands. Pressing one learns it; pressing a spell you know
## takes it on or off the keys; the loadout runs along the foot.
func _test_the_tree_screen() -> void:
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if not check(hud != null, "the level has a HUD"):
		return
	var screen := hud.get_node_or_null(NodePath("SpellTree")) as SpellTreeScreen
	if not check(screen != null, "which built a spell tree screen"):
		return
	var tree := spider.spell_tree
	check(not screen.open and not screen.visible, "shut until it is asked for")
	check(screen._cards.size() == tree.skills.size(),
		"with a card for every skill (%d)" % screen._cards.size())
	spider.require_captured_mouse = false
	send_action(spider.input_skill_tree)
	await process_frame
	release_action(spider.input_skill_tree)
	check(screen.open and screen.visible, "[E] opens it")
	check(screen.rank_text().contains("Apprentice Spooder") and screen.rank_text().contains(
		"2 points"), "the rank and the points across the top (%s)" % screen.rank_text())
	check(screen.card_text("douse").begins_with("learn it"),
		"a skill an Apprentice can learn says so (%s)" % screen.card_text("douse"))
	check(screen.card_text("lightning").begins_with("opens at Adept"),
		"one in a row not reached yet names its rank (%s)" % screen.card_text("lightning"))
	check(screen.press("douse") and tree.has("douse"), "pressing a card learns it")
	check(screen.card_text("douse") == "learned · on [2]",
		"and the card says which key it is on (%s)" % screen.card_text("douse"))
	check(screen.loadout_text().contains("[2] Douse"),
		"and so does the loadout (%s)" % screen.loadout_text())
	check(screen.press("douse") and not tree.is_slotted("douse"),
		"pressed again, it comes off the keys")
	check(screen.card_text("douse") == "learned · not on a key", "and says so")
	check(screen.press("douse") and tree.is_slotted("douse"), "and again, back on")
	check(not screen.press("fire") and screen.message_text().contains("opens at"),
		"a shut one says why when it is pressed (%s)" % screen.message_text())
	tree.earn(tree.xp_to_next())
	await process_frame
	check(screen.card_text("waterspout") == "needs Gust",
		"one standing on another says what it still needs (%s)" % screen.card_text("waterspout"))
	check(screen.card_text("wet_silk").begins_with("learn it"),
		"and once it is learned, that it can be learned (%s)" % screen.card_text("wet_silk"))
	check(screen.rank_text().contains("Adept Spooder"),
		"a new rank, across the top (%s)" % screen.rank_text())
	send_action(spider.input_skill_tree)
	await process_frame
	release_action(spider.input_skill_tree)
	check(not screen.open and not screen.visible, "and [E] again puts it away")


## The keys down the right-hand side — silk and the loadout's five, filled or empty —
## and the readout over the bar.
func _test_the_strip() -> void:
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if not check(hud != null, "the level has a HUD"):
		return
	await process_frame
	var strip := hud.get_node_or_null(NodePath("SpellStrip")) as Control
	if not check(strip != null, "which has a strip of spells"):
		return
	check(hud._spell_chips.size() == SpellTree.LOADOUT_SIZE + 1,
		"a chip for silk and one for each of the loadout's five (%d)" % hud._spell_chips.size())
	var chip := hud._spell_chips.get(0) as Control
	var state := chip.get_node_or_null(NodePath("Row/Lines/State")) as Label if chip != null \
		else null
	if check(state != null, "silk has a chip"):
		check(state.text == "in hand · ready", "which says it is in hand and ready (%s)"
			% state.text)
	check(hud.pattern_label.text.begins_with("Silk"),
		"the readout over the bar says what is in hand (%s)" % hud.pattern_label.text)
	check(hud.hint_label.text.contains("Right mouse"),
		"and what right mouse does with it (%s)" % hud.hint_label.text)
	var empty := hud._spell_chips.get(1) as Control
	var line := empty.get_node_or_null(NodePath("Row/Lines/State")) as Label if empty != null \
		else null
	check(line != null and line.text.begins_with("empty"),
		"an empty slot says where to fill it (%s)" % (line.text if line != null else "—"))
	spider.spell_tree.grant("gust")
	await process_frame
	await process_frame
	var filled := (hud._spell_chips.get(1) as Control).get_node_or_null(
		NodePath("Row/Lines/Name")) as Label
	check(filled != null and filled.text == "Gust",
		"a spell learned fills the first of them (%s)" % (filled.text if filled != null else "—"))

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


## Each number key takes what is on it in hand — silk on 1, the loadout on 2 to 6 —
## Q takes hold of lines, and the bag's bar is put away so the keys have one meaning.
func _test_number_keys() -> void:
	for key in range(1, spells.book.size() + 1):
		check(InputMap.has_action("spell_%d" % key), "a key for spell %d" % key)
	var wheel := InputMap.action_get_events("spell_next") + InputMap.action_get_events("spell_prev")
	var on_the_wheel := wheel.size() == 2
	for event in wheel:
		on_the_wheel = on_the_wheel and event is InputEventMouseButton
	check(on_the_wheel, "and the wheel turns it both ways")
	var on_q: Array[StringName] = []
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			var key_event := event as InputEventKey
			if key_event != null and key_event.physical_keycode == KEY_Q:
				on_q.append(action)
	check(on_q == [&"web_ride"], "Q takes hold of a line, and is nothing else (%s)" % str(on_q))
	var hud := level.get_node_or_null("HUD") as SpiderHUD
	if check(hud != null, "the level has a HUD"):
		check(not hud._hotbar.visible, "and the bag's bar is put away")
		var chip := hud._spell_chips.get(2) as Control
		var label := chip.get_node_or_null(NodePath("Row/Key")) as Label if chip != null else null
		check(label != null and label.text == "3",
			"each chip says its key (%s)" % (label.text if label != null else "—"))

	spider.require_captured_mouse = false
	var third := spells.book[2]
	send_action("spell_3")
	await process_frame
	release_action("spell_3")
	check(spells.current().id == "silk", "a key with nothing on it leaves the hand where it was")
	spells.open_all = true
	send_action("spell_3")
	await process_frame
	release_action("spell_3")
	check(spells.current() == third, "open, its key takes it in hand (%s)" % third.display_name)
	send_action("spell_1")
	await process_frame
	release_action("spell_1")
	check(spells.current().id == "silk", "and 1 takes silk back")
	# A key while winding up: the wind-up is given up and the key has its way.
	check(spells.take(2) and spells.begin_cast() and spells.charging, "winding up the second")
	check(spells.take(4) and not spells.charging and spells.current() == spells.book[3],
		"a key mid-wind-up drops it and takes its own spell")
	spells.take(1)


## Every spell but silk is drawn in a magic circle while it winds up — fire on the
## ground the geyser will come up out of, lightning on the ground where it will
## strike, water under the spider's feet — and leaves through it: the circle flares
## and fades as the spell goes, lightning draws a second one over the strike, and a
## wind-up given up fades the same way.
func _test_spells_leave_through_circles() -> void:
	spells.open_all = true
	spider.require_captured_mouse = false
	var slab := add_slab(Vector3(-30, 0.0, 150), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 6.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var height := spider.stage().body_height
	aim_at(centre)
	await process_frame

	# Held the way a player holds it: the spider lets go for you if the key is up.
	spells.take(1)
	send_action(spider.input_shoot)
	await process_frame
	check(builder.aiming and _circles().is_empty(), "winding up silk is a ball of silk, not a circle")
	spells.cancel_cast()
	release_action(spider.input_shoot)
	await process_frame

	# Fire: on the ground the geyser will come up out of.
	spells.take(5)
	var fire := spells.current()
	send_action(spider.input_shoot)
	await run_frames(20)
	check(spells.charging, "winding up fire")
	var circles := _circles()
	if not check(circles.size() == 1, "draws one circle (%d)" % circles.size()):
		return
	var circle := circles[0]
	var ground: Vector3 = spells.area_target(fire).get("point", Vector3.ZERO)
	check(circle.global_position.distance_to(ground) < height * 0.1
		and absf(ground.y - centre.y) < height * 0.1,
		"on the ground where the geyser will come up (%.2f m off)"
		% circle.global_position.distance_to(ground))
	check(circle.global_basis.y.normalized().dot(Vector3.UP) > 0.99, "lying flat")
	check(absf(circle.radius - fire.size_at(spells.charge) * height) < height * 0.05
		and circle.radius > fire.size_at(0.0) * height * 1.05,
		"as wide as the column, and growing with the wind-up (%.2f m)" % circle.radius)
	check(circle.points == fire.sigil, "with fire's own star (%d)" % circle.points)
	release_action(spider.input_shoot)
	await process_frame
	check(not spells.charging and spells.cooling(fire), "let go, it goes")
	check(circle.is_fading(), "and the circle flares and fades as the geyser comes up through it")
	var geyser := _last_geyser()
	check(geyser != null and Vector2(geyser.global_position.x - ground.x,
		geyser.global_position.z - ground.z).length() < height * 0.1,
		"where the ground glows, and the geyser will burst")
	var circle_id := circle.get_instance_id()
	var faded: bool = await wait_until(func() -> bool: return not is_instance_id_valid(circle_id),
		90)
	check(faded, "and is gone soon after")

	# Lightning: on the ground where it will strike, and a second over the strike.
	spells.take(4)
	var lightning := spells.current()
	send_action(spider.input_shoot)
	await run_frames(2)
	circles = _circles()
	if not check(circles.size() == 1, "winding up lightning draws one circle (%d)" % circles.size()):
		release_action(spider.input_shoot)
		return
	circle = circles[0]
	var spot: Vector3 = spells.area_target(lightning).get("point", Vector3.ZERO)
	check(circle.global_position.distance_to(spot) < height * 0.1,
		"on the ground where it will strike (%.2f m off)" % circle.global_position.distance_to(spot))
	check(circle.global_basis.y.normalized().dot(Vector3.UP) > 0.99, "lying flat")
	check(absf(circle.radius - lightning.size_at(spells.charge) * height) < height * 0.05,
		"as wide as the strike (%.2f m)" % circle.radius)
	release_action(spider.input_shoot)
	await process_frame
	check(spells.cooling(lightning), "let go, it strikes")
	var over := 0
	for each in _circles():
		if each.global_position.y > spot.y + height and each.global_basis.y.dot(Vector3.DOWN) > 0.99:
			over += 1
	check(over == 1, "with a second circle over the strike, face down (%d)" % over)
	check(circle.is_fading(), "and the one on the ground flares and fades")
	await wait_until(func() -> bool: return _circles().is_empty(), 90)

	# Water: under the spider's feet. Given up, it fades the same way.
	spells.take(2)
	send_action(spider.input_shoot)
	await run_frames(2)
	circles = _circles()
	if not check(circles.size() == 1, "winding up water draws one circle (%d)" % circles.size()):
		release_action(spider.input_shoot)
		return
	circle = circles[0]
	var under := circle.global_position - spider.global_position
	check(Vector2(under.x, under.z).length() < height * 0.1 and under.y < 0.0,
		"under the spider's feet")
	check(absf(spells.fan_shown() - spells.fan_reach(spells.current(), spells.charge))
		< height * 0.2, "with the fan it will cover laid out on the ground (%.2f m)"
		% spells.fan_shown())
	spells.cancel_cast()
	release_action(spider.input_shoot)
	await run_frames(2)
	check(circle.is_fading(), "and a wind-up given up fades out")


## The magic circles standing now.
func _circles() -> Array[MagicCircle]:
	var found: Array[MagicCircle] = []
	for node in spider.get_tree().get_nodes_in_group("spell_effects"):
		var circle := node as MagicCircle
		if circle != null and not circle.is_queued_for_deletion():
			found.append(circle)
	return found


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


## Water sprayed in a fan in front of the spider: what the spray catches is soaked
## and stung, a flier included; the ground stays wet, and keeps whatever walks onto
## it soaked until it dries; what is off to the side or past its reach stays dry.
## A web it reaches is wet, and fire passes a wet web by.
func _test_douse() -> void:
	var douse := spells.by_id("douse")
	if not check(douse != null and douse.form == SpiderSpell.Form.DOUSE,
			"there is Douse in the book"):
		return
	_learned("douse", 2)
	check(spells.select("douse"), "learned, it can be taken in hand")
	check(not spells.is_area(douse), "it is thrown from the spider, not called down")

	var slab := add_slab(Vector3(90, 0.0, -90), Vector3(60, 0.5, 60))
	await physics_frame
	var start := slab.global_position + Vector3(0, 0.25, 22.0)
	stand_on(start)
	await physics_frame
	var height := spider.stage().body_height
	var far := spells.fan_reach(douse, 0.0)
	var full := spells.fan_reach(douse, 1.0)
	check(far > height * 3.0 and full > far * 1.5,
		"a tap throws it %.1f m, a full wind-up %.1f m" % [far, full])
	var ahead := Vector3.FORWARD
	var side := Vector3.RIGHT
	clear_prey_near(start + ahead * full * 0.5, full * 1.5, null)
	var walker := spawn("beetle", start + ahead * far * 0.5 + Vector3(0.0, 0.2, 0.0))
	var flier := spawn("moth", start + ahead * far * 0.6 + Vector3(0.0, height * 1.5, 0.0))
	var aside := spawn("fly", start + ahead * far * 0.3 + side * far * 0.8 + Vector3.UP * 0.2)
	var beyond := spawn("beetle", start + ahead * (far + height * 4.0) + Vector3(0.0, 0.2, 0.0))
	if not check(walker != null and flier != null and aside != null and beyond != null,
			"two beetles, a moth and a fly"):
		return
	for creature in [walker, flier, aside, beyond]:
		creature.aggression = 0.0
		creature.move_speed = 0.0
	await physics_frame
	aim_at(start + ahead * full * 2.0 + Vector3.DOWN * 0.25)
	check(spells.cast_now(douse), "sprayed")
	var wet := _first_wet()
	if not check(wet != null, "and the ground is wet"):
		return
	check(wet.heading.dot(ahead) > 0.99, "out the way the cross looks")
	check(absf(wet.reach - far) < 0.01, "as far as a tap throws it (%.1f m)" % wet.reach)
	check(spells.cooling(douse), "and it waits its own wait (%.1fs)" % spells.cooldown_left(douse))
	check(walker.is_wet() and walker.health() < 1.0,
		"the beetle in it is soaked and stung (%d%% left)" % roundi(walker.health() * 100.0))
	check(flier.is_wet(), "and so is the moth over it")
	check(not aside.is_wet() and is_equal_approx(aside.health(), 1.0),
		"the fly off to the side is not")
	check(not beyond.is_wet(), "nor the beetle past its reach")
	var late := spawn("ant", start + ahead * far * 0.3 + Vector3(0.0, 0.2, 0.0))
	if check(late != null, "an ant on the wet ground after"):
		late.move_speed = 0.0
		var soaked: bool = await wait_until(func() -> bool: return late.is_wet(), 60)
		check(soaked, "is soaked by standing on it")
	wet.life = 0.0
	await run_frames(2)
	check(not wet.is_wet(), "and when its time is up, the ground dries")
	var wet_id := wet.get_instance_id()
	var gone: bool = await wait_until(func() -> bool: return not is_instance_id_valid(wet_id),
		120)
	check(gone, "and the wet is gone")

	# Silk it reaches is wet once Wet Silk is learned, and fire passes a wet web by.
	spells.forget_waits()
	clear_prey_near(start, full * 2.0, null)
	var half := height * 1.2
	var soaked_web := _spin(start + ahead * far * 0.6 + Vector3.UP * (half + 0.1), half)
	var dry_web := _spin(start + side * full + Vector3.UP * (half + 0.1), half)
	if not check(soaked_web != null and dry_web != null, "a web in the spray, one out of it"):
		return
	await physics_frame
	aim_at(start + ahead * full * 2.0 + Vector3.DOWN * 0.25)
	check(spells.cast_now(douse), "sprayed at a web")
	check(not WetSilk.is_wet(soaked_web), "before Wet Silk is learned, the web stays dry")
	spells.forget_waits()
	spider.spell_tree.grant("wet_silk")
	check(spells.cast_now(douse), "sprayed at it again, with Wet Silk learned")
	check(WetSilk.is_wet(soaked_web), "the web it reaches is wet")
	check(not WetSilk.is_wet(dry_web), "and the one out of the spray is dry")
	var plain_hold := soaked_web.hold_strength()
	spells.forget_waits()
	spider.spell_tree.grant("sodden_silk")
	check(spells.cast_now(douse), "and again, with Sodden Silk")
	check(is_equal_approx(soaked_web.hold_strength(), plain_hold * WetSilk.HEAVY_HOLD),
		"which holds half as hard again while it is wet (%.1f -> %.1f)"
		% [plain_hold, soaked_web.hold_strength()])
	var fire := spells.by_id("fire")
	var soaked_id := soaked_web.get_instance_id()
	var dry_id := dry_web.get_instance_id()
	for web in [soaked_web, dry_web]:
		var under := (web as WebNet).signal_point()
		under.y = start.y
		FireGeyser.erupt(level, under, height * 1.2, height, fire.power_at(0.0))
	await run_frames(roundi(FireGeyser.WARN * 60.0) + 6)
	check(is_instance_id_valid(soaked_id) and not soaked_web.is_queued_for_deletion(),
		"fire passes the wet web by")
	check(not is_instance_id_valid(dry_id) or dry_web.is_queued_for_deletion(),
		"and burns the dry one")


## Wind blown in a fan in front of the spider: everything loose in it is shoved away
## and stung, a boss only stung, and what it blows into a web the web catches.
func _test_gust() -> void:
	var gust := spells.by_id("gust")
	if not check(gust != null and gust.form == SpiderSpell.Form.GUST, "there is Gust in the book"):
		return
	_learned("gust", 2)
	check(spells.select("gust"), "learned, it can be taken in hand")
	var slab := add_slab(Vector3(-90, 0.0, -90), Vector3(60, 0.5, 60))
	await physics_frame
	var start := slab.global_position + Vector3(0, 0.25, 22.0)
	stand_on(start)
	await physics_frame
	var height := spider.stage().body_height
	var far := spells.fan_reach(gust, 0.0)
	var ahead := Vector3.FORWARD
	clear_prey_near(start + ahead * far * 0.5, far * 2.0, null)
	var blown := spawn("beetle", start + ahead * far * 0.4 + Vector3(0.0, 0.2, 0.0))
	var boss := spawn("beetle", start + ahead * far * 0.6 + Vector3.RIGHT * far * 0.2
		+ Vector3(0.0, 0.2, 0.0))
	var aside := spawn("fly", start + Vector3.RIGHT * far * 0.9 + Vector3.UP * 0.2)
	if not check(blown != null and boss != null and aside != null,
			"a beetle in the way, one that fears nothing, and a fly to one side"):
		return
	boss.kind = boss.kind.duplicate()
	boss.kind.boss = true
	for creature in [blown, boss, aside]:
		creature.aggression = 0.0
		creature.move_speed = 0.0
	await physics_frame
	var was := blown.global_position
	var boss_was := boss.global_position
	aim_at(start + ahead * far * 2.0 + Vector3.DOWN * 0.25)
	check(spells.cast_now(gust), "blown")
	await run_frames(30)
	var moved := blown.global_position - was
	check(moved.dot(ahead) > height,
		"the beetle is shoved away from you (%.2f m)" % moved.dot(ahead))
	check(blown.health() < 1.0, "and stung (%d%% left)" % roundi(blown.health() * 100.0))
	check(boss.global_position.distance_to(boss_was) < height * 0.3 and boss.health() < 1.0,
		"a boss stands its ground, and only takes the sting")
	check(is_equal_approx(aside.health(), 1.0), "and the fly to one side is left alone")

	# Blown into a web, it is caught.
	spells.forget_waits()
	clear_prey_near(start + ahead * far * 0.5, far * 2.0, null)
	var walker := spawn("beetle", start + ahead * far * 0.3 + Vector3(0.0, 0.2, 0.0))
	if not check(walker != null, "a beetle in front of a web"):
		return
	walker.aggression = 0.0
	walker.move_speed = 0.0
	walker.struggle_stamina = 30.0
	var half := height * 1.2
	var web := _spin(walker.global_position + ahead * height * 2.0
		+ Vector3.UP * (half - height * 0.3), half)
	if not check(web != null, "and the web"):
		return
	await physics_frame
	check(not walker.is_stuck(), "loose to start with")
	check(spells.cast_now(gust), "blown at it")
	var caught: bool = await wait_until(func() -> bool: return walker.is_stuck(), 60)
	check(caught and walker.held_by() == web, "blown into the web, it is caught")


## Wind over wet ground lifts the water into a whirl that runs on the way the wind
## blew, stops at the first thing it reaches and holds it there — round and round,
## going nowhere, worn down a little — for as long as the wind-up gave it. The
## ground it came from is dry, what is further on is left alone, and wind with no
## wet ground under it lifts nothing. All of it once Waterspout is learned: before,
## wind over wet ground is only wind.
func _test_the_whirl() -> void:
	var douse := spells.by_id("douse")
	var gust := spells.by_id("gust")
	if douse == null or gust == null:
		return
	spider.spell_tree.grant("douse")
	spider.spell_tree.grant("gust")
	var slab := add_slab(Vector3(90, 0.0, 90), Vector3(60, 0.5, 60))
	await physics_frame
	var start := slab.global_position + Vector3(0, 0.25, 22.0)
	stand_on(start)
	await physics_frame
	var height := spider.stage().body_height
	var far := spells.fan_reach(douse, 0.0)
	var ahead := Vector3.FORWARD
	clear_prey_near(start + ahead * far, far * 3.0, null)
	var first := spawn("beetle", start + ahead * (far + height * 2.0) + Vector3(0.0, 0.2, 0.0))
	var further := spawn("beetle", start + ahead * (far + height * 7.0) + Vector3(0.0, 0.2, 0.0))
	if not check(first != null and further != null, "two beetles past the wet, one behind the other"):
		return
	for creature in [first, further]:
		creature.aggression = 0.0
		creature.move_speed = 0.0
	await physics_frame
	aim_at(start + ahead * far * 3.0 + Vector3.DOWN * 0.25)
	check(spells.cast_now(douse), "the ground doused")
	var wet := _first_wet()
	if not check(wet != null and _first_whirl() == null, "wet, and no whirl yet"):
		return
	check(spells.cast_now(gust), "wind blown over it, before Waterspout is learned")
	check(_first_whirl() == null and wet.is_wet(), "lifts nothing, and the ground stays wet")
	spells.forget_waits()
	spider.spell_tree.grant("waterspout")
	check(spells.cast_now(gust), "and with it learned, wind blown over it")
	var whirl := _first_whirl()
	if not check(whirl != null, "lifts the water into a whirl"):
		return
	check(not wet.is_wet(), "and the ground it came from is dry")
	check(whirl.heading.dot(ahead) > 0.99, "running on the way the wind blew")
	var whirl_id := whirl.get_instance_id()
	var got: bool = await wait_until(func() -> bool:
		var going := instance_from_id(whirl_id) as WaterSpiral
		return going != null and going.caught == first, 240)
	if not check(got, "it stops at the first thing it reaches"):
		return
	check(first.is_held(), "and holds it")
	first.move_speed = 1.0
	first.go_to(start + ahead * far * 5.0)
	var held_at := first.global_position
	await run_frames(40)
	check(first.global_position.distance_to(held_at) < height * 0.6,
		"round and round, going nowhere (%.2f m)" % first.global_position.distance_to(held_at))
	check(not further.is_held() and not further.is_wet(), "the one further on is left alone")
	var let_go: bool = await wait_until(func() -> bool: return not first.is_held(), 300)
	check(let_go, "and once the hold runs out, it lets go")
	check(first.health() < 1.0, "having worn it down a little (%d%% left)"
		% roundi(first.health() * 100.0))
	await wait_until(func() -> bool: return _first_whirl() == null, 120)
	spells.forget_waits()
	check(spells.cast_now(gust), "wind again, over dry ground")
	check(_first_whirl() == null, "lifts nothing")


## A spider with Digestive Flood has acid water: what its whirl holds is dosed.
func _test_acid_water() -> void:
	var douse := spells.by_id("douse")
	var gust := spells.by_id("gust")
	if douse == null or gust == null:
		return
	for skill_id in ["douse", "gust", "waterspout"]:
		spider.spell_tree.grant(skill_id)
	var slab := add_slab(Vector3(-90, 0.0, 90), Vector3(30, 0.5, 30))
	await physics_frame
	var start := slab.global_position + Vector3(0, 0.25, 6.0)
	stand_on(start)
	await physics_frame
	var height := spider.stage().body_height
	var far := spells.fan_reach(douse, 0.0)
	clear_prey_near(start, far * 3.0, null)
	for step in ["paralytic", "digestive"]:
		traits.take(traits.by_id(step))
	check(traits.acid_water(), "a digestive flood makes the spider's water acid")
	var ant := spawn("ant", start + Vector3.FORWARD * (far + height * 2.0) + Vector3(0, 0.2, 0))
	if not check(ant != null, "an ant"):
		return
	ant.aggression = 0.0
	ant.move_speed = 0.0
	await physics_frame
	aim_at(start + Vector3.FORWARD * far * 3.0 + Vector3.DOWN * 0.25)
	check(spells.cast_now(douse) and spells.cast_now(gust), "doused, and a whirl blown at it")
	var eaten: bool = await wait_until(func() -> bool: return ant.is_poisoned(), 240)
	check(eaten, "and its water doses what it holds")


func _first_whirl() -> WaterSpiral:
	for node in spider.get_tree().get_nodes_in_group(WaterSpiral.GROUP):
		var whirl := node as WaterSpiral
		if whirl != null and not whirl.is_queued_for_deletion():
			return whirl
	return null


func _first_wet() -> WetGround:
	for node in spider.get_tree().get_nodes_in_group(WetGround.GROUP):
		var wet := node as WetGround
		if wet != null and not wet.is_queued_for_deletion():
			return wet
	return null


func _square(centre: Vector3, half: float) -> Array[Vector3]:
	return [
		centre + Vector3(-half, -half, 0),
		centre + Vector3(half, -half, 0),
		centre + Vector3(half, half, 0),
		centre + Vector3(-half, half, 0),
	]


# --- lightning ------------------------------------------------------------

## Called down where the cross is: what it strikes is stunned and hurt, a hunter
## gives up the chase, a flier falls — and the spider is never struck by its own.
func _test_summon_lightning() -> void:
	var lightning := spells.by_id("lightning")
	if not check(lightning != null and lightning.form == SpiderSpell.Form.LIGHTNING,
			"there is lightning in the book"):
		return
	check(not spells.is_open(lightning), "not known to begin with")
	_learned("lightning", 3)
	check(spells.select("lightning"), "learned, it can be called down")

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
	check(lightning.power_at(0.0) > 0.0
		and is_equal_approx(wasp.health(), 1.0 - lightning.power_at(0.0)),
		"and hurt (%d%% of it left)" % roundi(wasp.health() * 100.0))
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
	grow_to_tier(3)
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


## A strike on a web leaves it live: what it holds stays stunned for as long as the
## charge lasts, and what touches it is struck and hurt — caught by it, or loose in
## it. Then the charge runs out, and it is a web again. A strike on a line leaves
## nothing in the line, and nothing runs along it to the web at its end; aimed at a
## line, it comes down on the floor under it.
func _test_a_struck_web_stays_live() -> void:
	var lightning := _learned("lightning", 3)
	if lightning == null:
		return
	var slab := add_slab(Vector3(-150, 0.0, -150), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 6.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var height := spider.stage().body_height
	var radius := lightning.size_at(0.0) * height
	var half := radius * 0.8
	var web := _spin(centre + Vector3.UP * (half + height * 0.3), half)
	if not check(web != null, "a web"):
		return
	var wasp := spawn("wasp", (web as WebNet).signal_point())
	if not check(wasp != null, "a wasp in it"):
		return
	wasp.struggle_stamina = 30.0
	await physics_frame
	await physics_frame
	if not check(wasp.is_fighting(), "fighting the web"):
		return
	var stun := lightning.duration.x
	var harm := lightning.power_at(0.0)
	var strike := LightningStrike.call_down(level, (web as WebNet).signal_point(), radius,
		stun, 0, height * 0.6, lightning.colour, harm)
	check(strike.charged.has(web), "struck")
	check(is_equal_approx(wasp.health(), 1.0 - harm),
		"and the wasp in it hurt (%d%% of it left)" % roundi(wasp.health() * 100.0))
	var charge := WebCharge.of(web)
	if not check(charge != null, "and the web is live"):
		return
	check(is_equal_approx(charge.left, stun * LightningStrike.LIVE_FOR),
		"for %.1fs, twice the stun" % charge.left)
	# Past the stun the strike gave it, and it is still out of it.
	await run_frames(roundi((stun + 0.6) * 60.0))
	check(is_instance_valid(wasp) and wasp.is_stuck() and wasp.is_stunned(),
		"the wasp stays stunned in it past the strike's own %.1fs" % stun)

	# Caught while it is live: struck as it is caught.
	var fly := spawn("fly", (web as WebNet).signal_point() + Vector3(half * 0.4, half * 0.3, 0.0))
	if not check(fly != null, "a fly"):
		return
	var caught: bool = await wait_until(func() -> bool: return fly.is_stuck(), 60)
	check(caught and fly.is_stunned(), "a fly caught in it is struck as it is caught")
	check(charge.struck.has(fly), "and the web says it struck it")
	check(fly.health() < 1.0, "and hurt (%d%% of it left)" % roundi(fly.health() * 100.0))

	# Loose in it, but the web cannot take it: struck all the same.
	var beetle := spawn("beetle", (web as WebNet).signal_point() + Vector3(-half * 0.3, 0.0, 0.0))
	if not check(beetle != null, "a beetle"):
		return
	beetle._recatch_cooldown = 30.0
	beetle.move_speed = 0.0
	beetle.aggression = 0.0
	var touched: bool = await wait_until(func() -> bool: return beetle.is_stunned(), 60)
	check(touched and beetle.is_loose(), "a beetle it cannot hold is struck where it touches it")
	check(beetle.health() < 1.0, "and hurt (%d%% of it left)" % roundi(beetle.health() * 100.0))

	# Then it runs out.
	var web_id := web.get_instance_id()
	var out: bool = await wait_until(func() -> bool:
		var standing := instance_from_id(web_id) as WebStructure
		return standing == null or WebCharge.of(standing) == null, 900)
	check(out, "and in the end the charge runs out")

	# A line: nothing in it, and nothing along it to the web at its end.
	var far_web := _spin(centre + Vector3(height * 10.0, half + height * 0.3, 0.0), half)
	var line := WebStrand.spin(pattern_named("frame_line"),
		centre + Vector3(height * 3.0, half + height * 0.3, 0.0),
		(far_web as WebNet).signal_point(), 1.0) if far_web != null else null
	if not check(line != null, "a line out to another web"):
		return
	line.place_in(webs)
	await physics_frame
	var on_line := LightningStrike.call_down(level,
		centre + Vector3(height * 4.0, half + height * 0.3, 0.0), radius * 0.3, stun, 0,
		height * 0.6)
	check(on_line.charged.is_empty(), "a strike on a line runs through nothing")
	check(WebCharge.of(far_web) == null, "and the web at its end is not live")
	aim_at((line.point_a + line.point_b) * 0.5 + Vector3.UP * height * 0.1)
	# The builder finds where the cross lands on its physics frame.
	await physics_frame
	await process_frame
	var under: Vector3 = spells.area_target(lightning).get("point", Vector3.ZERO)
	check(builder.aimed_line() == line and absf(under.y - centre.y) < height * 0.1,
		"aimed at the line, it comes down on the floor under it (%.2f m up)"
		% (under.y - centre.y))


## Live Silk and Live Lines, cast the way a player casts. Before Live Silk a strike
## runs through a web and leaves nothing in it; after, the web stays live. Before
## Live Lines a line carries nothing; after, a charge in a web runs down a line tied
## to it to the web at its other end, and a strike on a line runs down it both ways.
func _test_live_silk_and_lines() -> void:
	var lightning := _learned("lightning", 3)
	if lightning == null:
		return
	spells.select("lightning")
	var slab := add_slab(Vector3(150, 0.0, -150), Vector3(40, 0.5, 40))
	await physics_frame
	stand_on(slab.global_position + Vector3(0, 0.25, 6.0))
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var height := spider.stage().body_height
	var radius := lightning.size_at(0.0) * height
	var half := radius * 0.8
	var web := _spin(centre + Vector3.UP * (half + height * 0.3), half)
	var far_web := _spin(centre + Vector3(height * 10.0, half + height * 0.3, 0.0), half)
	if not check(web != null and far_web != null, "a web, and another across the room"):
		return
	await physics_frame
	aim_at((web as WebNet).signal_point())
	await physics_frame
	await process_frame
	check(spells.cast_now(lightning), "struck, before Live Silk")
	var strike := _last_strike()
	check(strike != null and strike.charged.has(web), "it runs through the web")
	check(WebCharge.of(web) == null, "but leaves nothing in it")
	spells.forget_waits()
	spider.spell_tree.grant("live_silk")
	check(spells.cast_now(lightning), "struck again, with Live Silk learned")
	check(WebCharge.of(web) != null, "and the web stays live")

	# A line from a corner of one to a corner of the other.
	var line := WebStrand.spin(pattern_named("frame_line"), web.anchors[1], far_web.anchors[0],
		1.0)
	if not check(line != null, "a line between them"):
		return
	line.place_in(webs)
	await physics_frame
	spells.forget_waits()
	check(spells.cast_now(lightning), "struck, before Live Lines")
	strike = _last_strike()
	check(strike != null and not strike.charged.has(far_web),
		"the line carries nothing to the web at its end")
	spells.forget_waits()
	spider.spell_tree.grant("live_lines")
	check(spells.cast_now(lightning), "struck, with Live Lines learned")
	strike = _last_strike()
	check(strike != null and strike.charged.has(far_web) and strike.ran_along.has(line),
		"it runs down the line to the web at its end")
	check(WebCharge.of(far_web) != null, "and leaves that one live too")
	var middle := (line.point_a + line.point_b) * 0.5
	var on_line := LightningStrike.call_down(level, middle, radius * 0.3, lightning.duration.x,
		0, height * 0.6, lightning.colour, 0.0, true, true)
	check(on_line.charged.has(web) and on_line.charged.has(far_web),
		"and a strike on the line runs down it to both")


## Water carries a strike: what a whirl holds, twice as hard, and on from one wet
## thing to the next.
func _test_lightning_and_water() -> void:
	var lightning := spells.by_id("lightning")
	var douse := spells.by_id("douse")
	var gust := spells.by_id("gust")
	if lightning == null or douse == null or gust == null:
		return
	spells.open_all = true
	var slab := add_slab(Vector3(120, 0.0, -120), Vector3(40, 0.5, 40))
	await physics_frame
	var start := slab.global_position + Vector3(0, 0.25, 8.0)
	stand_on(start)
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 20.0, null)
	var height := spider.stage().body_height
	var strike_radius := lightning.size_at(0.0) * height
	var far := spells.fan_reach(douse, 0.0)
	var beetle := spawn("beetle", start + Vector3.FORWARD * (far + height * 2.0)
		+ Vector3(0.0, 0.2, 0.0))
	if not check(beetle != null, "a beetle past the wet ground"):
		return
	beetle.aggression = 0.0
	beetle.move_speed = 0.0
	await physics_frame
	aim_at(start + Vector3.FORWARD * far * 3.0 + Vector3.DOWN * 0.25)
	check(spells.cast_now(douse) and spells.cast_now(gust), "a whirl blown at it")
	var whirl := _first_whirl()
	if whirl == null:
		return
	var whirl_id := whirl.get_instance_id()
	var holding: bool = await wait_until(func() -> bool:
		var going := instance_from_id(whirl_id) as WaterSpiral
		return going != null and going.held().has(beetle), 240)
	if not check(holding, "and it holds it, wet"):
		return
	# Struck at its rim, from the side, with a strike too small to reach it.
	var small := whirl.radius * 0.15
	var side := whirl.heading.cross(Vector3.UP).normalized()
	var rim := whirl.global_position + side * whirl.radius * 0.95 + Vector3.UP * whirl.radius * 0.2
	check(beetle.global_position.distance_to(rim) > small + beetle.hit_radius(),
		"the rim of the whirl is out of the strike's own reach")
	var before := beetle.health()
	var strike := LightningStrike.call_down(level, rim, small, lightning.duration.x, 0,
		height * 0.6, lightning.colour, lightning.power_at(0.0))
	check(strike.shocked.has(beetle), "a strike on the whirl reaches what it holds")
	check(is_equal_approx(beetle.stunned, lightning.duration.x * Prey.WET_SHOCK),
		"and wet, twice as hard (%.1fs stunned)" % beetle.stunned)
	check(is_equal_approx(before - beetle.health(), lightning.power_at(0.0) * Prey.WET_SHOCK),
		"and twice as hurt (%d%% of it gone)" % roundi((before - beetle.health()) * 100.0))
	spells.open_all = false

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
	var lightning := _learned("lightning", 3)
	if lightning == null:
		return
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
## wrapped and all it is worth of something a web holds. A geyser raised under a
## creature glows on the ground first, then bursts, burns it and throws it up into
## the air; what it burns low is an easy catch; and with no ground under the cross
## for it to come up out of, nothing is raised and nothing waits.
func _test_fire_geyser() -> void:
	var fire := spells.by_id("fire")
	if not check(fire != null and fire.form == SpiderSpell.Form.FIRE,
			"there is fire in the book"):
		return
	check(spells.is_area(fire), "raised where you point, not sent out from the spider")
	check(not spells.is_open(fire), "not known to begin with")
	_learned("fire", 4)
	check(spells.is_open(fire), "learned, it can be raised")
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

	# Raised the way a player does it: under the creature the cross is on.
	clear_prey_near(centre, 20.0, null)
	var target := spawn("beetle", spider.global_position + Vector3(0.0, 0.1, -3.0))
	if not check(target != null, "a beetle to raise it under"):
		return
	target.move_speed = 0.0
	target.aggression = 0.0
	# A tough one, so that one burn is not already the whole catch.
	target.struggle_power = 12.0
	target.struggle_stamina = 30.0
	target.bind(0.6)
	await physics_frame
	await physics_frame
	var hold := builder.shot_hold(pattern_named("orb_web"), 3.0)
	var share := target.bind_share(hold)
	aim_at(target.global_position)
	await process_frame
	var ground: Vector3 = spells.area_target(fire).get("point", Vector3.ZERO)
	var under := ground - target.global_position
	check(Vector2(under.x, under.z).length() < height * 0.2 and absf(ground.y - centre.y)
		< height * 0.1, "it comes up out of the floor under it (%.2f m off)"
		% Vector2(under.x, under.z).length())
	var was := target.global_position.y
	check(spells.select("fire") and spells.cast_now(fire, 1.0), "raised")
	var geyser := _last_geyser()
	if not check(geyser != null and not geyser.has_burst(), "the ground glows first"):
		return
	check(is_equal_approx(target.health(), 1.0), "and nothing burns yet")
	var burned: bool = await wait_until(func() -> bool: return target.health() < 0.999, 120)
	if not check(burned, "then it bursts, and the beetle burns"):
		return
	var expected := fire.power_at(1.0) * lerpf(Prey.BARE_BURN, 1.0, target.bound)
	check(target.health() < 1.0 - expected * 0.8,
		"for about what its silk says (%d%% of it left)" % roundi(target.health() * 100.0))
	var top := target.global_position.y
	for i in 40:
		await physics_frame
		top = maxf(top, target.global_position.y)
	check(top > was + height * 1.5,
		"thrown up into the air (%.1f body heights)" % ((top - was) / height))
	check(target.bind_share(hold) > share * 1.3,
		"and burned low, it is an easier catch (%d%% a shot -> %d%%)"
		% [roundi(share * 100.0), roundi(target.bind_share(hold) * 100.0)])
	check(spells.cooling(fire), "and fire has its own wait (%.1fs)" % spells.cooldown_left(fire))

	var wrapped := spawn("fly", centre + Vector3(height * 3.0, height, height * 6.0))
	if check(wrapped != null and wrapped.bundle(), "something already caught"):
		check(is_zero_approx(wrapped.burn(power)), "is left be: it is caught")

	# Straight up at the sky: no ground under it, nothing raised, no wait spent.
	spells.forget_waits()
	aim_at(spider.view.aim_origin() + Vector3(0.0, 100.0, -1.0))
	await process_frame
	check(not spells.area_target(fire).get("hit", false), "the sky has no ground under it")
	check(not spells.cast_now(fire), "and nothing comes up out of it")
	check(not spells.cooling(fire), "and the wait is not spent")


## And the silk burns with it: a geyser under a web takes the web, and the frame it
## was walked round on, and what it held drops out burned as hard as fire burns
## anything; aimed at a line, it comes up under the line and not at the wall behind
## it, and burns it; silk out of the column is left standing; and a wet web over it
## stands in the fire, and catches what the geyser throws up into it.
func _test_fire_burns_silk() -> void:
	var fire := _learned("fire", 4)
	if fire == null:
		return
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
	var frame := _frame_lines(web)
	var far_frame := _frame_lines(far)
	check(frame.size() == 4 and far_frame.size() == 4,
		"each walked round on four lines (%d, %d)" % [frame.size(), far_frame.size()])
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
	var ground: Vector3 = spells.area_target(fire).get("point", Vector3.ZERO)
	check(absf(ground.y - centre.y) < height * 0.1
		and Vector2(ground.x - wasp.global_position.x, ground.z - wasp.global_position.z)
		.length() < height * 0.5, "the cross on the wasp puts the geyser on the floor under it")
	# Waited on by id: a lambda that holds the web itself complains once it is freed.
	var web_id := web.get_instance_id()
	check(spells.cast_now(fire), "a geyser raised under the web")
	var gone: bool = await wait_until(func() -> bool: return not is_instance_id_valid(web_id),
		120)
	check(gone, "and the web burns away")
	var frame_left := 0
	for line in frame:
		if is_instance_valid(line) and not line.is_queued_for_deletion():
			frame_left += 1
	check(frame_left == 0, "and the frame it was walked round on with it (%d left)" % frame_left)
	check(is_instance_valid(wasp) and not wasp.is_stuck(), "dropping the wasp out of it")
	if is_instance_valid(wasp):
		check(wasp.health() < 1.0 - fire.power_at(0.0) * 0.95,
			"burned as hard as fire burns anything held in silk (%d%% of it left)"
			% roundi(wasp.health() * 100.0))
	check(is_instance_valid(far) and not far.is_queued_for_deletion(),
		"and the web out of the column still stands")

	# A line across the room, with a wall a long way behind it: the cross just off
	# the line is on the line, and the geyser comes up under it.
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
	# The builder finds where the cross lands on its physics frame.
	await physics_frame
	await process_frame
	check(builder.aimed_line() == line, "the cross is on the line")
	var under: Vector3 = spells.area_target(fire).get("point", Vector3.ZERO)
	check(absf(under.z - a.z) < height * 0.3 and absf(under.y - centre.y) < height * 0.1,
		"and the geyser goes on the floor under it, not at the wall behind (%.2f m off)"
		% absf(under.z - a.z))
	var line_id := line.get_instance_id()
	check(spells.cast_now(fire), "raised")
	var burned: bool = await wait_until(func() -> bool: return not is_instance_id_valid(line_id),
		120)
	check(burned, "and the line burns away")
	check(is_instance_valid(far) and not far.is_queued_for_deletion(),
		"and the far web stands still")
	check(_frame_lines(far).size() == 4, "frame and all")

	# A wet web lying over a geyser stands in the fire, and catches what it throws up.
	spells.forget_waits()
	clear_prey_near(centre, 30.0, null)
	var spot := centre + Vector3(-height * 4.0, 0.0, height * 8.0)
	var canopy := _spin_flat(spot + Vector3.UP * height * 2.0, half)
	if not check(canopy != null, "a web lying flat over the floor"):
		return
	WetSilk.soak(canopy, 10.0)
	var beetle := spawn("beetle", spot + Vector3.UP * 0.2)
	if not check(beetle != null, "a beetle under it"):
		return
	beetle.move_speed = 0.0
	beetle.aggression = 0.0
	beetle.struggle_stamina = 30.0
	await physics_frame
	await physics_frame
	check(beetle.is_loose(), "loose to start with")
	var canopy_id := canopy.get_instance_id()
	FireGeyser.erupt(level, spot, height, height, fire.power_at(0.0))
	var caught: bool = await wait_until(func() -> bool: return beetle.is_stuck(), 120)
	check(caught and beetle.held_by() == canopy, "thrown up into the wet web, it is caught")
	check(beetle.health() < 1.0, "burned on the way (%d%% left)" % roundi(beetle.health() * 100.0))
	await run_frames(roundi((FireGeyser.BURN + FireGeyser.FADE) * 60.0) + 6)
	check(is_instance_id_valid(canopy_id) and not canopy.is_queued_for_deletion(),
		"and the wet web stands in the fire")
	check(beetle.is_stuck(), "holding it still")


## The geyser raised last, or null.
func _last_geyser() -> FireGeyser:
	var found: FireGeyser = null
	for node in spider.get_tree().get_nodes_in_group(FireGeyser.GROUP):
		var geyser := node as FireGeyser
		if geyser != null and not geyser.is_queued_for_deletion():
			found = geyser
	return found


## Every web in reach comes flying back: what it holds lands at the spider's feet,
## bundled; what it passes through takes silk; a web out of reach stays; a web
## lightning left live strikes what it passes; and with no web in reach nothing is
## cast and nothing waits.
func _test_pullback() -> void:
	var pullback := spells.by_id("pullback")
	if not check(pullback != null and pullback.form == SpiderSpell.Form.PULLBACK,
			"there is a pullback in the book"):
		return
	check(not spells.is_open(pullback), "not known to begin with")
	_learned("pullback", 1)
	check(spells.is_open(pullback), "learned, it can call webs back")
	spider.require_captured_mouse = false
	var slab := add_slab(Vector3(150, 0.0, 30), Vector3(80, 0.5, 80))
	await physics_frame
	var stand := slab.global_position + Vector3(0, 0.25, 8.0)
	stand_on(stand)
	await physics_frame
	var centre := slab.global_position + Vector3(0, 0.25, 0)
	clear_prey_near(centre, 40.0, null)
	var height := spider.stage().body_height
	var half := height * 1.2
	var lift := Vector3.UP * (half + height * 0.3)
	var holding := _spin(centre + lift + Vector3(-height * 5.0, 0, 0), half)
	var crossing := _spin(centre + lift + Vector3(height * 5.0, 0, 0), half)
	var far := _spin(centre + lift + Vector3(0, 0, -spells.cast_reach() * 1.3), half)
	if not check(holding != null and crossing != null and far != null,
			"two webs in reach and one out of it"):
		return
	var fly := spawn("fly", (holding as WebNet).signal_point())
	var on_the_way := (crossing as WebNet).signal_point().lerp(spider.global_position, 0.5)
	var wasp := spawn("wasp", on_the_way)
	if not check(fly != null and wasp != null, "a fly for one web, a wasp in the other's way"):
		return
	fly.struggle_stamina = 30.0
	wasp.move_speed = 0.0
	wasp.aggression = 0.0
	await physics_frame
	await physics_frame
	if not check(fly.is_stuck() and wasp.is_loose(), "the fly caught, the wasp loose"):
		return
	check(spells.pullable_webs().size() == 2, "two webs to call back (%d)"
		% spells.pullable_webs().size())

	# Wound up the way a player does it: lines out to what is coming.
	spells.take(spells.key_for(pullback))
	send_action(spider.input_shoot)
	await run_frames(3)
	# The lines are drawn in the frame, and physics can run ahead of the frame.
	await process_frame
	await process_frame
	check(spells.pull_lines_shown() == 2, "winding up, it draws a line to each (%d)"
		% spells.pull_lines_shown())
	var ids := [holding.get_instance_id(), crossing.get_instance_id()]
	var frame := _frame_lines(holding)
	release_action(spider.input_shoot)
	await process_frame
	check(spells.cooling(pullback), "let go, they come")
	check(spider.get_tree().get_nodes_in_group(WebPull.GROUP).size() == 2, "both of them")
	var back: bool = await wait_until(func() -> bool:
		return spider.get_tree().get_nodes_in_group(WebPull.GROUP).is_empty(), 300)
	check(back, "and both arrive")
	check(not is_instance_id_valid(ids[0]) and not is_instance_id_valid(ids[1]),
		"and are gone once they do")
	var frame_left := 0
	for line in frame:
		if is_instance_valid(line) and not line.is_queued_for_deletion():
			frame_left += 1
	check(frame.size() == 4 and frame_left == 0,
		"taking the frames they were walked round on with them (%d of %d left)"
		% [frame_left, frame.size()])
	check(is_instance_valid(far) and not far.is_queued_for_deletion(),
		"the web out of reach stays where it was")
	check(fly.is_bundled() and fly.global_position.distance_to(spider.global_position)
		< height * 3.0, "the fly lands at the spider's feet, bundled (%.2f m off)"
		% fly.global_position.distance_to(spider.global_position))
	check(wasp.bound > 0.0, "and the wasp in the way took silk as it went by (%d%%)"
		% roundi(wasp.bound * 100.0))

	# A live web strikes what it passes.
	spells.forget_waits()
	var live := _spin(centre + lift + Vector3(0, 0, -height * 6.0), half)
	if not check(live != null, "another web"):
		return
	var beetle := spawn("beetle", (live as WebNet).signal_point().lerp(spider.global_position, 0.5))
	if not check(beetle != null, "a beetle in its way"):
		return
	beetle.move_speed = 0.0
	beetle.aggression = 0.0
	await physics_frame
	LightningStrike.call_down(level, (live as WebNet).signal_point(), height * 0.5, 2.0, 0,
		height * 0.6)
	check(WebCharge.of(live) != null and not beetle.is_stunned(),
		"left live by lightning, out of the strike's reach of the beetle")
	check(spells.cast_now(pullback), "called back")
	var struck: bool = await wait_until(func() -> bool: return beetle.is_stunned(), 300)
	check(struck, "and it strikes the beetle as it passes through")
	await wait_until(func() -> bool:
		return spider.get_tree().get_nodes_in_group(WebPull.GROUP).is_empty(), 300)

	# Nothing in reach: nothing cast, and no wait spent on it.
	spells.forget_waits()
	check(not spells.cast_now(pullback), "with no web in reach, nothing comes")
	check(not spells.cooling(pullback), "and the wait is not spent")


## A level can hand the spider the whole book at once: every spell known and on a
## key, and every interaction, to an Apprentice — but no tier and no point — and
## shut again when it takes the book back.
func _test_the_whole_book_open() -> void:
	check(spells.open_spells().size() == 1, "an Apprentice has silk and nothing else")
	spells.open_all = true
	check(spells.open_spells().size() == spells.book.size(),
		"with the whole book open, it has all %d" % spells.book.size())
	check(spells.hand().size() == spells.book.size(), "every one of them on a key")
	var tree := spider.spell_tree
	check(tree.knows(&"live_silk") and tree.knows(&"waterspout"), "and every interaction")
	check(not tree.has_tier("douse") and tree.points() == SpellTree.POINTS_PER_RANK
		and is_equal_approx(tree.wait_scale("douse"), 1.0),
		"but no tier, no shorter wait and no point given away")
	check(spells.cycle(1) and spells.current().id != "silk", "and the wheel takes the next in hand")
	spells.open_all = false
	check(spells.open_spells().size() == 1 and spells.current().id == "silk",
		"shut again, it is back to silk")


## The lines [param web] was walked round on: both ends on its own anchors.
func _frame_lines(web: WebStructure) -> Array[WebStrand]:
	var found: Array[WebStrand] = []
	if not is_instance_valid(web):
		return found
	for standing in standing_webs():
		var line := standing as WebStrand
		if line == null:
			continue
		var ends := 0
		for anchor in web.anchors:
			if anchor.distance_to(line.point_a) < 0.01 or anchor.distance_to(line.point_b) < 0.01:
				ends += 1
		if ends >= 2:
			found.append(line)
	return found


func _last_strike() -> LightningStrike:
	var found: LightningStrike = null
	for node in spider.get_tree().get_nodes_in_group(LightningStrike.GROUP):
		var strike := node as LightningStrike
		if strike != null and not strike.is_queued_for_deletion():
			found = strike
	return found


## [param spell_id] learned — skill and all, given rather than bought — by a spider
## grown to [param tier], the size the check was written for. The spell.
func _learned(spell_id: String, tier := 0) -> SpiderSpell:
	grow_to_tier(tier)
	spider.spell_tree.grant(spell_id)
	return spells.by_id(spell_id)


## A sheet web standing up, [param half] either side of [param middle].
func _spin(middle: Vector3, half: float) -> WebStructure:
	select_pattern("sheet_web")
	builder.start()
	for point in _square(middle, half):
		builder.add_anchor(point)
	builder.finish()
	builder.stop()
	return newest_web("sheet_web")


## A sheet web lying flat, [param half] either side of [param middle].
func _spin_flat(middle: Vector3, half: float) -> WebStructure:
	select_pattern("sheet_web")
	builder.start()
	for corner: Vector3 in [Vector3(-half, 0, -half), Vector3(half, 0, -half),
			Vector3(half, 0, half), Vector3(-half, 0, half)]:
		builder.add_anchor(middle + corner)
	builder.finish()
	builder.stop()
	return newest_web("sheet_web")
