class_name LevelEditor
extends Node3D

## Making levels, in the game.
##
## The camera works like most 3D editors: the mouse wheel zooms toward what is
## under the mouse, the middle button (or Alt and the left) orbits, and with Shift
## it pans; F frames what is selected and Home the whole level. Holding the right
## button looks round, and WASD with Q and E fly (Shift for faster).
##
## Pick a thing from the palette on the left and click to put it down: it shows
## where it will go before you click, sits on whatever is under the mouse, and
## snaps to the grid drawn round it. Click a thing to select it, and drag it to
## move it (Shift and drag for up and down). Its handles stretch it from a face,
## lift it, and set where a door opens to, where a rail ends and where a platform
## stops. Everything else about it is in the panel on the right, and when nothing
## is selected that panel holds the level's own settings and anything that looks
## wrong with it. F1 shows every key.

signal playtest(level: Dictionary, path: String)
signal leave()

const PICK_MASK := GameLayers.WORLD | GameLayers.PREY | LevelBuilder.EDITOR_PICK
const SNAPS := [0.25, 0.5, 1.0, 2.0]
const GAMEPLAY := ["start", "exit", "fly", "crate", "plate", "door", "platform", "hazard", "panel",
	"slider", "cutter"]
## A fly's ways of moving, as the panel names them, and what the data calls them.
const FLY_MOVES := [["Still", "still"], ["Back and forth", "line"], ["Orbit", "orbit"]]
## How far over the floor a fly is put down.
const FLY_LIFT := 2.0
## How far the mouse has to move, in pixels, before a press becomes a drag.
const DRAG_START := 5.0

## A name a person would use for each type, and a line on what it is for.
const INFO := {
	"piece": ["Kit piece", "A solid piece of the level. Stone holds silk; slick metal doesn't."],
	"start": ["Spider start", "Where the spider starts, facing the way the green cone points (R turns it). A level has one."],
	"exit": ["Exit bag", "Walk into it to finish the level. A level has one, and it stays shut until every fly is taken."],
	"fly": ["Fly", "Hit it with a web and it's caught: a grapple point in mid-air. Reach it, or call the web home, to take it. The bag opens once every fly is taken."],
	"crate": ["Crate", "Silk sticks to it; call the web home and the crate comes along. Sit one on a plate to hold it down."],
	"plate": ["Pressure plate", "A crate on it powers its link: every door and platform on the same link."],
	"door": ["Door", "Slides open while its link is powered. Drag the aqua ball to set where it opens to."],
	"platform": ["Moving platform", "Rides along its path. Drag the yellow balls to move its stops. On a link, it only moves while that link is powered."],
	"hazard": ["Hazard", "Red: touch it and the level starts again."],
	"panel": ["Loose board", "Silk sticks to it, but it won't hold the grapple. Call a web on it home and it rips off."],
	"slider": ["Rail block", "Call a web on it home and it slides to the other end of its rail. Drag the orange ball to set where the rail ends."],
	"cutter": ["Silk cutter", "Violet lasers that cut any web flying through and any grapple line across. Harmless to the spider. Paint which cells hold lasers."],
}

## Ready-made pieces at the top of the palette, for the blocks a level is mostly
## built of.
const PRESETS := {
	"stone block": {"label": "Stone block", "piece": "cube", "surface": "stone", "size": [2.0, 2.0, 2.0],
		"tip": "A plain stone block: silk sticks to it. Drag its handles to any size."},
	"slick block": {"label": "Slick block", "piece": "cube", "surface": "slick", "size": [2.0, 2.0, 2.0],
		"tip": "A slick metal block: silk slides off it and the grapple can't hold it."},
	"stone wall": {"label": "Stone wall", "piece": "cube", "surface": "stone", "size": [6.0, 4.0, 0.5],
		"tip": "A thin stone wall, 6 m wide and 4 m high."},
	"slick wall": {"label": "Slick wall", "piece": "cube", "surface": "slick", "size": [6.0, 4.0, 0.5],
		"tip": "A thin slick wall, 6 m wide and 4 m high."},
}

const HELP := """[color=#ffc84d]Camera[/color]
Mouse wheel — zoom toward the mouse
Middle drag, or Alt + left drag — orbit round the selection
Shift + middle drag, or Alt + Shift + left drag — pan
WASD — fly, Q/E — down/up (Shift faster); hold right mouse to look round
F — frame the selection     Home — see the whole level

[color=#ffc84d]Building[/color]
Pick something on the left, then click to put it down
R — turn it 90° (Shift+R 15°)     T — tip it over
Right click or Esc — stop placing

[color=#ffc84d]Changing things[/color]
Click — select     drag — move     Shift + drag — move up and down
Drag a red, green or blue arrow — move along x, y (up) or z only
Drag the coloured squares to stretch from a face
Arrows, PgUp/PgDn — nudge by the grid     [ and ] — grid smaller / bigger
G — pick up and carry (click to drop)
Ctrl+D — copy     Delete — delete
Ctrl+Z — undo     Ctrl+Y or Ctrl+Shift+Z — redo

[color=#ffc84d]The level[/color]
Ctrl+S — save     F5 — play it (Esc in play comes back)
With nothing selected, the right panel holds the level's settings
and lists anything that looks wrong with it."""

var level: Dictionary = {}
var path := ""
var world: Node3D
var camera: Camera3D

## The thing selected, as built.
var selected: Node3D = null

## What a click puts down: a type, or "" to select instead.
var place_type := ""
var place_piece := "cube"
## For a preset: what it is called, its surface and its size.
var place_preset := ""
var snap_index := 1

var _yaw := 0.0
var _pitch := -0.5
var _looking := false
var _right_moved := false
var _orbiting := false
var _panning := false
var _pivot := Vector3.ZERO
var _speed := 12.0
var _ghost_root: Node3D
var _ghost: Node3D = null
var _ghost_rot := Vector3.ZERO
## The ghost's box, about its own origin: for setting it against a wall.
var _ghost_box := AABB()
var _path_mode := false
var _path_height := 0.0
var _undo: Array[String] = []
var _redo: Array[String] = []
var _dirty := false
## A drag under way, or empty: [code]{thing, from, handle, press, started, grab,
## t0, height, last, carry}[/code].
var _drag := {}
var _hovered: Node3D = null
## Where the grid and the cursor are drawn this frame, or [constant Vector3.INF].
var _grid_at := Vector3.INF
var _lines: MeshInstance3D
var _lines_mesh: ImmediateMesh
var _lines_paint: StandardMaterial3D
var _gizmo: EditorGizmo

var _ui: CanvasLayer
var _inspector: VBoxContainer
var _status: Label
var _title: Label
var _open_list: OptionButton
var _grid_list: OptionButton
var _palette_buttons := {}
var _kit_list: VBoxContainer
var _kit_filter: LineEdit
var _help: PanelContainer
var _confirm: ConfirmationDialog
var _status_hold := 0.0
var _flashed := ""

static var _helped := false


# --- setting up --------------------------------------------------------------

func _ready() -> void:
	LevelSky.dress(self)
	# Less haze than in play: an editor looks at a whole level from far off.
	var sky := get_node_or_null("Sky") as WorldEnvironment
	if sky != null:
		sky.environment.fog_density = 0.0012
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	_ghost_root = Node3D.new()
	_ghost_root.name = "Ghost"
	add_child(_ghost_root)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 70.0
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	_lines_mesh = ImmediateMesh.new()
	_lines_paint = StandardMaterial3D.new()
	_lines_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lines_paint.vertex_color_use_as_albedo = true
	_lines_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines_paint.no_depth_test = true
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	_lines.mesh = _lines_mesh
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lines)
	_gizmo = EditorGizmo.new()
	_gizmo.name = "Gizmo"
	add_child(_gizmo)
	_build_ui()
	_rebuild()
	_frame_all()
	_refresh_title()
	if not _helped:
		_helped = true
		_help.visible = true


## Opens [param data] for editing, kept as [param from_path].
func open(data: Dictionary, from_path: String) -> void:
	level = data.duplicate(true)
	if not level.has("objects"):
		level["objects"] = []
	path = from_path
	_undo.clear()
	_redo.clear()
	_dirty = false
	_drag = {}
	if is_inside_tree():
		_rebuild()
		_frame_all()
		_refresh_title()


