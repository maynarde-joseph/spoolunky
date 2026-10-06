class_name PauseMenu
extends CanvasLayer

## Esc while playing: the world stops, and you choose.

signal chose(choice: String)

var _editor_button: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.theme = UiStyle.theme()
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(320, 0)
	panel.add_child(column)
	column.add_child(UiStyle.title("Paused", 34))
	column.add_child(UiStyle.button("Resume", func() -> void: chose.emit("resume")))
	column.add_child(UiStyle.button("Restart (R)", func() -> void: chose.emit("restart")))
	_editor_button = UiStyle.button("Edit this level", func() -> void: chose.emit("editor"))
	column.add_child(_editor_button)
	column.add_child(UiStyle.button("Menu", func() -> void: chose.emit("menu")))


func open(from_editor: bool) -> void:
	_editor_button.text = "Back to the editor" if from_editor else "Edit this level"
	visible = true


func close() -> void:
	visible = false
