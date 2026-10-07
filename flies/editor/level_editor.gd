class_name LevelEditor
extends Node3D

## Making levels, in the game.
##
## A free camera over the level as it will be played: hold the right mouse button
## to look round, and WASD with Q and E to move (Shift for faster). Pick a thing
## from the palette on the left — the gameplay pieces, then every piece of the kit
## — and click to put it down where the cursor is, snapped to the grid. Click a
## thing to select it; its every setting is on the right. Play it with F5, and Esc
## from the pause menu comes back here.
##
## [codeblock]
## left click      place / select          R / Shift+R  turn 90° / 15° about up
## G               grab and move           T            turn 90° about across
## Ctrl+D          duplicate               Delete / X   delete
## arrows, PgUp/Dn nudge by the grid       [ / ]        grid smaller / bigger
## Ctrl+Z          undo                    Ctrl+S       save
## F5              play it                 Esc          stop placing / deselect
## [/codeblock]

signal playtest(level: Dictionary, path: String)
signal leave()

const PICK_MASK := GameLayers.WORLD | GameLayers.PREY | LevelBuilder.EDITOR_PICK
const SNAPS := [0.25, 0.5, 1.0, 2.0]
const GAMEPLAY := ["start", "exit", "crate", "plate", "door", "platform", "hazard", "panel",
	"slider"]

var level: Dictionary = {}
var path := ""
var world: Node3D
var camera: Camera3D

## The thing selected, as built.
var selected: Node3D = null

## What a click puts down: a type, or "" to select instead.
var place_type := ""
var place_piece := "cube"
var snap_index := 1

var _yaw := 0.0
var _pitch := -0.5
var _looking := false
var _speed := 12.0
var _ghost_root: Node3D
var _ghost: Node3D = null
var _ghost_rot := Vector3.ZERO
var _grabbing := false
var _grab_was := Vector3.ZERO
var _path_mode := false
var _path_height := 0.0
var _undo: Array[String] = []
var _outline: MeshInstance3D
var _outline_mesh: ImmediateMesh
var _outline_paint: StandardMaterial3D

var _ui: CanvasLayer
var _inspector: VBoxContainer
var _status: Label
var _name_edit: LineEdit
var _webs_spin: SpinBox
var _kill_spin: SpinBox
var _par_spin: SpinBox
var _ceiling_spin: SpinBox
var _open_list: OptionButton
var _palette_buttons := {}
var _status_hold := 0.0


# --- setting up --------------------------------------------------------------

func _ready() -> void:
	LevelSky.dress(self)
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
	_outline_mesh = ImmediateMesh.new()
	_outline_paint = StandardMaterial3D.new()
	_outline_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_paint.albedo_color = UiStyle.GOLD
	_outline_paint.no_depth_test = true
	_outline = MeshInstance3D.new()
	_outline.mesh = _outline_mesh
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline)
	_build_ui()
	_rebuild()
	_frame_start()
	_refresh_settings()


## Opens [param data] for editing, kept as [param from_path].
func open(data: Dictionary, from_path: String) -> void:
	level = data.duplicate(true)
	if not level.has("objects"):
		level["objects"] = []
	path = from_path
	_undo.clear()
	if is_inside_tree():
		_rebuild()
		_frame_start()
		_refresh_settings()


## Back from a playtest: the camera is the editor's again.
func resume() -> void:
	camera.make_current()
	_rebuild()


func _frame_start() -> void:
	var start := _find("start")
	var at := LevelData.vec(start.get("pos"), Vector3.ZERO) if not start.is_empty() else Vector3.ZERO
	camera.global_position = at + Vector3(0.0, 7.0, 11.0)
	_yaw = 0.0
	_pitch = -0.45
	_apply_look()


func _find(type: String) -> Dictionary:
	for thing in level["objects"]:
		if thing.get("type") == type:
			return thing
	return {}


func _rebuild() -> void:
	selected = null
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	LevelBuilder.build(level, world, true)
	_show_inspector()


