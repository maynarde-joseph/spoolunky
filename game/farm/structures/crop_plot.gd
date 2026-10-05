class_name CropPlot
extends FarmStructure

## A bed of something growing: a melon patch, a berry bush, a bed of herbs. It
## ripens on its own; F picks it into the bag when it is ripe, and it starts again.
##
## Melons and berries are what flies eat — the only way to fill a trough. Herbs
## season a fly at the prep table. A melon patch draws wild flies, too: there is
## nothing a fly likes better than fruit.

## What each kind grows: what it is called, what it is for, how many meals of feed
## it is, how long it takes to ripen, and its colours.
const CROPS := {
	"melon_patch": {"name": "Melon", "use": "feed", "meals": 6, "grow": 45.0,
		"leaf": "leaf", "fruit": "leaf_light"},
	"berry_bush": {"name": "Berries", "use": "feed", "meals": 3, "grow": 20.0,
		"leaf": "leaf_dark", "fruit": "petal_red"},
	"herb_bed": {"name": "Herbs", "use": "herb", "meals": 0, "grow": 30.0,
		"leaf": "leaf_light", "fruit": "leaf_dark"},
}

## How far it has to ripen, 0 just picked to 1 ripe.
var growth := 0.0

var _plants: Node3D


func crop() -> Dictionary:
	return CROPS.get(kind.id if kind != null else "", CROPS["melon_patch"])


func draw(on: Node3D, solid: bool) -> void:
	WorldKit.box(on, "Bed", Vector3(1.6, 0.14, 1.6), WorldKit.at(Vector3(0.0, 0.07, 0.0)), "soil", solid)
	for side: float in [-1.0, 1.0]:
		WorldKit.box(on, "EdgeX%s" % ("A" if side < 0.0 else "B"), Vector3(1.68, 0.18, 0.06),
			WorldKit.at(Vector3(0.0, 0.09, side * 0.8)), "wood_light", false)
		WorldKit.box(on, "EdgeZ%s" % ("A" if side < 0.0 else "B"), Vector3(0.06, 0.18, 1.6),
			WorldKit.at(Vector3(side * 0.8, 0.09, 0.0)), "wood_light", false)
	_plants = WorldKit.group(on, "Plants", WorldKit.at(Vector3(0.0, 0.14, 0.0)))
	var grows: Dictionary = crop()
	var id := kind.id if kind != null else ""
	var n := 0
	for row in 2:
		for column in 2:
			var at := Vector3((float(column) - 0.5) * 0.7, 0.0, (float(row) - 0.5) * 0.7)
			n += 1
			match id:
				"berry_bush":
					WorldKit.ball(_plants, "Bush%d" % n, Vector3(0.32, 0.36, 0.32), WorldKit.at(at + Vector3(0.0, 0.3, 0.0)),
						grows["leaf"], false)
					for b in 3:
						var turn := TAU * float(b) / 3.0 + float(n)
						WorldKit.ball(_plants, "Berry%d_%d" % [n, b], Vector3.ONE * 0.06,
							WorldKit.at(at + Vector3(cos(turn) * 0.27, 0.35 + 0.1 * float(b % 2), sin(turn) * 0.27)),
							grows["fruit"], false)
				"herb_bed":
					for b in 3:
						var turn := TAU * float(b) / 3.0 + float(n) * 0.7
						var foot := at + Vector3(cos(turn) * 0.1, 0.0, sin(turn) * 0.1)
						WorldKit.rod(_plants, "Sprig%d_%d" % [n, b], foot, foot + Vector3(cos(turn) * 0.08, 0.35, sin(turn) * 0.08),
							0.03, grows["fruit"] if b == 0 else grows["leaf"], false, -1.0, 6)
				_:
					WorldKit.ball(_plants, "Leaf%d" % n, Vector3(0.3, 0.06, 0.3), WorldKit.at(at + Vector3(0.12, 0.05, 0.1)),
						grows["leaf"], false)
					WorldKit.ball(_plants, "Melon%d" % n, Vector3(0.22, 0.18, 0.28), WorldKit.at(at + Vector3(0.0, 0.16, 0.0)),
						grows["fruit"], false)
	_show_growth()


func _physics_process(delta: float) -> void:
	if growth >= 1.0:
		return
	growth = minf(1.0, growth + delta / float(crop()["grow"]))
	_show_growth()


func is_ripe() -> bool:
	return growth >= 1.0


## Picks it, if it is ripe: what it grew. Null if it is not ripe yet.
func pick() -> Produce:
	if not is_ripe():
		return null
	growth = 0.0
	_show_growth()
	var grows := crop()
	return Produce.make(grows["name"], grows["use"], grows["meals"])


func _show_growth() -> void:
	if _plants != null:
		_plants.scale = Vector3.ONE * lerpf(0.2, 1.0, growth)


## A melon patch draws wild flies: rotting fruit.
func draws_flies() -> bool:
	return kind != null and kind.id == "melon_patch"


func reach_radius() -> float:
	return 0.8


func describe() -> String:
	if is_ripe():
		return "%s · ripe" % kind.display_name
	return "%s · %d%% ripe" % [kind.display_name, floori(growth * 100.0)]


func interact_hint(_spider: SpiderPlayer) -> String:
	return "F — pick the %s" % String(crop()["name"]).to_lower() if is_ripe() else ""


func interact(spider: SpiderPlayer) -> bool:
	if spider == null:
		return false
	if not is_ripe():
		spider.notify("%s — not ripe yet (%d%%)" % [kind.display_name, floori(growth * 100.0)])
		return false
	if spider.bag.is_full():
		spider.notify("Your bag is full")
		return false
	var picked := pick()
	spider.bag.add_produce(picked)
	spider.notify("Picked %s" % picked.label())
	return true
