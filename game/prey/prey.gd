class_name Prey
extends CharacterBody3D

## Something worth eating.
##
## Prey wanders a patch of the world, gets stuck in webs, struggles hard enough
## to tear them, and can be wrapped and drained by the spider. What kind of
## creature it is comes from a [PreySpecies] resource, so one scene and one
## script serve every creature in the game and a new one is a .tres.
##
## The species is copied into plain fields when it is applied rather than read
## through, so a level — or a test — can make one unusual individual without
## authoring a whole species for it.

signal snared(prey: Prey)
signal broke_free(prey: Prey)
signal eaten_by_spider(prey: Prey)

enum State {
	WANDER,    ## going about its business
	STUCK,     ## caught in silk, fighting it
	WRAPPED,   ## bundled up, going nowhere
	FLEEING,   ## just tore loose, getting out
	BUNDLED,   ## wrapped where it stood and dropped, out of any web
}

## How much better than a catch's total thrash a web has to be to keep it.
## Tuned so each web tier holds the prey tier below it: a sheet web keeps a
## fly, an orb web keeps a moth, a pressure snare keeps a wasp — and silk
## quality, which climbs with size, moves every one of those lines up.
const ESCAPE_MARGIN := 6.0

## The one scene every creature is built from.
const SCENE_PATH := "res://game/prey/prey.tscn"


## What this is. Applied on the way into the tree, or by whatever spawned it.
@export var kind: PreySpecies

## Shown in HUD messages.
var species := "Fly"

## Biomass gained by draining it.
var biomass := 8.0

## Silk recovered by draining it.
var silk_return := 7.0

## How big it is, against a web's mesh and the spider's bite power. 1 is
## fly-sized.
var size_class := 1

## How hard it fights a web. Tears silk and eventually pulls free.
var struggle_power := 1.0

## How long it fights for before it tires out. A catch is won or lost inside
## this window: if the web out-holds the whole thrash, it is still there when
## you come back, which is the only reason leaving a web is a plan and not a
## way to lose one.
var struggle_stamina := 5.0

## How hard a tired catch keeps pulling. Small on purpose — it means a full
## larder is a web slowly wearing out rather than a free store, without ever
## putting you on a stopwatch.
var settled_drain := 0.015

var move_speed := 1.6

## Flying prey ignores gravity and drifts; walking prey falls.
var flying := true

## How far from its spawn point it will wander.
var wander_radius := 6.0

## Low and high limits above the spawn point, for fliers.
var wander_height := Vector2(0.3, 2.6)

## Seconds before it picks somewhere new to be, even if it hasn't arrived.
var wander_interval := 3.0

## How strongly it drifts toward a funnel lure it can smell.
var lure_susceptibility := 0.8


var wrapped := false
var eaten := false

## Killed by venom: drainable no matter how big it is.
var subdued := false

var _state: State = State.WANDER
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wander_timer := 0.0
var _web: WebStructure = null
var _stuck_point := Vector3.ZERO
var _struggle := 0.0
var _fight_left := 0.0
var _snap_timer := 0.0
var _flee_timer := 0.0
var _recatch_cooldown := 0.0
var _marked_timer := 0.0
var _lure_timer := 0.0
var _life := 0.0
var _marker: MeshInstance3D
var _cocoon: MeshInstance3D
var _wings: Array[Node3D] = []
var _applied := false
var _tow_pull := Vector3.ZERO

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


## Builds one of a species, ready to be dropped into the world.
static func of(species: PreySpecies) -> Prey:
	# Loaded rather than preloaded: the scene this makes carries this very
	# script, and a preload of it from in here is a cycle.
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null or species == null:
		return null
	var prey := scene.instantiate() as Prey
	if prey == null:
		return null
	prey.apply_species(species)
	return prey


## Takes on a species: its numbers, its name and its body. Safe before the
## node is in the tree, which is where the spawner does it.
func apply_species(from: PreySpecies) -> void:
	if from == null:
		return
	kind = from
	name = from.display_name.replace(" ", "")
	species = from.display_name
	biomass = from.biomass
	silk_return = from.silk_return
	size_class = from.size_class
	struggle_power = from.struggle_power
	struggle_stamina = from.struggle_stamina
	settled_drain = from.settled_drain
	move_speed = from.move_speed
	flying = from.flying
	wander_radius = from.wander_radius
	wander_height = from.wander_height
	wander_interval = from.wander_interval
	lure_susceptibility = from.lure_susceptibility
	_applied = true
	if is_inside_tree():
		_build_body()


func _ready() -> void:
	add_to_group("prey")
	collision_layer = GameLayers.PREY
	collision_mask = GameLayers.WORLD
	if kind != null and not _applied:
		apply_species(kind)
	_build_body()
	_home = global_position
	_pick_target()