## Back from a playtest: the camera is the editor's again.
func resume() -> void:
	camera.make_current()
	_rebuild()


func _find(type: String) -> Dictionary:
	for thing in level["objects"]:
		if thing.get("type") == type:
			return thing
	return {}


func _rebuild() -> void:
	selected = null
	_hovered = null
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	LevelBuilder.build(level, world, true)
	_select(null)


## Builds [param thing] again after a change, keeping it selected. The panel on
## the right is built again too, unless [param panel] is false (mid-drag).
func _rebuild_thing(thing: Dictionary, panel := true) -> void:
	for node in world.get_children():
		if node.has_meta(LevelBuilder.THING) and is_same(node.get_meta(LevelBuilder.THING), thing):
			world.remove_child(node)
			node.queue_free()
	var made := LevelBuilder.build_thing(thing, world, true)
	_select(made, panel)
	LevelBuilder.build_ceiling(level, world, true)


func _thing() -> Dictionary:
	if selected == null or not is_instance_valid(selected):
		return {}
	return selected.get_meta(LevelBuilder.THING)


# --- the camera ----------------------------------------------------------------

func _apply_look() -> void:
	camera.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


func _look_at(point: Vector3) -> void:
	var ahead := (point - camera.global_position).normalized()
	_yaw = atan2(-ahead.x, -ahead.z)
	_pitch = asin(clampf(ahead.y, -1.0, 1.0))
	_apply_look()


## The box round everything in the level, the ceiling aside.
func _level_box() -> AABB:
	var box := AABB()
	var first := true
	for node in world.get_children():
		if node.name == "Ceiling":
			continue
		var part := _box_of(node)
		if part.size == Vector3.ZERO:
			continue
		box = part if first else box.merge(part)
		first = false
	return box


## Looks at the whole level from above and behind its start.
func _frame_all() -> void:
	var box := _level_box()
	if box.size == Vector3.ZERO:
		box = AABB(Vector3(-8.0, 0.0, -8.0), Vector3(16.0, 2.0, 16.0))
	var middle := box.get_center()
	var start := _find("start")
	var behind := Vector3(0.0, 0.0, 1.0)
	if not start.is_empty():
		var from := LevelData.vec(start.get("pos")) - middle
		from.y = 0.0
		if from.length() > 1.0:
			behind = from.normalized()
	var span := maxf(maxf(box.size.x, box.size.z), 12.0)
	camera.global_position = middle + behind * span * 0.55 + Vector3.UP * (span * 0.75 + box.size.y * 0.5)
	_look_at(middle)


## Brings the camera in on what is selected, keeping the way it looks.
func _frame_selected() -> void:
	if selected == null:
		_frame_all()
		return
	var box := _box_of(selected)
	var reach := maxf(box.size.length() * 1.8, 9.0)
	camera.global_position = box.get_center() + camera.global_basis.z * reach
	_look_at(box.get_center())


## What orbiting turns round: the selection, or what is under the mouse, or a
## point ahead.
func _find_pivot() -> Vector3:
	if selected != null and is_instance_valid(selected):
		return _box_of(selected).get_center()
	var hit := _ray(PICK_MASK)
	if not hit.is_empty():
		return hit["position"]
	return camera.global_position - camera.global_basis.z * 15.0


func _orbit(by: Vector2) -> void:
	var turn := -by.x * 0.006
	var tilt := clampf(_pitch - by.y * 0.006, -1.5, 1.5) - _pitch
	var offset := camera.global_position - _pivot
	offset = offset.rotated(Vector3.UP, turn)
	var right := camera.global_basis.x.rotated(Vector3.UP, turn)
	offset = offset.rotated(right, tilt)
	_yaw += turn
	_pitch += tilt
	_apply_look()
	camera.global_position = _pivot + offset


func _pan(by: Vector2) -> void:
	var reach := maxf(camera.global_position.distance_to(_pivot), 4.0)
	var basis := camera.global_basis
	camera.global_position += (-basis.x * by.x + basis.y * by.y) * reach * 0.0018


## The wheel: toward what is under the mouse, or back away from it.
func _zoom(closer: bool) -> void:
	var mouse := get_viewport().get_mouse_position()
	var hit := _ray(PICK_MASK)
	var toward: Vector3 = hit["position"] if not hit.is_empty() else \
		camera.project_ray_origin(mouse) + camera.project_ray_normal(mouse) * 20.0
	var gap := camera.global_position.distance_to(toward)
	if closer:
		if gap > 1.5:
			camera.global_position = camera.global_position.lerp(toward, 0.2)
	else:
		camera.global_position += (camera.global_position - toward).normalized() * maxf(gap * 0.25, 1.0)


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	if not typing and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_META):
		var move := Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			move.z -= 1.0
		if Input.is_key_pressed(KEY_S):
			move.z += 1.0
		if Input.is_key_pressed(KEY_A):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			move.x += 1.0
		if Input.is_key_pressed(KEY_E):
			move.y += 1.0
		if Input.is_key_pressed(KEY_Q):
			move.y -= 1.0
		if move != Vector3.ZERO:
			var fast := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
			var basis := camera.global_basis
			var step := basis.x * move.x + Vector3.UP * move.y + basis.z * move.z
			camera.global_position += step.normalized() * _speed * fast * delta
	# The ceiling only gets in the way from above it: show it from below.
	var lid := world.get_node_or_null("Ceiling") as Node3D
	if lid != null:
		lid.visible = camera.global_position.y < lid.global_position.y
	var over_ui := _over_ui()
	_grid_at = Vector3.INF
	_update_ghost(over_ui)
	_hovered = null
	_gizmo.hot = -1
	if not _drag.is_empty():
		_grid_at = _drag.get("shown", Vector3.INF)
	elif not over_ui and not _looking and not _orbiting:
		if _path_mode:
			_grid_at = _cursor_point(_path_height)
		elif place_type == "":
			_gizmo.hot = _gizmo.pick(camera, get_viewport().get_mouse_position())
			if _gizmo.hot < 0:
				var hit := _ray(PICK_MASK)
				_hovered = LevelBuilder.thing_of(hit.get("collider")) if not hit.is_empty() else null
	_gizmo.update_view(camera)
	_draw_lines()
	_status.text = _status_text()


func _over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


# --- the mouse and the keys ----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_button(event as InputEventMouseButton)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _looking:
			_right_moved = true
			_yaw -= motion.relative.x * 0.003
			_pitch = clampf(_pitch - motion.relative.y * 0.003, -1.5, 1.5)
			_apply_look()
		elif _orbiting:
			if _panning or motion.shift_pressed:
				_pan(motion.relative)
			else:
				_orbit(motion.relative)
		elif not _drag.is_empty():
			_drag_to(motion.position, motion.shift_pressed)
		return
	if not (event is InputEventKey) or not event.is_pressed():
		return
	var key := event as InputEventKey
	var ctrl := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_ESCAPE:
			_escape()
		KEY_F1:
			_help.visible = not _help.visible
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
		KEY_D:
			if ctrl:
				duplicate_selected()
			else:
				return
		KEY_Z:
			if ctrl and key.shift_pressed:
				redo()
			elif ctrl:
				undo()
			else:
				return
		KEY_Y:
			if ctrl:
				redo()
			else:
				return
		KEY_S:
			if ctrl:
				save()
			else:
				return
		KEY_F5:
			playtest.emit(level.duplicate(true), path)
		KEY_F:
			_frame_selected()
		KEY_HOME:
			_frame_all()
		KEY_G:
			_carry()
		KEY_R:
			_turn(Vector3(0.0, 15.0 if key.shift_pressed else 90.0, 0.0))
		KEY_T:
			_turn(Vector3(90.0, 0.0, 0.0))
		KEY_BRACKETLEFT:
			set_snap(snap_index - 1)
		KEY_BRACKETRIGHT:
			set_snap(snap_index + 1)
		KEY_LEFT:
			_nudge(Vector3(-1, 0, 0))
		KEY_RIGHT:
			_nudge(Vector3(1, 0, 0))
		KEY_UP:
			_nudge(Vector3(0, 0, -1))
		KEY_DOWN:
			_nudge(Vector3(0, 0, 1))
		KEY_PAGEUP:
			if _path_mode:
				_path_height += snap()
			else:
				_nudge(Vector3(0, 1, 0))
		KEY_PAGEDOWN:
			if _path_mode:
				_path_height -= snap()
			else:
				_nudge(Vector3(0, -1, 0))
		_:
			return
	get_viewport().set_input_as_handled()


