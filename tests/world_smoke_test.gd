extends TestSuite

## Headless check on the farm as the game opens it: a starter pen with flies in it,
## the spider on the land with its HUD, the market by the road, wild flies drawn
## in — and the shop, and building from it the way a player does, with the cross
## and the mouse buttons.
##
##     godot --headless --path . --script res://tests/world_smoke_test.gd

const SCENE := "res://game/world/farm.tscn"

var _farm: Farm
var _spider: SpiderPlayer
var _hud: SpiderHUD


func run_checks() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == SCENE,
		"the game opens on the farm")
	var level := await open(SCENE)
	if level == null:
		return
	_farm = level.get_node_or_null("Farm") as Farm
	_spider = level.get_node_or_null("Player") as SpiderPlayer
	_hud = level.get_node_or_null("HUD") as SpiderHUD
	if not check(_farm != null and _spider != null and _hud != null,
			"it has a farm, the spider and a HUD"):
		return
	_spider.require_captured_mouse = false
	await run_frames(60)
	_check_start(level)
	await _check_shop()
	await _check_building()
	await _check_wild()
	await _check_disc()


func _check_start(level: Node) -> void:
	var pen := _farm.grid.region_id(Farm.STARTER_FROM + Vector2i(1, 1))
	check(_farm.grid.is_pen(pen) and _farm.insects_in(pen).size() == Farm.STARTER_FLIES.size(),
		"it starts with a pen of %d flies" % _farm.insects_in(pen).size())
	check(_farm.grid.pens().size() == 1, "and the rest of the land empty")
	check(_farm.coins == 250, "with %d coins to start with" % _farm.coins)
	check(level.get_tree().get_first_node_in_group(MarketStall.GROUP) != null, "there is a market to sell at")
	var market := level.get_tree().get_first_node_in_group(MarketStall.GROUP) as MarketStall
	check(market != null and not _farm.grid.on_land(market.global_position),
		"and it stands off the land, where nothing built can take its place")
	check(_spider.climb.is_attached() and _spider.global_position.y < 1.0,
		"the spider is standing on the ground (%.2fm)" % _spider.global_position.y)
	check(_farm.grid.on_land(_spider.global_position + Vector3(0.0, 0.0, -3.0)),
		"looking out over the land")


func _check_shop() -> void:
	var shop := _hud.shop()
	_hud.toggle_shop()
	check(shop.open and shop.visible, "E opens the shop")
	var ids := shop.card_ids()
	var wanted := 0
	for kind in Catalogue.structures():
		wanted += 1 if ids.has(kind.id) else 0
	check(wanted == Catalogue.structures().size() and ids.size() == wanted,
		"with a card for everything the farm can build (%d cards)" % ids.size())
	check(ids.has("melon_patch") and ids.has("herb_bed") and not ids.has("stock_fly"),
		"crops among them, and no flies for sale")
	check(shop.card_text("fence").contains("a length"), "a fence is priced by the length: %s"
		% shop.card_text("fence"))
	_farm.coins = 10
	await run_frames(1)
	check(not shop.press("pond") and shop.message_text().contains("coins"),
		"something the farm cannot afford is not handed over")
	_farm.coins = 250
	check(shop.press("fence") and not shop.open, "pressing a card shuts the shop")
	check(_spider.builder.active and _spider.builder.kind.id == "fence",
		"and puts it in the spider's hand to build")


## Building with the cross: a run of fence corner to corner, a gate in it, a trough
## in the pen, and one taken down again.
func _check_building() -> void:
	var builder := _spider.builder
	var grid := _farm.grid
	var a := Vector2i(2, 2)
	var b := Vector2i(6, 6)
	await _aim_at(grid.corner_position(a))
	check(not builder.place() and builder.has_start, "a first click picks the run's first corner")
	await _aim_at(grid.corner_position(b))
	check(builder.hint().contains("16 lengths"), "the readout prices the run: %s" % builder.hint())
	var before := _farm.coins
	check(builder.place(), "a second click puts the run up")
	check(_farm.coins == before - 16 * 5 and grid.is_pen(grid.region_id(Vector2i(4, 4))),
		"sixteen lengths, paid for, and the inside is a pen")
	check(grid.pens().size() == 2, "a second pen beside the starter")
	builder.begin(Catalogue.structure("gate"))
	await _aim_at(grid.edge_middle(Vector3i(FarmGrid.ACROSS_Z, 4, 6)) + Vector3(0.0, 0.0, -0.2))
	check(builder.place(), "a gate goes into the fence")
	builder.begin(Catalogue.structure("trough"))
	await _aim_at(grid.centre_of(Vector2i(3, 3)))
	check(builder.valid and builder.place(), "a trough goes in the pen")
	await _aim_at(grid.centre_of(Vector2i(3, 3)))
	check(not builder.valid and builder.reason == "Something is already there",
		"and nothing else can go on top of it")
	builder.rotate_piece()
	check(builder.quarter == 1, "R turns what is in hand")
	builder.stop()
	check(not builder.active, "right click puts it away")
	# From inside the pen, so the cross is on the trough and not a fence.
	await _aim_at(grid.centre_of(Vector2i(3, 3)) + Vector3(0.0, 0.3, 0.0), Vector3(2.5, 0.6, 2.5))
	var coins := _farm.coins
	check(builder.demolish_aimed() and _farm.coins > coins and _farm.structure_at(Vector2i(3, 3)) == null,
		"X takes down what the cross is on, for coins back")
	check(grid.is_pen(grid.region_id(Vector2i(4, 4))), "and only that: the pen is still a pen")


## The starter pen's trough draws wild flies in.
func _check_wild() -> void:
	check(_farm.wild_flies, "the farm draws wild flies in")
	var fly := _farm.call_wild()
	check(fly != null and fly.wild and not fly.in_pen(), "a wild fly turns up outside the pen")
	await run_frames(5)
	if fly != null:
		fly.set_physics_process(false)
		await _aim_at(fly.global_position, Vector3(0.0, 0.6, 2.5))
		check(_hud.aimed_text().begins_with("Wild fly"), "the readout says what the cross is on: %s"
			% _hud.aimed_text())
		fly.set_physics_process(true)


func _check_disc() -> void:
	var disc := _spider.disc
	check(disc.open(), "Tab brings up the spell disc")
	check(disc.slices().size() == 7, "with every spell on it (%d)" % disc.slices().size())
	disc.close(false)
	check(_spider.spells.take(5) and _spider.spells.current().id == "fire", "5 takes fire breath in hand")


## Turns the spider to put the cross on [param point], from wherever it stands
## now, and lets the builder see it.
func _aim_at(point: Vector3, from := Vector3(0.0, 0.6, 4.0)) -> void:
	_spider.global_position = point + from
	_spider.velocity = Vector3.ZERO
	_spider.climb.stand_upright()
	_spider.view.settle()
	await run_frames(3)
	FarmRoom.aim(_spider, point)
	await process_frame
	_spider.builder._update()