## Builds [param thing] again after a change, keeping it selected.
func _rebuild_thing(thing: Dictionary) -> void:
	for node in world.get_children():
		if node.has_meta(LevelBuilder.THING) and is_same(node.get_meta(LevelBuilder.THING), thing):
			world.remove_child(node)
			node.queue_free()
	var made := LevelBuilder.build_thing(thing, world, true)
	_select(made)
	LevelBuilder.build_ceiling(level, world, true)


# --- the camera ----------------------------------------------------------------

func _apply_look() -> void:
	camera.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	var typing := get_viewport().gui_get_focus_owner() is LineEdit \
		or get_viewport().gui_get_focus_owner() is SpinBox
	if not typing:
		var move := Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			move.z -= 1.0
		if Input.is_key_pressed(KEY_S):
			move.z += 1.0
		if Input.is_key_pressed(KEY_A):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D) and not Input.is_key_pressed(KEY_CTRL):
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
	_update_ghost()
	if _grabbing and selected != null:
		var at := _cursor_point(LevelData.vec(selected.get_meta(LevelBuilder.THING).get("pos")).y)
		if at != Vector3.INF:
			selected.global_position = at
	_draw_outline()
	_status.text = _status_text()


# --- the mouse and the keys ----------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_looking = button.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		elif button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().gui_release_focus()
			_click()
		elif button.pressed and _looking and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_speed = minf(_speed * 1.2, 80.0)
		elif button.pressed and _looking and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_speed = maxf(_speed / 1.2, 2.0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _looking:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.003
		_pitch = clampf(_pitch - motion.relative.y * 0.003, -1.5, 1.5)
		_apply_look()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.is_pressed():
		return
	var key := event as InputEventKey
	var ctrl := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_ESCAPE:
			_escape()
		KEY_DELETE, KEY_BACKSPACE, KEY_X:
			delete_selected()
		KEY_D:
			if ctrl:
				duplicate_selected()
			else:
				return
		KEY_Z:
			if ctrl:
				undo()
			else:
				return
		KEY_S:
			if ctrl:
				save()
			else:
				return
		KEY_F5, KEY_P:
			playtest.emit(level.duplicate(true), path)
		KEY_G:
			_start_grab()
		KEY_R:
			_turn(Vector3(0.0, 15.0 if key.shift_pressed else 90.0, 0.0))
		KEY_T:
			_turn(Vector3(90.0, 0.0, 0.0))
		KEY_BRACKETLEFT:
			snap_index = maxi(snap_index - 1, 0)
		KEY_BRACKETRIGHT:
			snap_index = mini(snap_index + 1, SNAPS.size() - 1)
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
		KEY_1:
			choose("")
		_:
			return
	get_viewport().set_input_as_handled()


func snap() -> float:
	return SNAPS[snap_index]


func _escape() -> void:
	if _grabbing:
		_grabbing = false
		if selected != null:
			selected.global_position = _grab_was
		return
	if _path_mode:
		_path_mode = false
		_show_inspector()
		return
	if place_type != "":
		choose("")
		return
	_select(null)


func _click() -> void:
	if _grabbing:
		_grabbing = false
		var thing: Dictionary = selected.get_meta(LevelBuilder.THING)
		_push_undo()
		_move_thing(thing, selected.global_position)
		_rebuild_thing(thing)
		return
	if _path_mode and selected != null:
		var at := _cursor_point(_path_height)
		if at != Vector3.INF:
			add_path_point(selected.get_meta(LevelBuilder.THING), at)
		return
	if place_type != "":
		var at := _cursor_point(0.0, true)
		if at != Vector3.INF:
			place(place_type, at)
		return
	var hit := _ray(PICK_MASK)
	_select(LevelBuilder.thing_of(hit.get("collider")) if not hit.is_empty() else null)


## What the mouse is over in the world.
func _ray(mask: int) -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * 500.0
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)


