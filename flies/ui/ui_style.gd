class_name UiStyle
extends RefCounted

## The look of the menus and the editor's panels: dark glass, gold edges.

const GOLD := Color(1.0, 0.78, 0.3)
const INK := Color(0.07, 0.08, 0.11, 0.9)

static var _theme: Theme = null


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 18
	var normal := _box(Color(0.16, 0.17, 0.22, 0.95), Color(0.3, 0.32, 0.4))
	var hover := _box(Color(0.24, 0.25, 0.32, 0.95), GOLD)
	var pressed := _box(Color(0.36, 0.3, 0.16, 0.95), GOLD)
	for kind in ["Button", "OptionButton", "CheckBox"]:
		_theme.set_stylebox("normal", kind, normal)
		_theme.set_stylebox("hover", kind, hover)
		_theme.set_stylebox("pressed", kind, pressed)
		_theme.set_stylebox("focus", kind, _box(Color(0, 0, 0, 0), GOLD))
	_theme.set_stylebox("panel", "PanelContainer", panel())
	return _theme


static func panel() -> StyleBoxFlat:
	var box := _box(INK, Color(0.3, 0.32, 0.4))
	box.set_content_margin_all(12)
	return box


static func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func title(text: String, size := 40) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label


static func button(text: String, on_press: Callable) -> Button:
	var made := Button.new()
	made.text = text
	made.pressed.connect(on_press)
	return made
