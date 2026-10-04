class_name FloorPlan
extends RefCounted

## The layout of one floor of the dungeon: which room stands in which square of a
## grid, turned which way, and which doorways between rooms are open.
##
## Laid out the way Spelunky lays its levels out. First a way through: from a room in
## the top row, along the row and dropping to the next at random, down to a room in
## the bottom row — so whatever else the floor holds, there is always a way from where
## you come in to the way down. Then rooms off the side of it, some of them dead ends,
## and now and then a second doorway between two rooms already side by side, so a
## floor is not always a tree. Squares left over are rock, and a floor that comes out
## with fewer than [constant LEAST] rooms is laid out again.
##
## Each square gets a room that fits its doorways, picked by what the room is for
## ([constant Rooms.ENTRANCE] and the rest): a way in at the start, a way down at the
## end, a room for a dead end at most dead ends — the vault — a crossing now and then
## where the way runs straight through — the chasm — and a room for anywhere for the
## rest, turned whichever way makes its doorways line up. The same seed lays out the
## same floor.

## How many squares across, west to east, and down, north to south.
const COLUMNS := 4
const ROWS := 4

## How likely the way through is to drop to the next row rather than go on along this
## one, at each step.
const DROP := 0.35

## How likely a square off the way through is to get a room, how likely two rooms
## side by side are to get a second doorway between them, how likely a dead end is
## to get a room made for one, and a straight way a crossing.
const SIDE_ROOMS := 0.7
const LOOPS := 0.15
const DEAD_ENDS := 0.65
const CROSSINGS := 0.5

## The fewest rooms a floor has: a way straight down with nothing off it is over
## before it starts.
const LEAST := 8

## The grid's steps, by side: north is up the grid, toward row nought.
const STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## What the floor was laid out from.
var seed := 0

## Every square with a room, and what is in it: "room" — its name in [constant
## Rooms.ROOMS] — "turn", the quarter turns clockwise it is turned by, and "open",
## the sides its doorways are open on, as the grid has them.
var cells := {}

## The way through, the square it starts in — the way in — and the one it ends in —
## the way down.
var path: Array[Vector2i] = []
var start := Vector2i.ZERO
var finish := Vector2i.ZERO

var _rng := RandomNumberGenerator.new()


## The floor laid out from [param floor_seed].
static func make(floor_seed: int) -> FloorPlan:
	var plan := FloorPlan.new()
	plan.seed = floor_seed
	plan._lay_out()
	return plan


## Where the middle of square [param cell] is, the floor's middle being the grid's.
static func centre(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) - float(COLUMNS - 1) * 0.5) * Rooms.CELL, 0.0,
		(float(cell.y) - float(ROWS - 1) * 0.5) * Rooms.CELL)


## The square next to [param cell] on [param side].
static func beside(cell: Vector2i, side: int) -> Vector2i:
	return cell + STEPS[side]


## Whether [param cell] is on the grid.
static func on_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS


## Whether there is a doorway open between [param a] and the square beside it on
## [param side].
func is_open(a: Vector2i, side: int) -> bool:
	return cells.has(a) and (cells[a]["open"] as Array).has(side)


## How many rooms can be reached from the way in, going through open doorways.
func reachable() -> int:
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for side in cells[cell]["open"]:
			var next := beside(cell, side)
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size()


# --- laying it out ------------------------------------------------------------

func _lay_out() -> void:
	_rng.seed = seed
	while true:
		cells.clear()
		_way_through()
		_side_rooms()
		_loops()
		if cells.size() >= LEAST:
			break
	for cell in cells:
		_furnish(cell)


## The way through: along a row one way or the other, dropping to the next row at
## random or at the edge, from the top row to the bottom.
func _way_through() -> void:
	var cell := Vector2i(_rng.randi_range(0, COLUMNS - 1), 0)
	start = cell
	_room(cell)
	path = [cell]
	var heading := 1 if _rng.randf() < 0.5 else -1
	while true:
		var drop := _rng.randf() < DROP
		if not drop:
			var next := cell + Vector2i(heading, 0)
			if on_grid(next) and not cells.has(next):
				_join(cell, Rooms.Side.EAST if heading > 0 else Rooms.Side.WEST)
				cell = next
				path.append(cell)
				continue
			drop = true
		if cell.y == ROWS - 1:
			break
		_join(cell, Rooms.Side.SOUTH)
		cell += Vector2i(0, 1)
		path.append(cell)
		heading = 1 if _rng.randf() < 0.5 else -1
	finish = cell


