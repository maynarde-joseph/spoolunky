class_name SilkReach
extends RefCounted

## How far silk alone gets you in a level: a rough map of everywhere the spider can
## reach by walking, jumping, throwing webs and grappling to them — webs as many
## as it likes, since the Pullback leapfrogs them forever — and by riding webs in
## flight to wherever they stick or stop dead. Silk cutters cut its webs as they
## cut the spider's. Flies are grapple points wherever a throw can reach them —
## every point along a moving fly's way, and every fly as often as it likes — to
## hang from, throw from and drop from. What it leaves out is everything
## else: boards stay on, blocks stay where they start, crates stay put, doors stay
## shut and platforms stand still.
##
## A level whose exit this reaches can be finished with web, grapple, web, grapple,
## and none of its puzzles need solving. It is deliberately generous to the
## spider — it jumps further than the spider does, and steps off a web's rim onto
## anything near it — so that a level it cannot finish is one silk really cannot.
##
##     var found := SilkReach.explore(run)
##     found["reached"]   # whether the exit was reached
##     found["how"]       # if so, the way, step by step

const CELL := 0.5
const THROW := 22.0
const JUMP_ACROSS := 4.0
const JUMP_UP := 1.0
const STEP_UP := 0.5
const RIM := 2.3
## How far a jump off a web carries — webs are springy — across and up.
const WEB_JUMP_ACROSS := 6.0
const WEB_JUMP_UP := 1.7
const DIRECTIONS := 320

var _space: PhysicsDirectSpaceState3D
var _exclude: Array[RID] = []
var _origin := Vector3.ZERO
var _w := 0
var _d := 0
var _top := 0.0
var _bottom := 0.0
## Per column, the heights of the floors in it, top first.
var _floors: Array = []
## Per cell (column * 4 + layer), how it was reached: [from cell or -1, words].
var _came: Dictionary = {}
var _queue: Array[int] = []
var _hazards: Array[AABB] = []
var _spots: Dictionary = {}
## Throws still to make, from webs: [eye, cell, words].
var _throws: Array = []
var _drops_from: Dictionary = {}
var _dirs: Array[Vector3] = []
## Everywhere a fly is, or goes; and which of those a throw has reached.
var _flies: Array[Vector3] = []
var _fly_seen: Dictionary = {}


static func explore(run: LevelRun) -> Dictionary:
	var me := SilkReach.new()
	return me._explore(run)


func _explore(run: LevelRun) -> Dictionary:
	_space = run.get_world_3d().direct_space_state
	_exclude = [run.weaver.get_rid()]
	var box := AABB()
	var first := true
	var ceiling_y := INF
	for node in LevelBuilder._all_under(run.world):
		var lid := node as StaticBody3D
		if lid != null and lid.name == "Ceiling":
			ceiling_y = lid.global_position.y
			continue
		var view := node as VisualInstance3D
		if view == null or not view.is_visible_in_tree() or view.name == "PathLine" \
				or view.get_parent() is ExitBag:
			continue
		var part: AABB = view.global_transform * view.get_aabb()
		box = part if first else box.merge(part)
		first = false
		var hazard := node.get_parent() as Hazard
		if hazard != null:
			_hazards.append(part.grow(0.35))
	box = box.grow(2.0)
	_origin = box.position
	_w = int(ceil(box.size.x / CELL))
	_d = int(ceil(box.size.z / CELL))
	_top = minf(ceiling_y - 0.05, box.end.y)
	_bottom = run.weaver.kill_y
	_map_floors()
	_dirs = _sphere(DIRECTIONS)
	for node in run.get_tree().get_nodes_in_group(Fly.GROUP):
		if run.world.is_ancestor_of(node):
			_flies.append_array((node as Fly).route(12))

	var start := _cell_at(run.weaver.global_position + Vector3.DOWN * Weaver.RADIUS, 1.0)
	if start < 0:
		return {"reached": false, "how": "no floor under the start"}
	_reach(start, -1, "start")
	var exit_at := run.exit.global_position if run.exit != null else Vector3.INF
	while not _queue.is_empty() or not _throws.is_empty():
		if _queue.is_empty():
			var pending: Array = _throws.pop_back()
			_throw_from(pending[0], pending[1], pending[2])
			continue
		var cell: int = _queue.pop_back()
		if exit_at != Vector3.INF and _is_exit(cell, exit_at):
			return {"reached": true, "how": _trace(cell)}
		_walk_from(cell)
		if _throws_from(cell):
			_throw_from(_eye(cell), cell, "from %s" % _where(cell))
	return {"reached": false, "how": ""}


