class_name WebCharge
extends Node3D

## Lightning left standing in a web.
##
## A strike that reaches a web does not only run through it: the charge stays in
## the silk for a while, and the web is live. Everything it holds stays stunned
## for as long as the charge lasts — hanging limp, its fight running down, the
## silk winning — and anything that touches it is struck: flown into, walked into,
## or caught by it while it is live. A trap that shocks, put up where you want one,
## and as good against something too big to hold as against something that is not.
##
## Webs only. A line is a road, not a trap, and lightning on one does nothing; see
## [LightningStrike]. The spider is never struck by its own lightning.

const NAME := "Charge"

## How often it strikes what it holds and what is touching it, in seconds.
const PULSE := 0.3

## How bright the silk glows while it is live, at most and at least: it flickers.
const GLOW := Vector2(0.8, 2.4)

## How many crooked sparks it shows at once, and how often they jump.
const SPARKS := 5
const SPARK_EVERY := 0.12

## The web it is in.
var web: WebStructure

## Seconds of charge left.
var left := 5.0

## How long what it strikes stays stunned, before anything wet doubles it.
var stun := 2.5

var colour := Color(0.98, 0.92, 0.55, 1.0)

## Everything it has struck by touch, for the readout.
var struck: Array[Prey] = []

var _pulse := 0.0
var _spark := 0.0
var _sparks: MeshInstance3D
var _spark_material: StandardMaterial3D
var _emission := Color(0.56, 0.64, 0.82, 1.0)
var _emission_energy := 0.22


## Leaves a charge in [param in_web] for [param seconds], striking what it holds and
## what touches it for [param stun_for] seconds. A web already live keeps whichever
## charge is the longer and the harder.
static func lay(in_web: WebStructure, seconds: float, stun_for: float,
		tint := Color(0.98, 0.92, 0.55, 1.0)) -> WebCharge:
	if in_web == null or not is_instance_valid(in_web) or in_web.is_queued_for_deletion():
		return null
	var charge := of(in_web)
	if charge != null:
		charge.left = maxf(charge.left, seconds)
		charge.stun = maxf(charge.stun, stun_for)
		return charge
	charge = WebCharge.new()
	charge.name = NAME
	charge.web = in_web
	charge.left = seconds
	charge.stun = stun_for
	charge.colour = tint
	charge.add_to_group("spell_effects")
	in_web.add_child(charge)
	return charge


## The charge live in [param in_web], or null if it is not live. Looked for rather
## than fetched by name: one going out and a fresh one laid in the same frame are
## both there for that frame, and the fresh one cannot have the name.
static func of(in_web: WebStructure) -> WebCharge:
	if in_web == null or not is_instance_valid(in_web):
		return null
	for child in in_web.get_children():
		var charge := child as WebCharge
		if charge != null and not charge.is_queued_for_deletion() and charge.left > 0.0:
			return charge
	return null


func _ready() -> void:
	if web == null:
		web = get_parent() as WebStructure
	if web == null:
		queue_free()
		return
	web.prey_caught.connect(_on_caught)
	if web.catch_area != null:
		web.catch_area.body_entered.connect(_touched)
	if web.material != null:
		_emission = web.material.emission
		_emission_energy = web.material.emission_energy_multiplier
	_build_sparks()
	# Whatever is in it the moment it goes live is struck there and then.
	_strike_all()


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0:
		_go_out()
		return
	_pulse -= delta
	if _pulse <= 0.0:
		_strike_all()
	_spark -= delta
	if _spark <= 0.0:
		_spark = SPARK_EVERY
		_jump_sparks()
	if web.material != null:
		web.material.emission = colour
		web.material.emission_energy_multiplier = randf_range(GLOW.x, GLOW.y)


## One beat of it: what it holds kept stunned, and anything loose touching it struck.
func _strike_all() -> void:
	_pulse = PULSE
	for held in web.snared_prey():
		var creature := held as Prey
		if creature != null and is_instance_valid(creature):
			# Kept down rather than struck afresh: the strike that charged it already
			# took its share of the fight, and a web that took that much again every
			# beat would be a kill, not a trap.
			creature.stun(PULSE * 1.5)
	if web.catch_area == null:
		return
	for body in web.catch_area.get_overlapping_bodies():
		_touched(body)


## Something came into it: struck, unless it is already out of it.
func _touched(body: Node3D) -> void:
	var creature := body as Prey
	if creature == null or not is_instance_valid(creature) or creature.is_stunned():
		return
	if not creature.is_loose() and creature.held_by() != web:
		return
	if creature.shock(stun):
		if not struck.has(creature):
			struck.append(creature)
		SpellFlash.burst(get_tree().current_scene, creature.global_position, colour,
			creature.hit_radius() * 2.0, 0.2)


func _on_caught(_web: WebStructure, body: Node3D) -> void:
	_touched(body)


func _go_out() -> void:
	set_physics_process(false)
	if is_instance_valid(web) and web.material != null:
		web.material.emission = _emission
		web.material.emission_energy_multiplier = _emission_energy
	queue_free()


# --- what you can see ----------------------------------------------------

func _build_sparks() -> void:
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_spark_material.vertex_color_use_as_albedo = true
	_sparks = MeshInstance3D.new()
	_sparks.name = "Sparks"
	_sparks.material_override = _spark_material
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.top_level = true
	add_child(_sparks)
	_jump_sparks()


## A few short crooked sparks between points of its silk, somewhere new each time.
func _jump_sparks() -> void:
	if _sparks == null:
		return
	var points := PackedVector3Array(web.anchors)
	var net := web as WebNet
	if net != null:
		points.append(net.signal_point())
	if points.size() < 2:
		_sparks.mesh = null
		return
	var middle := Vector3.ZERO
	for point in points:
		middle += point
	middle /= float(points.size())
	var strands := WebGeometry.StrandSet.new()
	var span := 0.0
	for point in points:
		span = maxf(span, point.distance_to(middle))
	var width := maxf(span * 0.02, 0.006)
	for i in SPARKS:
		# From somewhere on the silk across to somewhere else on it.
		var a := points[randi() % points.size()].lerp(middle, randf_range(0.1, 0.6))
		var b := points[randi() % points.size()].lerp(middle, randf_range(0.1, 0.6))
		if a.distance_to(b) < span * 0.3:
			b = middle
		LightningStrike.zigzag(strands, a, b, 6, a.distance_to(b) * 0.12, width)
	_sparks.mesh = WebGeometry.build_mesh(strands, colour)
	_sparks.global_transform = Transform3D.IDENTITY
