class_name WebNet
extends WebStructure

## A closed web: three or more anchors, fitted to a plane and filled with
## spokes and spiral. This is the thing that actually catches dinner.

var centre_local := Vector3.ZERO
var plane_normal := Vector3.UP
var radius := 0.0


## Spins a net across the given world-space anchors. Returns null if the
## anchors are too close to a straight line to enclose anything.
static func spin(pattern: WebPattern, world_points: PackedVector3Array, quality: float) -> WebNet:
	if world_points.size() < 3:
		return null

	var origin := Vector3.ZERO
	for p in world_points:
		origin += p
	origin /= float(world_points.size())

	var layout := WebGeometry.layout_net(world_points, pattern, origin, quality)
	if not layout.valid:
		return null

	var net := WebNet.new()
	net.name = "WebNet_" + pattern.id
	net.pattern = pattern
	net.quality = quality
	net.area = layout.area
	net.centre_local = layout.centre
	net.plane_normal = layout.normal
	net.radius = layout.radius
	net._origin = origin
	net.max_durability = pattern.durability * quality
	net.durability = net.max_durability
	net.silk_cost = pattern.cost_for(layout.strands.length, layout.area)

	net._build_visual(layout.strands)

	if pattern.catches_prey or pattern.trigger == WebPattern.Trigger.ALERT:
		var depth := clampf(layout.radius * 0.35, 0.03, 1.2)
		var hull := ConvexPolygonShape3D.new()
		hull.points = WebGeometry.catch_hull(layout.rim, layout.normal, depth)
		net._make_catch_area(hull)

	return net



## Prey sticks where it hit the plane, dragged a little toward the middle.
func _catch_point(body: Node3D) -> Vector3:
	var centre := to_global(centre_local)
	var offset := body.global_position - centre
	var flattened := body.global_position - plane_normal * offset.dot(plane_normal)
	return flattened.lerp(centre, 0.25)
