class_name DevicePlacer
extends Node3D

## Place mode: take something out of the bag and put it on a surface.
##
## Deliberately thinner than the web builder. A device is one object at one
## point — there is no shape to draw and no silk to price — so the whole mode
## is "pick one, look somewhere, click". What makes it interesting is the wire
## you run to it afterwards, which is the web builder's job and the same
## machinery either way.

signal state_changed()
signal notice(text: String)
signal device_placed(device: SilkDevice)

## Why the device cannot go where the crosshair is.
enum Problem {
	NONE,
	NO_SURFACE,   ## nothing solid under the crosshair, or out of range
	EMPTY,        ## nothing of this kind left in the bag
	CROWDED,      ## practically on top of one already placed
}

## Where placed devices are parented. Defaults to a "Devices" node in the level.
@export var device_container_path: NodePath

## How close is too close to one already down, as a multiple of body height.
@export var crowding := 1.2

var active := false
var kind_index := 0

var aim_valid := false
var aim_point := Vector3.ZERO
var aim_normal := Vector3.UP
var problem := Problem.NO_SURFACE

var _spider: CharacterBody3D
var _inventory: SpiderInventory
var _growth: SpiderGrowth
var _view: SpiderCamera

var _ghost: MeshInstance3D
var _ghost_mesh: ImmediateMesh
var _ghost_material: StandardMaterial3D


func _ready() -> void:
	_build_ghost()
	set_process(true)


func setup(spider: CharacterBody3D, inventory: SpiderInventory, growth: SpiderGrowth,
		view: SpiderCamera) -> void:
	_spider = spider
	_inventory = inventory
	_growth = growth
	_view = view
	_inventory.changed.connect(_on_bag_changed)
	_select_first_carried()


func _process(_delta: float) -> void:
	if not active:
		_ghost.visible = false
		return
	_update_aim()
	_draw_ghost()


# --- mode ---------------------------------------------------------------

func toggle() -> void:
	if active:
		stop()
	else:
		start()


func start() -> void:
	if _inventory == null or _inventory.total() <= 0:
		notice.emit("Nothing in the bag to place")
		return
	active = true
	_select_first_carried()
	notice.emit("Place mode — %s" % _inventory.summary(current_kind()))
	state_changed.emit()


func stop() -> void:
	if not active:
		return
	active = false
	_ghost.visible = false
	notice.emit("Bag away")
	state_changed.emit()


## Steps through what the spider is actually carrying, not every kind that
## exists — an empty slot on the wheel is only ever a nuisance.
func cycle(step: int) -> void:
	var held: Array[DeviceKind] = []
	if _inventory != null:
		held = _inventory.carried()
	if held.is_empty():
		notice.emit("Bag empty")
		return
	var here := held.find(current_kind())
	var next: DeviceKind = held[wrapi(here + step, 0, held.size())]
	kind_index = _inventory.kinds.find(next)
	notice.emit("%s  ×%d — %s" % [next.display_name, _inventory.count(next), next.description])
	state_changed.emit()


func current_kind() -> DeviceKind:
	if _inventory == null or _inventory.kinds.is_empty():
		return null
	return _inventory.kinds[clampi(kind_index, 0, _inventory.kinds.size() - 1)]


# --- placing ------------------------------------------------------------

## Puts the selected device where the crosshair is. Returns it, or null.
func place() -> SilkDevice:
	var kind := current_kind()
	if kind == null:
		notice.emit("Nothing in the bag")
		return null
	_update_aim()
	if problem != Problem.NONE:
		notice.emit(problem_text())
		return null
	if not _inventory.take(kind):
		notice.emit("No %s left" % kind.display_name)
		return null

	var device := SilkDevice.make(kind, aim_point, aim_normal, _stage().body_height)
	device.place_in(_resolve_container())
	device.spent_itself.connect(_on_spent)
	notice.emit("%s placed — [G] to wire it up" % kind.display_name)
	device_placed.emit(device)
	state_changed.emit()
	return device


## Takes back the device under the crosshair. Returns true if the bag took it.
func pick_up_aimed() -> bool:
	var device := aimed_device()
	if device == null:
		return false
	var label := device.label()
	if device.spent:
		device.pick_up()
		notice.emit("Swept up the spent %s" % label)
		state_changed.emit()
		return true
	if not _inventory.has_room_for(device.kind):
		notice.emit("Can't carry another %s" % label)
		return false
	_inventory.give(device.pick_up())
	notice.emit("Picked the %s back up" % label)
	state_changed.emit()
	return true


## The device the player is looking at, if any. Devices are small, so this is
## as forgiving as the web pick is.
func aimed_device() -> SilkDevice:
	if _view == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var reach := _stage().anchor_range

	return SilkDevice.aimed_from(get_tree(), from, direction, reach,
		maxf(_stage().body_height * 0.8, 0.25))


# --- aiming -------------------------------------------------------------

