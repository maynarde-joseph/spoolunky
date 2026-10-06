class_name PieceLook
extends RefCounted

## Dresses a body as one of the kit's pieces in `Pieces/`, stretched to any size:
## the piece's mesh stretched to fit, painted as its surface, and a collider of
## the same shape — for the level's still pieces, and for the platforms and doors
## that move.
##
## Nothing is scaled: physics does not like a stretched body, so the faces are
## stretched instead.

## Whether [param piece] is a plain box, which collides as one: a box is solid all
## through, where a mesh collider is only its skin, and "is there room to stand
## here" needs to know about the inside of a block as well as its faces.
static func is_box(piece: String) -> bool:
	return piece == "box" or piece.begins_with("cube")


## The natural size of [param piece], or a 2 m cube for a piece there is not.
static func size_of(piece: String) -> Vector3:
	var look := Kit.look_of(piece)
	if look.is_empty():
		return Vector3(2.0, 2.0, 2.0)
	return look["size"]


## Adds the look of [param piece] at [param size] to [param body], painted as
## [param surface]. A moving body, or a plain box, collides as a box the size of
## the piece — a mesh collider is for things that stay put, and is only a skin;
## anything else collides as the piece's own stretched faces. Returns the view.
static func dress(body: CollisionObject3D, piece: String, size: Vector3, surface: String,
		moving := false) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = "View"
	body.add_child(view)
	var solid := CollisionShape3D.new()
	solid.name = "Solid"
	body.add_child(solid)
	var look := Kit.look_of(piece)
	if look.is_empty():
		var box := BoxMesh.new()
		box.size = size
		view.mesh = box
		view.position.y = size.y * 0.5
		var shape := BoxShape3D.new()
		shape.size = size
		solid.shape = shape
		solid.position.y = size.y * 0.5
		Surfaces.apply(body, view, surface)
		return view
	var native: Vector3 = look["size"]
	var stretch := Vector3(
		size.x / native.x if native.x > 0.001 else 1.0,
		size.y / native.y if native.y > 0.001 else 1.0,
		size.z / native.z if native.z > 0.001 else 1.0)
	var mesh: Mesh = look["mesh"]
	var where := Transform3D(Basis.from_scale(stretch), Vector3.ZERO) * (look["where"] as Transform3D)
	view.mesh = mesh
	view.transform = where
	if moving or is_box(piece):
		var shape := BoxShape3D.new()
		shape.size = Vector3(maxf(size.x, 0.05), maxf(size.y, 0.05), maxf(size.z, 0.05))
		solid.shape = shape
		solid.position.y = size.y * 0.5
	else:
		var faces := mesh.get_faces()
		for i in faces.size():
			faces[i] = where * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = look["open"]
		solid.shape = shape
	Surfaces.apply(body, view, surface)
	return view
