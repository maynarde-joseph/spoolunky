extends TestSuite

## Headless check on getting a fly from the pen to the market: silk wraps it on the
## spot, a line drags it to a prep table, every kitchen spell does its one step to
## what is on the table and in the order the kitchen allows, F takes the dish into
## the bag, and the market buys the bag.
##
##     godot --headless --path . --script res://tests/kitchen_smoke_test.gd

var _room: Node3D
var _farm: Farm
var _spider: SpiderPlayer
var _table: PrepTable


func run_checks() -> void:
	_check_rules()
	_room = FarmRoom.make(true, Vector3(0.0, 0.6, 9.0))
	await stage(_room)
	_farm = FarmRoom.farm_of(_room)
	_spider = FarmRoom.spider_of(_room)
	await run_frames(20)
	_table = _farm.build(Catalogue.structure("prep_table"), Vector2i(8, 9)) as PrepTable
	var fly := await _check_wrap()
	if fly == null:
		return
	await _check_tether(fly)
	await _check_cooking()
	await _check_taking()
	await _check_market()
	await _check_cut_free()


## The kitchen's rules, as data.
func _check_rules() -> void:
	var none: Array[int] = []
	check(Prep.why_not(none, Prep.Step.DRY).begins_with("Wash it first"), "nothing is dried before it is washed")
	check(Prep.why_not(none, Prep.Step.PULL).begins_with("Only cooked meat"), "nothing is pulled before it is cooked")
	var crusted: Array[int] = [Prep.Step.WASH, Prep.Step.CRUST]
	check(not Prep.can_do(crusted, Prep.Step.TENDERISE) and Prep.can_do(crusted, Prep.Step.COOK),
		"sealed in clay, only fire gets in")
	var cooked: Array[int] = [Prep.Step.WASH, Prep.Step.COOK]
	check(not Prep.can_do(cooked, Prep.Step.WASH) and Prep.can_do(cooked, Prep.Step.PULL),
		"cooked, only the pullback is left")
	check(Prep.dish_name("Fly", cooked) == "Roast Fly", "washed and cooked is a Roast Fly")
	var gritty: Array[int] = [Prep.Step.COOK]
	check(Prep.dish_name("Fly", gritty) == "Gritty Roast Fly" and Prep.worth(gritty) < Prep.worth(cooked),
		"cooked unwashed it is gritty, and worth less")
	var raw: Array[int] = [Prep.Step.WASH]
	check(Prep.dish_name("Fly", raw) == "Washed Raw Fly" and Prep.worth(raw) < Prep.worth(cooked),
		"uncooked it is raw, and worth less again")
	var everything: Array[int] = [Prep.Step.WASH, Prep.Step.DRY, Prep.Step.TENDERISE, Prep.Step.CRUST,
		Prep.Step.COOK, Prep.Step.PULL]
	check(Prep.dish_name("Fly", everything) == "Pulled Tender Crispy Clay-baked Fly",
		"the whole kitchen is a %s" % Prep.dish_name("Fly", everything))
	var fly := Catalogue.insect("fly")
	var plain := Dish.make(fly, 1.0, 0.0, cooked)
	var best := Dish.make(fly, 1.0, 1.0, everything)
	check(best.value() > plain.value() * 5, "a grown A5 fly through the whole kitchen is worth far more than a plain roast (%d against %d)"
		% [best.value(), plain.value()])
	check(Dish.make(fly, 0.0, 0.0, cooked).value() < plain.value(), "and a hatchling is worth less than a grown fly")
	check(Dish.grade_name(Dish.grade_of(0.0)) == "A1" and Dish.grade_name(Dish.grade_of(1.0)) == "A5",
		"grades run A1 to A5")
	var spells := Catalogue.spells()
	var steps := {}
	for spell in spells:
		steps[Prep.step_for(spell.form)] = spell.id
	check(spells.size() == 7 and steps.size() == 7,
		"seven spells, silk and one step each for the other six (%s)" % ", ".join(steps.values()))
	check(Catalogue.spell("water_spiral") != null and Catalogue.spell("douse") == null,
		"the water spell is the water spiral")


## Silk, thrown at a fly, wraps it on the spot.
func _check_wrap() -> Insect:
	var fly := _farm.add_insect(Catalogue.insect("fly"), _spider.global_position + Vector3(0.0, 0.0, -4.0), 1.0)
	await run_frames(2)
	fly.set_physics_process(false)
	FarmRoom.aim(_spider, fly.global_position)
	_spider.spells.select("silk")
	check(_spider.spells.shot_target() == fly, "a fly under the cross is what silk will be thrown at")
	check(_spider.spells.cast_now(_spider.spells.by_id("silk")), "silk is thrown")
	var wrapped := await wait_until(func() -> bool: return fly.is_bundle(), 60)
	if not check(wrapped, "one ball of silk wraps the fly on the spot — no partial wraps"):
		return null
	fly.set_physics_process(true)
	await run_frames(40)
	check(fly.is_on_floor() and fly.velocity.length() < 0.01, "and the bundle drops and lies still")
	return fly