## Where a click puts something: on whatever the mouse is over, or on the level
## plane at [param height] if it is over nothing — snapped to the grid either way.
## With [param on_surface] the height comes from the surface hit.
func _cursor_point(height: float, on_surface := false) -> Vector3:
	var point := Vector3.INF
	if on_surface:
		var hit := _ray(GameLayers.WORLD | LevelBuilder.EDITOR_PICK)
		if not hit.is_empty():
			point = hit["position"]
	if point == Vector3.INF:
		var mouse := get_viewport().get_mouse_position()
		var from := camera.project_ray_origin(mouse)
		var along := camera.project_ray_normal(mouse)
		var plane := Plane(Vector3.UP, height)
		var crossed: Variant = plane.intersects_ray(from, along)
		if crossed == null:
			return Vector3.INF
		point = crossed
	var grid := snap()
	return Vector3(snappedf(point.x, grid), snappedf(point.y, grid * 0.5), snappedf(point.z, grid))


# --- doing things ----------------------------------------------------------------

## Chooses what a click puts down: a gameplay type, a kit piece by name, or ""
## for selecting.
func choose(what: String) -> void:
	_path_mode = false
	if what == "":
		place_type = ""
	elif GAMEPLAY.has(what):
		place_type = what
	else:
		place_type = "piece"
		place_piece = what
	_ghost_rot = Vector3.ZERO
	_make_ghost()


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
	var thing := LevelData.make(type, at)
	thing["rot"] = LevelData.vec_out(_ghost_rot)
	if type == "piece":
		thing["piece"] = place_piece
		thing["size"] = LevelData.vec_out(PieceLook.size_of(place_piece))
	level["objects"].append(thing)
	var made := LevelBuilder.build_thing(thing, world, true)
	_select(made)
	return thing


func delete_selected() -> void:
	if selected == null:
		return
	var thing: Dictionary = selected.get_meta(LevelBuilder.THING)
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
	var thing: Dictionary = selected.get_meta(LevelBuilder.THING)
	if thing.get("type") == "start" or thing.get("type") == "exit":
		return
	_push_undo()
	var copy: Dictionary = thing.duplicate(true)
	level["objects"].append(copy)
	_move_thing(copy, LevelData.vec(copy.get("pos")) + Vector3(snap() * 2.0, 0.0, 0.0))
	_select(LevelBuilder.build_thing(copy, world, true))
	_start_grab()


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
	var thing: Dictionary = selected.get_meta(LevelBuilder.THING)
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
	var thing: Dictionary = selected.get_meta(LevelBuilder.THING)
	_push_undo()
	var turn := LevelData.vec(thing.get("rot")) + by
	thing["rot"] = LevelData.vec_out(Vector3(fmod(turn.x, 360.0), fmod(turn.y, 360.0),
		fmod(turn.z, 360.0)))
	_rebuild_thing(thing)


func _start_grab() -> void:
	if selected == null:
		return
	_grabbing = true
	_grab_was = selected.global_position


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


func _select(node: Node3D) -> void:
	selected = node
	_show_inspector()


func _push_undo() -> void:
	_undo.append(JSON.stringify(level))
	if _undo.size() > 100:
		_undo.pop_front()


func undo() -> void:
	if _undo.is_empty():
		return
	var parsed: Variant = JSON.parse_string(_undo.pop_back())
	if parsed is Dictionary:
		level = parsed
		_rebuild()
		_refresh_settings()


## Writes the level to where it came from, or somewhere new for a new one. True if
## it was written.
func save(as_new := false) -> bool:
	_read_settings()
	if path == "" or as_new or path.begins_with("res://") and not _writable(path):
		path = LevelData.save_path(String(level.get("name", "level")))
	var ok := LevelData.save_file(level, path)
	_flash("Saved to %s" % path if ok else "Could not save to %s" % path)
	_refresh_open_list()
	return ok


