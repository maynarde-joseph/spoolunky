class_name PrepTable
extends FarmStructure

## Where a catch is made into a dish.
##
## The kitchen spells work on a bundle wherever it lies, but the table holds one
## still and in one place while you work, seasons it — F with herbs in the bag —
## and plates it: F takes what is on it off as a dish.
## Drag a bundle up to it and the bundle is put down on top and stays there: the
## line comes off, and every kitchen spell cast at the table — or at the bundle on
## it — is a step done to it (see [Prep]). F takes what is on it off as a [Dish],
## into the bag. Pressed with a bundle on your line, F puts the bundle on the table.

## How near a bundle has to come, across the ground, to be taken onto the table.
const DOCK := 1.6

## How high the top is, in metres.
const TOP := 0.85

## The bundle on it, if there is one.
var bundle: Insect = null


func draw(on: Node3D, solid: bool) -> void:
	var top := Vector3(1.5, 0.08, 1.0)
	WorldKit.box(on, "Top", top, WorldKit.at(Vector3(0.0, TOP - top.y * 0.5, 0.0)), "wood_light",
		solid)
	WorldKit.box(on, "Board", Vector3(0.95, 0.04, 0.62), WorldKit.at(Vector3(0.0, TOP + 0.02, 0.0)),
		"stone_dark", false)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			WorldKit.box(on, "Leg%s%s" % ["W" if x < 0.0 else "E", "N" if z < 0.0 else "S"],
				Vector3(0.09, TOP - top.y, 0.09),
				WorldKit.at(Vector3(x * (top.x * 0.5 - 0.08), (TOP - top.y) * 0.5, z * (top.z * 0.5 - 0.08))),
				"wood_dark", solid)
	# A shelf of jars and a pot under it, so it reads as a kitchen from across a pen.
	WorldKit.box(on, "Shelf", Vector3(top.x - 0.2, 0.04, top.z - 0.2), WorldKit.at(Vector3(0.0, 0.25, 0.0)),
		"wood_dark", false)
	WorldKit.cylinder(on, "Pot", 0.17, 0.22, WorldKit.at(Vector3(-0.35, 0.38, 0.0)), "black", false)
	for i in 3:
		WorldKit.cylinder(on, "Jar%d" % (i + 1), 0.06, 0.14,
			WorldKit.at(Vector3(0.12 + 0.17 * float(i), 0.34, 0.12)),
			["yellow", "petal_red", "leaf_light"][i], false, -1.0, 10)


func _physics_process(_delta: float) -> void:
	if bundle != null and (not is_instance_valid(bundle) or bundle.is_queued_for_deletion()
			or bundle.table != self):
		bundle = null
	if bundle == null:
		_take_nearby()


## Where a bundle lies on it, in the world: the middle of the top.
func hold_point() -> Vector3:
	return global_position + Vector3(0.0, TOP + 0.04, 0.0)


## Takes onto the table any bundle near enough, if it is free.
func _take_nearby() -> void:
	for node in get_tree().get_nodes_in_group(Insect.GROUP):
		var insect := node as Insect
		if insect == null or not insect.is_bundle() or insect.table != null \
				or insect.is_queued_for_deletion():
			continue
		var gap := Vector2(insect.global_position.x - global_position.x,
			insect.global_position.z - global_position.z)
		if gap.length() <= DOCK and absf(insect.global_position.y - global_position.y) < 2.5:
			take_on(insect)
			return


## Puts [param insect] on the table. False if something is on it already, or it is
## not a bundle.
func take_on(insect: Insect) -> bool:
	if bundle != null or insect == null or not insect.is_bundle():
		return false
	bundle = insect
	insect.dock(self)
	if farm != null:
		farm.notice.emit("The %s is on the table — cast at it to prepare it" \
			% insect.kind.display_name.to_lower())
	return true


## Does [param step] to what is on the table. Returns why it could not, or nothing
## if it was done.
func apply(step: int) -> String:
	if bundle == null:
		return "Nothing on the table — drag a bundle onto it"
	return bundle.apply(step)


func reach_radius() -> float:
	return 0.75


func describe() -> String:
	if bundle == null:
		return "Prep table · empty"
	var dish := bundle.as_dish()
	var next := Prep.next_text(bundle.steps)
	return "Prep table · %s (%d)%s" % [dish.label(), dish.value(),
		"" if next.is_empty() else " · next: " + next]


func interact_hint(spider: SpiderPlayer) -> String:
	if bundle != null:
		if spider != null and spider.bag.count_produce("herb") > 0 \
				and Prep.can_do(bundle.steps, Prep.Step.SEASON):
			return "F — season it with herbs"
		var dish := bundle.as_dish()
		return "F — take the %s (%d)" % [dish.title(), dish.value()]
	if spider != null and spider.tether.is_towing():
		return "F — put the bundle on the table"
	return ""


func interact(spider: SpiderPlayer) -> bool:
	if spider == null:
		return false
	if bundle == null:
		if not spider.tether.is_towing():
			spider.notify("Nothing on the table — drag a bundle onto it")
			return false
		var towed := spider.tether.cargo as Insect
		spider.tether.cut()
		return take_on(towed)
	if spider.bag.count_produce("herb") > 0 and Prep.can_do(bundle.steps, Prep.Step.SEASON):
		spider.bag.take_produce("herb")
		bundle.apply(Prep.Step.SEASON)
		spider.notify("Seasoned with herbs — %s" % bundle.as_dish().label())
		return true
	if spider.bag.is_full():
		spider.notify("Your bag is full — sell what is in it at the market")
		return false
	var dish := bundle.take()
	bundle = null
	spider.bag.add(dish)
	spider.notify("%s — %d coins at market" % [dish.label(), dish.value()])
	return true


func taken_down() -> void:
	if bundle != null and is_instance_valid(bundle):
		bundle.undock()
	bundle = null