func _mouse_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_looking = true
				_right_moved = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_looking = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				if not _right_moved:
					_stop_placing()
		MOUSE_BUTTON_MIDDLE:
			_orbiting = button.pressed
			_panning = button.shift_pressed
			if button.pressed:
				_pivot = _find_pivot()
		MOUSE_BUTTON_LEFT:
			if button.pressed and button.alt_pressed:
				_orbiting = true
				_panning = button.shift_pressed
				_pivot = _find_pivot()
			elif button.pressed:
				get_viewport().gui_release_focus()
				_press(button.position)
			else:
				_orbiting = false
				_release()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not button.pressed:
				return
			var up := button.button_index == MOUSE_BUTTON_WHEEL_UP
			if _looking:
				_speed = clampf(_speed * (1.2 if up else 1.0 / 1.2), 2.0, 80.0)
			else:
				_zoom(up)


func snap() -> float:
	return SNAPS[snap_index]


func set_snap(index: int) -> void:
	snap_index = clampi(index, 0, SNAPS.size() - 1)
	if _grid_list != null:
		_grid_list.select(snap_index)


## Esc: drops what is being carried back where it was, then stops adding stops,
## then stops placing, then lets go of the selection.
func _escape() -> void:
	if _help.visible:
		_help.visible = false
		return
	if not _drag.is_empty():
		_cancel_drag()
		return
	if _path_mode or place_type != "":
		_stop_placing()
		return
	_select(null)


func _stop_placing() -> void:
	if _path_mode:
		_path_mode = false
		_show_inspector()
	if place_type != "":
		choose("")


func _press(mouse: Vector2) -> void:
	if not _drag.is_empty() and _drag.get("carry", false):
		_release()
		return
	if _path_mode and selected != null:
		var at := _cursor_point(_path_height)
		if at != Vector3.INF:
			add_path_point(_thing(), at)
		return
	if place_type != "":
		var at := _place_point()
		if at != Vector3.INF:
			place(place_type, at)
		return
	var handle := _gizmo.pick(camera, mouse)
	if handle >= 0:
		_begin_drag(_gizmo.handles[handle], mouse)
		return
	var hit := _ray(PICK_MASK)
	var node: Node3D = LevelBuilder.thing_of(hit.get("collider")) if not hit.is_empty() else null
	if node != selected:
		_select(node)
	if node != null:
		_begin_drag({}, mouse, hit.get("position", Vector3.INF))


## What the mouse is over in the world.
func _ray(mask: int) -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * 500.0
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)


## Where the mouse points on the level plane at [param height], snapped to the grid.
func _cursor_point(height: float) -> Vector3:
	var point := EditorGizmo.on_plane(camera, get_viewport().get_mouse_position(), height)
	if point == Vector3.INF:
		return point
	var grid := snap()
	return Vector3(snappedf(point.x, grid), height, snappedf(point.z, grid))


## Where a click puts the thing being placed: on whatever the mouse is over, set
## against it — on a floor, up against a wall, hanging under a ledge — or on the
## ground plane if it is over nothing. Snapped to the grid along the surface; the
## surface itself is kept exactly.
func _place_point() -> Vector3:
	var hit := _ray(GameLayers.WORLD | LevelBuilder.EDITOR_PICK)
	if hit.is_empty():
		return _cursor_point(0.0)
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var grid := snap()
	var out := point
	var main := 0
	for axis in 3:
		if absf(normal[axis]) > absf(normal[main]):
			main = axis
	for axis in 3:
		if axis != main:
			out[axis] = snappedf(point[axis], grid)
	# Set it against the surface: move it out along the surface's normal until its
	# box only touches.
	var flat := normal.abs()
	var axis_normal := Vector3.ZERO
	axis_normal[main] = signf(normal[main])
	if flat[main] > 0.7 and _ghost_box.size != Vector3.ZERO:
		var deepest := INF
		for i in 8:
			deepest = minf(deepest, _ghost_box.get_endpoint(i).dot(axis_normal))
		out += axis_normal * -deepest
	return out


# --- dragging ----------------------------------------------------------------------

## Starts a drag: of [param handle], or with an empty one of the selection itself,
## grabbed at [param grab]. It only takes once the mouse moves.
func _begin_drag(handle: Dictionary, mouse: Vector2, grab := Vector3.INF, carry := false) -> void:
	var thing := _thing()
	if thing.is_empty():
		return
	var kind: int = handle.get("kind", -1)
	var height := LevelData.vec(thing.get("pos")).y
	var anchor := LevelData.vec(thing.get("pos"))
	if kind == EditorGizmo.Kind.POINT or kind == EditorGizmo.Kind.END:
		anchor = handle["at"]
		height = anchor.y
	elif kind == EditorGizmo.Kind.SIZE:
		anchor = handle["at"]
	elif kind == EditorGizmo.Kind.MOVE:
		anchor = handle["origin"]
	var on_floor := EditorGizmo.on_plane(camera, mouse, height)
	_drag = {
		"thing": thing,
		"from": thing.duplicate(true),
		"handle": handle,
		"press": mouse,
		"started": carry,
		"carry": carry,
		"anchor": anchor,
		"height": height,
		"grab": on_floor if on_floor != Vector3.INF else anchor,
		"t0": EditorGizmo.along_line(camera, mouse, anchor, handle.get("way", Vector3.UP)),
		"last": JSON.stringify(thing),
		"shown": Vector3.INF,
		"pushed": carry,
	}
	if carry:
		_push_undo()


func _drag_to(mouse: Vector2, vertical: bool) -> void:
	if not _drag["started"]:
		if mouse.distance_to(_drag["press"]) < DRAG_START:
			return
		_drag["started"] = true
		_drag["pushed"] = true
		_push_undo()
	var thing: Dictionary = _drag["thing"]
	var from: Dictionary = _drag["from"]
	var handle: Dictionary = _drag["handle"]
	var kind: int = handle.get("kind", -1)
	var grid := snap()
	var anchor: Vector3 = _drag["anchor"]
	_restore(thing, from)
	if kind == EditorGizmo.Kind.SIZE:
		var axis: int = handle["axis"]
		var t := EditorGizmo.along_line(camera, mouse, anchor, handle["way"])
		if is_nan(t) or is_nan(float(_drag["t0"])):
			return
		var size := LevelData.vec(from["size"])
		var wanted := maxf(snappedf(size[axis] + t - float(_drag["t0"]), grid), grid)
		EditorGizmo.resized(thing, axis, handle["sign"], wanted - size[axis], 0.05)
		_drag["shown"] = anchor + (handle["way"] as Vector3) * (wanted - size[axis])
	elif kind == EditorGizmo.Kind.MOVE:
		var axis: int = handle["axis"]
		var t := EditorGizmo.along_line(camera, mouse, anchor, handle["way"])
		if is_nan(t) or is_nan(float(_drag["t0"])):
			return
		var pos := LevelData.vec(from.get("pos"))
		pos[axis] = snappedf(pos[axis] + t - float(_drag["t0"]), grid)
		_move_thing(thing, pos)
		_drag["shown"] = anchor + pos - LevelData.vec(from.get("pos"))
	else:
		var moved := _dragged_point(mouse, vertical, anchor)
		if moved == Vector3.INF:
			return
		_drag["shown"] = moved
		match kind:
			EditorGizmo.Kind.POINT:
				var points: Array = thing["path"]
				points[handle["index"]] = LevelData.vec_out(moved)
			EditorGizmo.Kind.END:
				thing[handle["key"]] = LevelData.vec_out(moved - LevelData.vec(thing.get("pos")))
			_:
				_move_thing(thing, moved)
	var now := JSON.stringify(thing)
	if now != _drag["last"]:
		_drag["last"] = now
		_rebuild_thing(thing, false)


