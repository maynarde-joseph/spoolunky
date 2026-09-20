class_name WebStrand
extends WebStructure

## Two anchors and a line between them: triplines, draglines and bridges.
## A strand never encloses an area, so it never catches — it either reports
## what crossed it or it holds the player's weight.

var point_a := Vector3.ZERO
var point_b := Vector3.ZERO


static func spin(pattern: WebPattern, a: Vector3, b: Vector3, quality: float) -> WebStrand:
	if a.distance_to(b) < 0.05:
		return null

	var origin := (a + b) * 0.5
	var strands := WebGeometry.layout_strand(a, b, pattern, origin, quality)
	if strands.size() == 0:
		return null

	var strand := WebStrand.new()
	strand.name = "WebStrand_" + pattern.id
	strand.pattern = pattern
	strand.quality = quality
	strand.point_a = a
	strand.point_b = b
	strand._origin = origin
	strand.anchors = PackedVector3Array([a, b])
	strand.max_durability = pattern.durability * quality
	strand.durability = strand.max_durability
	strand.silk_cost = pattern.cost_for(strands.length, 0.0)

	strand._build_visual(strands)

	var length := a.distance_to(b)
	var axis := (b - a).normalized()
	var alignment := Transform3D(Basis.looking_at(axis, _safe_up(axis)), Vector3.ZERO)

	if pattern.catches_prey or pattern.trigger == WebPattern.Trigger.ALERT:
		var girth := clampf(0.06 * quality, 0.03, 0.6)
		var trip_box := BoxShape3D.new()
		trip_box.size = Vector3(girth, girth, length)
		strand._make_catch_area(trip_box, alignment)

	if pattern.walkable:
		var width: float = maxf(pattern.walk_width * quality, 0.05)
		var plank := BoxShape3D.new()
		plank.size = Vector3(width, maxf(width * 0.25, 0.02), length)
		strand._make_walk_surface(plank, alignment)

	return strand



static func _safe_up(axis: Vector3) -> Vector3:
	if absf(axis.dot(Vector3.UP)) > 0.95:
		return Vector3.FORWARD
	return Vector3.UP
