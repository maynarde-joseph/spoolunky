class_name SilkDevice
extends SilkNode

## A device the spider carried here and put down.
##
## It sits in the same signal network as the webs, so a tripline can set one
## off and it can set a web off in turn. What it does when it goes off is the
## only thing that makes it worth carrying instead of spinning.

signal spent_itself(device: SilkDevice)

var kind: DeviceKind
var spent := false

var _origin := Vector3.ZERO
var _sense_timer := 0.0
var _smelled_something := false


## Builds one ready to be dropped into the world.
static func make(of_kind: DeviceKind, at: Vector3, normal: Vector3,
		scale_to: float) -> SilkDevice:
	if of_kind == null:
		return null
	var device := SilkDevice.new()
	device.name = "Device_" + of_kind.id
	device.kind = of_kind
	device._origin = at + normal * scale_to * 0.25
	device._build_visual(scale_to)
	return device


## The device nearest a line of sight, within reach. Devices are small, so this
## is a proximity-to-the-ray test rather than a raycast — the same forgiveness
## the web pick gets, and for the same reason.
static func aimed_from(tree: SceneTree, from: Vector3, direction: Vector3,
		reach: float, tolerance: float) -> SilkDevice:
	var best: SilkDevice = null
	var best_score := INF
	for node in tree.get_nodes_in_group("silk_devices"):
		var device := node as SilkDevice
		if device == null or not is_instance_valid(device):
			continue
		var offset := device.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > reach:
			continue
		var distance := (offset - direction * along).length()
		if distance > tolerance or distance >= best_score:
			continue
		best_score = distance
		best = device
	return best


func place_in(container: Node3D) -> void:
	container.add_child(self)
	global_transform = Transform3D(Basis.IDENTITY, _origin)


func _ready() -> void:
	super()
	add_to_group("silk_devices")
	if kind != null and kind.effect == DeviceKind.Effect.LURE:
		add_to_group("silk_lures")


func _physics_process(delta: float) -> void:
	_tick_signal(delta)
	if spent or kind == null:
		return
	if kind.effect == DeviceKind.Effect.LURE:
		_sense_timer -= delta
		if _sense_timer <= 0.0:
			_sense_timer = 1.0
			_sense_for_prey()


func can_signal() -> bool:
	return kind != null and kind.reports and not spent


func can_receive_signal() -> bool:
	return kind != null and kind.listens and not spent


## Prey inside a lure's reach is drawn to it, exactly as a funnel web would,
## which is why it joins the same group the prey already watches.
func lure_radius() -> float:
	if kind == null or spent or kind.effect != DeviceKind.Effect.LURE:
		return 0.0
	return kind.radius


func label() -> String:
	return kind.display_name if kind != null else name


func status_line() -> String:
	if kind == null:
		return "device"
	var text := label()
	if spent:
		text += "  (spent)"
	if links.size() > 0:
		text += "  → sets off %d" % links.size()
	if _linked_by.size() > 0:
		text += "  (wired)"
	return text


## Takes it back off the wall. Returns the kind, so it goes back in the bag.
func pick_up() -> DeviceKind:
	var carried := kind
	unlink_all()
	queue_free()
	return carried if not spent else null


func _react_to_signal(source: SilkNode) -> void:
	if spent or kind == null:
		return
	match kind.effect:
		DeviceKind.Effect.VENOM:
			_bite()
		DeviceKind.Effect.BELL:
			_ring(source)
		_:
			pass
	if kind.one_shot:
		spent = true
		spent_itself.emit(self)
	_refresh_visual()


## Kills whatever is close enough. A dead thing can be drained whatever its
## size, which is the one thing silk can never do for you.
func _bite() -> void:
	var killed := 0
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		if global_position.distance_to(prey.global_position) > kind.radius:
			continue
		if prey.envenom():
			killed += 1
	if killed > 0:
		_tell_spider("%s fired — %d killed" % [kind.display_name, killed])
	else:
		_tell_spider("%s fired, and caught nothing" % kind.display_name)


## Passes the news to the spider wherever it happens to be.
func _ring(source: SilkNode) -> void:
	var what := source.status_line() if source != null else "something"
	var spider := get_tree().get_first_node_in_group("spider")
	var distance := 0.0
	if spider is Node3D:
		distance = (spider as Node3D).global_position.distance_to(global_position)
	_tell_spider("Bell: %s — %dm away" % [what, roundi(distance)])


## A lure reports the arrival, not the standing fact — otherwise a fly sitting
## next to one would ring a wired bell once a second until you came back.
func _sense_for_prey() -> void:
	var close := false
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		if global_position.distance_to(prey.global_position) <= kind.radius * 0.25:
			close = true
			break
	if close and not _smelled_something:
		fire()
	_smelled_something = close


func _tell_spider(text: String) -> void:
	var spider := get_tree().get_first_node_in_group("spider")
	if spider != null and spider.has_method("notify"):
		spider.notify(text)


func _build_visual(scale_to: float) -> void:
	var size: float = maxf(scale_to * 0.35, 0.03)
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 10
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = kind.colour
	material.emission_enabled = true
	material.emission = kind.colour
	material.emission_energy_multiplier = 0.5
	material.roughness = 0.4
	var view := MeshInstance3D.new()
	view.name = "Shell"
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


func _refresh_visual() -> void:
	var view := get_node_or_null("Shell") as MeshInstance3D
	if view == null:
		return
	var material := view.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_energy_multiplier = 0.1 if spent else 0.5
	material.albedo_color = kind.colour.darkened(0.6) if spent else kind.colour