## Where a dragged point goes: across the level plane at its height, or with
## [param vertical] straight up and down; snapped to the grid.
func _dragged_point(mouse: Vector2, vertical: bool, anchor: Vector3) -> Vector3:
	var grid := snap()
	if vertical:
		var t := EditorGizmo.along_line(camera, mouse, anchor, Vector3.UP)
		if is_nan(t) or is_nan(float(_drag["t0"])):
			return Vector3.INF
		return Vector3(anchor.x, snappedf(anchor.y + t - float(_drag["t0"]), grid * 0.5), anchor.z)
	var on_floor := EditorGizmo.on_plane(camera, mouse, _drag["height"])
	if on_floor == Vector3.INF:
		return Vector3.INF
	var at: Vector3 = anchor + on_floor - (_drag["grab"] as Vector3)
	return Vector3(snappedf(at.x, grid), anchor.y, snappedf(at.z, grid))


func _release() -> void:
	if _drag.is_empty():
		return
	var started: bool = _drag["started"]
	_drag = {}
	if started:
		_show_inspector()


func _cancel_drag() -> void:
	if _drag.is_empty():
		return
	var thing: Dictionary = _drag["thing"]
	var started: bool = _drag["started"]
	var pushed: bool = _drag["pushed"]
	_restore(thing, _drag["from"])
	_drag = {}
	if started:
		_rebuild_thing(thing)
	if pushed and not _undo.is_empty():
		_undo.pop_back()


## Puts [param thing] back as [param from] was, keeping it the same dictionary.
static func _restore(thing: Dictionary, from: Dictionary) -> void:
	thing.clear()
	thing.merge(from.duplicate(true))


## G: picks the selection up to carry with the mouse; a click puts it down.
func _carry() -> void:
	if selected == null:
		return
	var mouse := get_viewport().get_mouse_position()
	_begin_drag({}, mouse, Vector3.INF, true)


# --- doing things ----------------------------------------------------------------

## Chooses what a click puts down: a gameplay type, a preset, a kit piece by name,
## or "" for selecting.
func choose(what: String) -> void:
	_path_mode = false
	place_preset = ""
	if what == "":
		place_type = ""
	elif GAMEPLAY.has(what):
		place_type = what
	elif PRESETS.has(what):
		place_type = "piece"
		place_preset = what
		place_piece = String(PRESETS[what]["piece"])
	else:
		place_type = "piece"
		place_piece = what
	_ghost_rot = Vector3.ZERO
	_make_ghost()
	_refresh_palette()


## The data for a new thing of [param type] at [param at], as the palette has it.
func _new_thing(type: String, at: Vector3) -> Dictionary:
	var thing := LevelData.make(type, at)
	thing["rot"] = LevelData.vec_out(_ghost_rot)
	if type == "piece":
		thing["piece"] = place_piece
		thing["size"] = LevelData.vec_out(PieceLook.size_of(place_piece))
		if place_preset != "":
			var preset: Dictionary = PRESETS[place_preset]
			thing["surface"] = preset["surface"]
			thing["size"] = (preset["size"] as Array).duplicate()
	return thing


## Puts a new thing of [param type] down at [param at]. Returns its data.
func place(type: String, at: Vector3) -> Dictionary:
	_push_undo()
	if type == "start" or type == "exit":
		# One of each: putting it down moves it.
		var existing := _find(type)
		if not existing.is_empty():
			existing["pos"] = LevelData.vec_out(at)
			existing["rot"] = LevelData.vec_out(_ghost_rot)
			_rebuild_thing(existing)
			return existing
	var thing := _new_thing(type, at)
	if type == "fly":
		# Flies hang in the air: put one down a little over where the mouse is.
		thing["pos"] = LevelData.vec_out(at + Vector3.UP * FLY_LIFT)
	level["objects"].append(thing)
	var made := LevelBuilder.build_thing(thing, world, true)
	_select(made)
	LevelBuilder.build_ceiling(level, world, true)
	return thing


func delete_selected() -> void:
	if selected == null:
		return
	var thing := _thing()
	_push_undo()
	var kept: Array = []
	for other in level["objects"]:
		if not is_same(other, thing):
			kept.append(other)
	level["objects"] = kept
	world.remove_child(selected)
	selected.queue_free()
	_select(null)
	LevelBuilder.build_ceiling(level, world, true)


func duplicate_selected() -> void:
	if selected == null:
		return
	var thing := _thing()
	if thing.get("type") == "start" or thing.get("type") == "exit":
		_flash("A level has one %s: there's nothing to copy." % _name_of(thing).to_lower())
		return
	_push_undo()
	var copy: Dictionary = thing.duplicate(true)
	level["objects"].append(copy)
	_move_thing(copy, LevelData.vec(copy.get("pos")) + Vector3(snap() * 2.0, 0.0, 0.0))
	_select(LevelBuilder.build_thing(copy, world, true))
	_begin_drag({}, get_viewport().get_mouse_position(), Vector3.INF, true)
	# The copy is already one step on the undo list; carrying it adds none.
	_undo.pop_back()
	_drag["pushed"] = false


## Moves [param thing] to [param to], and its path with it.
func _move_thing(thing: Dictionary, to: Vector3) -> void:
	var by := to - LevelData.vec(thing.get("pos"))
	thing["pos"] = LevelData.vec_out(to)
	if thing.has("path"):
		var moved: Array = []
		for point in LevelData.path_of(thing):
			moved.append(LevelData.vec_out(point + by))
		thing["path"] = moved


func _nudge(direction: Vector3) -> void:
	if selected == null:
		return
	var thing := _thing()
	_push_undo()
	_move_thing(thing, LevelData.vec(thing.get("pos")) + direction * snap())
	_rebuild_thing(thing)


func _turn(by: Vector3) -> void:
	if place_type != "":
		_ghost_rot = Vector3(fmod(_ghost_rot.x + by.x, 360.0), fmod(_ghost_rot.y + by.y, 360.0),
			_ghost_rot.z)
		_make_ghost()
		return
	if selected == null:
		return
	var thing := _thing()
	_push_undo()
	var turn := LevelData.vec(thing.get("rot")) + by
	thing["rot"] = LevelData.vec_out(Vector3(fmod(turn.x, 360.0), fmod(turn.y, 360.0),
		fmod(turn.z, 360.0)))
	_rebuild_thing(thing)


## Adds a point to the path of [param thing] at [param at]. The first point added
## to an empty path is where the thing is now, so the path starts from it.
func add_path_point(thing: Dictionary, at: Vector3) -> void:
	_push_undo()
	var points: Array = thing.get("path", [])
	if points.is_empty():
		points.append(thing["pos"])
	points.append(LevelData.vec_out(at))
	thing["path"] = points
	_rebuild_thing(thing)
	_path_mode = true


func _select(node: Node3D, panel := true) -> void:
	selected = node
	_gizmo.show_for(_thing())
	if panel:
		_show_inspector()


func _push_undo() -> void:
	_undo.append(JSON.stringify(level))
	if _undo.size() > 200:
		_undo.pop_front()
	_redo.clear()
	_set_dirty(true)


func undo() -> void:
	if _undo.is_empty():
		_flash("Nothing to undo")
		return
	_redo.append(JSON.stringify(level))
	_load_state(_undo.pop_back())


func redo() -> void:
	if _redo.is_empty():
		_flash("Nothing to redo")
		return
	_undo.append(JSON.stringify(level))
	_load_state(_redo.pop_back())


func _load_state(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		level = parsed
		_drag = {}
		_rebuild()
		_set_dirty(true)


func _set_dirty(on: bool) -> void:
	_dirty = on
	_refresh_title()


## Writes the level to where it came from, or somewhere new for a new one. True if
## it was written.
func save(as_new := false) -> bool:
	if path == "" or as_new or path.begins_with("res://") and not _writable(path):
		path = LevelData.save_path(String(level.get("name", "level")))
	var ok := LevelData.save_file(level, path)
	_flash("Saved to %s" % path if ok else "Couldn't save to %s" % path)
	if ok:
		_set_dirty(false)
	_refresh_open_list()
	return ok


func _writable(file: String) -> bool:
	var probe := FileAccess.open(file.get_base_dir() + "/.write_probe", FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file.get_base_dir() + "/.write_probe"))
	return true


## Does [param then] now, or once the person says losing their changes is fine.
func _unsaved_then(then: Callable) -> void:
	if not _dirty:
		then.call()
		return
	for link in _confirm.confirmed.get_connections():
		_confirm.confirmed.disconnect(link["callable"])
	_confirm.confirmed.connect(then, CONNECT_ONE_SHOT)
	_confirm.popup_centered()