func _physics_process(delta: float) -> void:
	_life += delta
	if _recatch_cooldown > 0.0:
		_recatch_cooldown -= delta
	if _marked_timer > 0.0:
		_marked_timer -= delta
		if _marked_timer <= 0.0:
			_set_marked(false)
	_flap()

	match _state:
		State.BUNDLED:
			_fall(delta)
		State.STUCK, State.WRAPPED:
			_process_stuck(delta)
		State.FLEEING:
			_flee_timer -= delta
			if _flee_timer <= 0.0:
				_state = State.WANDER
				_pick_target()
			_steer(delta, move_speed * 1.8)
		_:
			_process_wander(delta)


# --- being prey ---------------------------------------------------------

## Webs ask before catching, so prey that just tore loose gets a moment — and
## so that anything already caught is not caught again. Bundles matter here:
## one dropped inside the web that made it sits in that web's catch volume,
## and without this the web grabs it back on the next frame and pins it in
## mid-air instead of letting it fall.
func can_be_snared() -> bool:
	if eaten or wrapped or _state == State.STUCK:
		return false
	return _recatch_cooldown <= 0.0


## Called by a web that has caught this. [param snap_time] is the rigid hold
## from a sprung pressure snare.
func on_snared(web: WebStructure, point: Vector3, snap_time: float) -> void:
	_web = web
	_stuck_point = point
	_snap_timer = snap_time
	_struggle = 0.0
	_fight_left = struggle_stamina
	_state = State.STUCK
	velocity = Vector3.ZERO
	_set_marked(false)
	snared.emit(self)


## Called when the web holding this is destroyed.
func on_freed(_web_that_tore: WebStructure) -> void:
	if _state != State.STUCK:
		return
	_release_into_flight()


## Called by an alert web (tripline) that this walked through.
func on_tripped(_web: WebStructure, mark_time: float) -> void:
	_marked_timer = maxf(_marked_timer, mark_time)
	_set_marked(true)


func is_stuck() -> bool:
	return _state == State.STUCK or _state == State.WRAPPED


## Wrapped and on the floor, out of any web. Something a thrown web took
## cleanly, waiting to be collected.
func is_bundled() -> bool:
	return _state == State.BUNDLED


## Everything it will throw at a web before it tires itself out: the number a
## web has to beat to keep hold of it.
func total_thrash() -> float:
	return struggle_power * struggle_stamina


## Still fighting, and still able to get free. This is the only window in which
## a catch can be lost, so it is the window worth running back for.
func is_fighting() -> bool:
	return _state == State.STUCK and _fight_left > 0.0


## Caught for keeps: tired out or wrapped. It will hang there until you come
## and take it, or until the web gives out under it.
func is_secured() -> bool:
	return _state == State.BUNDLED or (is_stuck() and not is_fighting())


## Silk needed to bundle this up so it stops wrecking the web.
func wrap_cost() -> float:
	return 1.0 + biomass * 0.25


## Killed outright by venom: it stops fighting, and it can be drained whatever
## size it is, which is what makes a venom spur worth carrying.
func envenom() -> bool:
	if eaten or subdued:
		return false
	subdued = true
	# Something dead in open air is not something that hovers. Killed in a web
	# it hangs there wrapped, which is what a web holding something is for;
	# killed anywhere else it drops, like any other bundle.
	#
	# This used to set WRAPPED whatever was true, without ever recording a
	# point to hang from — and the stuck handler drags the body towards that
	# point every frame, which for anything poisoned in open air is the world
	# origin. It sailed off across the level wearing a cocoon.
	if not is_stuck() or not is_instance_valid(_web):
		bundle()
		return true
	wrapped = true
	_state = State.WRAPPED
	_stuck_point = global_position
	_struggle = 0.0
	_set_marked(false)
	_set_cocoon(true)
	return true


## Wrapped on the spot and cut loose: the silk goes round it where it is and
## the bundle drops. This is what a web thrown over something does when the
## silk is good enough to take it outright, rather than leaving it hanging
## there fighting.
func bundle() -> bool:
	if eaten or _state == State.BUNDLED:
		return false
	if is_instance_valid(_web):
		_web.on_prey_escaped(self)
	_web = null
	wrapped = true
	_struggle = 0.0
	_fight_left = 0.0
	_snap_timer = 0.0
	_recatch_cooldown = 0.0
	_state = State.BUNDLED
	_set_marked(false)
	_set_cocoon(true)
	velocity = Vector3.ZERO
	_tow_pull = Vector3.ZERO
	# Whatever it was before, a bundle is a thing that falls: floating bodies
	# never report standing on anything, so it would never settle.
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	return true


## Dragged by something outside — a tether. Kept as a pull to be spent rather
## than applied on the spot, because whatever is towing this runs in its own
## physics step and the movement belongs in ours.
func tow(pull: Vector3) -> void:
	_tow_pull += pull


