class_name MaskGrid
extends Control

## A silk cutter's cells, to paint with the mouse: click a cell to flip it, and drag
## to paint every cell the mouse crosses the same way. Violet cells hold lasers,
## dark ones are open. Laid out as the cutter is seen from its front, top row first.

## Painting is done: [param mask] is the cutter's new mask, rows top first.
signal changed(mask: Array)

const LASER := Color(0.72, 0.32, 1.0)
const OPEN := Color(0.1, 0.11, 0.14)
const LINE := Color(0.3, 0.32, 0.4)

var cols := 1
var rows := 1
## Whether each cell holds lasers, by row from the top, then column.
var cells: Array[PackedByteArray] = []

var _cell := 16.0
var _painting := false
var _paint_with := 1
var _hover := Vector2i(-1, -1)


## Shows the cells of a cutter [param extent] in size with [param mask], at most
## [param width] pixels wide.
func setup(extent: Vector3, mask: Array, width := 280.0) -> void:
	var count := SilkCutter.cells_of(extent)
	cols = count.x
	rows = count.y
	cells.clear()
	for line in rows:
		var row := PackedByteArray()
		row.resize(cols)
		var text := String(mask[line]) if line < mask.size() else ""
		for col in cols:
			row[col] = 1 if col >= text.length() or text[col] == "#" else 0
		cells.append(row)
	_cell = clampf(minf(width / cols, 320.0 / rows), 5.0, 22.0)
	custom_minimum_size = Vector2(_cell * cols, _cell * rows)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## The mask the cells make: a row of [code]#[/code] and [code].[/code] each, top
## first; full rows at the bottom are left off, as missing rows hold lasers anyway.
func mask() -> Array:
	var out: Array = []
	for row in cells:
		var text := ""
		for value in row:
			text += "#" if value == 1 else "."
		out.append(text)
	while not out.is_empty() and not String(out[-1]).contains("."):
		out.pop_back()
	return out


## Sets every cell to lasers ([param on]) or open.
func fill(on: bool) -> void:
	for row in cells:
		row.fill(1 if on else 0)
	queue_redraw()
	changed.emit(mask())


## Flips every cell.
func invert() -> void:
	for row in cells:
		for col in cols:
			row[col] = 1 - row[col]
	queue_redraw()
	changed.emit(mask())


## Sets the cell [param col] across and [param line] down from the top.
func set_cell(col: int, line: int, on: bool) -> void:
	if col < 0 or line < 0 or col >= cols or line >= rows:
		return
	cells[line][col] = 1 if on else 0
	queue_redraw()


func _cell_at(point: Vector2) -> Vector2i:
	var at := Vector2i(floori(point.x / _cell), floori(point.y / _cell))
	if at.x < 0 or at.y < 0 or at.x >= cols or at.y >= rows:
		return Vector2i(-1, -1)
	return at


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			var at := _cell_at(button.position)
			if at.x < 0:
				return
			_painting = true
			_paint_with = 1 - cells[at.y][at.x]
			set_cell(at.x, at.y, _paint_with == 1)
		elif _painting:
			_painting = false
			changed.emit(mask())
		accept_event()
	elif event is InputEventMouseMotion:
		var at := _cell_at((event as InputEventMouseMotion).position)
		if at != _hover:
			_hover = at
			queue_redraw()
		if _painting and at.x >= 0:
			set_cell(at.x, at.y, _paint_with == 1)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2i(-1, -1)
		queue_redraw()


func _draw() -> void:
	for line in rows:
		for col in cols:
			var box := Rect2(col * _cell, line * _cell, _cell, _cell)
			var tint := LASER if cells[line][col] == 1 else OPEN
			if Vector2i(col, line) == _hover:
				tint = tint.lightened(0.3)
			draw_rect(box.grow(-1.0), tint)
	for col in cols + 1:
		draw_line(Vector2(col * _cell, 0.0), Vector2(col * _cell, rows * _cell), LINE)
	for line in rows + 1:
		draw_line(Vector2(0.0, line * _cell), Vector2(cols * _cell, line * _cell), LINE)
