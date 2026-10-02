class_name CreatureFighter
extends Node3D

## A creature's moves, carried out: which one it uses, when, and what it does.
##
## While its creature is hunting the spider, this picks from the creature's
## [CreatureAttack]s — whichever are off their wait and in reach, by weight — and
## runs it through its three beats: a wind-up with a tell in the attack's colour,
## the strike, and a recovery in which the creature stands open. With nothing in
## reach it closes the gap. Anything that takes the creature out of the hunt in
## the middle of an attack — a web, a stun, a shock — ends the attack there, tell
## and all.
##
## Every move is a thing to read rather than a number to soak:
##
## * a **bite** is told by a ring round the creature, and lands if you are still
##   in reach when it closes;
## * a **lunge** draws its line along the ground and goes where you were when the
##   line stopped following you; a drill that goes into a wall instead sticks fast;
## * a **spit** is a glob you can step out of the way of, or stop with a web;
## * a **tongue** draws its line too, and drags you in unless something is in the way;
## * a **burst** draws its ring, and throws and dazes whatever is inside it;
## * a **sweep** draws its ring and cuts the silk in front of it;
## * a **summon** calls more of a kind, up to a limit.

enum Beat { NONE, WIND_UP, STRIKE, RECOVER }

## Where the hostile species a summon calls up are kept.
const HOSTILES_DIR := "res://game/data/hostiles"

## How far a lunge carries on past where it was aimed, as a share of its reach,
## before it gives up on finding you there.
const OVERSHOOT := 1.4

## How fast a creature still creeps at you while it winds up, as a share of its
## pace: enough to keep it turned to you, which is most of what the tell is.
const CREEP := 0.08

var creature: Prey
var attacks: Array[CreatureAttack] = []

## The attack under way, if any, and the beat it is in.
var attack: CreatureAttack = null
var beat := Beat.NONE

var _left := 0.0
var _cooling := {}
var _quarry: Node3D = null
var _aim := Vector3.ZERO
var _from := Vector3.ZERO
var _heading := Vector3.ZERO
var _gone := 0.0
var _landed := false
var _stuck := false
var _ring: MeshInstance3D = null
var _line: MeshInstance3D = null
var _summoned: Array[Prey] = []


func setup(owner_creature: Prey, moves: Array[CreatureAttack]) -> void:
	creature = owner_creature
	attacks.clear()
	for move in moves:
		if move != null:
			attacks.append(move)


## Whether an attack is under way.
func is_attacking() -> bool:
	return attack != null


## Whether it is stuck fast after a lunge that went into a wall.
func is_stuck_fast() -> bool:
	return _stuck and beat == Beat.RECOVER


## Seconds before [param move] can be used again.
func cooling(move: CreatureAttack) -> float:
	return float(_cooling.get(move, 0.0))


func _physics_process(delta: float) -> void:
	for move in _cooling.keys():
		_cooling[move] = maxf(0.0, float(_cooling[move]) - delta)
	if attack != null and not _can_fight():
		cancel()


func _can_fight() -> bool:
	return is_instance_valid(creature) and creature.is_hunting() \
		and not creature.is_stunned() and not creature.is_dead()


## One frame of the hunt, from the creature's own step: closes on [param quarry]
## until something it has is in reach, then uses it.
func hunt(delta: float, quarry: Node3D) -> void:
	_quarry = quarry
	if attack != null:
		_step(delta)
		return
	var span := _span()
	var chosen := _choose(span)
	if chosen != null:
		_begin(chosen)
		return
	if _wants_closer(span):
		creature.steer_at(quarry.global_position, creature.current_speed() * Prey.CHASE_DASH, delta)
		return
	if _wants_further(span):
		# Too close for what it would rather use: it gives ground until it has room.
		var away := creature.global_position - quarry.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.000001 \
			else creature.global_basis.z
		creature.steer_at(creature.global_position + away * 2.0, creature.current_speed(), delta)
		return
	# In reach of what it has and waiting on it: it holds its ground, turned to
	# you, rather than walking into whatever you have put between you.
	creature.steer_at(quarry.global_position, creature.current_speed() * CREEP, delta)


## Ends whatever attack is under way, tell and all.
func cancel() -> void:
	attack = null
	beat = Beat.NONE
	_stuck = false
	_clear_tell()