## A bundle is dead weight: it falls whether or not the thing inside it could
## fly, and stays where it lands until you come and drain it — unless something
## is dragging it, in which case it comes along and keeps the swing.
func _fall(delta: float) -> void:
	var pull := _tow_pull
	_tow_pull = Vector3.ZERO
	if is_on_floor() and pull.length_squared() < 0.000001:
		velocity = Vector3.ZERO
		return
	# A towed bundle scrapes along rather than gliding: enough friction that it
	# trails behind you, not so much that it refuses to come.
	var slow: float = 4.0 if pull.length_squared() < 0.000001 else 1.2
	velocity.x = move_toward(velocity.x, 0.0, delta * slow)
	velocity.z = move_toward(velocity.z, 0.0, delta * slow)
	velocity.y -= _gravity * delta
	velocity += pull
	move_and_slide()


## Bundles it: no more struggling, no more damage to the web.
func wrap() -> void:
	if not is_stuck():
		return
	wrapped = true
	_state = State.WRAPPED
	_struggle = 0.0
	_set_marked(false)
	_set_cocoon(true)


func silk_value() -> float:
	return silk_return * (1.5 if wrapped else 1.0)


## Drained by the spider.
func consume() -> void:
	if eaten:
		return
	eaten = true
	if is_instance_valid(_web):
		_web.on_prey_escaped(self)
	eaten_by_spider.emit(self)
	queue_free()


# --- behaviour ----------------------------------------------------------

func _process_stuck(delta: float) -> void:
	var pull: float = 12.0 if _snap_timer > 0.0 else 5.0
	var jitter := Vector3.ZERO
	if _state == State.STUCK and _snap_timer <= 0.0:
		var wobble: float = _stuck_wobble()
		jitter = Vector3(sin(_life * 23.0), sin(_life * 17.0 + 1.3), cos(_life * 19.0)) * wobble
	global_position = global_position.lerp(_stuck_point + jitter, clampf(pull * delta, 0.0, 1.0))
	velocity = Vector3.ZERO

	if _snap_timer > 0.0:
		_snap_timer -= delta
		return
	if _state == State.WRAPPED:
		# Wrapped is finished business, and finished business obeys gravity.
		# With nothing holding it up — the web came down, or something has a
		# line on it and is dragging it out — it is a bundle, and bundles fall.
		# Left as it was, the cocoon hung in the air where the web used to be.
		if not is_instance_valid(_web) or _tow_pull.length_squared() > 0.000001:
			bundle()
		return
	if not is_instance_valid(_web):
		_release_into_flight()
		return

	if _fight_left <= 0.0:
		# Fought itself out. It is not getting free on its own any more, so it
		# keeps until you come for it — still hanging there pulling, which is
		# what eventually costs you the web if you never do.
		_web.take_damage(settled_drain * delta)
		return

	_fight_left -= delta
	_struggle += struggle_power * delta
	_web.take_damage(struggle_power * delta * 0.6)
	if _struggle >= _web.hold_strength() * ESCAPE_MARGIN:
		var torn_from := _web
		torn_from.on_prey_escaped(self)
		_release_into_flight()
		broke_free.emit(self)


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	_lure_timer -= delta
	if _lure_timer <= 0.0:
		_lure_timer = 0.75
		_sniff_for_lures()
	if _wander_timer <= 0.0 or global_position.distance_to(_target) < _arrival_distance():
		_pick_target()
	_steer(delta, move_speed)


func _steer(delta: float, speed: float) -> void:
	var to_target := _target - global_position
	if to_target.length() < 0.001:
		return
	var desired := to_target.normalized() * speed
	if not flying:
		desired.y = velocity.y - _gravity * delta
	velocity = velocity.lerp(desired, clampf(3.0 * delta, 0.0, 1.0))
	move_and_slide()
	if is_on_wall():
		_pick_target()


func _pick_target() -> void:
	_wander_timer = wander_interval * randf_range(0.6, 1.4)
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	offset *= wander_radius * randf_range(0.2, 1.0)
	_target = _home + offset
	if flying:
		_target.y = _home.y + randf_range(wander_height.x, wander_height.y)


## Funnel lures bend a wanderer's path toward them — that's the whole point.
func _sniff_for_lures() -> void:
	if lure_susceptibility <= 0.0:
		return
	var best: Node3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("silk_lures"):
		var lure := node as SilkNode
		if lure == null:
			continue
		var distance := global_position.distance_to(lure.global_position)
		if distance > lure.lure_radius() or distance >= best_distance:
			continue
		best_distance = distance
		best = lure
	if best == null:
		return
	if randf() > lure_susceptibility:
		return
	var wobble := Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2),
		randf_range(-0.2, 0.2))
	_target = best.global_position + wobble
	_wander_timer = wander_interval


