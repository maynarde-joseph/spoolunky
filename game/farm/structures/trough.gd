class_name Trough
extends FarmStructure

## Fruit for the pen it stands in. Every fly in the pen eats here, a meal at a time,
## and it does not fill itself: F with fruit in the bag tips it in — a melon is six
## meals, berries three. Grow the fruit, or the flies go hungry. It draws wild flies
## in, too.

## How many meals it holds, and how many it is built with.
const PORTIONS := 12
const BUILT_WITH := 6

var portions := BUILT_WITH

var _grain: MeshInstance3D


func draw(on: Node3D, solid: bool) -> void:
	var size := Vector3(1.3, 0.42, 0.62)
	WorldKit.box(on, "Base", Vector3(size.x, 0.08, size.z), WorldKit.at(Vector3(0.0, 0.04, 0.0)),
		"wood_dark", false)
	for side: float in [-1.0, 1.0]:
		WorldKit.box(on, "Side%s" % ("A" if side < 0.0 else "B"), Vector3(size.x, size.y, 0.06),
			WorldKit.at(Vector3(0.0, size.y * 0.5, side * (size.z * 0.5 - 0.03))), "wood_light", false)
		WorldKit.box(on, "End%s" % ("A" if side < 0.0 else "B"), Vector3(0.06, size.y, size.z - 0.12),
			WorldKit.at(Vector3(side * (size.x * 0.5 - 0.03), size.y * 0.5, 0.0)), "wood_light", false)
	_grain = WorldKit.box(on, "Feed", Vector3(size.x - 0.12, 1.0, size.z - 0.12),
		WorldKit.at(Vector3.ZERO), "fruit_mash", false)
	if solid:
		var box := BoxShape3D.new()
		box.size = size
		var shape := CollisionShape3D.new()
		shape.name = "Solid"
		shape.shape = box
		shape.position = Vector3(0.0, size.y * 0.5, 0.0)
		on.add_child(shape)
	_show_fill()


func has_food_for(_insect: Insect) -> bool:
	return portions > 0


func feed(_insect: Insect) -> bool:
	if portions <= 0:
		return false
	portions -= 1
	_show_fill()
	return true


## The feed in it, as deep as what is left.
func _show_fill() -> void:
	if _grain == null:
		return
	var depth := 0.02 + 0.3 * float(portions) / float(PORTIONS)
	_grain.scale = Vector3(1.0, depth, 1.0)
	_grain.position.y = 0.08 + depth * 0.5


## Tips [param meals] of fruit in, up to what it holds. Returns how many went in.
func add_feed(meals: int) -> int:
	var went := clampi(meals, 0, PORTIONS - portions)
	portions += went
	_show_fill()
	return went


func describe() -> String:
	return "Fruit trough · %d of %d meals" % [portions, PORTIONS]


func interact_hint(spider: SpiderPlayer) -> String:
	if spider == null or spider.bag.count_produce("feed") == 0:
		return ""
	return "F — tip fruit in" if portions < PORTIONS else ""


func interact(spider: SpiderPlayer) -> bool:
	if spider == null:
		return false
	if portions >= PORTIONS:
		spider.notify("The trough is full")
		return false
	var fruit := spider.bag.take_produce("feed")
	if fruit == null:
		spider.notify("No fruit in the bag — grow melons or berries to fill the trough")
		return false
	var went := add_feed(fruit.meals)
	spider.notify("%s in the trough — %d meals" % [fruit.display_name, portions])
	return went > 0


func draws_flies() -> bool:
	return true
