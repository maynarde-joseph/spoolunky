class_name Lava
extends Node3D

## A pool of lava: a puddle the spider's fire turned molten.
##
## No spell casts it on its own. Douse leaves puddles where its drops land; a breath
## of fire that reaches one turns it to lava where it lies — see [WetGround] and
## [FireBreath]. Whatever stands in it burns, silk or none, a little every moment
## it stays, until it cools a few seconds later.
##
## And it is better with the rest of what the spider has:
##
## * **Lightning.** A strike that reaches it erupts it: a column of fire out of the
##   pool, and the strike goes out round it as fire — see [LightningStrike].
## * **Wind.** With Waterspout learned, wind blown over it lifts it into a spiral of
##   fire that runs on down the lane and holds and burns the first thing it reaches
##   — see [WaterSpiral].

const GROUP := "lava"

## How often it burns what is standing in it, in seconds.
const PULSE := 0.25

## How long it takes to cool once its time is up, in seconds.
const FADE := 1.0

## How long the column of fire an eruption throws up is on screen, in seconds, and
## how tall it is, as so many times the pool's radius.
const ERUPTION := 0.6
const COLUMN := 6.0

## Its middle, which way is up from the ground it is on, and how wide it is from the
## middle to the rim, in metres.
var centre := Vector3.ZERO
var up := Vector3.UP
var radius := 0.1

## How long it stays molten, in seconds from when it was made, and how much of a
## creature's health it takes every second something stands in it.
var life := 6.0
var heat := 0.1

var colour := Color(1.0, 0.42, 0.1, 1.0)

## Everything it burned, in the order it reached them.
var burned: Array[Prey] = []

var _age := 0.0
var _pulse := 0.0
var _cool_at := -1.0
var _erupted_at := -1.0
var _paint: StandardMaterial3D
var _core_paint: StandardMaterial3D
var _column_paint: StandardMaterial3D
var _column: MeshInstance3D


## Turns the ground under [param host] at [param at], facing [param normal], to lava
## [param wide] metres from the middle to the rim, molten for [param seconds] and
## taking [param burn] of a creature's health every second it stands in it.
static func melt(host: Node, at: Vector3, normal: Vector3, wide: float, seconds: float,
		burn: float) -> Lava:
	if host == null or wide <= 0.0:
		return null
	var pool := Lava.new()
	pool.name = "Lava"
	pool.centre = at
	pool.up = normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	pool.radius = wide
	pool.life = maxf(seconds, 0.1)
	pool.heat = maxf(burn, 0.0)
	pool.add_to_group(GROUP)
	pool.add_to_group("spell_effects")
	host.add_child(pool)
	pool.global_transform = MagicCircle.facing(at, pool.up)
	pool._build_view()
	return pool


## Whether it is still molten.
func molten() -> bool:
	return _cool_at < 0.0


## Whether [param point] is in it — inside its rim, and down at the ground rather
## than above it — within [param margin], while it is molten.
func holds(point: Vector3, margin := 0.0) -> bool:
	if not molten():
		return false
	var off := point - centre
	var rise := off.dot(up)
	if rise < -radius - margin or rise > radius + margin * 2.0:
		return false
	return (off - up * rise).length() <= radius + margin


## Whether [param point] is within [param ring] of its middle across the ground, and
## no further above or below it than that, within [param margin].
func in_ring(point: Vector3, ring: float, margin := 0.0) -> bool:
	var off := point - centre
	var rise := off.dot(up)
	if absf(rise) > ring + margin:
		return false
	return (off - up * rise).length() <= ring + margin


## Whether a lane of wind blown from [param from] along [param toward], out to
## [param far] metres and [param half_width] either side, passes over it.
func met_by(from: Vector3, toward: Vector3, far: float, half_width: float) -> bool:
	if not molten() or not Gust.in_lane(centre, from, toward, far, half_width, radius):
		return false
	var rise := centre.y - from.y
	return rise >= -far * Gust.REACH_DOWN - radius and rise <= far * Gust.REACH_UP + radius