## Whether getting nearer would help: something it would come after you for is
## ready but not yet in reach, or nothing it has reaches this far at all.
func _wants_closer(span: float) -> bool:
	var longest := 0.0
	for move in attacks:
		longest = maxf(longest, move.reach)
		if move.chases and cooling(move) <= 0.0 and move.reach < span:
			return true
	return span > longest


## Whether backing off would help: something it has is ready but needs more room
## than it has — a spit from too close, a dive with no run-up.
func _wants_further(span: float) -> bool:
	for move in attacks:
		if cooling(move) <= 0.0 and move.min_reach > span:
			return true
	return false


func _choose(span: float) -> CreatureAttack:
	var usable: Array[CreatureAttack] = []
	var total := 0.0
	for move in attacks:
		if cooling(move) > 0.0 or span > move.reach or span < move.min_reach:
			continue
		if move.kind == CreatureAttack.Kind.SUMMON and _alive_summons() >= move.summon_count:
			continue
		usable.append(move)
		total += maxf(move.weight, 0.0)
	if usable.is_empty() or total <= 0.0:
		return null
	var roll := randf() * total
	for move in usable:
		roll -= maxf(move.weight, 0.0)
		if roll <= 0.0:
			return move
	return usable[usable.size() - 1]


# --- the beats ----------------------------------------------------------

func _begin(move: CreatureAttack) -> void:
	attack = move
	beat = Beat.WIND_UP
	_left = maxf(move.wind_up, 0.0)
	_cooling[move] = move.cooldown
	_landed = false
	_stuck = false
	_gone = 0.0
	_show_tell()


func _step(delta: float) -> void:
	_left -= delta
	match beat:
		Beat.WIND_UP:
			_wind_up(delta)
			if _left <= 0.0:
				_strike()
		Beat.STRIKE:
			_striking(delta)
			if beat == Beat.STRIKE and _left <= 0.0:
				_recover()
		Beat.RECOVER:
			_stand(delta)
			if _left <= 0.0:
				cancel()


## Stands nearly still, turned to the spider, while the tell says what is coming.
func _wind_up(delta: float) -> void:
	creature.steer_at(_quarry.global_position, creature.current_speed() * CREEP, delta)
	_update_tell()


## The moment it goes. Most attacks are over in the frame; a lunge and a tongue
## take their time, and run on in [method _striking].
func _strike() -> void:
	beat = Beat.STRIKE
	_left = maxf(attack.strike_time, 0.0)
	_aim = _quarry.global_position
	_from = creature.global_position
	_heading = _aim - _from
	if not creature.flying:
		_heading.y = 0.0
	_heading = _heading.normalized() if _heading.length_squared() > 0.000001 \
		else -creature.global_basis.z
	_clear_tell()
	match attack.kind:
		CreatureAttack.Kind.BITE:
			if _span() <= attack.reach + _slack():
				_land(_heading)
			_recover()
		CreatureAttack.Kind.SPIT:
			Spit.throw(creature.get_parent(), _mouth(), _aim, attack, creature)
			_recover()
		CreatureAttack.Kind.TONGUE:
			if not _tongue():
				_recover()
		CreatureAttack.Kind.BURST:
			if _span() <= attack.radius:
				_land(_quarry.global_position - creature.global_position)
			if attack.cuts_silk:
				_cut_silk(attack.radius, Vector3.ZERO, 360.0)
			_recover()
		CreatureAttack.Kind.SWEEP:
			if _span() <= attack.radius and _in_arc(_quarry.global_position):
				_land(_quarry.global_position - creature.global_position)
			if attack.cuts_silk:
				_cut_silk(attack.radius, _heading, attack.arc)
			_recover()
		CreatureAttack.Kind.SUMMON:
			_summon()
			_recover()
		_:
			pass


func _striking(delta: float) -> void:
	match attack.kind:
		CreatureAttack.Kind.LUNGE:
			_lunge(delta)
		CreatureAttack.Kind.TONGUE:
			_haul()
		_:
			pass


func _recover(seconds := -1.0) -> void:
	beat = Beat.RECOVER
	_left = attack.recover if seconds < 0.0 else seconds
	_clear_tell()


