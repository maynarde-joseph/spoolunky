class_name MainMenu
extends Node3D

## The title, and every level: pick one to play or to edit, or start a new one.
## Behind it, the first level turns slowly.

signal play(path: String)
signal edit(path: String)
signal create()
signal quit()

var _list: ItemList
var _levels: Array[Dictionary] = []
var _camera: Camera3D
var _clock := 0.0
var _centre := Vector3.ZERO


func _ready() -> void:
	_levels = LevelData.catalogue()
	_backdrop()
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 80)
	root.add_theme_constant_override("margin_top", 70)
	root.add_theme_constant_override("margin_bottom", 70)
	root.theme = UiStyle.theme()
	layer.add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(column)
	column.add_child(UiStyle.title("Put the Flies in the Bag", 54))
	var sub := Label.new()
	sub.text = "Throw silk. Grapple to it. Call it back. Get out."
	sub.add_theme_font_size_override("font_size", 20)
	column.add_child(sub)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 10)
	panel.add_child(inside)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 300)
	_list.add_theme_font_size_override("font_size", 20)
	inside.add_child(_list)
	for level in _levels:
		var best := LevelRun.best_for(level["path"])
		var line: String = level["name"]
		if not level["built_in"]:
			line += "   (yours)"
		if best >= 0.0:
			line += "   — best " + GameHUD.clock_text(best)
		_list.add_item(line)
	if not _levels.is_empty():
		_list.select(0)
	_list.item_activated.connect(func(index: int) -> void: play.emit(_levels[index]["path"]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inside.add_child(row)
	row.add_child(UiStyle.button("Play", func() -> void:
		var picked := _picked()
		if picked != "":
			play.emit(picked)))
	row.add_child(UiStyle.button("Edit", func() -> void:
		var picked := _picked()
		if picked != "":
			edit.emit(picked)))
	row.add_child(UiStyle.button("New level", func() -> void: create.emit()))
	row.add_child(UiStyle.button("Quit", func() -> void: quit.emit()))
	var keys := Label.new()
	keys.text = "RIGHT MOUSE silk — hold for a bigger web   ·   LEFT MOUSE grapple — onto a stuck web, or ride a flying one into a launch   ·   E / MIDDLE MOUSE pullback\n" \
		+ "WASD walk   ·   SPACE jump   ·   R restart   ·   ESC pause"
	keys.add_theme_font_size_override("font_size", 17)
	keys.modulate = Color(1, 1, 1, 0.85)
	column.add_child(keys)


func _picked() -> String:
	var chosen := _list.get_selected_items()
	if chosen.is_empty():
		return ""
	return _levels[chosen[0]]["path"]


## The first level, built and left running with no spider in it, under a camera
## that circles it.
func _backdrop() -> void:
	LevelSky.dress(self)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	add_child(_camera)
	_camera.make_current()
	if _levels.is_empty():
		return
	var data := LevelData.load_file(_levels[0]["path"])
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	LevelBuilder.build(data, world, false)
	var box := AABB()
	var first := true
	for node in world.get_children():
		var spatial := node as Node3D
		if spatial == null:
			continue
		if first:
			box = AABB(spatial.global_position, Vector3.ZERO)
			first = false
		else:
			box = box.expand(spatial.global_position)
	_centre = box.get_center()


func _process(delta: float) -> void:
	_clock += delta * 0.08
	var at := _centre + Vector3(cos(_clock) * 34.0, 16.0, sin(_clock) * 34.0)
	_camera.look_at_from_position(at, _centre + Vector3(0.0, 2.0, 0.0))