# --- the floors ---------------------------------------------------------------

func _map_floors() -> void:
	_floors.resize(_w * _d)
	for iz in _d:
		for ix in _w:
			var heights: Array[float] = []
			var x := _origin.x + (float(ix) + 0.5) * CELL
			var z := _origin.z + (float(iz) + 0.5) * CELL
			var from_y := _top
			while from_y > _bottom and heights.size() < 4:
				var hit := _ray(Vector3(x, from_y, z), Vector3(x, _bottom, z))
				if hit.is_empty():
					break
				var at: Vector3 = hit["position"]
				if (hit["normal"] as Vector3).y > 0.6 and _headroom(at) and not _deadly(at):
					heights.append(at.y)
				from_y = at.y - 0.05
			_floors[ix + iz * _w] = heights


## Room to stand at [param at]: nothing solid over it, and not inside something —
## a ray started inside a block does not see the block.
func _headroom(at: Vector3) -> bool:
	if _inside(at + Vector3.UP * 0.35) or _inside(at + Vector3.UP * 0.65):
		return false
	return _ray(at + Vector3.UP * 0.05, at + Vector3.UP * 0.75).is_empty()


func _inside(at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = GameLayers.WORLD
	query.exclude = _exclude
	return not _space.intersect_point(query, 1).is_empty()


## Where the spider standing in [param cell] throws from: a little over it, lower
## where the ceiling is close.
func _eye(cell: int) -> Vector3:
	var at := _stand(cell)
	var over := _ray(at, at + Vector3.UP * 0.9)
	if over.is_empty():
		return at + Vector3.UP * 0.9
	return at + Vector3.UP * maxf(at.distance_to(over["position"]) - 0.1, 0.0)


func _deadly(at: Vector3) -> bool:
	for box in _hazards:
		if box.has_point(at + Vector3.UP * 0.2):
			return true
	return false


func _column(x: float, z: float) -> int:
	var ix := int(floor((x - _origin.x) / CELL))
	var iz := int(floor((z - _origin.z) / CELL))
	if ix < 0 or iz < 0 or ix >= _w or iz >= _d:
		return -1
	return ix + iz * _w


## The floor cell at [param at], within [param slack] of its height; -1 for none.
func _cell_at(at: Vector3, slack: float) -> int:
	var col := _column(at.x, at.z)
	if col < 0:
		return -1
	var heights: Array = _floors[col]
	for layer in heights.size():
		if absf(float(heights[layer]) - at.y) <= slack:
			return col * 4 + layer
	return -1


## The highest floor under [param at], or -1.
func _landing(at: Vector3) -> int:
	var col := _column(at.x, at.z)
	if col < 0:
		return -1
	var heights: Array = _floors[col]
	for layer in heights.size():
		if float(heights[layer]) < at.y - 0.35:
			return col * 4 + layer
	return -1


func _height(cell: int) -> float:
	return float((_floors[cell >> 2] as Array)[cell & 3])


func _stand(cell: int) -> Vector3:
	var col := cell >> 2
	return Vector3(_origin.x + (float(col % _w) + 0.5) * CELL, _height(cell) + Weaver.RADIUS,
		_origin.z + (float(col / _w) + 0.5) * CELL)


# --- moving ---------------------------------------------------------------------

func _reach(cell: int, from: int, how: String) -> void:
	if cell < 0 or _came.has(cell):
		return
	_came[cell] = [from, how]
	_queue.append(cell)


func _walk_from(cell: int) -> void:
	var here := _stand(cell)
	var col := cell >> 2
	var ix := col % _w
	var iz := col / _w
	var reach := int(ceil(JUMP_ACROSS / CELL))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dz == 0:
				continue
			var nx := ix + dx
			var nz := iz + dz
			if nx < 0 or nz < 0 or nx >= _w or nz >= _d:
				continue
			var across := Vector2(dx, dz).length() * CELL
			if across > JUMP_ACROSS:
				continue
			var heights: Array = _floors[nx + nz * _w]
			for layer in heights.size():
				var next := (nx + nz * _w) * 4 + layer
				if _came.has(next):
					continue
				var rise := float(heights[layer]) - _height(cell)
				var near := absf(dx) <= 1 and absf(dz) <= 1
				if near and rise <= STEP_UP:
					if _clear(here + Vector3.UP * 0.15, _stand(next) + Vector3.UP * 0.15
							+ Vector3.UP * maxf(-rise, 0.0)):
						_reach(next, cell, "walk")
				elif rise <= JUMP_UP:
					var lift := Vector3.UP * (maxf(rise, 0.0) + 0.8)
					if _clear(here + lift, _stand(next) + lift - Vector3.UP * maxf(rise, 0.0)):
						_reach(next, cell, "jump")


## Throws only from some cells — every other one, and the edges — or the search
## would take all day; webs reach the same places from a step further on.
func _throws_from(cell: int) -> bool:
	var col := cell >> 2
	if (col % _w) % 2 == 0 and (col / _w) % 2 == 0:
		return true
	var ix := col % _w
	var iz := col / _w
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = ix + offset.x
		var nz: int = iz + offset.y
		if nx < 0 or nz < 0 or nx >= _w or nz >= _d:
			return true
		var near := false
		for h in _floors[nx + nz * _w]:
			if absf(float(h) - _height(cell)) < 0.3:
				near = true
		if not near:
			return true
	return false


## Every web thrown from [param eye]: where each sticks, or — ridden, since a ride
## can't be got off — where each stops dead and drops its rider: at the end of its
## reach, on slick metal, or cut by a silk cutter.
func _throw_from(eye: Vector3, cell: int, words: String) -> void:
	_catch_flies(eye, cell, words)
	for dir in _dirs:
		var hit := _ray(eye, eye + dir * THROW)
		var length := THROW
		if not hit.is_empty():
			length = eye.distance_to(hit["position"])
		var cut := SilkCutter.crossing(_space, eye, eye + dir * length)
		if not cut.is_empty():
			length = eye.distance_to(cut["position"])
			hit = {}
		if not hit.is_empty() and _holds(hit.get("collider")):
			var spot: Vector3 = hit["position"]
			var key := Vector3i((spot / 0.8).floor())
			if _spots.has(key):
				continue
			_spots[key] = true
			_on_web(spot, hit["normal"], cell, "%s, a web at %s" % [words, spot.snappedf(0.1)])
			continue
		var end := eye + dir * maxf(length - 0.5, 0.0)
		var landing := _landing(end)
		if landing >= 0 and not _came.has(landing):
			_reach(landing, cell, "%s, a web ridden to %s, stopped dead, and a drop"
				% [words, end.snappedf(0.1)])


## Every fly a web from [param eye] can reach: caught, grappled to, hung from — and
## thrown from, and dropped from.
func _catch_flies(eye: Vector3, cell: int, words: String) -> void:
	for i in _flies.size():
		if _fly_seen.has(i):
			continue
		var at := _flies[i]
		if eye.distance_to(at) > THROW or not _clear(eye, at):
			continue
		if not SilkCutter.crossing(_space, eye, at).is_empty():
			continue
		_fly_seen[i] = true
		var said := "%s, a fly caught at %s and reached" % [words, at.snappedf(0.1)]
		_reach(_landing(at), cell, said + ", and a drop")
		_throws.append([at, cell, said + ", then"])


func _holds(collider: Variant) -> bool:
	var node := collider as Node
	if node == null or node is LoosePanel:
		return false
	return not Surfaces.is_slick(node)


## On a web at [param spot]: off its rim onto whatever floor is near, off it by
## jumping and falling, and throws from it.
func _on_web(spot: Vector3, normal: Vector3, cell: int, words: String) -> void:
	if normal.y > 0.6:
		_reach(_cell_at(spot, 0.4), cell, words)
	var up := normal.normalized()
	var across := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var along := across.cross(up).normalized()
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var rim := spot + (across * cos(angle) + along * sin(angle)) * RIM
		for dx in [-1.0, 0.0, 1.0]:
			for dz in [-1.0, 0.0, 1.0]:
				var col := _column(rim.x + dx, rim.z + dz)
				if col < 0:
					continue
				var heights: Array = _floors[col]
				for layer in heights.size():
					var h := float(heights[layer])
					if h < rim.y - 1.2 or h > rim.y + 0.5:
						continue
					var next := col * 4 + layer
					if _came.has(next):
						continue
					# Only where nothing solid is in the way from the web to there.
					if _clear(spot + up * 0.3, _stand(next) + Vector3.UP * 0.2):
						_reach(next, cell, words + ", off its rim")
	_reach(_landing(spot + up * 1.0), cell, words + ", jumped off")
	# Jumped off it — a web throws you harder than the ground does — onto any floor
	# in a jump's reach and in sight.
	var col := _column(spot.x, spot.z)
	var steps := int(ceil(WEB_JUMP_ACROSS / CELL))
	if col >= 0:
		var ix := col % _w
		var iz := col / _w
		for dz in range(-steps, steps + 1):
			for dx in range(-steps, steps + 1):
				if Vector2(dx, dz).length() * CELL > WEB_JUMP_ACROSS:
					continue
				var nx := ix + dx
				var nz := iz + dz
				if nx < 0 or nz < 0 or nx >= _w or nz >= _d:
					continue
				var heights: Array = _floors[nx + nz * _w]
				for layer in heights.size():
					var next := (nx + nz * _w) * 4 + layer
					if _came.has(next) or float(heights[layer]) > spot.y + WEB_JUMP_UP:
						continue
					if _clear(spot + up * 0.4 + Vector3.UP * 0.5, _stand(next) + Vector3.UP * 0.5):
						_reach(next, cell, words + ", a spring off it")
	var eye := spot + up * 0.9
	if not _inside(eye):
		_throws.append([eye, cell, words + ", then"])


func _is_exit(cell: int, exit_at: Vector3) -> bool:
	var at := _stand(cell)
	return Vector2(at.x - exit_at.x, at.z - exit_at.z).length() < 1.1 \
		and absf(_height(cell) - exit_at.y) < 0.8


# --- helpers ----------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.WORLD, _exclude)
	return _space.intersect_ray(query)


func _clear(from: Vector3, to: Vector3) -> bool:
	return _ray(from, to).is_empty()


func _where(cell: int) -> String:
	return str(_stand(cell).snappedf(0.1))


func _trace(cell: int) -> String:
	var steps: Array[String] = []
	var at := cell
	var guard := 0
	while at >= 0 and guard < 400:
		var came: Array = _came[at]
		var how := String(came[1])
		if how != "walk" and how != "jump" or came[0] == -1:
			steps.push_front("%s -> %s" % [how, _where(at)])
		at = int(came[0])
		guard += 1
	return "\n".join(steps)


static func _sphere(count: int) -> Array[Vector3]:
	var found: Array[Vector3] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in count:
		var y := 1.0 - (float(i) + 0.5) / float(count) * 2.0
		var r := sqrt(1.0 - y * y)
		var theta := golden * float(i)
		if y > 0.97 or y < -0.9:
			continue
		found.append(Vector3(cos(theta) * r, y, sin(theta) * r))
	return found
