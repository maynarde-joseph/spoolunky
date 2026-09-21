class_name WebGraph
extends RefCounted

## Finds the areas the player's silk encloses.
##
## Every strand in the world is treated as an edge. Edges meet where their ends
## share a point *and* where they simply cross in mid-air, so three lines slung
## across a shaft enclose the triangle in the middle even though none of them
## touches another at an end. Any loop that comes out of that is somewhere a web
## could be woven.
##
## Nothing here changes the world: the strands are left alone and the loops are
## reported as plain rings of points.

## One enclosed ring of silk.
class Loop extends RefCounted:
	var points := PackedVector3Array()
	var centre := Vector3.ZERO
	var normal := Vector3.UP
	var area := 0.0
	var radius := 0.0
	## Worst distance of any corner from the loop's own plane.
	var buckle := 0.0

	func key() -> String:
		return "%.2v" % centre + "|%d" % points.size()


## Loops enclosed by [param strands], largest first.
##
## [param merge] is how close two points have to be to count as the same place,
## and should scale with the spider — a giant's silk is coarser than a
## spiderling's.
static func find_loops(strands: Array, merge: float, node_budget := 96) -> Array:
	var loops: Array = []
	if strands.size() < 3:
		return loops

	var ends: Array[PackedVector3Array] = []
	for strand in strands:
		var line := strand as WebStrand
		if line == null or not is_instance_valid(line):
			continue
		ends.append(PackedVector3Array([line.point_a, line.point_b]))
	if ends.size() < 3:
		return loops

	# Where does each line have to be cut? Its own ends, plus anywhere another
	# line passes close enough to count as touching it.
	var cuts: Array[PackedFloat32Array] = []
	for i in ends.size():
		cuts.append(PackedFloat32Array([0.0, 1.0]))
	for i in ends.size():
		for j in range(i + 1, ends.size()):
			var meeting := _crossing(ends[i], ends[j], merge)
			if meeting.is_empty():
				continue
			cuts[i].append(meeting["s"])
			cuts[j].append(meeting["t"])

	# Turn the cut points into shared nodes.
	var nodes := PackedVector3Array()
	var edges: Array[Vector2i] = []
	for i in ends.size():
		var along := cuts[i]
		along.sort()
		var previous := -1
		var last_value := -1.0
		for value in along:
			if value - last_value < 0.0001 and previous >= 0:
				continue
			last_value = value
			var point: Vector3 = ends[i][0].lerp(ends[i][1], value)
			var node := _node_for(nodes, point, merge)
			if node >= nodes.size():
				nodes.append(point)
			if previous >= 0 and previous != node:
				edges.append(Vector2i(previous, node))
			previous = node
		if nodes.size() > node_budget:
			return loops

	if edges.size() < 3:
		return loops

	# Neighbours, for walking round.
	var links: Array[PackedInt32Array] = []
	for i in nodes.size():
		links.append(PackedInt32Array())
	for edge in edges:
		links[edge.x].append(edge.y)
		links[edge.y].append(edge.x)

	# The shortest way home along every edge gives the small loops, which are
	# the ones worth offering to fill.
	var seen := {}
	for edge in edges:
		var ring := _shortest_ring(links, edge.x, edge.y)
		if ring.size() < 3:
			continue
		var loop := _describe(nodes, ring)
		if loop == null:
			continue
		var id := loop.key()
		if seen.has(id):
			continue
		seen[id] = true
		loops.append(loop)

	loops.sort_custom(func(a, b) -> bool: return a.area > b.area)
	return loops


## Where two lines cross, as a fraction along each, or empty if they miss.
static func _crossing(first: PackedVector3Array, second: PackedVector3Array,
		merge: float) -> Dictionary:
	var closest := Geometry3D.get_closest_points_between_segments(
		first[0], first[1], second[0], second[1])
	if closest.size() < 2:
		return {}
	if closest[0].distance_to(closest[1]) > merge:
		return {}
	var s := _fraction(first, closest[0])
	var t := _fraction(second, closest[1])
	# Ends already share nodes; only a genuine mid-line crossing adds anything.
	if s < 0.02 or s > 0.98 or t < 0.02 or t > 0.98:
		return {}
	return {"s": s, "t": t}


static func _fraction(line: PackedVector3Array, point: Vector3) -> float:
	var along := line[1] - line[0]
	var length := along.length_squared()
	if length < 0.000001:
		return 0.0
	return clampf((point - line[0]).dot(along) / length, 0.0, 1.0)


static func _node_for(nodes: PackedVector3Array, point: Vector3, merge: float) -> int:
	for i in nodes.size():
		if nodes[i].distance_to(point) <= merge:
			return i
	return nodes.size()


## Shortest way from [param from] back to [param to] without using the edge
## that joins them directly.
static func _shortest_ring(links: Array[PackedInt32Array], from: int, to: int) -> PackedInt32Array:
	var came_from := {}
	var queue: Array[int] = [from]
	came_from[from] = -1
	while not queue.is_empty():
		var node: int = queue.pop_front()
		for next in links[node]:
			if next == to and node == from:
				continue  # the edge we are trying to get around
			if came_from.has(next):
				continue
			came_from[next] = node
			if next == to:
				queue.clear()
				break
			queue.append(next)

	var ring := PackedInt32Array()
	if not came_from.has(to):
		return ring
	var step: int = to
	while step != -1:
		ring.append(step)
		step = came_from[step]
	return ring


static func _describe(nodes: PackedVector3Array, ring: PackedInt32Array) -> Loop:
	var loop := Loop.new()
	for index in ring:
		loop.points.append(nodes[index])
	if loop.points.size() < 3:
		return null

	var centre := Vector3.ZERO
	for p in loop.points:
		centre += p
	loop.centre = centre / float(loop.points.size())
	loop.normal = WebGeometry.plane_normal(loop.points)

	var total := Vector3.ZERO
	for i in loop.points.size():
		total += loop.points[i].cross(loop.points[(i + 1) % loop.points.size()])
	loop.area = absf(total.dot(loop.normal)) * 0.5
	if loop.area < 0.002:
		return null

	for p in loop.points:
		var offset := p - loop.centre
		loop.radius = maxf(loop.radius, offset.length())
		loop.buckle = maxf(loop.buckle, absf(offset.dot(loop.normal)))
	# A ring that wanders too far out of its own plane is a tangle, not a gap.
	if loop.radius > 0.0 and loop.buckle / loop.radius > 0.6:
		return null
	return loop