# --- what might be wrong with the level ---------------------------------------------

## Anything that looks wrong with the level: [code]{text, thing}[/code] each, the
## thing it is about (or an empty dictionary).
func problems() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if _find("start").is_empty():
		found.append({"text": "There's no spider start.", "thing": {}})
	if _find("exit").is_empty():
		found.append({"text": "There's no exit bag.", "thing": {}})
	var plates := {}
	var users := {}
	var crates := 0
	for thing in level["objects"]:
		var type := String(thing.get("type"))
		var link := String(thing.get("channel", ""))
		match type:
			"crate":
				crates += 1
			"plate":
				plates[link] = int(plates.get(link, 0)) + 1
			"door", "platform":
				if link != "":
					users[link] = int(users.get(link, 0)) + 1
	for thing in level["objects"]:
		var type := String(thing.get("type"))
		var link := String(thing.get("channel", ""))
		match type:
			"door":
				if not plates.has(link):
					found.append({"text": "A door on link \"%s\" has no plate to open it." % link,
						"thing": thing})
			"platform":
				if link != "" and not plates.has(link):
					found.append({"text": "A platform waits for link \"%s\", but no plate powers it." % link,
						"thing": thing})
				if LevelData.path_of(thing).size() < 2:
					found.append({"text": "A platform has nowhere to go: give it another stop.",
						"thing": thing})
			"plate":
				if not users.has(link):
					found.append({"text": "A plate on link \"%s\" works nothing." % link, "thing": thing})
			"slider":
				if LevelData.vec(thing.get("travel")).length() < 0.01:
					found.append({"text": "A rail block has no rail to slide along.", "thing": thing})
	var plate_count := 0
	for link in plates:
		plate_count += int(plates[link])
	if plate_count > crates:
		found.append({"text": "%d plate%s but only %d crate%s to hold them down." % [plate_count,
			"" if plate_count == 1 else "s", crates, "" if crates == 1 else "s"], "thing": {}})
	return found


## Every link name the level uses, sorted.
func links() -> Array[String]:
	var found: Array[String] = []
	for thing in level["objects"]:
		var link := String(thing.get("channel", ""))
		if link != "" and not found.has(link):
			found.append(link)
	found.sort()
	return found


static func link_tint(link: String) -> Color:
	return Color.from_hsv(fposmod(float(link.hash() % 997) / 997.0, 1.0), 0.65, 1.0)


# --- the ghost and the lines --------------------------------------------------------

func _make_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_box = AABB()
	if place_type == "":
		return
	var thing := _new_thing(place_type, Vector3.ZERO)
	_ghost = LevelBuilder.build_thing(thing, _ghost_root, true)
	if _ghost == null:
		return
	_ghost.remove_from_group(LevelBuilder.GROUP)
	for node in [_ghost] + _all_under(_ghost):
		var body := node as CollisionObject3D
		if body != null:
			body.collision_layer = 0
			body.collision_mask = 0
		if node is RigidBody3D:
			(node as RigidBody3D).freeze = true
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).transparency = 0.35
	if thing.has("size"):
		var size := LevelData.vec(thing["size"])
		_ghost_box = LevelData.transform_of(thing) * AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)
	else:
		_ghost_box = AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)


func _update_ghost(over_ui: bool) -> void:
	if _ghost == null:
		return
	var at := Vector3.INF if over_ui or _looking or _orbiting else _place_point()
	_ghost.visible = at != Vector3.INF
	if at != Vector3.INF:
		_ghost.global_position = at + (Vector3.UP * FLY_LIFT if place_type == "fly" else Vector3.ZERO)
		_grid_at = at


func _all_under(node: Node) -> Array:
	var found := []
	for child in node.get_children():
		found.append(child)
		found.append_array(_all_under(child))
	return found


## The box round what [param node] looks like, in the world.
func _box_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part_node in [node] + _all_under(node):
		var view := part_node as VisualInstance3D
		if view == null or view.top_level or not view.is_visible_in_tree():
			continue
		var part: AABB = view.global_transform * view.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		box = AABB(node.global_position - Vector3.ONE * 0.5, Vector3.ONE)
	return box


## The outlines, the links between plates and what they work, and the grid.
func _draw_lines() -> void:
	_lines_mesh.clear_surfaces()
	_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _lines_paint)
	var count := 0
	if selected != null and is_instance_valid(selected):
		count += _box_lines(_box_of(selected).grow(0.05), UiStyle.GOLD)
	if _hovered != null and is_instance_valid(_hovered) and _hovered != selected:
		count += _box_lines(_box_of(_hovered).grow(0.03), Color(1.0, 1.0, 1.0, 0.45))
	count += _link_lines()
	for i in _gizmo.handles.size():
		var handle := _gizmo.handles[i]
		if handle["kind"] == EditorGizmo.Kind.MOVE:
			var tint: Color = EditorGizmo.HOT if i == _gizmo.hot else handle["tint"]
			_line(handle["origin"], handle["at"], tint)
			count += 1
	if _grid_at != Vector3.INF:
		count += _grid_lines(_grid_at)
	if count == 0:
		# An empty surface is an error: a point nobody sees instead.
		_lines_mesh.surface_set_color(Color(0, 0, 0, 0))
		_lines_mesh.surface_add_vertex(Vector3.ZERO)
		_lines_mesh.surface_add_vertex(Vector3.ZERO)
	_lines_mesh.surface_end()


func _line(a: Vector3, b: Vector3, tint: Color, tint_b := Color(0, 0, 0, -1)) -> void:
	_lines_mesh.surface_set_color(tint)
	_lines_mesh.surface_add_vertex(a)
	_lines_mesh.surface_set_color(tint if tint_b.a < 0.0 else tint_b)
	_lines_mesh.surface_add_vertex(b)


func _box_lines(box: AABB, tint: Color) -> int:
	var pairs := [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4],
		[0, 4], [1, 5], [2, 6], [3, 7]]
	for pair in pairs:
		_line(box.get_endpoint(pair[0]), box.get_endpoint(pair[1]), tint)
	return pairs.size()


## A line from every plate to each door and platform on its link, in the link's
## colour.
func _link_lines() -> int:
	var count := 0
	var lift := Vector3(0.0, 0.3, 0.0)
	for plate in level["objects"]:
		if plate.get("type") != "plate":
			continue
		var link := String(plate.get("channel", ""))
		var tint := link_tint(link)
		tint.a = 0.8
		for other in level["objects"]:
			var type := String(other.get("type"))
			if (type == "door" or type == "platform") and String(other.get("channel", "")) == link:
				var size := LevelData.vec(other.get("size"))
				var to := LevelData.transform_of(other) * Vector3(0.0, size.y * 0.5, 0.0)
				_line(LevelData.vec(plate.get("pos")) + lift, to, tint)
				count += 1
	return count


## A patch of grid round [param at], fading out with distance, and a cross at it.
func _grid_lines(at: Vector3) -> int:
	var grid := snap()
	var cell := grid
	while 10.0 / cell > 24.0:
		cell *= 2.0
	var reach := cell * 12.0
	var middle := Vector3(snappedf(at.x, cell), at.y + 0.01, snappedf(at.z, cell))
	var count := 0
	var steps := int(reach / cell)
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps):
			for across in [true, false]:
				var a := middle + (Vector3(i * cell, 0.0, j * cell) if across else Vector3(j * cell, 0.0, i * cell))
				var b := a + (Vector3(0.0, 0.0, cell) if across else Vector3(cell, 0.0, 0.0))
				var fade_a := 1.0 - minf(Vector2(a.x - at.x, a.z - at.z).length() / reach, 1.0)
				var fade_b := 1.0 - minf(Vector2(b.x - at.x, b.z - at.z).length() / reach, 1.0)
				if fade_a <= 0.0 and fade_b <= 0.0:
					continue
				_line(a, b, Color(1, 1, 1, fade_a * 0.35), Color(1, 1, 1, fade_b * 0.35))
				count += 1
	var gold := UiStyle.GOLD
	_line(at + Vector3(-0.5, 0.02, 0.0), at + Vector3(0.5, 0.02, 0.0), gold)
	_line(at + Vector3(0.0, 0.02, -0.5), at + Vector3(0.0, 0.02, 0.5), gold)
	if absf(at.y) > 0.05:
		_line(at, Vector3(at.x, 0.0, at.z), Color(gold, 0.4))
	return count + 3


