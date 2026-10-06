class_name PieceLook
extends RefCounted

## Dresses a body as one of the kit's pieces in `Pieces/`, stretched to any size:
## the piece's mesh stretched to fit, painted as its surface, and a collider of
## the same shape. What [KitBlock] does, for bodies that are not KitBlocks — the
## level's still pieces, and the platforms and doors that move.
##
## Nothing is scaled: physics does not like a stretched body, so the faces are
## stretched instead.

## The natural size of [param piece], or a 2 m cube for a piece there is not.
static func size_of(piece: String) -> Vector3:
	var look := Kit.look_of(piece)
	if look.is_empty():
		return Vector3(2.0, 2.0, 2.0)
	return look["size"]


## Adds the look of [param piece] at [param size] to [param body], painted as
## [param surface]. A moving body collides as a box the size of the piece, since
## a mesh collider is for things that stay put; a still one collides as the
## piece's own stretched faces. Returns the view.
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
	if moving:
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