## Rooms off the way: each square left over may get one, through a doorway from a room
## already beside it — going round until a pass adds nothing, so they can grow in
## chains away from the way.
func _side_rooms() -> void:
	var grew := true
	var tried := {}
	while grew:
		grew = false
		var squares: Array[Vector2i] = []
		for x in COLUMNS:
			for y in ROWS:
				var cell := Vector2i(x, y)
				if not cells.has(cell) and not tried.has(cell):
					squares.append(cell)
		_shuffle(squares)
		for cell in squares:
			var sides: Array[int] = []
			for side in 4:
				if cells.has(beside(cell, side)) and beside(cell, side) != finish:
					sides.append(side)
			if sides.is_empty():
				continue
			tried[cell] = true
			if _rng.randf() >= SIDE_ROOMS:
				continue
			_room(cell)
			_join(cell, sides[_rng.randi_range(0, sides.size() - 1)])
			grew = true


## Now and then, a second doorway between two rooms already side by side — but never
## into the way down from the side, or out of the way in, which stay as the way
## through made them.
func _loops() -> void:
	for cell in cells.keys():
		for side in [Rooms.Side.EAST, Rooms.Side.SOUTH]:
			var other := beside(cell, side)
			if not cells.has(other) or is_open(cell, side):
				continue
			if cell == finish or other == finish or cell == start or other == start:
				continue
			if _rng.randf() < LOOPS:
				_join(cell, side)


## A room for [param cell] that fits its open doorways, and the turn that lines them
## up: one for what the square is for if one fits, and one for anywhere if not.
func _furnish(cell: Vector2i) -> void:
	var open: Array[int] = []
	open.assign(cells[cell]["open"])
	var wanted: Array[String] = []
	if cell == start:
		wanted = _picks(Rooms.ENTRANCE)
	elif cell == finish:
		wanted = _picks(Rooms.EXIT)
	elif open.size() == 1 and _rng.randf() < DEAD_ENDS:
		wanted = _picks(Rooms.DEAD_END)
	elif _straight(open) and _rng.randf() < CROSSINGS:
		wanted = _picks(Rooms.CROSSING)
	wanted.append_array(_picks(Rooms.ANY))
	for room_id in wanted:
		var turns: Array[int] = [0, 1, 2, 3]
		_shuffle(turns)
		for turn in turns:
			if _fits(Rooms.turned(Rooms.doors_of(room_id), turn), open):
				cells[cell]["room"] = room_id
				cells[cell]["turn"] = turn
				return
	push_warning("no room fits square %s, open on %s" % [cell, open])


## Whether a room with doorways on [param sides] can have [param open] open.
static func _fits(sides: Array[int], open: Array[int]) -> bool:
	for side in open:
		if not sides.has(side):
			return false
	return true


## Whether [param open] is a straight way through: north and south, or east and west.
static func _straight(open: Array[int]) -> bool:
	return open.size() == 2 and posmod(open[0] - open[1], 4) == 2


## The rooms for [param role], in an order of the floor's own.
func _picks(role: String) -> Array[String]:
	var found := Rooms.with_role(role)
	_shuffle(found)
	return found


func _room(cell: Vector2i) -> void:
	cells[cell] = {"room": "", "turn": 0, "open": []}


## Opens the doorway between [param cell] and the square beside it on [param side],
## from both sides.
func _join(cell: Vector2i, side: int) -> void:
	var other := beside(cell, side)
	if not cells.has(other):
		_room(other)
	if not (cells[cell]["open"] as Array).has(side):
		(cells[cell]["open"] as Array).append(side)
	var back := posmod(side + 2, 4)
	if not (cells[other]["open"] as Array).has(back):
		(cells[other]["open"] as Array).append(back)


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var held: Variant = items[i]
		items[i] = items[j]
		items[j] = held
