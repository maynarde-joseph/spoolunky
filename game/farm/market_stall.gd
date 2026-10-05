class_name MarketStall
extends StaticBody3D

## Where the farm's dishes are sold: a stall at the gate, with a striped awning to
## find it by. F at the counter sells everything in the bag.
##
## It stands off the land, by the road, so nothing built can take its place —
## there has to be somewhere to sell from before there is anything to sell.

const GROUP := "market"


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	add_to_group(GROUP)
	if get_child_count() == 0:
		draw(self)


## The stall, built facing -Z: a counter, four posts, a striped awning, a sign, and
## crates of what it sells.
static func draw(on: Node3D) -> void:
	var width := 3.4
	var depth := 1.6
	WorldKit.box(on, "Counter", Vector3(width, 1.0, 0.7), WorldKit.at(Vector3(0.0, 0.5, -depth * 0.5 + 0.35)),
		"wood_light", true)
	WorldKit.box(on, "CounterTop", Vector3(width + 0.1, 0.06, 0.8),
		WorldKit.at(Vector3(0.0, 1.03, -depth * 0.5 + 0.35)), "wood_dark", false)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var tall := 2.5 if z < 0.0 else 2.9
			WorldKit.box(on, "Post%s%s" % ["W" if x < 0.0 else "E", "N" if z < 0.0 else "S"],
				Vector3(0.12, tall, 0.12), WorldKit.at(Vector3(x * width * 0.5, tall * 0.5, z * depth * 0.5)),
				"wood_dark", true)
	# The awning, in stripes, sloping down to the front.
	var stripes := 8
	var slope := atan2(0.4, depth)
	for i in stripes:
		var x := -width * 0.5 + width * (float(i) + 0.5) / float(stripes)
		WorldKit.box(on, "Stripe%d" % (i + 1), Vector3(width / float(stripes), 0.05, depth + 0.5),
			Transform3D(Basis(Vector3.RIGHT, slope), Vector3(x, 2.72, 0.0)),
			"canvas_red" if i % 2 == 0 else "canvas_cream", i == 0)
	WorldKit.box(on, "Sign", Vector3(1.8, 0.5, 0.06), WorldKit.at(Vector3(0.0, 3.25, depth * 0.5 + 0.05)),
		"canvas_cream", false)
	WorldKit.box(on, "SignBoard", Vector3(1.9, 0.6, 0.04), WorldKit.at(Vector3(0.0, 3.25, depth * 0.5 + 0.09)),
		"wood_dark", false)
	for i in 3:
		var at := Vector3(-1.1 + 1.1 * float(i), 0.25, depth * 0.5 + 0.55 + 0.1 * float(i % 2))
		WorldKit.box(on, "Crate%d" % (i + 1), Vector3(0.5, 0.5, 0.5), WorldKit.at(at, 12.0 * float(i)),
			"wood_light", true)
		WorldKit.ball(on, "Goods%d" % (i + 1), Vector3(0.2, 0.12, 0.2), WorldKit.at(at + Vector3(0.0, 0.3, 0.0)),
			["grain", "petal_red", "leaf_light"][i], false)


func describe(spider: SpiderPlayer = null) -> String:
	if spider == null or spider.bag.is_empty():
		return "Market · bring dishes to sell"
	return "Market · %d dish%s for %d coins" % [spider.bag.count(),
		"" if spider.bag.count() == 1 else "es", spider.bag.total_value()]


func interact_hint(spider: SpiderPlayer) -> String:
	if spider == null or spider.bag.is_empty():
		return ""
	return "F — sell %d dish%s for %d" % [spider.bag.count(),
		"" if spider.bag.count() == 1 else "es", spider.bag.total_value()]


## Sells everything in [param spider]'s bag. Returns whether anything sold.
func interact(spider: SpiderPlayer) -> bool:
	if spider == null:
		return false
	if spider.bag.is_empty():
		if spider.tether.is_towing():
			spider.notify("The market buys dishes — put that on a prep table and cook it")
		else:
			spider.notify("Nothing to sell — cook something and bring it here")
		return false
	var sold := spider.bag.count()
	var paid := sell(spider.bag)
	spider.notify("Sold %d dish%s for %d coins" % [sold, "" if sold == 1 else "es", paid])
	return true


## Sells everything in [param bag] to the farm this stall is at. Returns what it
## paid.
func sell(bag: SpiderInventory) -> int:
	var paid := 0
	for dish in bag.take_all():
		paid += dish.value()
	var farm := Farm.of(self)
	if farm != null:
		farm.earn(paid)
	return paid
