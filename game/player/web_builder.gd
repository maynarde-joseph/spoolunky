class_name WebBuilder
extends Node3D

## Build mode: aim, drop anchors, spin a web between them.
##
## The player never places a prefab. They shoot silk at real surfaces, and the
## shape of the web falls out of where those anchors landed — which is what
## makes a corner, a doorway and a drain all play differently.

signal state_changed()
signal notice(text: String)
signal web_built(web: WebStructure)

## Why the current aim point cannot be anchored.
enum Problem {
	NONE,
	NO_SURFACE,      ## nothing solid under the crosshair, or out of range
	TOO_FAR,         ## further from the last anchor than this size can span
	TOO_CLOSE,       ## practically on top of the last anchor
	FULL,            ## pattern has taken all the anchors it allows
	NO_SILK,         ## the web as drawn costs more than we carry
	LOCKED,          ## pattern needs a bigger spider
}

## Where finished webs are parented. Defaults to a "Webs" node in the level.
@export var web_container_path: NodePath

var patterns: Array[WebPattern] = []
var pattern_index := 0
var building := false
var anchors := PackedVector3Array()

var aim_valid := false
var aim_point := Vector3.ZERO
var aim_normal := Vector3.UP
var problem := Problem.NONE
var estimated_cost := 0.0

var _spider: CharacterBody3D
var _silk: SilkPool
var _growth: SpiderGrowth
var _preview: MeshInstance3D
var _preview_mesh: ImmediateMesh
var _preview_material: StandardMaterial3D
var _cursor: MeshInstance3D
var _cursor_mesh: SphereMesh
var _cursor_material: StandardMaterial3D


func _ready() -> void:
	patterns = WebLibrary.load_patterns()
	_build_preview_nodes()
	set_process(true)


## Wires the builder to the spider that owns it.
func setup(spider: CharacterBody3D, silk: SilkPool, growth: SpiderGrowth) -> void:
	_spider = spider
	_silk = silk
	_growth = growth


func _process(_delta: float) -> void:
	if building:
		_update_aim()
	_draw_preview()


# --- build mode ---------------------------------------------------------

func toggle() -> void:
	if building:
		stop()
	else:
		start()


func start() -> void:
	if building:
		return
	building = true
	anchors.clear()
	if not _is_unlocked(current_pattern()):
		_select_first_unlocked()
	notice.emit("Build mode: %s" % _pattern_name())
	state_changed.emit()


func stop() -> void:
	if not building:
		return
	building = false
	anchors.clear()
	problem = Problem.NONE
	estimated_cost = 0.0
	state_changed.emit()


## Drops an anchor at the aim point, or closes the web if the player clicked
## back on the first anchor.
func place() -> void:
	if not building:
		return
	var pattern := current_pattern()
	if pattern == null:
		return
	_update_aim()

	if anchors.size() >= pattern.min_anchors and pattern.shape == WebPattern.Shape.NET \
			and aim_valid and aim_point.distance_to(anchors[0]) <= _snap_radius():
		finish()
		return

	if problem != Problem.NONE:
		notice.emit(problem_text())
		return

	add_anchor(aim_point)


## Drops an anchor at an explicit world point, skipping the aim checks.
## Spins the web automatically once the pattern has all the anchors it takes.
func add_anchor(point: Vector3) -> bool:
	var pattern := current_pattern()
	if not building or pattern == null:
		return false
	if anchors.size() >= pattern.max_anchors:
		return false
	anchors.append(point)
	state_changed.emit()
	if anchors.size() >= pattern.max_anchors:
		finish()
	return true


## Takes the last anchor back, or leaves build mode if there are none.
func undo() -> void:
	if not building:
		return
	if anchors.is_empty():
		stop()
		notice.emit("Build mode off")
		return
	anchors.remove_at(anchors.size() - 1)
	state_changed.emit()


## Spins the web. Silk is only spent once the real layout is known, so the
## player is never charged for a web that turned out to be impossible.
func finish() -> void:
	if not building:
		return
	var pattern := current_pattern()
	if pattern == null:
		return
	if anchors.size() < pattern.min_anchors:
		notice.emit("%s needs %d anchors" % [pattern.display_name, pattern.min_anchors])
		return

	var quality := _quality()
	var web: WebStructure = null
	if pattern.shape == WebPattern.Shape.STRAND:
		web = WebStrand.spin(pattern, anchors[0], anchors[1], quality)
	else:
		web = WebNet.spin(pattern, anchors, quality)

	if web == null:
		notice.emit("Those anchors won't hold a web")
		return

	if not _silk.can_afford(web.silk_cost):
		notice.emit("Not enough silk — %d needed" % ceili(web.silk_cost))
		web.free()
		return

	_silk.spend(web.silk_cost)
	web.place_in(_resolve_container())
	anchors.clear()
	state_changed.emit()
	web_built.emit(web)
	notice.emit("%s spun (%d silk)" % [pattern.display_name, roundi(web.silk_cost)])


