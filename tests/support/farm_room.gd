class_name FarmRoom
extends RefCounted

## Somewhere for a check to run: a flat floor a long way across, a small [Farm] on
## it, and — if asked — the spider, with its keys read whether or not the mouse is
## caught, since a headless run can never catch it. Built in code so nothing the
## game's own farm has stands in the way of what a check is asking.

## How many cells a side the farm is, and how wide each is.
const CELLS := 12
const CELL := 2.0


## The room: a floor, a farm with [param coins] to spend, and the spider at
## [param start] if [param with_spider].
static func make(with_spider := true, start := Vector3(0.0, 0.6, 9.0), coins := 1000) -> Node3D:
	var room := Node3D.new()
	room.name = "Room"
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = GameLayers.WORLD
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(400.0, 1.0, 400.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	room.add_child(floor_body)
	var farm := Farm.new()
	farm.name = "Farm"
	farm.cells = CELLS
	farm.cell_size = CELL
	farm.coins = coins
	# A check builds what it needs: no starter pen, and no wild flies turning up in
	# the middle of it.
	farm.starter = false
	farm.wild_flies = false
	room.add_child(farm)
	if with_spider:
		var spider := (load("res://game/player/spider.tscn") as PackedScene).instantiate() as SpiderPlayer
		spider.name = "Player"
		spider.require_captured_mouse = false
		spider.position = start
		room.add_child(spider)
	return room


static func farm_of(room: Node) -> Farm:
	return room.get_node("Farm") as Farm


static func spider_of(room: Node) -> SpiderPlayer:
	return room.get_node_or_null("Player") as SpiderPlayer


## Turns the spider's view so the cross is on [param point].
static func aim(spider: SpiderPlayer, point: Vector3) -> void:
	var view := spider.view
	view.update(spider.body_height, spider.climb.view_up())
	var pivot := view.aim_pivot()
	var toward := point - pivot
	var flat := Vector2(toward.x, toward.z).length()
	view.yaw = atan2(-toward.x, -toward.z)
	view.pitch = atan2(toward.y, flat)
	view.update(spider.body_height, spider.climb.view_up())


## A pen of [param from] to [param to] corners with a gate, a trough and a pond in
## it. Returns the region it makes.
static func pen(farm: Farm, from: Vector2i, to: Vector2i) -> int:
	farm.build_run(Catalogue.structure("fence"), from, to)
	farm.build(Catalogue.structure("trough"), from)
	farm.build(Catalogue.structure("pond"), to - Vector2i(2, 2))
	return farm.grid.region_id(from + Vector2i(1, 1))
