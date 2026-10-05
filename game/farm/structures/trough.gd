class_name Trough
extends FarmStructure

## Rotting fruit for the pen it stands in. Every fly in the pen eats here, a
## portion a meal, and it fills itself back up a portion at a time — so a trough
## keeps a few flies fed and a crowd of them hungry.

## How many meals it holds, and how long it takes to put one back, in seconds.
const PORTIONS := 6
const REFILL := 10.0

var portions := PORTIONS

var _refill_left := REFILL
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


func _physics_process(delta: float) -> void:
	if portions >= PORTIONS:
		_refill_left = REFILL
		return
	_refill_left -= delta
	if _refill_left <= 0.0:
		_refill_left = REFILL
		portions += 1
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


func describe() -> String:
	return "Fruit trough · %d of %d meals" % [portions, PORTIONS]