func cycle(step: int) -> void:
	var available := unlocked_patterns()
	if available.size() <= 1:
		return
	var current := current_pattern()
	var index := available.find(current)
	index = wrapi(index + step, 0, available.size())
	pattern_index = patterns.find(available[index])
	anchors.clear()
	state_changed.emit()
	notice.emit(_pattern_name())


func current_pattern() -> WebPattern:
	if patterns.is_empty():
		return null
	return patterns[clampi(pattern_index, 0, patterns.size() - 1)]


func unlocked_patterns() -> Array[WebPattern]:
	var available: Array[WebPattern] = []
	for pattern in patterns:
		if _is_unlocked(pattern):
			available.append(pattern)
	return available


# --- existing webs ------------------------------------------------------

## The web the player is looking at, if any. Tolerant, because silk is thin.
func aimed_web() -> WebStructure:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.global_position
	var direction := -camera.global_basis.z
	var reach := _stage().anchor_range

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach,
		GameLayers.WEB, _exclusions())
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var web := _web_from(hit.get("collider"))
		if web != null:
			return web

	# Fall back to the closest web near the line of sight.
	var best: WebStructure = null
	var best_score := INF
	var tolerance: float = maxf(0.35, _stage().body_height)
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null:
			continue
		var offset := web.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > reach:
			continue
		var distance := (offset - direction * along).length()
		var span := tolerance
		var net := web as WebNet
		if net != null:
			span += net.radius
		if distance > span:
			continue
		if distance < best_score:
			best_score = distance
			best = web
	return best


## Pulls down the web under the crosshair. Returns the silk recovered.
func demolish_aimed() -> float:
	var web := aimed_web()
	if web == null:
		notice.emit("Nothing to pull down")
		return 0.0
	var label := web.pattern.display_name
	var refund := web.demolish()
	_silk.refill(refund)
	notice.emit("%s pulled down (+%d silk)" % [label, roundi(refund)])
	return refund


# --- aiming -------------------------------------------------------------

func _update_aim() -> void:
	var pattern := current_pattern()
	aim_valid = false
	problem = Problem.NO_SURFACE
	estimated_cost = 0.0
	if pattern == null:
		return
	if not _is_unlocked(pattern):
		problem = Problem.LOCKED
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var stage := _stage()
	var from := camera.global_position
	var to := from - camera.global_basis.z * stage.anchor_range
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.WORLD, _exclusions())
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return

	aim_point = hit["position"]
	aim_normal = hit.get("normal", Vector3.UP)
	# Lift the anchor off the surface a touch so silk doesn't z-fight the wall.
	aim_point += aim_normal * stage.body_height * 0.08
	aim_valid = true
	problem = Problem.NONE

	if anchors.size() >= pattern.max_anchors:
		problem = Problem.FULL
		return

	if anchors.size() > 0:
		var last := anchors[anchors.size() - 1]
		var span := last.distance_to(aim_point)
		if span > stage.max_strand_length:
			problem = Problem.TOO_FAR
			return
		if span < stage.body_height * 0.25:
			problem = Problem.TOO_CLOSE
			return

	var provisional := anchors.duplicate()
	provisional.append(aim_point)
	estimated_cost = _estimate_cost(pattern, provisional)
	if estimated_cost > _silk.current and provisional.size() >= pattern.min_anchors:
		problem = Problem.NO_SILK


## Rough silk figure for the HUD. The real cost is measured off the finished
## layout when the web is actually spun.
func _estimate_cost(pattern: WebPattern, points: PackedVector3Array) -> float:
	if points.size() < 2:
		return pattern.silk_base_cost
	if pattern.shape == WebPattern.Shape.STRAND:
		var length := points[0].distance_to(points[1])
		if pattern.walkable:
			length *= 2.4
		return pattern.cost_for(length, 0.0)
	if points.size() < 3:
		var rim := 0.0
		for i in range(points.size() - 1):
			rim += points[i].distance_to(points[i + 1])
		return pattern.cost_for(rim, 0.0)

	var perimeter := 0.0
	for i in points.size():
		perimeter += points[i].distance_to(points[(i + 1) % points.size()])
	var area := _polygon_area(points)
	var mean_radius: float = sqrt(maxf(area, 0.0001) / PI)
	var spokes: float = float(pattern.radial_count) * mean_radius
	var spiral: float = float(pattern.ring_count) * TAU * mean_radius * 0.5
	return pattern.cost_for(perimeter + spokes + spiral, area)


func _polygon_area(points: PackedVector3Array) -> float:
	var normal := WebGeometry.plane_normal(points)
	var total := Vector3.ZERO
	for i in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return absf(total.dot(normal)) * 0.5


# --- text for the HUD ---------------------------------------------------

func problem_text() -> String:
	match problem:
		Problem.NO_SURFACE:
			return "No surface in reach"
		Problem.TOO_FAR:
			return "Too far to span — %.1fm limit" % _stage().max_strand_length
		Problem.TOO_CLOSE:
			return "Too close to the last anchor"
		Problem.FULL:
			return "Anchors full — press F to spin"
		Problem.NO_SILK:
			return "Not enough silk — %d needed" % ceili(estimated_cost)
		Problem.LOCKED:
			return "%s needs a bigger spider" % _pattern_name()
	return ""