func _writable(file: String) -> bool:
	var probe := FileAccess.open(file.get_base_dir() + "/.write_probe", FileAccess.WRITE)
	if probe == null:
		return false
	probe.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file.get_base_dir() + "/.write_probe"))
	return true


# --- the ghost and the outline ----------------------------------------------------

func _make_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if place_type == "":
		return
	var thing := LevelData.make(place_type, Vector3.ZERO)
	thing["rot"] = LevelData.vec_out(_ghost_rot)
	if place_type == "piece":
		thing["piece"] = place_piece
		thing["size"] = LevelData.vec_out(PieceLook.size_of(place_piece))
	_ghost = LevelBuilder.build_thing(thing, _ghost_root, true)
	if _ghost != null:
		_ghost.remove_from_group(LevelBuilder.GROUP)
		for node in [_ghost] + _all_under(_ghost):
			var body := node as CollisionObject3D
			if body != null:
				body.collision_layer = 0
				body.collision_mask = 0
			if node is RigidBody3D:
				(node as RigidBody3D).freeze = true


func _update_ghost() -> void:
	if _ghost == null:
		return
	var at := _cursor_point(0.0, true)
	_ghost.visible = at != Vector3.INF
	if at != Vector3.INF:
		_ghost.global_position = at


func _all_under(node: Node) -> Array:
	var found := []
	for child in node.get_children():
		found.append(child)
		found.append_array(_all_under(child))
	return found


func _draw_outline() -> void:
	_outline_mesh.clear_surfaces()
	if selected == null or not is_instance_valid(selected):
		return
	var box := AABB()
	var first := true
	for node in [selected] + _all_under(selected):
		var view := node as VisualInstance3D
		if view == null or view.name == "PathLine":
			continue
		var part: AABB = view.global_transform * view.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		box = AABB(selected.global_position - Vector3.ONE * 0.5, Vector3.ONE)
	box = box.grow(0.05)
	_outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _outline_paint)
	for i in 12:
		var edge := _edge(box, i)
		_outline_mesh.surface_add_vertex(edge[0])
		_outline_mesh.surface_add_vertex(edge[1])
	_outline_mesh.surface_end()


