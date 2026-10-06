class_name GameRoot
extends Node

## The whole game: the menu, a level being played, and the level editor, one at
## a time.
##
## From the menu you pick a level to play or edit, or start a new one. Playing,
## Esc pauses; R starts again; finishing offers the next level. A level played
## from the editor goes back to the editor instead of the menu.

enum Screen { MENU, PLAY, EDIT }

var screen := Screen.MENU

## The level being played, where it came from, and whether the editor sent it.
var playing: LevelRun = null
var playing_data: Dictionary = {}
var playing_path := ""
var from_editor := false

var editor: LevelEditor = null
var menu: MainMenu = null
var pause: PauseMenu = null

## Set for headless checks: never touch the mouse.
var headless := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	headless = DisplayServer.get_name() == "headless"
	pause = PauseMenu.new()
	pause.name = "Pause"
	add_child(pause)
	pause.chose.connect(_on_pause_choice)
	show_menu()


func show_menu() -> void:
	_clear()
	screen = Screen.MENU
	menu = MainMenu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.play.connect(func(path: String) -> void: play_file(path))
	menu.edit.connect(func(path: String) -> void: edit_file(path))
	menu.create.connect(func() -> void: edit_level(LevelData.blank(), ""))
	menu.quit.connect(func() -> void: get_tree().quit())
	_free_mouse()


## Plays the level in [param path].
func play_file(path: String) -> void:
	var data := LevelData.load_file(path)
	if data.is_empty():
		return
	from_editor = false
	play_level(data, path)


func play_level(data: Dictionary, path: String) -> void:
	_clear()
	screen = Screen.PLAY
	playing_data = data
	playing_path = path
	playing = LevelRun.new()
	playing.name = "Level"
	playing.process_mode = Node.PROCESS_MODE_PAUSABLE
	playing.require_captured_mouse = not headless
	# A level being tried out in the editor keeps no best time: it is still changing.
	playing.setup(data, "" if from_editor else path)
	add_child(playing)
	playing.restart_requested.connect(_restart, CONNECT_DEFERRED)
	playing.finished.connect(func(_t: float, _b: float) -> void: _free_mouse())
	_catch_mouse()


func edit_file(path: String) -> void:
	var data := LevelData.load_file(path)
	if data.is_empty():
		return
	edit_level(data, path)


func edit_level(data: Dictionary, path: String) -> void:
	_clear()
	screen = Screen.EDIT
	if editor == null:
		editor = LevelEditor.new()
		editor.name = "Editor"
		editor.playtest.connect(_on_playtest)
		editor.leave.connect(show_menu)
		editor.open(data, path)
		add_child(editor)
	else:
		if editor.get_parent() == null:
			add_child(editor)
		if not data.is_empty():
			editor.open(data, path)
	_free_mouse()


func _on_playtest(data: Dictionary, path: String) -> void:
	from_editor = true
	if editor != null and editor.get_parent() != null:
		remove_child(editor)
	play_level(data, path)


func _back_to_editor() -> void:
	_clear()
	screen = Screen.EDIT
	if editor.get_parent() == null:
		add_child(editor)
	editor.resume()
	_free_mouse()


func _restart() -> void:
	if screen == Screen.PLAY:
		play_level(playing_data, playing_path)


## Whatever is showing goes, except an editor waiting for its playtest to end.
func _clear() -> void:
	get_tree().paused = false
	pause.visible = false
	if playing != null and is_instance_valid(playing):
		playing.queue_free()
		remove_child(playing)
	playing = null
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null
	if editor != null and editor.get_parent() != null and screen == Screen.EDIT:
		remove_child(editor)


func _unhandled_input(event: InputEvent) -> void:
	if screen != Screen.PLAY or playing == null:
		return
	if playing.done:
		if event.is_action_pressed("ui_accept"):
			_next_level()
		elif event.is_action_pressed("ui_cancel"):
			_leave_play()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_catch_mouse()
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		pause.open(from_editor)
		_free_mouse()
	else:
		pause.close()
		_catch_mouse()


func _on_pause_choice(choice: String) -> void:
	match choice:
		"resume":
			_set_paused(false)
		"restart":
			_set_paused(false)
			_restart()
		"editor":
			if from_editor:
				_back_to_editor()
			else:
				edit_level(playing_data, playing_path)
		"menu":
			show_menu()


func _leave_play() -> void:
	if from_editor:
		_back_to_editor()
	else:
		show_menu()


## The next built-in level after this one, or the menu after the last.
func _next_level() -> void:
	if from_editor:
		_back_to_editor()
		return
	var all := LevelData.catalogue()
	for i in all.size():
		if all[i]["path"] == playing_path and i + 1 < all.size():
			play_file(all[i + 1]["path"])
			return
	show_menu()


func _catch_mouse() -> void:
	if not headless:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _free_mouse() -> void:
	if not headless:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
