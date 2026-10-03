@tool
class_name KitBlock
extends StaticBody3D

## A solid of any size in the look of one of the kit's pieces: that piece's mesh
## stretched to fit, and a box to collide with.
##
## For the bulk of a building. The kit is built on a wall four metres long, and a
## tier of seating forty metres long and twelve high would be thirty of them —
## this is one node, and changing its size in the inspector changes the tier. The
## look is the piece's own, so the bulk takes the kit's colours with the rest of it.

## Which piece in `Pieces/` to stretch, by file name.
@export var piece := "wall":
	set(value):
		piece = value
		_fit()

## How big it is, in metres. It stands on its origin, centred across it.
@export var size := Vector3(4.0, 4.0, 4.0):
	set(value):
		size = value
		_fit()

var _view: MeshInstance3D = null
var _solid: CollisionShape3D = null


func _init() -> void:
	collision_layer = GameLayers.WORLD
	collision_mask = 0


func _ready() -> void:
	_fit()


func _fit() -> void:
	if not is_inside_tree():
		return
	if _view == null:
		_view = MeshInstance3D.new()
		_view.name = "View"
		add_child(_view, false, INTERNAL_MODE_FRONT)
		_solid = CollisionShape3D.new()
		_solid.name = "Solid"
		_solid.shape = BoxShape3D.new()
		add_child(_solid, false, INTERNAL_MODE_FRONT)
	(_solid.shape as BoxShape3D).size = size
	_solid.position = Vector3(0.0, size.y * 0.5, 0.0)
	var look := Kit.look_of(piece)
	if look.is_empty():
		_view.mesh = null
		return
	var native: Vector3 = look["size"]
	# A side the piece has no depth on — a floor tile — stays as thin as it was.
	var stretch := Vector3(
		size.x / native.x if native.x > 0.001 else 1.0,
		size.y / native.y if native.y > 0.001 else 1.0,
		size.z / native.z if native.z > 0.001 else 1.0)
	_view.mesh = look["mesh"]
	_view.transform = Transform3D(Basis.from_scale(stretch), Vector3.ZERO) * (look["where"] as Transform3D)
