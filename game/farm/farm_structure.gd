class_name FarmStructure
extends StaticBody3D

## Something built on the farm.
##
## Each one is a solid body on the world layer — the spider can climb it, an
## insect cannot walk through it — drawn from the same flat-painted shapes as the
## rest of the world (see [WorldKit]). What it is comes from its [StructureKind];
## what it does is the subclass for that kind, made by [method make]. Some stand on
## a patch of cells and serve the pen they are in — a trough, a pond — and some
## stand on an edge between cells and make the pens — a fence, a gate.
##
## An insect asks the structures in its pen for what it needs: food
## ([method has_food_for], [method feed]), water ([method water]), and where to
## stand to get it ([method approach_from], [method reached_by]).

const GROUP := "structures"

var kind: StructureKind
var farm: Farm

## The edge it stands on, for a fence or a gate; (-1, -1, -1) for anything else.
var edge := Vector3i(-1, -1, -1)

## The cells it stands on, for anything not on an edge.
var cells: Array[Vector2i] = []

## How many quarter turns it was put down at.
var quarter := 0

## What it cost, for what comes back when it is taken down.
var paid := 0


## A new structure of [param of_kind], not yet put anywhere.
static func make(of_kind: StructureKind) -> FarmStructure:
	var made: FarmStructure
	match of_kind.id if of_kind != null else "":
		"fence", "gate":
			made = Fence.new()
		"trough":
			made = Trough.new()
		"pond":
			made = Pond.new()
		"sugar_bowl":
			made = SugarBowl.new()
		"shade_tree":
			made = ShadeTree.new()
		"compost_heap":
			made = CompostHeap.new()
		"melon_patch", "berry_bush", "herb_bed":
			made = CropPlot.new()
		"prep_table":
			made = PrepTable.new()
		_:
			made = FarmStructure.new()
	made.kind = of_kind
	if of_kind != null:
		made.name = of_kind.display_name.replace(" ", "")
		if made is Fence:
			(made as Fence).is_gate = of_kind.id == "gate"
	return made


## What [param of_kind] looks like, and nothing else: no colliders, nothing that
## runs. For showing where something will go before it does.
static func preview(of_kind: StructureKind) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Preview"
	var maker := make(of_kind)
	maker.draw(holder, false)
	maker.free()
	return holder


func _ready() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0
	add_to_group(GROUP)
	if get_child_count() == 0:
		draw(self, true)


## Builds what it looks like onto [param on]: the shapes, and with
## [param solid] a collider for each. Drawn standing on the origin, as long as its
## footprint, facing -Z; the farm turns and moves it into place.
func draw(_on: Node3D, _solid: bool) -> void:
	pass


## Whether it stands on an edge between cells, as a fence or a gate does.
func is_on_edge() -> bool:
	return edge.x >= 0


## Whether an insect can get past it. Nothing built can, but an open gate.
func lets_through() -> bool:
	return false


## The region of the farm it stands on: the pen it serves. -1 for something on an
## edge, which is between two.
func region() -> int:
	if farm == null or cells.is_empty():
		return -1
	return farm.grid.region_id(cells[0])


## How far out from its middle its sides are, as near as matters, in metres: what
## an insect comes up against when it comes to it.
func reach_radius() -> float:
	if kind == null or farm == null:
		return 0.6
	var span := maxi(kind.footprint.x, kind.footprint.y)
	return float(span) * farm.grid.cell * 0.36


## Where an insect coming from [param from] stands to be at it: just outside it,
## on the near side, [param gap] further out for the insect's own size.
func approach_from(from: Vector3, gap: float) -> Vector3:
	var middle := global_position
	var out := Vector3(from.x - middle.x, 0.0, from.z - middle.z)
	if out.length_squared() < 0.0001:
		out = Vector3.BACK
	return middle + out.normalized() * (reach_radius() + gap * Insect.HITBOX_SCALE + 0.05)


## Whether [param insect] is up against it, near enough to eat or drink.
func reached_by(insect: Insect) -> bool:
	var middle := global_position
	var gap := Vector2(insect.global_position.x - middle.x, insect.global_position.z - middle.z)
	return gap.length() <= reach_radius() + insect.radius() * Insect.HITBOX_SCALE + 0.35


## Whether there is anything here for [param insect] to eat, right now.
func has_food_for(_insect: Insect) -> bool:
	return false


## [param insect] eats here. Returns whether there was anything for it.
func feed(_insect: Insect) -> bool:
	return false


## Whether it draws wild flies in to the farm.
func draws_flies() -> bool:
	return false


func has_water() -> bool:
	return false


## [param insect] drinks here. Returns whether there was anything for it.
func water(_insect: Insect) -> bool:
	return false


## A line about it for the readout under the cross.
func describe() -> String:
	return kind.display_name if kind != null else "Something built"


## What F does to it, for the readout — or nothing, if F does nothing to it.
func interact_hint(_spider: SpiderPlayer) -> String:
	return ""


## F, pressed on it. Returns whether anything happened.
func interact(_spider: SpiderPlayer) -> bool:
	return false


## Told it is coming down, just before it goes.
func taken_down() -> void:
	pass


## The cell size of the farm it stands on, or the usual two metres before it is on
## one.
func _cell() -> float:
	return farm.grid.cell if farm != null else 2.0