func _release_into_flight() -> void:
	var escape_from := _stuck_point
	_web = null
	_struggle = 0.0
	_fight_left = 0.0
	_snap_timer = 0.0
	wrapped = false
	_set_cocoon(false)
	_state = State.FLEEING
	_flee_timer = 2.0
	_recatch_cooldown = 2.5
	var away := (global_position - escape_from)
	if away.length() < 0.01:
		away = Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))
	_target = global_position + away.normalized() * wander_radius * 0.5 + Vector3.UP * 0.4


func _arrival_distance() -> float:
	return maxf(0.25, wander_radius * 0.05)


## Fades out as it tires, so you can read a web across the room: still things
## are yours, thrashing things are about to not be.
func _stuck_wobble() -> float:
	var fight := clampf(_fight_left / maxf(struggle_stamina, 0.001), 0.0, 1.0)
	return clampf(struggle_power * 0.01, 0.002, 0.05) * fight


func _flap() -> void:
	if _wings.is_empty():
		return
	var angle := 0.0
	if _state != State.WRAPPED:
		angle = sin(_life * 70.0) * 0.9
	for i in _wings.size():
		var wing := _wings[i]
		var sign_value: float = 1.0 if i % 2 == 0 else -1.0
		wing.rotation.z = angle * sign_value


## Body, wings and hitbox, all from the species. Built in code rather than
## authored per creature, so a new one really is a .tres and nothing else.
func _build_body() -> void:
	var radius := 0.045
	var colour := Color(0.13, 0.12, 0.15, 1.0)
	var sheen := Color(0.45, 0.3, 0.08, 1.0)
	var winged := true
	if kind != null:
		radius = maxf(kind.body_radius, 0.008)
		colour = kind.colour
		sheen = kind.sheen
		winged = kind.winged

	_replace_child("Body", _make_body(radius, colour, sheen))
	_replace_child("Hitbox", _make_hitbox(radius))
	_wings.clear()
	if winged:
		_replace_child("WingLeft", _make_wing(radius, 1.0))
		_replace_child("WingRight", _make_wing(radius, -1.0))
		for wing_name in ["WingLeft", "WingRight"]:
			var wing := get_node_or_null(NodePath(wing_name)) as Node3D
			if wing != null:
				_wings.append(wing)
	else:
		_drop_child("WingLeft")
		_drop_child("WingRight")

	# A cocoon drawn for the old body is the wrong size for this one.
	if _cocoon != null:
		_cocoon.queue_free()
		_cocoon = null
	if _marker != null:
		_marker.queue_free()
		_marker = null


func _make_body(radius: float, colour: Color, sheen: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = 0.4
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = sheen
	material.emission_energy_multiplier = 0.6
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	return view


func _make_wing(radius: float, side: float) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(radius * 2.4, maxf(radius * 0.06, 0.002), radius * 1.1)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.9, 1.0, 0.35)
	material.roughness = 0.1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var view := MeshInstance3D.new()
	view.name = "Mesh"
	view.mesh = mesh
	view.material_override = material
	view.position = Vector3(radius * 1.2 * side, radius * 0.45, 0.0)
	var pivot := Node3D.new()
	pivot.add_child(view)
	return pivot


func _make_hitbox(radius: float) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius * 1.15
	var hit := CollisionShape3D.new()
	hit.shape = shape
	return hit


func _replace_child(child_name: String, node: Node) -> void:
	_drop_child(child_name)
	node.name = child_name
	add_child(node)


func _drop_child(child_name: String) -> void:
	var existing := get_node_or_null(NodePath(child_name))
	if existing == null:
		return
	remove_child(existing)
	existing.queue_free()


## Silk bundle drawn around wrapped prey.
func _set_cocoon(active: bool) -> void:
	if active and _cocoon == null:
		var radius: float = kind.body_radius if kind != null else 0.045
		var mesh := SphereMesh.new()
		mesh.radius = radius * 2.0
		mesh.height = radius * 5.8
		mesh.radial_segments = 10
		mesh.rings = 5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.93, 0.93, 0.9, 0.9)
		material.roughness = 0.9
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cocoon = MeshInstance3D.new()
		_cocoon.name = "Cocoon"
		_cocoon.mesh = mesh
		_cocoon.material_override = material
		_cocoon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cocoon)
	if _cocoon != null:
		_cocoon.visible = active


## Highlight for prey that has tripped an alert web.
func _set_marked(active: bool) -> void:
	if active and _marker == null:
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		mesh.radial_segments = 8
		mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.45, 0.3, 0.28)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_marker = MeshInstance3D.new()
		_marker.name = "TripMarker"
		_marker.mesh = mesh
		_marker.material_override = material
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
	if _marker != null:
		_marker.visible = active
