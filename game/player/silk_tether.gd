class_name SilkTether
extends Node3D

## A line from the spider to something it is dragging along.
##
## Catching things and moving things were separate problems until this: a
## bundle used to be a thing you walked back to, which meant the larder had to
## come to you or you had to eat where you stood. A tether makes a catch into
## cargo. Hook it, and it comes with you — over walls, along silk, off the end
## of a zipline.
##
## It is a rope, not a rod. Slack does nothing at all: walk towards the thing
## you are towing and the line sags and drags on the floor. Only past its
## length does it pull, and then it pulls rather than snaps the cargo to a
## fixed distance, so the weight swings behind you and keeps swinging when you
## stop. That is the whole feel of the thing, and it is why the rope is
## simulated rather than drawn as a straight line between two points.

signal hooked(cargo: Node3D)
signal released(cargo: Node3D)
signal notice(text: String)

## As far as the crosshair is ever asked to look for a wall.
const WALL_REACH := 4096.0

## How far away something can be hooked. Zero is as far as you can see, which
## is what grappling already is: aiming at a thing you have caught and firing
## silk at it should not stop working because it is across the room.
@export var reach := 0.0

## How much line is left paid out once it is reeled in, in body heights. Past
## this the cargo is hauled along.
@export var rope_bodies := 6.0

## How fast a long shot is wound back in, in metres per second. Hooking
## something across the room does not snap it to your feet; it comes in.
@export var reel_speed := 7.0

## Overstretch this many times the rope's length and the silk gives way. High
## on purpose: the line is meant to drag things through corners, not to be a
## tripwire that punishes a long grapple.
@export var snap_strain := 3.5

## How hard the cargo is pulled back to the end of its line, per second.
@export var haul_force := 9.0

## How hard a snagged catch is lifted, on top of being pulled along.
##
## A rope pulls in a straight line and the world is not straight. Haul something
## towards you with a wall in between and the pull is *into* the wall: the catch
## cannot follow, you keep walking, and the line stretches until it parts. Which
## is a real thing for a rope to do and a stupid way to lose a catch you had
## already won, because there is nothing you could have done differently short of
## not going that way.
##
## So a line that is pulling and getting nowhere starts lifting as well, and the
## catch goes up and over. That is what a spider hauling something up a wall
## looks like anyway. Has to beat gravity — about 9.8 — or it lifts nothing.
@export var snag_lift := 20.0

## Seconds of getting nowhere before the lift is at full strength. Short enough
## that a wall is a pause rather than a problem, long enough that a catch merely
## bumping over a kerb does not fly.
@export var snag_patience := 0.3

## How much line a snagged catch is given, as a multiple of the resting length.
##
## A line caught on a wall is not an over-stretched line, and snapping it is
## answering the wrong question — you did nothing wrong, you walked round a
## corner. So while the catch is stuck the line pays out and the breaking point
## goes with it; once the catch is coming again the line reels back in on its
## own, which it already did.
##
## Bounded rather than infinite: past this the catch really is somewhere the line
## cannot get it out of, and a leash with no end is worse than a break.
@export_range(1.0, 6.0, 0.25) var snag_slack := 3.0

## How fast a snagged catch is worked upward, in metres a second.
##
## A governed rate rather than a shove, and it is what makes the height of the
## wall stop mattering: the lift runs until the catch is climbing this fast and
## then holds, so a tall wall takes longer and nothing gets flung. Ungoverned,
## the same numbers threw a catch to three metres over a wall of one.
@export var snag_climb := 2.2

## How much the cargo slows you down, per size class over the first. Towing a
## wasp home should be a decision, not a free ride.
@export_range(0.0, 0.5, 0.01) var haul_drag := 0.13

@export var rope_segments := 12
@export var rope_iterations := 6
@export var rope_gravity := 7.0
@export_range(0.5, 1.0, 0.01) var rope_damping := 0.96
@export var rope_color := Color(0.92, 0.94, 1.0, 0.85)

var cargo: Node3D = null

var _spider: SpiderPlayer
var _growth: SpiderGrowth
var _view: SpiderCamera
var _climb: SpiderClimb
var _rope := PackedVector3Array()
var _previous := PackedVector3Array()
var _rope_length := 0.0
## Where the cargo was last frame, and how long it has been going nowhere while
## the line pulls. See [member snag_lift].
var _cargo_was := Vector3.ZERO
var _snagged := 0.0
var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _view_node: MeshInstance3D