## Open: standing where the attack left it, or stuck fast where a drill went in.
func _stand(delta: float) -> void:
	if _stuck:
		creature.velocity = Vector3.ZERO
		return
	var still := Vector3.ZERO
	if not creature.flying:
		still.y = creature.velocity.y - _gravity() * delta
	creature.velocity = creature.velocity.lerp(still, clampf(8.0 * delta, 0.0, 1.0))
	creature.move_and_slide()


# --- strikes ------------------------------------------------------------

## A straight dash at where you were — at its slowed pace, if water has it. It lands
## once if it reaches you; a drill that goes into the world instead is stuck there
## for a while.
func _lunge(delta: float) -> void:
	var speed := attack.speed * creature.pace()
	var dash := _heading * speed
	if not creature.flying:
		dash.y = creature.velocity.y - _gravity() * delta
	creature.velocity = dash
	creature.move_and_slide()
	_gone += speed * delta
	if attack.cuts_silk:
		_cut_silk(creature.hit_radius() * 1.5, Vector3.ZERO, 360.0)
	if not _landed and _touching():
		_landed = true
		_land(_heading)
		_recover()
		return
	var struck := creature.is_on_wall() or creature.is_on_ceiling() \
		or (creature.flying and creature.is_on_floor())
	if struck:
		if attack.stuck_on_miss > 0.0:
			_stuck = true
			_recover(attack.stuck_on_miss)
		else:
			_recover()
		return
	if _gone >= attack.reach * OVERSHOOT:
		_recover()


## Out to the spider in a straight line. Returns whether it got there: the world
## or a web in the way takes it instead.
func _tongue() -> bool:
	var space := creature.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(_mouth(), _quarry.global_position,
		GameLayers.WORLD | GameLayers.PLAYER | GameLayers.WEB, [creature.get_rid()])
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != _quarry:
		return false
	if _quarry.has_method("drag_to"):
		_quarry.drag_to(creature.global_position, attack.speed, attack.strike_time)
	return true


## Reeling the spider in: when it arrives, it is bitten.
func _haul() -> void:
	if _landed:
		return
	if _touching(0.4):
		_landed = true
		_land(_heading)
		_recover()


func _summon() -> void:
	var kind := hostile_species(attack.summons)
	if kind == null:
		return
	var room := attack.summon_count - _alive_summons()
	for i in room:
		var called := Prey.of(kind)
		if called == null:
			continue
		var turn := TAU * float(i) / float(maxi(room, 1)) + randf() * 0.6
		var out := Vector3(cos(turn), 0.0, sin(turn)) * (creature.hit_radius() * 2.0 + 0.6)
		creature.get_parent().add_child(called)
		called.global_position = creature.global_position + out + Vector3.UP * 0.2
		called.attack_spider(_quarry)
		_summoned.append(called)


## The spider is hit: what the attack does to it.
func _land(away: Vector3) -> void:
	if not is_instance_valid(_quarry):
		return
	if _quarry.has_method("take_bite") and attack.damage > 0.0:
		_quarry.take_bite(attack.damage, creature)
	if attack.knockback > 0.0 and _quarry.has_method("fling"):
		var flat := Vector3(away.x, 0.0, away.z)
		var push := flat.normalized() if flat.length_squared() > 0.000001 else Vector3.ZERO
		_quarry.fling(push * attack.knockback + Vector3.UP * attack.knockback * 0.45)
	if attack.daze > 0.0 and _quarry.has_method("daze"):
		_quarry.daze(attack.daze)


## Takes down the silk within [param reach] of the creature — in front of it, for
## an [param arc] less than all the way round.
func _cut_silk(reach: float, facing: Vector3, arc: float) -> int:
	var cut := 0
	var centre := creature.global_position
	for node in creature.get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null or not is_instance_valid(web) or web.is_queued_for_deletion():
			continue
		var near := web.nearest_silk(centre)
		if near.distance_to(centre) > reach:
			continue
		if arc < 360.0 and not _in_arc(near, facing, arc):
			continue
		web.demolish()
		cut += 1
	return cut


# --- reading the fight --------------------------------------------------

func _span() -> float:
	if not is_instance_valid(_quarry):
		return INF
	return creature.global_position.distance_to(_quarry.global_position)


