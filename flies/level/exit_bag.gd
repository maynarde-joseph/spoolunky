class_name ExitBag
extends Node3D

## The way out: a sack of silk hanging in a gold ring. Walk into it and the level is
## done. It can be shut — dim, and the ring red — though nothing shuts it now.

signal entered()

var open := false

var _ring_paint: StandardMaterial3D
var _sense: Area3D
var _light: OmniLight3D
var _sack: MeshInstance3D
var _clock := 0.0


func _ready() -> void:
	var stand := MeshInstance3D.new()
	stand.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.3
	torus.rings = 32
	torus.ring_segments = 12
	stand.mesh = torus
	stand.rotation.x = PI * 0.5
	stand.position.y = 1.4
	_ring_paint = StandardMaterial3D.new()
	_ring_paint.albedo_color = Color(0.8, 0.25, 0.2)
	_ring_paint.emission_enabled = true
	_ring_paint.emission = Color(0.9, 0.2, 0.15)
	_ring_paint.emission_energy_multiplier = 0.8
	stand.material_override = _ring_paint
	add_child(stand)

	_sack = MeshInstance3D.new()
	_sack.name = "Sack"
	var sack := SphereMesh.new()
	sack.radius = 0.5
	sack.height = 1.3
	_sack.mesh = sack
	_sack.position.y = 1.35
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(0.95, 0.95, 0.98, 0.85)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	silk.roughness = 0.6
	silk.emission_enabled = true
	silk.emission = Color(0.85, 0.88, 1.0)
	silk.emission_energy_multiplier = 0.3
	_sack.material_override = silk
	add_child(_sack)

	var base := MeshInstance3D.new()
	base.name = "Base"
	var foot := CylinderMesh.new()
	foot.top_radius = 1.2
	foot.bottom_radius = 1.35
	foot.height = 0.12
	base.mesh = foot
	base.position.y = 0.06
	base.material_override = Surfaces.paint("accent")
	add_child(base)

	_light = OmniLight3D.new()
	_light.position.y = 1.4
	_light.omni_range = 5.0
	_light.light_color = Color(1.0, 0.4, 0.3)
	_light.light_energy = 0.6
	add_child(_light)

	_sense = Area3D.new()
	_sense.name = "Sense"
	_sense.collision_layer = 0
	_sense.collision_mask = GameLayers.PLAYER
	var shape := CylinderShape3D.new()
	shape.radius = 1.2
	shape.height = 2.8
	var volume := CollisionShape3D.new()
	volume.shape = shape
	volume.position.y = 1.4
	_sense.add_child(volume)
	add_child(_sense)
	_sense.body_entered.connect(_on_body_entered)


func set_open(value: bool) -> void:
	open = value
	var tint := Color(1.0, 0.78, 0.25) if open else Color(0.9, 0.2, 0.15)
	_ring_paint.albedo_color = tint
	_ring_paint.emission = tint
	_ring_paint.emission_energy_multiplier = 2.0 if open else 0.8
	_light.light_color = tint
	_light.light_energy = 1.6 if open else 0.6


func _process(delta: float) -> void:
	_clock += delta
	_sack.position.y = 1.35 + sin(_clock * 1.6) * 0.05
	_sack.rotation.y += delta * (0.8 if open else 0.2)


## Whether the spider is standing in it now.
func holds(weaver: Node3D) -> bool:
	return _sense.overlaps_body(weaver)


func _on_body_entered(found: Node3D) -> void:
	if found is Weaver:
		entered.emit()
