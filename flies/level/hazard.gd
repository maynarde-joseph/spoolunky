class_name Hazard
extends Area3D

## Something you must not touch. Touch it and the level starts again.

var size := Vector3(4.0, 0.4, 4.0)


func _ready() -> void:
	collision_layer = 0
	collision_mask = GameLayers.PLAYER
	monitoring = true
	var view := MeshInstance3D.new()
	view.name = "View"
	var box := BoxMesh.new()
	box.size = size
	view.mesh = box
	view.position.y = size.y * 0.5
	view.material_override = Surfaces.paint("hazard")
	add_child(view)
	var shape := BoxShape3D.new()
	shape.size = size
	var volume := CollisionShape3D.new()
	volume.shape = shape
	volume.position.y = size.y * 0.5
	add_child(volume)
	body_entered.connect(_on_body_entered)


func _on_body_entered(found: Node3D) -> void:
	if found is Weaver:
		var run := LevelRun.current(self)
		if run != null:
			run.lose("Touched the red")