## Handed its parts by the spider. Not read off the parent in _ready(), because
## a child is ready before its parent is and the spider's own pieces are not
## assigned yet at that point — which reads as a null silk pool the first time
## anything asks the line to cost something.
func setup(spider: SpiderPlayer, growth: SpiderGrowth,
		view: SpiderCamera, climb: SpiderClimb) -> void:
	_spider = spider
	_growth = growth
	_view = view
	_climb = climb


func _ready() -> void:
	_build_view()


func _physics_process(delta: float) -> void:
	if cargo == null:
		return
	if _eaten_off_the_line():
		_let_go("")
		return
	if not _still_there():
		_let_go("The line came back empty")
		return

	var hand := _hand()
	var tail := cargo.global_position
	var span := hand.distance_to(tail)
	if span > _rope_length * snap_strain:
		_let_go("The line snapped")
		return
	# A shot fired across the room pays out the whole distance, then winds
	# back to a length you can walk with. That is what makes hooking something
	# at range a harpoon rather than a yank.
	# Paid out while the catch is caught on something, reeled back in once it is
	# coming. The breaking point is a multiple of this, so it moves with it.
	var rest := _resting_length() * (snag_slack if _snagged > 0.0 else 1.0)
	_rope_length = move_toward(_rope_length, rest, reel_speed * delta)

	_haul(delta, hand, tail)
	_simulate_rope(delta, hand, cargo.global_position)
	_draw()


# --- hooking ------------------------------------------------------------

## Hooks whatever is under the crosshair, or cuts the line if already towing.
func toggle() -> bool:
	if cargo != null:
		var was := cargo
		_let_go("Let the %s go" % _label(was))
		return true
	var target := aimed_cargo()
	if target == null:
		notice.emit("Nothing to put a line on — wrap it first")
		return false
	return hook(target)


## Puts a line on something.
func hook(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target) or cargo != null:
		return false
	if _spider == null:
		return false
	if not can_carry(target):
		notice.emit("Not something you can drag along")
		return false
	# Paid out to wherever it is. A long shot is a long line, and then it reels.
	_rope_length = maxf(_resting_length(), _hand().distance_to(target.global_position))
	_cargo_was = target.global_position
	_snagged = 0.0
	cargo = target
	_watch_cargo(true)
	_reset_rope(_hand(), target.global_position)
	notice.emit("Hooked the %s" % _label(target))
	hooked.emit(target)
	return true


## Cuts the line, leaving the cargo where it is.
func cut() -> void:
	if cargo == null:
		return
	_let_go("Let the %s go" % _label(cargo))


func is_towing() -> bool:
	return cargo != null and is_instance_valid(cargo)


func cargo_name() -> String:
	return _label(cargo) if is_towing() else ""


## How slack the line is right now, as a fraction of its length. One is dead
## slack, zero is drawn tight. The HUD reads it so you can feel the pull.
func slack() -> float:
	if not is_towing() or _rope_length <= 0.0:
		return 0.0
	var span := _hand().distance_to(cargo.global_position)
	return clampf(1.0 - span / _rope_length, 0.0, 1.0)


## What the spider's speed is multiplied by while hauling. Nothing towed is
## free of it, and something three sizes up is a genuine haul.
func drag_factor() -> float:
	return 1.0 / (1.0 + maxf(cargo_weight() - 1.0, 0.0) * haul_drag)