# --- the panels -------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	add_child(_ui)
	var theme := UiStyle.theme()

	# The palette, down the left.
	var left := PanelContainer.new()
	left.theme = theme
	left.anchor_bottom = 1.0
	left.offset_left = 10
	left.offset_right = 250
	left.offset_top = 62
	left.offset_bottom = -44
	_ui.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var palette := VBoxContainer.new()
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(palette)
	palette.add_child(_palette_button("Select and move", "",
		"Click a thing to select it; drag it to move it. Esc or right click gets you back here."))
	palette.add_child(_heading("Build"))
	for what in PRESETS:
		palette.add_child(_palette_button(String(PRESETS[what]["label"]), what, String(PRESETS[what]["tip"])))
	palette.add_child(_heading("Gameplay"))
	for type in GAMEPLAY:
		palette.add_child(_palette_button(String(INFO[type][0]), type, String(INFO[type][1])))
	var names := Kit.names()
	var kit_toggle := Button.new()
	kit_toggle.text = "Kit pieces (%d)  ▸" % names.size()
	kit_toggle.flat = true
	kit_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	kit_toggle.add_theme_color_override("font_color", UiStyle.GOLD)
	kit_toggle.tooltip_text = "Every piece in the kit: stairs, ramps, pillars, walls and more."
	palette.add_child(kit_toggle)
	var kit := VBoxContainer.new()
	kit.visible = false
	palette.add_child(kit)
	kit_toggle.pressed.connect(func() -> void:
		kit.visible = not kit.visible
		kit_toggle.text = "Kit pieces (%d)  %s" % [names.size(), "▾" if kit.visible else "▸"])
	_kit_filter = LineEdit.new()
	_kit_filter.placeholder_text = "Search pieces…"
	_kit_filter.clear_button_enabled = true
	_kit_filter.text_changed.connect(func(text: String) -> void:
		for child in _kit_list.get_children():
			(child as Control).visible = text == "" or (child as Button).text.containsn(text))
	kit.add_child(_kit_filter)
	_kit_list = VBoxContainer.new()
	kit.add_child(_kit_list)
	for piece in names:
		_kit_list.add_child(_palette_button(piece, piece, "The kit's \"%s\", stone to start with." % piece))

	# The file and the play button, along the top.
	var top := PanelContainer.new()
	top.theme = theme
	top.anchor_right = 1.0
	top.offset_left = 10
	top.offset_top = 8
	top.offset_right = -10
	_ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiStyle.GOLD)
	_title.custom_minimum_size = Vector2(200, 0)
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_open_list = OptionButton.new()
	_open_list.custom_minimum_size = Vector2(180, 0)
	_open_list.tooltip_text = "Open another level to edit"
	_open_list.item_selected.connect(_on_open_chosen)
	bar.add_child(_open_list)
	bar.add_child(_tipped(UiStyle.button("New", func() -> void:
		_unsaved_then(func() -> void: open(LevelData.blank(), ""))), "Start a new level"))
	bar.add_child(_tipped(UiStyle.button("Save", func() -> void: save()), "Save (Ctrl+S)"))
	bar.add_child(_tipped(UiStyle.button("Save as new", func() -> void: save(true)),
		"Save a copy under the level's name"))
	bar.add_child(_spacer(12))
	bar.add_child(_tipped(UiStyle.button("Undo", undo), "Undo (Ctrl+Z)"))
	bar.add_child(_tipped(UiStyle.button("Redo", redo), "Redo (Ctrl+Y)"))
	bar.add_child(_spacer(12))
	_grid_list = OptionButton.new()
	for size in SNAPS:
		_grid_list.add_item("Grid %s m" % String.num(size))
	_grid_list.select(snap_index)
	_grid_list.tooltip_text = "How far things snap: [ and ] change it"
	_grid_list.item_selected.connect(set_snap)
	bar.add_child(_grid_list)
	bar.add_child(_tipped(UiStyle.button("Help", func() -> void: _help.visible = not _help.visible),
		"Every key and mouse button (F1)"))
	var play := UiStyle.button("▶ Play", func() -> void: playtest.emit(level.duplicate(true), path))
	play.add_theme_color_override("font_color", UiStyle.GOLD)
	bar.add_child(_tipped(play, "Play it now (F5); Esc in play comes back here"))
	bar.add_child(UiStyle.button("Menu", func() -> void: _unsaved_then(func() -> void: leave.emit())))
	_refresh_open_list()

	# What is selected, or the level, down the right.
	var right := PanelContainer.new()
	right.theme = theme
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -370
	right.offset_right = -10
	right.offset_top = 62
	right.offset_bottom = -44
	_ui.add_child(right)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(right_scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 6)
	right_scroll.add_child(_inspector)

	_status = Label.new()
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.anchor_right = 1.0
	_status.offset_top = -38
	_status.offset_left = 16
	_status.offset_right = -16
	_status.clip_text = true
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_ui.add_child(_status)

	# Every key, over the middle.
	_help = PanelContainer.new()
	_help.theme = theme
	_help.anchor_left = 0.5
	_help.anchor_right = 0.5
	_help.anchor_top = 0.5
	_help.anchor_bottom = 0.5
	_help.offset_left = -330
	_help.offset_right = 330
	_help.offset_top = -270
	_help.offset_bottom = 270
	_help.visible = false
	_ui.add_child(_help)
	var help_column := VBoxContainer.new()
	_help.add_child(help_column)
	help_column.add_child(_heading("How the editor works"))
	var help_text := RichTextLabel.new()
	help_text.bbcode_enabled = true
	help_text.text = HELP
	help_text.fit_content = true
	help_text.scroll_active = false
	help_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help_text.add_theme_font_size_override("normal_font_size", 16)
	help_text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.92))
	help_column.add_child(help_text)
	help_column.add_child(UiStyle.button("Got it", func() -> void: _help.visible = false))

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Unsaved changes"
	_confirm.dialog_text = "This level has changes that aren't saved. Lose them?"
	_confirm.ok_button_text = "Lose them"
	_confirm.cancel_button_text = "Keep editing"
	_ui.add_child(_confirm)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.GOLD)
	return label


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label


