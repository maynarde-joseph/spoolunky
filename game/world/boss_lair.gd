class_name BossLair
extends Node3D

## A boss's room: the way in shuts behind you while its keeper lives, and opens for
## good once it is beaten.
##
## A lair is somewhere you can look into and scout before you commit — its doorways
## stand open until you are over the threshold with the keeper alive. Then a veil
## of old silk drops across every way in and the fight is the only way out.
## Driven off, you wake at a shrine with the veils up and the keeper back at its
## post, as though you never came; silk you strung in there is still there. Beat
## it, and the veils are gone for good, the way on is open, and what it was
## keeping is yours.

signal sealed(lair: BossLair)
signal won(lair: BossLair)

@export var display_name := "Lair"

## The room, in world space. Stepping inside it with the keeper alive seals it.
@export var bounds := AABB()

## What the spider takes when the keeper is beaten: a trait, by id. Empty for
## nothing but the way on.
@export var reward_trait := ""

## Whether the keeper has been beaten here.
@export var beaten := false

const VEIL := Color(0.86, 0.86, 0.9, 0.45)

var keeper: HostileSpawn = null
var _veils: Array[StaticBody3D] = []
var _sealed := false


## One whose room runs from [param lo] to [param hi], kept by a [param species_id]
## standing at [param keeper_at]; all in world space.
static func make(parent: Node3D, lair_name: String, lo: Vector3, hi: Vector3,
		species_id: String, keeper_at: Vector3, reward := "") -> BossLair:
	var lair := BossLair.new()
	lair.name = lair_name.replace(" ", "").replace("'", "")
	lair.display_name = lair_name
	lair.bounds = AABB(lo, hi - lo).abs()
	lair.reward_trait = reward
	parent.add_child(lair)
	lair.global_transform = Transform3D.IDENTITY
	var mark := HostileSpawn.new()
	mark.name = "Keeper"
	mark.species_id = species_id
	mark.stays_beaten = true
	lair.add_child(mark)
	mark.global_position = keeper_at
	lair._adopt()
	return lair


## A veil across a way in, filling [param lo] to [param hi] in world space. Up only
## while the lair is sealed.
func add_veil(lo: Vector3, hi: Vector3) -> StaticBody3D:
	var low := Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z))
	var high := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	var veil := StaticBody3D.new()
	veil.name = "Veil%d" % _veils.size()
	add_child(veil)
	veil.global_position = (low + high) * 0.5
	var shape := BoxShape3D.new()
	shape.size = high - low
	var collider := CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = shape
	veil.add_child(collider)
	var box := BoxMesh.new()
	box.size = high - low
	var view := MeshInstance3D.new()
	view.name = "View"
	view.mesh = box
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.albedo_color = VEIL
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	view.material_override = paint
	veil.add_child(view)
	_veils.append(veil)
	_show_veil(veil, false)
	return veil


func _ready() -> void:
	add_to_group("boss_lairs")
	_adopt()
	_set_sealed(false)


## Picks up the keeper and the veils, built this run or loaded with the scene.
func _adopt() -> void:
	keeper = get_node_or_null("Keeper") as HostileSpawn
	if keeper != null and not keeper.beaten_for_good.is_connected(_on_keeper_beaten):
		keeper.beaten_for_good.connect(_on_keeper_beaten)
	_veils.clear()
	for child in get_children():
		if child is StaticBody3D and String(child.name).begins_with("Veil"):
			_veils.append(child)


func _physics_process(_delta: float) -> void:
	if beaten or _sealed or keeper == null or keeper.is_down():
		return
	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if spider != null and contains(spider.global_position):
		seal(spider)


## Whether [param point] is inside the room.
func contains(point: Vector3) -> bool:
	return bounds.has_point(point)


func is_sealed() -> bool:
	return _sealed


## Drops the veils and sets the keeper on you.
func seal(spider: SpiderPlayer) -> void:
	if beaten or _sealed:
		return
	_set_sealed(true)
	if keeper != null and keeper.creature != null and not keeper.is_down():
		keeper.creature.attack_spider(spider)
	spider.notice.emit(display_name)
	sealed.emit(self)


## As it was before you came in: veils up, unless the keeper is beaten. The
## keeper's own mark puts it back at its post.
func reset() -> void:
	_set_sealed(false)


func _on_keeper_beaten(_mark: HostileSpawn) -> void:
	if beaten:
		return
	beaten = true
	_set_sealed(false)
	var spider := get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if spider != null:
		var what := "%s is beaten" % (keeper.species().display_name if keeper.species() != null
			else "The keeper")
		var gift := spider.traits.by_id(reward_trait) if spider.traits != null \
			and reward_trait != "" else null
		if gift != null and spider.traits.take(gift, display_name):
			what += " — and what it kept is yours: %s" % gift.display_name
		spider.notice.emit(what)
	won.emit(self)


func _set_sealed(on: bool) -> void:
	_sealed = on
	for veil in _veils:
		if is_instance_valid(veil):
			_show_veil(veil, on)


func _show_veil(veil: StaticBody3D, on: bool) -> void:
	veil.collision_layer = GameLayers.WORLD if on else 0
	veil.collision_mask = 0
	veil.visible = on