## Left mouse on the bundle puts a line on it; walked to the table, it goes onto it.
func _check_tether(fly: Insect) -> void:
	FarmRoom.aim(_spider, fly.global_position)
	check(_spider.grapple() and _spider.tether.is_towing() and _spider.tether.cargo == fly,
		"left mouse on a bundle puts a line on it rather than grappling")
	var start := fly.global_position
	_spider.view.face(_table.global_position - _spider.global_position)
	Input.action_press("move_forward")
	var docked := await wait_until(func() -> bool: return _table.bundle == fly, 600)
	Input.action_release("move_forward")
	check(fly.global_position.distance_to(start) > 2.0, "the bundle comes along on the line (%.1fm)"
		% fly.global_position.distance_to(start))
	check(docked and fly.table == _table, "dragged up to a prep table, it goes onto it")
	await run_frames(2)
	check(not _spider.tether.is_towing(), "and the table takes it off the line")
	check(fly.global_position.y > _table.global_position.y + PrepTable.TOP, "lying on top of the table")


## Every kitchen spell does its step to what is on the table, in the order allowed.
func _check_cooking() -> void:
	var fly := _table.bundle
	if not check(fly != null, "there is a bundle on the table to cook"):
		return
	_spider.global_position = _table.global_position + Vector3(0.0, 0.6, 3.0)
	await run_frames(10)
	var order: Array = [
		["pullback", false, "the pullback will not pull it raw"],
		["gust", false, "the gust will not dry it unwashed"],
		["water_spiral", true, "the water spiral washes it"],
		["gust", true, "then the gust dries it"],
		["lightning", true, "lightning tenderises it"],
		["earth", true, "clay seals it in a crust"],
		["water_spiral", false, "sealed in clay, it will not wash again"],
		["fire", true, "fire breath cooks it"],
		["pullback", true, "and once it is cooked, the pullback pulls it"],
	]
	for entry: Array in order:
		_spider.spells.forget_waits()
		FarmRoom.aim(_spider, _table.hold_point())
		var before := fly.steps.size()
		_spider.spells.cast_now(_spider.spells.by_id(entry[0]))
		await run_frames(2)
		var took := fly.steps.size() > before
		check(took == entry[1], entry[2])
	check(fly.as_dish().title() == "Pulled Tender Crispy Clay-baked Fly",
		"and it comes out a %s" % fly.as_dish().title())
	var effects := 0
	for node in get_nodes_in_group("spell_effects"):
		effects += 1
	check(effects > 0, "every spell is something to see (%d effects up)" % effects)
	_spider.spells.forget_waits()
	FarmRoom.aim(_spider, _spider.global_position + Vector3(0.0, -0.5, -3.0))
	var steps_before := fly.steps.size()
	check(_spider.spells.cast_now(_spider.spells.by_id("fire")) and fly.steps.size() == steps_before,
		"cast at bare ground, a kitchen spell still goes off and touches nothing")


## F at the table takes the dish into the bag.
func _check_taking() -> void:
	var fly := _table.bundle
	var worth := fly.as_dish().value() if fly != null else 0
	FarmRoom.aim(_spider, _table.hold_point())
	check(_spider.interact_hint().begins_with("F — take the"), "the readout offers the dish: %s"
		% _spider.interact_hint())
	check(_spider.interact(), "F at the table takes the dish")
	await run_frames(2)
	check(_spider.bag.count() == 1 and _spider.bag.total_value() == worth,
		"it is in the bag, worth %d" % worth)
	check(_table.bundle == null and not is_instance_valid(fly), "and the table is empty again")


## F at the market sells the bag.
func _check_market() -> void:
	var market := MarketStall.new()
	market.name = "Market"
	_room.add_child(market)
	market.global_position = _spider.global_position + Vector3(0.0, 0.0, 3.5)
	await run_frames(3)
	var worth := _spider.bag.total_value()
	var before := _farm.coins
	FarmRoom.aim(_spider, market.global_position + Vector3(0.0, 0.8, -0.5))
	check(_spider.interact(), "F at the market sells")
	check(_spider.bag.is_empty() and _farm.coins == before + worth,
		"the bag is emptied and the farm paid %d" % worth)
	market.queue_free()
	await run_frames(2)


## F on a bundle nothing has been done to cuts it free.
func _check_cut_free() -> void:
	var fly := _farm.add_insect(Catalogue.insect("fly"), _spider.global_position + Vector3(2.0, 0.0, -2.0), 0.5)
	await run_frames(2)
	fly.wrap()
	await run_frames(30)
	FarmRoom.aim(_spider, fly.global_position)
	check(_spider.interact() and not fly.is_bundle(), "F on a plain bundle cuts the fly free")
	fly.wrap()
	fly.apply(Prep.Step.WASH)
	check(not fly.cut_free().is_empty() and fly.is_bundle(), "but not once the kitchen has started on it")