## Its heat is spent: it cools and is gone.
func cool() -> void:
	if molten():
		_cool_at = _age


## Lightning reached it: a column of fire bursts up out of it, and it is spent.
## [param ring] is how far round it the fire goes, for the burst on the ground.
func erupt(ring: float) -> void:
	if not molten():
		return
	_erupted_at = _age
	cool()
	if _column != null:
		_column.visible = true
	SpellFlash.burst(get_parent(), centre + up * radius * 0.5, colour, ring, 0.5)


func _physics_process(delta: float) -> void:
	_age += delta
	if not molten():
		if _age >= _cool_at + maxf(FADE, ERUPTION if _erupted_at >= 0.0 else 0.0):
			queue_free()
		return
	if _age >= life:
		cool()
		return
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = PULSE
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten \
				or creature.is_bundled() or not holds(creature.global_position, creature.hit_radius()):
			continue
		creature.wound(heat * PULSE)
		if not burned.has(creature):
			burned.append(creature)


func _process(_delta: float) -> void:
	if _paint == null:
		return
	var shown := 1.0
	if not molten():
		shown = 1.0 - clampf((_age - _cool_at) / FADE, 0.0, 1.0)
	var glow := 0.85 + 0.15 * sin(_age * 6.0)
	_paint.albedo_color.a = 0.9 * shown
	_core_paint.albedo_color.a = 0.85 * shown * glow
	if _column != null and _column.visible:
		var burst := clampf((_age - _erupted_at) / ERUPTION, 0.0, 1.0)
		_column.scale = Vector3(1.0 - burst * 0.5, lerpf(0.4, 1.0, sqrt(burst)), 1.0 - burst * 0.5)
		_column_paint.albedo_color.a = 0.8 * (1.0 - burst)


# --- what you can see ----------------------------------------------------

## A glowing pool on the ground, round but not quite, with a hotter middle; and,
## for when lightning erupts it, a column of fire waiting out of sight.
func _build_view() -> void:
	_paint = _flat_paint(Color(colour.r * 0.85, colour.g * 0.6, colour.b, 0.9))
	_core_paint = _flat_paint(Color(1.0, 0.82, 0.35, 0.85))
	var rim := _rim()
	var pool := MeshInstance3D.new()
	pool.name = "Pool"
	pool.mesh = _disc(rim)
	pool.material_override = _paint
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3.UP * maxf(radius * 0.04, 0.003)
	pool.scale = Vector3(radius, 1.0, radius)
	add_child(pool)
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = pool.mesh
	core.material_override = _core_paint
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = Vector3.UP * maxf(radius * 0.06, 0.004)
	core.scale = Vector3(radius * 0.55, 1.0, radius * 0.55)
	add_child(core)
	var shaft := CylinderMesh.new()
	shaft.top_radius = radius * 0.35
	shaft.bottom_radius = radius * 0.8
	shaft.height = radius * COLUMN
	shaft.radial_segments = 12
	shaft.rings = 1
	shaft.cap_top = false
	shaft.cap_bottom = false
	_column_paint = _flat_paint(Color(1.0, 0.55, 0.15, 0.8))
	_column = MeshInstance3D.new()
	_column.name = "Column"
	_column.mesh = shaft
	_column.material_override = _column_paint
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.position = Vector3.UP * radius * COLUMN * 0.5
	_column.visible = false
	add_child(_column)


func _flat_paint(tint: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.albedo_color = tint
	return paint


func _rim() -> PackedVector3Array:
	var sides := 18
	var lumps := randf() * TAU
	var rim := PackedVector3Array()
	for i in sides:
		var turn := TAU * float(i) / float(sides)
		var out := 1.0 + 0.08 * sin(turn * 3.0 + lumps) + 0.05 * sin(turn * 5.0 + lumps * 2.0)
		rim.append(Vector3(cos(turn) * out, 0.0, sin(turn) * out))
	return rim


func _disc(rim: PackedVector3Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rim.size():
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(rim[i])
		tool.add_vertex(rim[(i + 1) % rim.size()])
	return tool.commit()