## Anything already dealt with — a bundle, a wrapped catch, a catch that has
## worn itself out — and anything you put down yourself. A thing still fighting
## is not cargo: wrap it first, which is what the wrapping is for.
##
## Webs are not cargo any more. Dragging one home on a rope was fiddly and it made
## the catch depend on the trip — walk it through a corner and half of it spilled.
## A web comes home in one go now, and is gone: see [method collect_aimed].
func can_carry(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var prey := target as Prey
	if prey != null:
		# Not one still hanging in a web. Taking the web takes everything in it
		# now, so a catch that is in one has nothing left to gain from a line —
		# and while it counted as cargo, a click meant for the web picked the
		# creature out of it instead the moment that creature tired out or got
		# wrapped. Eating one where it hangs is still F, at fang reach.
		if prey.eaten or prey.held_by() != null:
			return false
		# A carcass is dead weight, the same as a bundle: something to drag home.
		return prey.wrapped or prey.is_secured() or prey.is_dead()
	return target is SilkDevice


## The thing worth hooking along the line of sight, near or far.
##
## Picked by how close it sits to the line rather than by a cone, and the
## tolerance is a slice of the screen with a ceiling on it — the same shape as
## the line pick, and for the same reason. A bundle is a small deliberate
## target, so a click that merely passed one on its way to a wall is a grapple
## and must stay one.
func aimed_cargo() -> Node3D:
	if _view == null or _spider == null:
		return null
	var origin := _view.aim_origin()
	var forward := _view.aim_forward()
	var wall := _wall_distance(origin, forward)
	var height := _height()

	var best: Node3D = null
	var best_gap := INF
	for group in ["prey", "silk_devices"]:
		for node in get_tree().get_nodes_in_group(group):
			var target := node as Node3D
			if target == null or not can_carry(target):
				continue
			var offset := target.global_position - origin
			var along := offset.dot(forward)
			if along <= 0.0 or along > wall:
				continue
			if reach > 0.0 and along > reach:
				continue
			var gap := (offset - forward * along).length()
			if gap > _aim_tolerance(along, height) or gap >= best_gap:
				continue
			best_gap = gap
			best = target
	return best


## How far off the line of sight something can sit at that distance and still be
## what you meant: a slice of the screen, with a floor and a ceiling on it.
##
## Only cargo is picked this way, and only because a bundle is small enough to be
## a point. A web is not — see [method _aimed_web], which casts at the thing
## itself because this rule finds a web roughly one time in fifteen.
func _aim_tolerance(along: float, height: float) -> float:
	return clampf(along * 0.05, height * 0.5, height * 2.0)


## The net worth taking down along the line of sight, near or far.
func aimed_web() -> WebStructure:
	var found := _aimed_web()
	return found.get("web") as WebStructure if not found.is_empty() else null


## The same, with how far down the line of sight it was hit, so a click can tell
## which of a web and a bundle was actually in front.
##
## Cast against the web's own colliders rather than measured against its origin
## point. The point version looked reasonable and was almost never right: a web is
## a surface metres across and the tolerance is a slice of the screen — half a
## metre at ten — so only a shot at the dead centre landed. Probed across the face
## of a sheet web it found it **once in fifteen**, and the other fourteen clicks
## fell through to the grapple, which is exactly what it looked like in play.
func _aimed_web() -> Dictionary:
	if _view == null or _spider == null:
		return {}
	var origin := _view.aim_origin()
	var forward := _view.aim_forward()
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [_spider.get_rid()]
	# WORLD as well as WEB, so the nearest hit wins and a web on the far side of a
	# wall is not something you can see, let alone take down.
	var query := PhysicsRayQueryParameters3D.create(origin,
		origin + forward * WALL_REACH, GameLayers.WORLD | GameLayers.WEB, exclude)
	# The sticky face is an Area3D, and it is the part of a web you can see and
	# therefore the part you point at.
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var web := _web_under(hit.get("collider"))
	# A road is a hit and not a web to take: the click falls through to the
	# grapple, which is how you get onto one.
	if web == null or not web.can_be_collected():
		return {}
	var along: float = origin.distance_to(hit["position"])
	if reach > 0.0 and along > reach:
		return {}
	return {"web": web, "along": along}


## The web a collider belongs to. A web's catch area and walkway are children of
## it, so this walks up rather than asking the collider itself.
func _web_under(collider: Variant) -> WebStructure:
	var node := collider as Node
	while node != null:
		var web := node as WebStructure
		if web != null:
			return web
		node = node.get_parent()
	return null


## What left mouse asks the tether first, and whether it dealt with the click.
##
## A catch comes to you on a line. A web comes to you in one piece and is gone.
## Firing silk at either should do something to *it* rather than haul you over to
## stand next to it, which is what the grapple would otherwise do.
##
## Whichever of the two is nearer along the line of sight wins. That is the only
## rule that matches what you can see: a bundle lying on the floor in *front* of a
## web is the thing you pointed at, and the web behind it is not — and the other
## way round just as much. Asking cargo first regardless was the first cut, and it
## meant a web with anything settled in it could not be taken at all, because the
## catch answered for it.
func take_aimed() -> bool:
	var found := _aimed_web()
	var target := aimed_cargo()
	if found.is_empty():
		return grab_aimed()
	if target != null and _along_aim(target.global_position) <= float(found["along"]):
		return grab_aimed()
	return _collect(found["web"] as WebStructure)


## How far down the line of sight something sits.
func _along_aim(point: Vector3) -> float:
	if _view == null:
		return INF
	return (point - _view.aim_origin()).dot(_view.aim_forward())


## Puts a line on the catch under the crosshair, and says whether it did.
func grab_aimed() -> bool:
	if cargo != null:
		return false
	var target := aimed_cargo()
	return target != null and hook(target)


## Takes down the web under the crosshair and brings it in, catches and all.
##
## The catches arrive bundled — silk still on them, going nowhere, yours to drain
## when you like — and the web is gone. That is the trade: a web is a larder while
## it stands, and collecting it is how you cash it in, which costs you the web. The
## same bargain [method WebStructure.on_prey_taken] already makes one catch at a
## time; this is the whole shelf at once.
func collect_aimed() -> bool:
	return _collect(aimed_web())


func _collect(web: WebStructure) -> bool:
	if web == null or not is_instance_valid(web):
		return false
	var label := web.label()
	var took := web.collect(_hand(), _height() * 1.5)
	if took <= 0:
		notice.emit("Took the %s down — there was nothing in it" % label)
	elif took == 1:
		notice.emit("Took the %s and what was in it — a bundle at your feet" % label)
	else:
		notice.emit("Took the %s and what was in it — %d bundles at your feet"
			% [label, took])
	return true


## How far the crosshair gets before it meets something solid. Cargo behind a
## wall is not cargo you can see, let alone hook.
func _wall_distance(origin: Vector3, forward: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if _spider != null:
		exclude.append(_spider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * WALL_REACH,
		GameLayers.WORLD, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return WALL_REACH
	return origin.distance_to(hit["position"]) + _height()


func _resting_length() -> float:
	return _height() * rope_bodies


# --- the rope -----------------------------------------------------------

## The cargo is pulled only once it is further away than the line is long, and
## it is pulled rather than placed, so it swings in behind you instead of
## snapping to a fixed distance.
func _haul(delta: float, hand: Vector3, tail: Vector3) -> void:
	var shifted := tail - _cargo_was
	_cargo_was = tail
	var offset := hand - tail
	var span := offset.length()
	if span <= _rope_length or span < 0.0001:
		# Slack line, so getting nowhere is not the line's fault.
		_snagged = maxf(0.0, _snagged - delta * 2.0)
		return
	var along := offset / span
	var pull := along * (span - _rope_length) * haul_force
	var prey := cargo as Prey
	if prey != null:
		# Pulling hard and the catch is not coming: it is against something. Ramp
		# a lift in and it goes over, then let go twice as fast as it built so the
		# swing settles the moment the catch is moving again.
		#
		# Progress is measured *along the pull*, not as plain movement. Plain
		# movement was the first cut and it oscillated, because the lift is its
		# own undoing: the catch rises, rising counts as moving, moving cancels
		# the lift, the catch drops back. Projected onto the line, going up is not
		# progress, so the lift holds until the catch is actually coming.
		if shifted.dot(along) < _height() * 0.02:
			_snagged += delta
		else:
			_snagged = maxf(0.0, _snagged - delta * 2.0)
		var ramp := clampf(_snagged / maxf(snag_patience, 0.01), 0.0, 1.0)
		var lift := Vector3.ZERO
		if ramp > 0.0 and prey.velocity.y < snag_climb * ramp:
			lift = Vector3.UP * snag_lift * ramp
		prey.tow((pull + lift) * delta)
		return
	# A device has no physics of its own, so it simply comes along.
	cargo.global_position = tail + along * (span - _rope_length)


func _simulate_rope(delta: float, hand: Vector3, tail: Vector3) -> void:
	if _rope.size() != rope_segments + 1:
		_reset_rope(hand, tail)
	var fall := Vector3.DOWN * rope_gravity * delta * delta
	for i in range(1, _rope.size() - 1):
		var current := _rope[i]
		var drift := (current - _previous[i]) * rope_damping
		_previous[i] = current
		_rope[i] = current + drift + fall
	_rope[0] = hand
	_rope[_rope.size() - 1] = tail

	# Rope, not rod: a segment shorter than its rest length is slack and is
	# left alone, so the line sags between you and whatever you are dragging
	# and only goes taut when it is actually holding something back.
	var rest: float = _rope_length / float(rope_segments)
	for iteration in rope_iterations:
		for i in _rope.size() - 1:
			var a := _rope[i]
			var b := _rope[i + 1]
			var between := b - a
			var distance := between.length()
			if distance <= rest or distance < 0.0001:
				continue
			var fix := between * ((distance - rest) / distance) * 0.5
			if i > 0:
				_rope[i] = a + fix
			if i + 1 < _rope.size() - 1:
				_rope[i + 1] = b - fix
		_rope[0] = hand
		_rope[_rope.size() - 1] = tail


func _reset_rope(hand: Vector3, tail: Vector3) -> void:
	_rope.resize(rope_segments + 1)
	_previous.resize(rope_segments + 1)
	for i in _rope.size():
		var along := float(i) / float(rope_segments)
		var point := hand.lerp(tail, along)
		_rope[i] = point
		_previous[i] = point


func _let_go(text: String) -> void:
	var was := cargo
	_watch_cargo(false)
	cargo = null
	_snagged = 0.0
	_rope.clear()
	_previous.clear()
	_draw()
	if text != "":
		notice.emit(text)
	released.emit(was)


# --- odds and ends ------------------------------------------------------

## Told when the thing on the line is drained, rather than working it out
## afterwards from the fact that it is gone.
##
## Which is what the old version did, and it was a race it usually lost: eating
## happens on an input frame and frees the creature at the end of it, so by the
## tether's next physics tick there was nothing left to ask. All it could see was
## a cargo that had vanished, so every meal came back as "the line came back
## empty" — a success reported as a failure, every time.
func _watch_cargo(watching: bool) -> void:
	var prey := cargo as Prey
	if prey == null:
		return
	if watching:
		if not prey.eaten_by_spider.is_connected(_on_cargo_eaten):
			prey.eaten_by_spider.connect(_on_cargo_eaten)
	elif prey.eaten_by_spider.is_connected(_on_cargo_eaten):
		prey.eaten_by_spider.disconnect(_on_cargo_eaten)


## You ate it. That is what a tether is for, so the line goes quietly: a report
## here would land on top of the one that just said what you got out of it.
func _on_cargo_eaten(prey: Prey) -> void:
	if prey != cargo:
		return
	_let_go("")


## Whether the cargo went because the spider drained it, rather than because it
## stopped existing for some other reason. The signal above is what usually
## catches this; this is for the tick where the flag is set and the signal has
## not been reached yet.
func _eaten_off_the_line() -> bool:
	if not is_instance_valid(cargo):
		return false
	var prey := cargo as Prey
	return prey != null and prey.eaten


func _still_there() -> bool:
	if not is_instance_valid(cargo) or cargo.is_queued_for_deletion():
		return false
	var prey := cargo as Prey
	if prey != null and prey.eaten:
		return false
	var device := cargo as SilkDevice
	return device == null or not device.is_queued_for_deletion()


## Where the line leaves the spider — a little above where it stands, so the
## rope does not start inside the floor.
func _hand() -> Vector3:
	var up := _climb.body_up() if _climb != null else Vector3.UP
	return _spider.global_position + up * _height() * 0.4


func _label(target: Node3D) -> String:
	if target == null:
		return "thing"
	var prey := target as Prey
	if prey != null:
		return prey.species
	var device := target as SilkDevice
	return device.label() if device != null else target.name


## What is on the line, in size classes — one when there is nothing. What slows
## the spider down ([method drag_factor]) and what makes a sprint cost more
## ([method SpiderVitals.sprint_effort]) are the same number, read from here so
## they cannot drift apart.
func cargo_weight() -> float:
	return _weight_of(cargo) if is_towing() else 1.0


func _weight_of(target: Node3D) -> float:
	var prey := target as Prey
	return float(prey.size_class) if prey != null else 1.0


func _height() -> float:
	return _growth.current_stage().body_height if _growth != null else 0.35


func _quality() -> float:
	return _growth.current_stage().silk_quality if _growth != null else 1.0


func _build_view() -> void:
	_material = WebGeometry.silk_material()
	_mesh = ImmediateMesh.new()
	_view_node = MeshInstance3D.new()
	_view_node.name = "TetherLine"
	_view_node.mesh = _mesh
	_view_node.material_override = _material
	_view_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view_node.top_level = true
	add_child(_view_node)
	_view_node.transform = Transform3D.IDENTITY


func _draw() -> void:
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	if _rope.size() < 2:
		return
	var width: float = maxf(_height() * 0.045, 0.004)
	for i in _rope.size() - 1:
		WebGeometry.draw_line_into(_mesh, _material, _rope[i], _rope[i + 1],
			width, rope_color)