static func _edge(box: AABB, i: int) -> Array:
	var a := box.position
	var b := box.end
	var corners := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z),
		Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z),
		Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	var pairs := [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7]]
	return [corners[pairs[i][0]], corners[pairs[i][1]]]


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
	left.offset_right = 240
	left.offset_top = 70
	left.offset_bottom = -50
	_ui.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var palette := VBoxContainer.new()
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(palette)
	palette.add_child(_heading("Tools"))
	palette.add_child(_palette_button("Select (1)", ""))
	palette.add_child(_heading("Gameplay"))
	for type in GAMEPLAY:
		palette.add_child(_palette_button(String(type).capitalize(), type))
	palette.add_child(_heading("Kit pieces"))
	for piece in Kit.names():
		palette.add_child(_palette_button(piece, piece))

	# The level's own settings and the file, along the top.
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
	bar.add_child(_small("Name"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(220, 0)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _read_settings())
	_name_edit.focus_exited.connect(_read_settings)
	bar.add_child(_name_edit)
	bar.add_child(_small("Webs"))
	_webs_spin = _spin(1, 6, 1)
	bar.add_child(_webs_spin)
	bar.add_child(_small("Fall at y"))
	_kill_spin = _spin(-200, 50, 1)
	bar.add_child(_kill_spin)
	bar.add_child(_small("Par s"))
	_par_spin = _spin(0, 600, 1)
	bar.add_child(_par_spin)
	bar.add_child(_small("Ceiling y (0 = auto)"))
	_ceiling_spin = _spin(0, 300, 1)
	bar.add_child(_ceiling_spin)
	for spin in [_webs_spin, _kill_spin, _par_spin, _ceiling_spin]:
		(spin as SpinBox).value_changed.connect(func(_v: float) -> void: _read_settings())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_open_list = OptionButton.new()
	_open_list.custom_minimum_size = Vector2(200, 0)
	_open_list.item_selected.connect(_on_open_chosen)
	bar.add_child(_open_list)
	bar.add_child(UiStyle.button("New", func() -> void: open(LevelData.blank(), "")))
	bar.add_child(UiStyle.button("Save", func() -> void: save()))
	bar.add_child(UiStyle.button("Save as new", func() -> void: save(true)))
	bar.add_child(UiStyle.button("Play (F5)", func() -> void:
		playtest.emit(level.duplicate(true), path)))
	bar.add_child(UiStyle.button("Menu", func() -> void: leave.emit()))
	_refresh_open_list()

	# What is selected, down the right.
	var right := PanelContainer.new()
	right.theme = theme
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -330
	right.offset_right = -10
	right.offset_top = 70
	_ui.add_child(right)
	_inspector = VBoxContainer.new()
	_inspector.custom_minimum_size = Vector2(300, 0)
	right.add_child(_inspector)

	_status = Label.new()
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_top = -40
	_status.offset_left = 250
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_ui.add_child(_status)


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


func _spin(least: float, most: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = least
	spin.max_value = most
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.custom_minimum_size = Vector2(80, 0)
	return spin


func _palette_button(text: String, what: String) -> Button:
	var made := Button.new()
	made.text = text
	made.toggle_mode = true
	made.alignment = HORIZONTAL_ALIGNMENT_LEFT
	made.pressed.connect(func() -> void: choose(what))
	_palette_buttons[what] = made
	return made


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
	if index <= 0:
		return
	var chosen := String(_open_list.get_item_metadata(index))
	var data := LevelData.load_file(chosen)
	if not data.is_empty():
		open(data, chosen)
	_open_list.select(0)


func _refresh_settings() -> void:
	if _name_edit == null:
		return
	_name_edit.text = String(level.get("name", "New level"))
	_webs_spin.set_value_no_signal(float(level.get("webs", 2)))
	_kill_spin.set_value_no_signal(float(level.get("kill_y", -20.0)))
	_par_spin.set_value_no_signal(float(level.get("par", 60.0)))
	_ceiling_spin.set_value_no_signal(float(level.get("ceiling", 0.0)))


func _read_settings() -> void:
	if _name_edit == null:
		return
	level["name"] = _name_edit.text
	level["webs"] = int(_webs_spin.value)
	level["kill_y"] = _kill_spin.value
	level["par"] = _par_spin.value
	var lid := _ceiling_spin.value
	if not is_equal_approx(lid, float(level.get("ceiling", 0.0))):
		level["ceiling"] = lid
		LevelBuilder.build_ceiling(level, world, true)


func _flash(text: String) -> void:
	_status.text = text
	_status_hold = 3.0


func _status_text() -> String:
	if _status_hold > 0.0:
		_status_hold -= get_process_delta_time()
		return _status.text
	for what in _palette_buttons:
		var button: Button = _palette_buttons[what]
		var on: bool = (what == "" and place_type == "") or (what == place_type and place_type != "piece") \
			or (place_type == "piece" and what == place_piece)
		button.set_pressed_no_signal(on)
	var doing := "Selecting"
	if _grabbing:
		doing = "Moving — click to drop, Esc to cancel"
	elif _path_mode:
		doing = "Adding path points — click to add, PgUp/PgDn height (%.1f), Esc when done" \
			% _path_height
	elif place_type != "":
		doing = "Placing %s — click to put down, R to turn" % (place_piece if place_type == "piece"
			else place_type)
	return "%s   ·   grid %.2f m ([ ])   ·   hold right mouse to look, WASD/QE to fly   ·   G move · R/T turn · Ctrl+D copy · Del delete · Ctrl+Z undo · Ctrl+S save · F5 play" \
		% [doing, snap()]


# --- the inspector -------------------------------------------------------------------

func _show_inspector() -> void:
	if _inspector == null:
		return
	for child in _inspector.get_children():
		_inspector.remove_child(child)
		child.queue_free()
	if selected == null or not is_instance_valid(selected):
		_inspector.add_child(_heading("Nothing selected"))
		var hint := Label.new()
		hint.text = "Click a thing to select it,\nor pick something from the\npalette to put down."
		_inspector.add_child(hint)
		return
	var thing: Dictionary = selected.get_meta(LevelBuilder.THING)
	var type := String(thing.get("type"))
	_inspector.add_child(_heading(type.capitalize() + ("  · " + String(thing.get("piece", "")) if
		thing.has("piece") else "")))
	_vector_row("Position", thing, "pos", 0.25)
	_vector_row("Turn (°)", thing, "rot", 15.0)
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
		_inspector.add_child(pieces)
	if thing.has("size"):
		_vector_row("Size (m)", thing, "size", 0.25)
	if thing.has("surface"):
		var surfaces := OptionButton.new()
		for i in Surfaces.KINDS.size():
			surfaces.add_item(Surfaces.KINDS[i])
			if Surfaces.KINDS[i] == thing["surface"]:
				surfaces.select(i)
		surfaces.item_selected.connect(func(index: int) -> void:
			_push_undo()
			thing["surface"] = Surfaces.KINDS[index]
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("Surface", surfaces))
	if thing.has("channel"):
		var channel := LineEdit.new()
		channel.text = String(thing["channel"])
		channel.placeholder_text = "none"
		channel.text_submitted.connect(func(text: String) -> void:
			_push_undo()
			thing["channel"] = text
			_rebuild_thing(thing))
		_inspector.add_child(_labelled("Channel", channel))
	if thing.has("open"):
		_vector_row("Opens by", thing, "open", 0.25)
	if thing.has("travel"):
		_vector_row("Slides by", thing, "travel", 0.25)
	for number in ["speed", "wait"]:
		if thing.has(number):
			var spin := _spin(0, 60, 0.1)
			spin.set_value_no_signal(float(thing[number]))
			spin.value_changed.connect(func(value: float) -> void:
				_push_undo()
				thing[number] = value
				_rebuild_thing(thing))
			_inspector.add_child(_labelled(String(number).capitalize(), spin))
	if thing.has("loop"):
		var loop := CheckBox.new()
		loop.text = "Loop (else back and forth)"
		loop.button_pressed = bool(thing["loop"])
		loop.toggled.connect(func(on: bool) -> void:
			_push_undo()
			thing["loop"] = on
			_rebuild_thing(thing))
		_inspector.add_child(loop)
	if thing.has("path"):
		var count := (thing["path"] as Array).size()
		_inspector.add_child(_small("Path: %d point%s" % [count, "" if count == 1 else "s"]))
		var row := HBoxContainer.new()
		row.add_child(UiStyle.button("Add points", func() -> void:
			_path_mode = true
			_path_height = LevelData.vec(thing.get("pos")).y))
		row.add_child(UiStyle.button("Clear", func() -> void:
			_push_undo()
			thing["path"] = []
			_rebuild_thing(thing)))
		_inspector.add_child(row)
	var actions := HBoxContainer.new()
	actions.add_child(UiStyle.button("Duplicate", duplicate_selected))
	actions.add_child(UiStyle.button("Delete", delete_selected))
	_inspector.add_child(actions)


func _labelled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _small(text)
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


## Three boxes for one vector of [param thing], at [param key].
func _vector_row(text: String, thing: Dictionary, key: String, step: float) -> void:
	_inspector.add_child(_small(text))
	var row := HBoxContainer.new()
	var value := LevelData.vec(thing.get(key))
	for axis in 3:
		# A range that is a whole number of steps either side of nought: a SpinBox
		# snaps to its minimum plus steps, and -1000 in 15s never lands on 0.
		var spin := _spin(-1080, 1080, step)
		spin.custom_minimum_size = Vector2(92, 0)
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
