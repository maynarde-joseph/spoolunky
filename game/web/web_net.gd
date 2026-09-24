class_name WebNet
extends WebStructure

## A closed web: three or more anchors, fitted to a plane and filled with
## spokes and spiral. This is the thing that actually catches dinner.

var centre_local := Vector3.ZERO
var plane_normal := Vector3.UP
var radius := 0.0

## Radius of the sticky disc, for inscribed webs. Zero for stretched ones,
## which are sticky all the way out to the frame.
var spiral_radius := 0.0


## Spins a net across the given world-space anchors. Returns null if the
## anchors are too close to a straight line to enclose anything.
static func spin(pattern: WebPattern, world_points: PackedVector3Array, quality: float,
		weave: WebGeometry.Weave = WebGeometry.Weave.STRETCHED,
		include_frame := true) -> WebNet:
	if world_points.size() < 3:
		return null

	var origin := Vector3.ZERO
	for p in world_points:
		origin += p
	origin /= float(world_points.size())

	var layout := WebGeometry.layout_net(world_points, pattern, origin, quality, weave,
		include_frame)
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
	net.spiral_radius = layout.spiral_radius
	net.weave = weave
	net._origin = origin
	net.anchors = world_points.duplicate()
	net.max_durability = pattern.durability * quality
	net.durability = net.max_durability

	net._build_visual(layout.strands)

	# A spider lives on its web, so give it something to stand on. Thin, and on
	# the silk layer, so prey still flies straight into it.
	var plank := ConvexPolygonShape3D.new()
	plank.points = WebGeometry.catch_hull(layout.rim, layout.normal,
		maxf(layout.radius * 0.03, 0.02))
	net._make_walk_surface(plank)

	if pattern.catches_prey or pattern.trigger == WebPattern.Trigger.ALERT:
		var depth := clampf(layout.radius * 0.35, 0.03, 1.2)
		if weave == WebGeometry.Weave.INSCRIBED:
			# Only the disc is sticky, so only the disc catches.
			var disc := CylinderShape3D.new()
			disc.radius = layout.spiral_radius
			disc.height = maxf(depth, 0.02)
			var sideways := layout.plane_u.cross(layout.normal).normalized()
			var frame := Basis(layout.plane_u, layout.normal, sideways)
			net._make_catch_area(disc, Transform3D(frame, layout.centre))
		else:
			var hull := ConvexPolygonShape3D.new()
			hull.points = WebGeometry.catch_hull(layout.rim, layout.normal, depth)
			net._make_catch_area(hull)

	return net



## Signal lines attach at the middle of the web, not its node origin.
func signal_point() -> Vector3:
	return to_global(centre_local)


## A wired snare whips out when the signal reaches it and drags in whatever is
## close enough. That reach is the entire reason to wire one up — left alone, a
## snare only ever catches what happens to walk into it.
func _spring_to_signal(_source: SilkNode) -> bool:
	if pattern.trigger != WebPattern.Trigger.SNARE or not armed:
		return false
	armed = false
	var centre := to_global(centre_local)
	var reach: float = maxf(radius, 0.1) * pattern.signal_strike_factor
	var target: Node3D = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Node3D
		if prey == null or not is_instance_valid(prey):
			continue
		var distance := prey.global_position.distance_to(centre)
		if distance > reach or distance >= closest:
			continue
		if prey.has_method("can_be_snared") and not prey.can_be_snared():
			continue
		closest = distance
		target = prey
	if target != null:
		_capture(target, pattern.snap_hold_time, centre)
	return true


## Prey sticks where it hit the plane, dragged a little toward the middle.
func _catch_point(body: Node3D) -> Vector3:
	var centre := to_global(centre_local)
	var offset := body.global_position - centre
	var flattened := body.global_position - plane_normal * offset.dot(plane_normal)
	return flattened.lerp(centre, 0.25)
