@tool
class_name KitBlock
extends StaticBody3D

## One of the kit's pieces at any size: its mesh stretched to fit, and a collider
## of the same stretched shape — a doorway made three times as tall is still a
## doorway you can walk through, and a wall made forty metres long is one node.
##
## For anything the kit does not have at the size a building wants: the bulk of a
## tier of seating, a pier as tall as a cathedral's, a tower a column's shape but
## ten times its width. A piece placed as it is stays an instance of its own file;
## a block is for the ones that are not. Change its size in the inspector and it
## follows, and since the look is the piece's own it takes the kit's colours with
## the rest of it.
##
## Nothing is scaled. Physics does not like a stretched body, so the block stays at
## scale one and its collider is built from the stretched faces instead.

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


## A block of [param piece], [param block_size] big, under [param parent] at
## [param where].
static func make(parent: Node, part_name: String, look: String, block_size: Vector3,
		where: Transform3D) -> KitBlock:
	var block := KitBlock.new()
	block.name = part_name
	block.piece = look
	block.size = block_size
	block.transform = where
	parent.add_child(block, true)
	return block


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
		add_child(_solid, false, INTERNAL_MODE_FRONT)
	var look := Kit.look_of(piece)
	if look.is_empty():
		_view.mesh = null
		_solid.shape = null
		return
	var native: Vector3 = look["size"]
	# A side the piece has no depth on — a floor tile — stays as thin as it was.
	var stretch := Vector3(
		size.x / native.x if native.x > 0.001 else 1.0,
		size.y / native.y if native.y > 0.001 else 1.0,
		size.z / native.z if native.z > 0.001 else 1.0)
	var mesh: Mesh = look["mesh"]
	var where := Transform3D(Basis.from_scale(stretch), Vector3.ZERO) * (look["where"] as Transform3D)
	_view.mesh = mesh
	_view.transform = where
	var faces := mesh.get_faces()
	for i in faces.size():
		faces[i] = where * faces[i]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = look["open"]
	_solid.shape = shape