## Whether the creature's body has reached the spider's, give or take [param more].
func _touching(more := 0.15) -> bool:
	return _span() <= creature.hit_radius() + _quarry_radius() + more


func _quarry_radius() -> float:
	if _quarry != null and _quarry.has_method("stage"):
		return _quarry.stage().body_height * 0.5
	return 0.2


## How much further than its reach a bite still lands: the spider is a body, not
## a point.
func _slack() -> float:
	return _quarry_radius()


func _in_arc(point: Vector3, facing := Vector3.ZERO, arc := -1.0) -> bool:
	var ahead := facing if facing != Vector3.ZERO else _heading
	var width := arc if arc > 0.0 else attack.arc
	var off := point - creature.global_position
	off.y = 0.0
	ahead.y = 0.0
	if off.length_squared() < 0.0001 or ahead.length_squared() < 0.0001:
		return true
	return rad_to_deg(off.angle_to(ahead)) <= width * 0.5


func _mouth() -> Vector3:
	return creature.global_position + _heading * creature.hit_radius() * 0.8


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _alive_summons() -> int:
	var alive: Array[Prey] = []
	for called in _summoned:
		if is_instance_valid(called) and not called.is_dead() and not called.eaten \
				and not called.is_bundled():
			alive.append(called)
	_summoned = alive
	return alive.size()


## A species by id: one of the hostiles, or else any species there is — a boss can
## call up ordinary things as well as its own.
static func hostile_species(id: String) -> PreySpecies:
	if id.is_empty():
		return null
	var path := HOSTILES_DIR.path_join(id + ".tres")
	if ResourceLoader.exists(path):
		return load(path) as PreySpecies
	return PreyLibrary.find(id)


# --- the tell -----------------------------------------------------------

## What it shows while it winds up: a ring round it for anything close, a ring as
## wide as a burst or a sweep, and a line along the ground to you for a lunge or a
## tongue. Brightening as the moment comes.
func _show_tell() -> void:
	_clear_tell()
	var wide := attack.kind == CreatureAttack.Kind.BURST \
		or attack.kind == CreatureAttack.Kind.SWEEP
	var size := attack.radius if wide else creature.hit_radius() * 1.4
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(size - maxf(size * 0.08, 0.03), 0.01)
	ring.outer_radius = size
	ring.rings = 32
	ring.ring_segments = 6
	_ring = _tell_part(ring)
	if attack.kind == CreatureAttack.Kind.LUNGE or attack.kind == CreatureAttack.Kind.TONGUE:
		var bar := BoxMesh.new()
		bar.size = Vector3(0.06, 0.02, 1.0)
		_line = _tell_part(bar)
	_update_tell()


func _tell_part(mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.top_level = true
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.no_depth_test = true
	paint.albedo_color = attack.tell_colour
	part.material_override = paint
	add_child(part)
	return part


func _update_tell() -> void:
	if attack == null:
		return
	var coming := 1.0 - clampf(_left / maxf(attack.wind_up, 0.001), 0.0, 1.0)
	var alpha := lerpf(0.25, 0.85, coming)
	var at := creature.global_position
	if is_instance_valid(_ring):
		_ring.global_transform = Transform3D(Basis.IDENTITY, at)
		(_ring.material_override as StandardMaterial3D).albedo_color.a = alpha
	if is_instance_valid(_line) and is_instance_valid(_quarry):
		var to := _quarry.global_position
		var run := to - at
		var length := minf(run.length(), attack.reach * OVERSHOOT)
		if length > 0.01:
			var along := run.normalized()
			var side := along.cross(Vector3.UP)
			if side.length_squared() < 0.0001:
				side = Vector3.RIGHT
			var up := side.cross(along).normalized()
			# The bar is a metre long down its own z, so that axis carries the length.
			var basis := Basis(side.normalized(), up, along * length)
			_line.global_transform = Transform3D(basis, at + along * length * 0.5)
			_line.visible = true
		else:
			_line.visible = false
		(_line.material_override as StandardMaterial3D).albedo_color.a = alpha


func _clear_tell() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	if is_instance_valid(_line):
		_line.queue_free()
	_ring = null
	_line = null
