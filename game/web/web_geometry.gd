class_name WebGeometry
extends RefCounted

## Turns lines into silk you can see.
##
## The spider does not build webs any more, but silk still goes everywhere: the
## grapple's thread, the tether, the rings of a magic circle, the spray round a
## water spiral and the forks of a lightning strike are all lines drawn the same
## way — each one two crossed quads, so it reads from any angle without a
## billboard shader.


## A bundle of lines waiting to be turned into a mesh.
class StrandSet extends RefCounted:
	var starts := PackedVector3Array()
	var ends := PackedVector3Array()
	var widths := PackedFloat32Array()
	var length := 0.0

	func add(a: Vector3, b: Vector3, width: float) -> void:
		var span := a.distance_to(b)
		if span <= 0.0005:
			return
		starts.append(a)
		ends.append(b)
		widths.append(width)
		length += span

	func size() -> int:
		return starts.size()


## Builds the drawable mesh. Each line becomes two crossed quads so it stays
## visible from any angle without needing a billboard shader.
static func build_mesh(strands: StrandSet, color: Color, width_scale := 1.0) -> ArrayMesh:
	if strands.size() == 0:
		return null
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in strands.size():
		var a := strands.starts[i]
		var b := strands.ends[i]
		var half: float = strands.widths[i] * 0.5 * width_scale
		var axis := (b - a).normalized()
		var side_a := _perpendicular(axis)
		var side_b := axis.cross(side_a).normalized()
		_add_quad(tool, a, b, side_a * half, color)
		_add_quad(tool, a, b, side_b * half, color)
	tool.generate_tangents()
	return tool.commit()


## Draws a single line straight into an [ImmediateMesh], for lines that move
## every frame — the grapple's thread, a tether — where rebuilding an [ArrayMesh]
## would be wasteful. Same crossed-quad trick as [method build_mesh].
static func draw_line_into(mesh: ImmediateMesh, material: Material, a: Vector3,
		b: Vector3, width: float, color: Color) -> void:
	if a.distance_squared_to(b) < 0.000001:
		return
	var axis := (b - a).normalized()
	var side_a := _perpendicular(axis) * width * 0.5
	var side_b := axis.cross(side_a).normalized() * width * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	_write_quad(mesh, a, b, side_a, color)
	_write_quad(mesh, a, b, side_b, color)
	mesh.surface_end()


static func _write_quad(mesh: ImmediateMesh, a: Vector3, b: Vector3, offset: Vector3,
		color: Color) -> void:
	# Normals, the same as the built mesh lays down: the silk is lit, and a line
	# without them is a line lit by nothing.
	var normal := (b - a).cross(offset).normalized()
	var p0 := a - offset
	var p1 := a + offset
	var p2 := b + offset
	var p3 := b - offset
	for point in [p0, p1, p2, p0, p2, p3]:
		mesh.surface_set_color(color)
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(point)


## The material silk is drawn with. Dark and glossy rather than pale and flat,
## because that is what silk is in life: a dark filament that flashes where the
## light catches it, which is a reading that works against grass and sky alike.
##
## Vertex coloured, so each line can carry its own tint; double sided, so it reads
## from behind; and a faint glow of its own, so a line in shade is still a line.
static func silk_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1, 1, 1, 1)
	material.metallic = 0.0
	material.metallic_specular = 0.9
	material.roughness = 0.16
	material.emission_enabled = true
	material.emission = Color(0.56, 0.64, 0.82, 1.0)
	material.emission_energy_multiplier = 0.22
	material.disable_receive_shadows = true
	return material


static func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, offset: Vector3, color: Color) -> void:
	var normal := (b - a).cross(offset).normalized()
	var p0 := a - offset
	var p1 := a + offset
	var p2 := b + offset
	var p3 := b - offset
	tool.set_color(color)
	tool.set_normal(normal)
	tool.set_uv(Vector2(0, 0))
	tool.add_vertex(p0)
	tool.set_uv(Vector2(0, 1))
	tool.add_vertex(p1)
	tool.set_uv(Vector2(1, 1))
	tool.add_vertex(p2)
	tool.set_uv(Vector2(0, 0))
	tool.add_vertex(p0)
	tool.set_uv(Vector2(1, 1))
	tool.add_vertex(p2)
	tool.set_uv(Vector2(1, 0))
	tool.add_vertex(p3)


static func _perpendicular(axis: Vector3) -> Vector3:
	var reference := Vector3.UP
	if absf(axis.dot(reference)) > 0.95:
		reference = Vector3.RIGHT
	return axis.cross(reference).normalized()