func hint_text() -> String:
	var pattern := current_pattern()
	if pattern == null:
		return ""
	if not building:
		return ""
	if anchors.size() < pattern.min_anchors:
		return "Anchor %d of %d" % [anchors.size(), pattern.min_anchors]
	if pattern.shape == WebPattern.Shape.NET:
		return "F to spin, or click the first anchor to close"
	return "F to spin"


# --- internals ----------------------------------------------------------

func _pattern_name() -> String:
	var pattern := current_pattern()
	return pattern.display_name if pattern != null else "—"


func _stage() -> GrowthStage:
	if _growth == null:
		return GrowthStage.new()
	return _growth.current_stage()


func _quality() -> float:
	return _stage().silk_quality


func _is_unlocked(pattern: WebPattern) -> bool:
	if pattern == null:
		return false
	if _growth == null:
		return pattern.unlock_stage == 0
	return pattern.is_unlocked_at(_growth.stage_index)


func _select_first_unlocked() -> void:
	for i in patterns.size():
		if _is_unlocked(patterns[i]):
			pattern_index = i
			return


func _snap_radius() -> float:
	return maxf(_stage().body_height * 0.8, _stage().max_strand_length * 0.12)


func _exclusions() -> Array[RID]:
	var list: Array[RID] = []
	if _spider != null:
		list.append(_spider.get_rid())
	return list


func _web_from(collider: Variant) -> WebStructure:
	var node := collider as Node
	while node != null:
		var web := node as WebStructure
		if web != null:
			return web
		node = node.get_parent()
	return null


func _resolve_container() -> Node3D:
	var container := get_node_or_null(web_container_path) as Node3D
	if container != null:
		return container

	# Otherwise keep webs tidy under a "Webs" node in the level, making one if
	# the level hasn't got around to providing it.
	var host := get_tree().current_scene
	if host == null and _spider != null:
		host = _spider.get_parent()
	if host == null:
		host = get_parent()

	container = host.get_node_or_null("Webs") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Webs"
		host.add_child(container)
	return container


func _build_preview_nodes() -> void:
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.vertex_color_use_as_albedo = true
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.no_depth_test = true
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_preview_mesh = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.name = "BuildPreview"
	_preview.mesh = _preview_mesh
	_preview.material_override = _preview_material
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.top_level = true
	add_child(_preview)
	_preview.transform = Transform3D.IDENTITY

	_cursor_material = StandardMaterial3D.new()
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_material.no_depth_test = true
	_cursor_mesh = SphereMesh.new()
	_cursor_mesh.radial_segments = 8
	_cursor_mesh.rings = 4
	_cursor = MeshInstance3D.new()
	_cursor.name = "AnchorCursor"
	_cursor.mesh = _cursor_mesh
	_cursor.material_override = _cursor_material
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.top_level = true
	add_child(_cursor)
	_cursor.visible = false


func _draw_preview() -> void:
	_preview_mesh.clear_surfaces()
	if not building:
		_cursor.visible = false
		return

	var pattern := current_pattern()
	if pattern == null:
		return

	var good := pattern.color
	good.a = 1.0
	var bad := Color(1.0, 0.35, 0.3, 1.0)
	var line_color := good if problem == Problem.NONE else bad
	var tick: float = maxf(_stage().body_height * 0.35, 0.03)

	var points := anchors.duplicate()
	if aim_valid:
		points.append(aim_point)

	# One lone aim point draws no lines — only the cursor below — and opening an
	# empty surface is an error.
	if points.size() >= 2 or anchors.size() >= 1:
		_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
		for i in range(points.size() - 1):
			var colour := line_color if i == points.size() - 2 else good
			_line(points[i], points[i + 1], colour)
		if pattern.shape == WebPattern.Shape.NET and points.size() >= 3:
			var closing := good
			closing.a = 0.4
			_line(points[points.size() - 1], points[0], closing)
		for anchor in anchors:
			_cross(anchor, tick, good)
		_preview_mesh.surface_end()

	_cursor.visible = aim_valid
	if aim_valid:
		_cursor_mesh.radius = tick * 0.5
		_cursor_mesh.height = tick
		_cursor_material.albedo_color = Color(line_color.r, line_color.g, line_color.b, 0.7)
		_cursor.global_position = aim_point


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_preview_mesh.surface_set_color(color)
	_preview_mesh.surface_add_vertex(a)
	_preview_mesh.surface_set_color(color)
	_preview_mesh.surface_add_vertex(b)


func _cross(point: Vector3, size: float, color: Color) -> void:
	_line(point - Vector3.RIGHT * size, point + Vector3.RIGHT * size, color)
	_line(point - Vector3.UP * size, point + Vector3.UP * size, color)
	_line(point - Vector3.BACK * size, point + Vector3.BACK * size, color)
