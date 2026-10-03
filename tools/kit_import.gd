@tool
extends EditorScenePostImport

## Turns each piece of the kit in `Pieces/` into something the spider can stand on.
##
## The pieces come out of their files wherever they sat in the scene they were
## exported from — a wall eleven metres east of the origin, a coin ten — and with
## nothing to collide with. This puts each one's footprint centred on its origin
## with its base on the ground, so a piece dropped at a point stands on that point,
## and makes it a body on the world layer with a collider the shape of its mesh:
## everything you can see you can walk on and stick silk to.
##
## Every `.fbx.import` in the folder names this script, and so does the project's
## default for scenes, so a piece added later comes in the same way. Anything
## imported from anywhere else comes through untouched.

const DIR := "res://Pieces/"


func _post_import(scene: Node) -> Object:
	if not get_source_file().begins_with(DIR):
		return scene
	var views: Array[MeshInstance3D] = []
	_views_under(scene, views)
	if views.is_empty():
		return scene

	var placed := {}
	var bounds := AABB()
	for i in views.size():
		var where := _to_root(views[i], scene)
		placed[views[i]] = where
		var box := where * views[i].mesh.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	var base := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)

	var body := StaticBody3D.new()
	body.name = scene.name
	body.collision_layer = GameLayers.WORLD
	body.collision_mask = 0
	for view in views:
		var where: Transform3D = Transform3D(Basis.IDENTITY, -base) * placed[view]
		view.get_parent().remove_child(view)
		view.transform = where
		body.add_child(view)
		view.owner = body
		var shape := view.mesh.create_trimesh_shape()
		# A piece that is a sheet — a floor tile, a wall with no back, a corner made
		# of planes — has a back you can walk into, so it has to stop you from both
		# faces. A closed one only ever meets you from the front.
		shape.backface_collision = Kit.is_open(view.mesh)
		var solid := CollisionShape3D.new()
		solid.name = String(view.name) + "Shape"
		solid.shape = shape
		solid.transform = where
		body.add_child(solid)
		solid.owner = body
	scene.free()
	return body


func _views_under(node: Node, found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		var view := child as MeshInstance3D
		if view != null and view.mesh != null:
			found.append(view)
		_views_under(child, found)


## Where [param node] is relative to [param root], through every parent between.
func _to_root(node: Node3D, root: Node) -> Transform3D:
	var where := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != root:
		if at is Node3D:
			where = (at as Node3D).transform * where
		at = at.get_parent()
	return where