func _update_aim() -> void:
	aim_valid = false
	problem = Problem.NO_SURFACE
	var kind := current_kind()
	if kind == null or _inventory.count(kind) <= 0:
		problem = Problem.EMPTY
		return
	if not _cast_surface(_stage().anchor_range):
		return
	if _nearest_device_distance(aim_point) < _stage().body_height * crowding:
		problem = Problem.CROWDED
		return
	problem = Problem.NONE


func _cast_surface(reach: float) -> bool:
	if _view == null:
		return false
	var from := _view.aim_origin()
	var to := from + _view.aim_forward() * reach
	var space := get_world_3d().direct_space_state
	# A web is a floor as far as the spider is concerned, so it is a shelf too.
	var query := PhysicsRayQueryParameters3D.create(from, to,
		GameLayers.WORLD | GameLayers.WEB_WALK, _exclusions())
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	aim_point = hit["position"]
	aim_normal = hit.get("normal", Vector3.UP)
	aim_valid = true
	return true


func _nearest_device_distance(point: Vector3) -> float:
	var nearest := INF
	for node in get_tree().get_nodes_in_group("silk_devices"):
		var device := node as Node3D
		if device == null or not is_instance_valid(device):
			continue
		nearest = minf(nearest, device.global_position.distance_to(point))
	return nearest


# --- text for the HUD ---------------------------------------------------

func problem_text() -> String:
	match problem:
		Problem.NO_SURFACE:
			return "No surface in reach"
		Problem.EMPTY:
			return "None left — wheel to pick another"
		Problem.CROWDED:
			return "Too close to one already down"
	return ""


func hint_text() -> String:
	var kind := current_kind()
	if kind == null:
		return "Nothing left to place — [N] to stop"
	return "Left mouse to put the %s down, wheel to pick, [X] to take one back, [N] to stop" \
		% kind.display_name


# --- internals ----------------------------------------------------------

func _on_bag_changed() -> void:
	if _inventory.count(current_kind()) <= 0:
		_select_first_carried()


func _on_spent(device: SilkDevice) -> void:
	if device != null and device.kind != null:
		notice.emit("The %s is used up" % device.kind.display_name)


func _select_first_carried() -> void:
	if _inventory == null:
		return
	for i in _inventory.kinds.size():
		if _inventory.count(_inventory.kinds[i]) > 0:
			kind_index = i
			return


func _stage() -> GrowthStage:
	if _growth == null:
		return GrowthStage.new()
	return _growth.current_stage()


func _exclusions() -> Array[RID]:
	var list: Array[RID] = []
	if _spider != null:
		list.append(_spider.get_rid())
	return list


func _resolve_container() -> Node3D:
	var container := get_node_or_null(device_container_path) as Node3D
	if container != null:
		return container

	var host := get_tree().current_scene
	if host == null and _spider != null:
		host = _spider.get_parent()
	if host == null:
		host = get_parent()

	container = host.get_node_or_null("Devices") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Devices"
		host.add_child(container)
	return container


func _build_ghost() -> void:
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.vertex_color_use_as_albedo = true
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.no_depth_test = true
	_ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_ghost_mesh = ImmediateMesh.new()
	_ghost = MeshInstance3D.new()
	_ghost.name = "DeviceGhost"
	_ghost.mesh = _ghost_mesh
	_ghost.material_override = _ghost_material
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.top_level = true
	add_child(_ghost)
	_ghost.transform = Transform3D.IDENTITY
	_ghost.visible = false


## Draws where it would land and, for anything with a reach, how far that
## reach goes — a lure is worth nothing if you cannot see what it covers.
func _draw_ghost() -> void:
	_ghost_mesh.clear_surfaces()
	var kind := current_kind()
	if kind == null or not aim_valid:
		_ghost.visible = false
		return
	_ghost.visible = true
	_ghost_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var tint: Color = kind.colour if problem == Problem.NONE else Color(1.0, 0.4, 0.35, 0.8)
	var size: float = maxf(_stage().body_height * 0.35, 0.03)
	var centre := aim_point + aim_normal * size * 0.5
	_cross(centre, size, tint)
	_line(aim_point, centre, tint)
	if kind.radius > 0.05:
		_circle(centre, aim_normal, kind.radius, tint * Color(1, 1, 1, 0.45))

	_ghost_mesh.surface_end()


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_ghost_mesh.surface_set_color(color)
	_ghost_mesh.surface_add_vertex(a)
	_ghost_mesh.surface_set_color(color)
	_ghost_mesh.surface_add_vertex(b)


func _cross(point: Vector3, size: float, color: Color) -> void:
	_line(point - Vector3.RIGHT * size, point + Vector3.RIGHT * size, color)
	_line(point - Vector3.UP * size, point + Vector3.UP * size, color)
	_line(point - Vector3.BACK * size, point + Vector3.BACK * size, color)


func _circle(centre: Vector3, normal: Vector3, radius: float, color: Color) -> void:
	var up := normal.normalized()
	var right := up.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := up.cross(right).normalized()
	var steps := 32
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var b := TAU * float(i + 1) / float(steps)
		_line(centre + (right * cos(a) + forward * sin(a)) * radius,
			centre + (right * cos(b) + forward * sin(b)) * radius, color)