## A paragraph, wrapped to the panel.
func _note(text: String, tint := Color(0.78, 0.8, 0.86)) -> Label:
	var label := _small(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(120, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", tint)
	return label


func _spacer(width: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(width, 0)
	return gap


func _tipped(control: Control, tip: String) -> Control:
	control.tooltip_text = tip
	return control


func _spin(least: float, most: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = least
	spin.max_value = most
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.custom_minimum_size = Vector2(80, 0)
	spin.select_all_on_focus = true
	return spin


func _palette_button(text: String, what: String, tip: String) -> Button:
	var made := Button.new()
	made.text = text
	made.toggle_mode = true
	made.alignment = HORIZONTAL_ALIGNMENT_LEFT
	made.tooltip_text = tip
	made.pressed.connect(func() -> void: choose(what))
	_palette_buttons[what] = made
	return made


func _refresh_palette() -> void:
	for what in _palette_buttons:
		var button: Button = _palette_buttons[what]
		var on := false
		if what == "":
			on = place_type == ""
		elif place_preset != "":
			on = what == place_preset
		elif place_type == "piece":
			on = what == place_piece and not PRESETS.has(what)
		else:
			on = what == place_type
		button.set_pressed_no_signal(on)


func _refresh_open_list() -> void:
	if _open_list == null:
		return
	_open_list.clear()
	_open_list.add_item("Open…")
	for entry in LevelData.catalogue():
		_open_list.add_item(String(entry["name"]))
		_open_list.set_item_metadata(_open_list.item_count - 1, entry["path"])
	_open_list.select(0)


func _on_open_chosen(index: int) -> void:
	_open_list.select(0)
	if index <= 0:
		return
	var chosen := String(_open_list.get_item_metadata(index))
	_unsaved_then(func() -> void:
		var data := LevelData.load_file(chosen)
		if not data.is_empty():
			open(data, chosen))


func _refresh_title() -> void:
	if _title == null:
		return
	_title.text = "%s%s" % [String(level.get("name", "New level")), "  •  unsaved" if _dirty else ""]


func _flash(text: String) -> void:
	_flashed = text
	_status_hold = 3.0


func _status_text() -> String:
	if _status_hold > 0.0:
		_status_hold -= get_process_delta_time()
		return _flashed
	var doing := ""
	if not _drag.is_empty() and _drag.get("carry", false):
		doing = "Carrying it: click to put it down, Esc to put it back"
	elif not _drag.is_empty():
		doing = "Dragging: Shift for up and down"
	elif _path_mode:
		doing = "Click to add a stop at height %.1f (PgUp/PgDn to change) · Esc when done" % _path_height
	elif place_type != "":
		doing = "Click to put down a %s · R turn · T tip · Esc or right click to stop" \
			% (_name_of(_new_thing(place_type, Vector3.ZERO)).to_lower())
	elif _gizmo.hot >= 0:
		doing = _handle_hint(_gizmo.handles[_gizmo.hot])
	elif selected != null:
		doing = "Drag an arrow to move along x/y/z, or the thing itself across the floor · squares stretch · R turn · Del delete · F frame"
	else:
		doing = "Click a thing to select it, or pick something on the left to build · wheel zoom · middle drag orbit · WASD fly"
	var where := ""
	if _grid_at != Vector3.INF:
		where = "   ·   x %.2f  y %.2f  z %.2f" % [_grid_at.x, _grid_at.y, _grid_at.z]
	return "%s%s   ·   grid %s m   ·   F1 help" % [doing, where, String.num(snap())]


func _handle_hint(handle: Dictionary) -> String:
	match handle["kind"]:
		EditorGizmo.Kind.SIZE:
			return "Drag to stretch it %s" % ["across", "up or down", "along"][handle["axis"]]
		EditorGizmo.Kind.MOVE:
			return "Drag to move it along %s only" % ["x (red)", "y, up and down (green)", "z (blue)"][handle["axis"]]
		EditorGizmo.Kind.POINT:
			return "Drag to move this stop (Shift: up and down)"
	return "Drag to move where it goes (Shift: up and down)"


func _name_of(thing: Dictionary) -> String:
	var type := String(thing.get("type"))
	if type == "piece":
		if thing.get("piece") == "cube":
			return "%s block" % String(thing.get("surface", "stone")).capitalize()
		return String(thing.get("piece", "piece")).capitalize()
	return String(INFO.get(type, [type.capitalize()])[0])


# --- the panel on the right -----------------------------------------------------------

func _clear_inspector() -> void:
	for child in _inspector.get_children():
		_inspector.remove_child(child)
		child.queue_free()


func _show_inspector() -> void:
	if _inspector == null:
		return
	_clear_inspector()
	var thing := _thing()
	if thing.is_empty():
		_show_level()
		return
	var type := String(thing.get("type"))
	_inspector.add_child(_heading(_name_of(thing)))
	_inspector.add_child(_note(String(INFO.get(type, ["", ""])[1])))
	_vector_row("Position", thing, "pos", 0.25)
	var turn_row := HBoxContainer.new()
	turn_row.add_child(UiStyle.button("Turn 90°", func() -> void: _turn(Vector3(0.0, 90.0, 0.0))))
	turn_row.add_child(UiStyle.button("Tip 90°", func() -> void: _turn(Vector3(90.0, 0.0, 0.0))))
	turn_row.add_child(UiStyle.button("Square up", func() -> void:
		_push_undo()
		thing["rot"] = [0.0, 0.0, 0.0]
		_rebuild_thing(thing)))
	_inspector.add_child(turn_row)
	_vector_row("Turned (degrees)", thing, "rot", 15.0)
	if thing.has("size"):
		_vector_row("Size (metres)", thing, "size", 0.25)
	if thing.has("surface") and type != "panel":
		var surfaces := OptionButton.new()
		surfaces.add_item("Stone: silk sticks")
		surfaces.add_item("Slick: silk slides off")
		surfaces.select(0 if thing["surface"] == Surfaces.STONE else 1)
		surfaces.item_selected.connect(func(index: int) -> void:
			_push_undo()
			thing["surface"] = Surfaces.KINDS[index]
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("Surface", surfaces))
	if thing.has("piece"):
		var pieces := OptionButton.new()
		var names := Kit.names()
		for i in names.size():
			pieces.add_item(names[i])
			if names[i] == thing["piece"]:
				pieces.select(i)
		pieces.item_selected.connect(func(index: int) -> void:
			_push_undo()
			thing["piece"] = names[index]
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("Looks like", pieces))
	if thing.has("channel"):
		_link_row(thing)
	if thing.has("open"):
		_vector_row("Opens by (metres)", thing, "open", 0.25)
	if type == "fly":
		_fly_rows(thing)
	elif thing.has("travel"):
		_vector_row("Rail runs (metres)", thing, "travel", 0.25)
	if type == "cutter":
		_mask_rows(thing)
	for number in ["speed", "wait"]:
		if thing.has(number):
			var spin := _spin(0, 60, 0.1)
			spin.suffix = "m/s" if number == "speed" else "s"
			spin.set_value_no_signal(float(thing[number]))
			spin.value_changed.connect(func(value: float) -> void:
				_push_undo()
				thing[number] = value
				_rebuild_thing(thing))
			_inspector.add_child(_labelled("Speed" if number == "speed" else "Waits at stops", spin))
	if thing.has("loop"):
		var loop := CheckBox.new()
		loop.text = "Go round in a loop (else back and forth)"
		loop.button_pressed = bool(thing["loop"])
		loop.toggled.connect(func(on: bool) -> void:
			_push_undo()
			thing["loop"] = on
			_rebuild_thing(thing))
		_inspector.add_child(loop)
	if thing.has("path"):
		var count := (thing["path"] as Array).size()
		_inspector.add_child(_small("Path: %d stop%s" % [count, "" if count == 1 else "s"]))
		var row := HBoxContainer.new()
		row.add_child(_tipped(UiStyle.button("Add stops", func() -> void:
			_path_mode = true
			_path_height = LevelData.vec(thing.get("pos")).y), "Then click in the level to add each stop"))
		row.add_child(UiStyle.button("Remove last", func() -> void:
			var points: Array = thing.get("path", [])
			if points.size() <= 1:
				return
			_push_undo()
			points.pop_back()
			_rebuild_thing(thing)))
		_inspector.add_child(row)
	var actions := HBoxContainer.new()
	actions.add_child(_tipped(UiStyle.button("Copy", duplicate_selected), "Ctrl+D"))
	actions.add_child(_tipped(UiStyle.button("Delete", delete_selected), "Delete"))
	actions.add_child(_tipped(UiStyle.button("Frame", _frame_selected), "F"))
	_inspector.add_child(actions)


## The level's own settings, and anything wrong with it: the panel when nothing
## is selected.
func _show_level() -> void:
	_inspector.add_child(_heading("This level"))
	var name_edit := LineEdit.new()
	name_edit.text = String(level.get("name", "New level"))
	name_edit.text_changed.connect(func(text: String) -> void:
		if not _dirty:
			_push_undo()
		level["name"] = text
		_refresh_title())
	_inspector.add_child(_labelled("Name", name_edit))
	_setting("Webs out at once", "webs", 2.0, 1, 6, 1, "",
		"How many webs the spider can have out at the same time.")
	_setting("Par time", "par", 60.0, 0, 600, 1, "s", "A time to beat.")
	_setting("Fall out below", "kill_y", -20.0, -200, 50, 1, "m",
		"Fall below this height and the level starts again.")
	_setting("Ceiling at", "ceiling", 0.0, 0, 300, 1, "m",
		"The slick lid over the level. 0 puts it 6 m over the top of everything.")
	_inspector.add_child(_heading("Checks"))
	var wrong := problems()
	if wrong.is_empty():
		_inspector.add_child(_note("Nothing looks wrong: it has a start and an exit, and every link has a plate and something to work.",
			Color(0.55, 0.9, 0.6)))
	for problem in wrong:
		var about: Dictionary = problem["thing"]
		var button := Button.new()
		button.text = "⚠ " + String(problem["text"])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(120, 0)
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		if not about.is_empty():
			button.tooltip_text = "Click to select it"
			button.pressed.connect(func() -> void:
				_select_thing(about)
				_frame_selected())
		_inspector.add_child(button)
	_inspector.add_child(_heading("Getting started"))
	_inspector.add_child(_note("Pick something on the left and click in the level to put it down. Click a thing to select it and drag to move it. Press F1 any time to see every key."))


func _setting(text: String, key: String, fallback: float, least: float, most: float, step: float,
		unit: String, tip: String) -> void:
	var spin := _spin(least, most, step)
	spin.suffix = unit
	spin.tooltip_text = tip
	spin.set_value_no_signal(float(level.get(key, fallback)))
	spin.value_changed.connect(func(value: float) -> void:
		_push_undo()
		level[key] = int(value) if key == "webs" else value
		if key == "ceiling":
			LevelBuilder.build_ceiling(level, world, true))
	var row := _labelled(text, spin)
	row.tooltip_text = tip
	_inspector.add_child(row)


func _select_thing(thing: Dictionary) -> void:
	for node in world.get_children():
		if node.has_meta(LevelBuilder.THING) and is_same(node.get_meta(LevelBuilder.THING), thing):
			_select(node)
			return


## Which link a plate, door or platform is on: a list of the links there are, a
## new one, and (for a platform) none.
func _link_row(thing: Dictionary) -> void:
	var type := String(thing.get("type"))
	var choices: Array[String] = []
	var picker := OptionButton.new()
	if type == "platform":
		picker.add_item("None: always moving")
		choices.append("")
	for link in links():
		picker.add_item("Link \"%s\"" % link)
		choices.append(link)
	picker.add_item("New link…")
	var now := String(thing.get("channel", ""))
	var at := choices.find(now)
	picker.select(at if at >= 0 else 0)
	picker.item_selected.connect(func(index: int) -> void:
		_push_undo()
		if index >= choices.size():
			thing["channel"] = _new_link_name()
		else:
			thing["channel"] = choices[index]
		_rebuild_thing(thing))
	var row := _labelled("Link", picker)
	if now != "":
		var swatch := ColorRect.new()
		swatch.color = link_tint(now)
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
	_inspector.add_child(row)
	if now != "":
		var plates := 0
		var works := 0
		for other in level["objects"]:
			if String(other.get("channel", "")) != now or is_same(other, thing):
				continue
			if other.get("type") == "plate":
				plates += 1
			else:
				works += 1
		var told := "Pressed by %d other plate%s; works %d door%s or platform%s." % [plates,
			"" if plates == 1 else "s", works, "" if works == 1 else "s", "" if works == 1 else "s"] \
			if type == "plate" else \
			"Powered by %d plate%s. Things on the same link are joined by a line." % [plates,
			"" if plates == 1 else "s"]
		_inspector.add_child(_note(told))
	if now == "":
		return
	var rename := LineEdit.new()
	rename.placeholder_text = "Rename this link…"
	rename.tooltip_text = "Type a new name and press Enter: everything on this link follows."
	rename.text_submitted.connect(func(text: String) -> void:
		var named := text.strip_edges()
		if named == "":
			return
		_push_undo()
		for other in level["objects"]:
			if String(other.get("channel", "")) == now:
				other["channel"] = named
		_rebuild_thing(thing))
	_inspector.add_child(rename)


## How a fly moves: still, back and forth (with the orange ball to drag to its far
## end), or round in an orbit; how long a trip takes; and its glow.
func _fly_rows(thing: Dictionary) -> void:
	var how := String(thing.get("move", "still"))
	var moves := OptionButton.new()
	for i in FLY_MOVES.size():
		moves.add_item(FLY_MOVES[i][0])
		if FLY_MOVES[i][1] == how:
			moves.select(i)
	moves.item_selected.connect(func(index: int) -> void:
		_push_undo()
		set_fly_move(thing, String(FLY_MOVES[index][1]))
		_rebuild_thing(thing))
	_inspector.add_child(_labelled("Moves", moves))
	if how == "line":
		_vector_row("Flies to (metres from here)", thing, "travel", 0.25)
		_inspector.add_child(_note("Or drag the orange ball to its far end."))
	elif how == "orbit":
		_vector_row("Round the axis", thing, "axis", 0.25)
		var reach := _spin(0.25, 50, 0.25)
		reach.suffix = "m"
		reach.set_value_no_signal(float(thing.get("radius", 2.5)))
		reach.value_changed.connect(func(value: float) -> void:
			_push_undo()
			thing["radius"] = value
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("This far out", reach))
	if how != "still":
		var trip := _spin(0.2, 60, 0.1)
		trip.suffix = "s"
		trip.tooltip_text = "How long one trip takes: there and back, or once round."
		trip.set_value_no_signal(float(thing.get("period", 4.0)))
		trip.value_changed.connect(func(value: float) -> void:
			_push_undo()
			thing["period"] = value
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("One trip takes", trip))
		var start := _spin(0, 1, 0.05)
		start.tooltip_text = "How far into a trip it is when the clock starts: 0 to 1."
		start.set_value_no_signal(float(thing.get("phase", 0.0)))
		start.value_changed.connect(func(value: float) -> void:
			_push_undo()
			thing["phase"] = value
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("Starts this far in", start))
		_inspector.add_child(_note("Flies keep to the level's clock: every try, the same fly is in the same place at the same time."))
	var glow := CheckBox.new()
	glow.text = "Glows yellow"
	glow.button_pressed = bool(thing.get("glow", true))
	glow.toggled.connect(func(on: bool) -> void:
		_push_undo()
		thing["glow"] = on
		_rebuild_thing(thing))
	_inspector.add_child(glow)


## Sets how [param thing], a fly, moves, giving it what that way of moving needs
## and taking away what it does not.
static func set_fly_move(thing: Dictionary, how: String) -> void:
	thing["move"] = how
	if how == "line":
		if not thing.has("travel"):
			thing["travel"] = [0.0, 0.0, -4.0]
	else:
		thing.erase("travel")
	if how == "orbit":
		if not thing.has("axis"):
			thing["axis"] = [0.0, 1.0, 0.0]
		if not thing.has("radius"):
			thing["radius"] = 2.5
	else:
		thing.erase("axis")
		thing.erase("radius")


func _new_link_name() -> String:
	var taken := links()
	for letter in "abcdefghijklmnopqrstuvwxyz":
		if not taken.has(letter):
			return letter
	return "link %d" % (taken.size() + 1)


## A silk cutter's cells, to paint.
func _mask_rows(thing: Dictionary) -> void:
	_inspector.add_child(_small("Lasers: click or drag to paint (%s m cells)" % String.num(SilkCutter.CELL)))
	var cells := MaskGrid.new()
	cells.setup(LevelData.vec(thing.get("size")), thing.get("mask", []), 300.0)
	cells.changed.connect(func(mask: Array) -> void:
		_push_undo()
		thing["mask"] = mask
		_rebuild_thing(thing, false))
	_inspector.add_child(cells)
	var row := HBoxContainer.new()
	row.add_child(UiStyle.button("All lasers", func() -> void: cells.fill(true)))
	row.add_child(UiStyle.button("All open", func() -> void: cells.fill(false)))
	row.add_child(UiStyle.button("Flip", func() -> void: cells.invert()))
	_inspector.add_child(row)


func _labelled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _small(text)
	label.custom_minimum_size = Vector2(118, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


## Three boxes for one vector of [param thing], at [param key], marked x, y and z
## in the colours of the handles.
func _vector_row(text: String, thing: Dictionary, key: String, step: float) -> void:
	_inspector.add_child(_small(text))
	var row := HBoxContainer.new()
	var value := LevelData.vec(thing.get(key))
	for axis in 3:
		var mark := Label.new()
		mark.text = ["x", "y", "z"][axis]
		mark.add_theme_color_override("font_color", EditorGizmo.AXIS_TINTS[axis])
		mark.add_theme_font_size_override("font_size", 15)
		row.add_child(mark)
		# A range that is a whole number of steps either side of nought: a SpinBox
		# snaps to its minimum plus steps, and -1000 in 15s never lands on 0.
		var spin := _spin(-1080, 1080, step)
		spin.custom_minimum_size = Vector2(0, 0)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.set_value_no_signal(value[axis])
		spin.value_changed.connect(func(changed: float) -> void:
			_push_undo()
			var now := LevelData.vec(thing.get(key))
			now[axis] = changed
			if key == "pos":
				_move_thing(thing, now)
			else:
				thing[key] = LevelData.vec_out(now)
			_rebuild_thing(thing))
		row.add_child(spin)
	_inspector.add_child(row)
