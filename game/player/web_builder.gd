class_name WebBuilder
extends Node3D

## Build mode: aim, drop anchors, spin a web between them.
##
## The player never places a prefab. They shoot silk at real surfaces, and the
## shape of the web falls out of where those anchors landed — which is what
## makes a corner, a doorway and a drain all play differently.

signal state_changed()
signal notice(text: String)
signal web_built(web: WebStructure)

## Why the current aim point cannot be anchored.
enum Problem {
	NONE,
	NO_SURFACE,      ## nothing solid under the crosshair, or out of range
	TOO_FAR,         ## further from the last anchor than this size can span
	TOO_CLOSE,       ## practically on top of the last anchor
	FULL,            ## pattern has taken all the anchors it allows
	NO_SILK,         ## the web as drawn costs more than we carry
	LOCKED,          ## pattern needs a bigger spider
}

## Where finished webs are parented. Defaults to a "Webs" node in the level.
@export var web_container_path: NodePath

## Flat silk cost of running a signal line between two webs.
@export var link_base_cost := 1.5

## Silk per metre of signal line.
@export var link_silk_per_metre := 0.5

## Most anchors one run round a frame may have.
@export var max_chain := 12

## How far a grapple may reach, in metres. Zero means as far as you can see.
## The size tiers gate what you can hold and how much you can spin — not where
## you are allowed to go, because being stuck within three metres of yourself
## is what made getting about a chore.
@export var grapple_reach := 0.0

## How long holding the place key takes to grow a web from its smallest to the
## biggest this size tier can spin.
@export var place_grow_time := 1.1

## Pattern dragged between anchors when the chosen one is a net.
const FRAME_PATTERN := "frame_line"

## Stand-in for "no limit": further than any sane level is wide, so the ray
## stops at geometry rather than at a rule.
const UNLIMITED_REACH := 4096.0

## Corners on a placed web's rim. More than it takes to read as round, because
## they are what the shape of a gap gets recorded in.
const PLACE_SIDES := 16

## Closest a rim corner may sit to the middle. Silk can hug a corner tightly,
## but a web that reaches almost nowhere on one side is a sliver, not a trap.
const PLACE_MIN_SPAN := 0.18

## How far ahead the charge ghost sits when the crosshair has found nothing,
## so a throw at open sky still shows the size being wound up.
const CHARGE_GHOST_RANGE := 6.0

## How long a thrown web takes to spring out to full size. Looks only — the
## silk catches at its real size from the moment it lands.
const ARRIVAL_SPRING := 0.18

var patterns: Array[WebPattern] = []
var pattern_index := 0
var building := false

## Dial settings, kept per pattern so an orb web you like spun tight stays that
## way when you come back to it.
var tunings := {}

## How new webs are woven. A test switch: stretched webs take the shape you
## drew, inscribed ones keep an even spiral inside the frame.
var weave: WebGeometry.Weave = WebGeometry.Weave.STRETCHED

## Which dial the tuning keys are pointed at.
var selected_dial: WebTuning.Dial = WebTuning.Dial.TENSION

## Rigs the player has saved, and which one is on the end of the cursor.
var designs: Array[WebDesign] = []
var design_index := 0
var placing_design := false
var anchors := PackedVector3Array()

## Web waiting to be wired to something, while the player picks the other end.
var link_source: SilkNode = null

## Spinning a web where you are pointing: held down, it grows.
var placing := false
var place_radius := 0.0
var place_centre := Vector3.ZERO
var place_normal := Vector3.UP
var place_valid := false

## Stopped growing because the next size over is more silk than we have.
var place_capped := false

## Whether letting go throws a bolt of silk that opens where it lands, rather
## than putting the web straight down under the crosshair. A test switch while
## the two are being compared.
var throwing := false

## A bolt in flight, so a second press cannot send another.
var _shot: SilkShot = null

## How many rim corners found something to hold onto, and how much the web
## would actually cover once the room has had its say.
var place_anchored := 0
var place_area := 0.0

## What the throw is aimed over, if anything — the web centres on it instead
## of on the surface behind it.
var place_target: Node3D = null

var aim_valid := false
var aim_point := Vector3.ZERO
var aim_normal := Vector3.UP
var problem := Problem.NONE
var estimated_cost := 0.0

var _spider: CharacterBody3D
var _silk: SilkPool
var _growth: SpiderGrowth
var _view: SpiderCamera
var _climb: SpiderClimb

## Frame strands laid on the way round the current chain.
var _chain: Array[WebStrand] = []
var _pending_anchor := Vector3.ZERO
var _awaiting_grapple := false

## Where the spider pushed off from, so the line it drags has somewhere to
## start once it lands.
var _launched_from := Vector3.ZERO

## A line the current grapple is aimed at, to be ridden on arrival instead of
## having fresh silk laid out to it.
var _pending_ride: WebStrand = null

## Rings of silk the player could weave into, and what they were built from.
var _loops: Array = []
var _loop_source := 0
var _preview: MeshInstance3D
var _preview_mesh: ImmediateMesh
var _preview_material: StandardMaterial3D
var _cursor: MeshInstance3D
var _cursor_mesh: SphereMesh
var _cursor_material: StandardMaterial3D


func _ready() -> void:
	patterns = WebLibrary.load_patterns()
	designs = DesignLibrary.load_all()
	_select_first_spinnable()
	_build_preview_nodes()
	set_process(true)


## Wires the builder to the spider that owns it.
func setup(spider: CharacterBody3D, silk: SilkPool, growth: SpiderGrowth,
		view: SpiderCamera, climb: SpiderClimb = null) -> void:
	_spider = spider
	_silk = silk
	_growth = growth
	_view = view
	_climb = climb
	if _climb != null:
		_climb.grappled.connect(_on_grappled)


func _process(delta: float) -> void:
	if placing:
		_grow_placement(delta)
	elif placing_design:
		_update_design_aim()
	else:
		_update_aim()
	_draw_preview()


# --- spinning a web where you point -------------------------------------

## Start spinning. Held down the web grows; letting go puts it there.
##
## This replaced filling a ring the player had grappled around. That version
## read well and played badly: it asked you to enclose an area by accident and
## then go and find it again. Pointing at a spot and spinning a web there is
## what people actually try to do, so it is what the game does.
func begin_place() -> bool:
	if placing or placing_design:
		return false
	var pattern := current_pattern()
	if pattern == null:
		return false
	if pattern.shape != WebPattern.Shape.NET:
		notice.emit("%s is a line — grapple it across a gap instead"
			% pattern.display_name)
		return false
	if not _is_unlocked(pattern):
		notice.emit("%s needs a bigger spider" % pattern.display_name)
		return false
	placing = true
	place_capped = false
	place_radius = _min_place_radius()
	_update_placement()
	# You can never start something you could not finish: growth stops when
	# the silk runs out, so refusing here is the same rule at its floor.
	if place_valid and not _silk.can_afford(estimated_cost):
		placing = false
		notice.emit("Not enough silk for even a small web — %d needed"
			% ceili(estimated_cost))
		return false
	state_changed.emit()
	return true


## Let go: spin what the ghost was showing.
func commit_place() -> bool:
	if not placing:
		return false
	placing = false
	_update_placement()
	state_changed.emit()
	if throwing:
		return _throw_place()
	if not place_valid:
		notice.emit("Nothing to spin a web against")
		return false

	var pattern := current_pattern()
	var dials := tuning_for(pattern)
	var rim := place_rim()
	var smallest := _min_place_radius()
	if place_area < smallest * smallest:
		notice.emit("Too tight in there to get a web up")
		return false
	var web := WebNet.spin(dials.apply_to(pattern), rim, _quality(), weave, true)
	if web == null:
		notice.emit("No room for a web there")
		return false
	if not _silk.can_afford(web.silk_cost):
		notice.emit("Not enough silk — %d needed" % ceili(web.silk_cost))
		web.free()
		return false

	web.tuning = dials.copy()
	_silk.spend(web.silk_cost)
	web.place_in(_resolve_container())
	_loop_source = -1
	web_built.emit(web)
	if web.bundled_on_arrival > 0 and web.snared_count() == 0:
		# The silk went round what it hit. There is nothing left to hang on a
		# wall, so the web goes with it rather than sitting there empty.
		notice.emit("%s thrown over %d — wrapped and dropped (%d silk)"
			% [pattern.display_name, web.bundled_on_arrival, roundi(web.silk_cost)])
		# web_built has already gone out with this one, so anything that kept
		# hold of it is looking at a web that is about to stop existing. Every
		# listener in the game checks is_instance_valid before touching a web;
		# anything new must too, because reading a freed one is a crash rather
		# than an error.
		web.unlink_all()
		web.queue_free()
		return true
	if web.bundled_on_arrival > 0:
		notice.emit("%s thrown over %d, and still holding %d (%d silk)"
			% [pattern.display_name, web.bundled_on_arrival, web.snared_count(),
			roundi(web.silk_cost)])
	elif web.caught_on_arrival > 0:
		notice.emit("%s caught %d on the way up, still fighting (%d silk)"
			% [pattern.display_name, web.caught_on_arrival, roundi(web.silk_cost)])
	elif place_anchored > 0:
		notice.emit("%s spun into the gap, %.2f m2 on %d anchors (%d silk)"
			% [pattern.display_name, place_area, place_anchored, roundi(web.silk_cost)])
	else:
		notice.emit("%s spun, %.2f m2 (%d silk)"
			% [pattern.display_name, place_area, roundi(web.silk_cost)])
	return true


## Sends a bolt of silk off to open out wherever it lands. The size the throw
## was charged to travels with it, so holding still decides how big the web is
## — you just find out where it went a moment later.
func _throw_place() -> bool:
	if shot_in_flight():
		return false
	var pattern := current_pattern()
	if pattern == null or _view == null:
		return false
	if not _silk.can_afford(estimated_cost):
		notice.emit("Not enough silk to throw one — %d needed" % ceili(estimated_cost))
		return false

	var charged := place_radius
	var shot := SilkShot.fire(_view.aim_origin(), _view.aim_forward(),
		_stage().body_height, _exclusions())
	shot.landed.connect(func(at: Vector3, normal: Vector3, prey: Node3D) -> void:
		_open_web_at(at, normal, prey, charged))
	shot.fizzled.connect(func() -> void: notice.emit("The silk went wide"))
	# Straight from where aiming starts, with no head start down the barrel. An
	# offset looks tidier and tunnels: aiming starts at the spider's own body in
	# third person, so a body length forward is through the floor it is standing
	# on. The sweep covers that first stretch anyway, and the spider is excluded
	# from it.
	shot.launch_from(_resolve_container(), _view.aim_origin())
	_shot = shot
	notice.emit("%s thrown" % pattern.display_name)
	return true


## A bolt landed. Open it out there, at the size it was charged to, fitted to
## whatever it found — which is the same fitting a placed web gets.
func _open_web_at(at: Vector3, normal: Vector3, prey: Node3D, charged: float) -> void:
	_shot = null
	var pattern := current_pattern()
	if pattern == null:
		return
	place_radius = charged
	place_normal = normal
	place_centre = at + normal * clampf(charged * 0.2, 0.02, 0.4)
	if prey != null:
		# Over the thing rather than off the skin of it, the same way the placed
		# web centres on prey: a catch volume is a thin slab around the web's own
		# plane, so half a metre of clearance would catch nothing.
		place_normal = -_view.aim_forward() if _view != null else normal
		place_centre = at
	place_valid = true
	place_target = prey

	var dials := tuning_for(pattern)
	var rim := place_rim()
	var smallest := _min_place_radius()
	if place_area < smallest * smallest:
		notice.emit("It landed somewhere too tight to open out")
		return
	var web := WebNet.spin(dials.apply_to(pattern), rim, _quality(), weave, true)
	if web == null:
		notice.emit("It landed somewhere a web will not hold")
		return
	if not _silk.can_afford(web.silk_cost):
		notice.emit("Not enough silk to open it — %d needed" % ceili(web.silk_cost))
		web.free()
		return

	web.tuning = dials.copy()
	_silk.spend(web.silk_cost)
	web.place_in(_resolve_container())
	_loop_source = -1
	web_built.emit(web)
	if web.bundled_on_arrival > 0 and web.snared_count() == 0:
		notice.emit("Caught it mid-air — wrapped and dropped (%d silk)"
			% roundi(web.silk_cost))
		web.unlink_all()
		web.queue_free()
		return
	web.play_arrival(ARRIVAL_SPRING)
	notice.emit("%s opened out, %.2f m2 (%d silk)"
		% [pattern.display_name, place_area, roundi(web.silk_cost)])


## Switches between putting the web down where you point and throwing a bolt
## of silk that opens out where it lands.
func toggle_throwing() -> void:
	throwing = not throwing
	state_changed.emit()
	notice.emit("Webs: %s" % throw_name())


func throw_name() -> String:
	if throwing:
		return "thrown — a bolt that opens where it lands"
	return "placed — straight down where you point"


## True while a bolt is still in the air.
func shot_in_flight() -> bool:
	return _shot != null and is_instance_valid(_shot)


func cancel_place() -> void:
	if not placing:
		return
	placing = false
	place_valid = false
	state_changed.emit()


## The outline a placed web would have: a ring facing you at the aim point,
## with every corner run out until it meets something.
##
## Holding the key sets how far a corner is *allowed* to reach, and the room
## decides where it actually stops. So the same press gives you a wide circle
## in open air and a web that fills the angle when you point into a corner —
## the shape is the space, not a disc dropped into it.
func place_rim() -> PackedVector3Array:
	var rim := PackedVector3Array()
	if not place_valid:
		return rim
	var right := place_normal.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = place_normal.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(place_normal).normalized()

	var space := get_world_3d().direct_space_state
	var exclude := _exclusions()
	var floor_span: float = maxf(place_radius * PLACE_MIN_SPAN, 0.05)
	# Silk is drawn as crossed quads with real thickness, so a corner sitting
	# exactly on the surface it found buries half of itself in the wall. Stop
	# just shy of it instead, by enough to clear the strand.
	var pattern := current_pattern()
	var inset := 0.02
	if pattern != null:
		inset = maxf(pattern.strand_thickness * _quality() * 5.0, 0.02)
	place_anchored = 0
	for i in PLACE_SIDES:
		var angle := TAU * float(i) / float(PLACE_SIDES)
		var direction := (right * cos(angle) + up * sin(angle)).normalized()
		# Reaching exactly as far as it is allowed to, so open air gives the
		# full held size and anything solid cuts the corner short where it is.
		var span := place_radius
		var query := PhysicsRayQueryParameters3D.create(place_centre,
			place_centre + direction * place_radius, GameLayers.WORLD, exclude)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			span = maxf(place_centre.distance_to(hit["position"]) - inset, floor_span)
			place_anchored += 1
		rim.append(place_centre + direction * span)
	place_area = _polygon_area(rim)
	return rim


## The ghost for a throw. Which room the bolt lands in is not known yet, so
## this is the plain size being wound up rather than a rim fitted to whatever
## the crosshair happens to be resting on — the fitting happens on arrival.
## It also has to draw with nothing under the crosshair at all, because a
## throw at open sky is a throw, not an error.
func place_charge_ring() -> PackedVector3Array:
	var ring := PackedVector3Array()
	if _view == null:
		return ring
	var normal := -_view.aim_forward()
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	normal = normal.normalized()
	var right := normal.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = normal.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(normal).normalized()
	var centre := place_charge_centre()
	for i in PLACE_SIDES:
		var angle := TAU * float(i) / float(PLACE_SIDES)
		ring.append(centre + (right * cos(angle) + up * sin(angle)) * place_radius)
	return ring


## Middle of a charge ghost: on the crosshair when it found something, and a
## fixed distance ahead when it did not.
func place_charge_centre() -> Vector3:
	if place_valid or _view == null:
		return place_centre
	return _view.aim_origin() + _view.aim_forward() * CHARGE_GHOST_RANGE


## Where the web would go and which way it would face: straight out from the
## crosshair, turned to face you, so what you see is what you get.
func _update_placement() -> void:
	place_valid = false
	estimated_cost = 0.0
	if _view == null:
		return
	if not _cast_surface(UNLIMITED_REACH):
		return
	var facing := -_view.aim_forward()
	if facing.length_squared() < 0.000001:
		facing = aim_normal
	place_normal = facing.normalized()
	# Point at something and the web goes over *it*, not onto the wall behind
	# it. Without this, throwing silk at a moth puts a web a metre past the
	# moth and catches nothing, because a catch volume is a thin slab around
	# the web's own plane.
	place_target = _prey_under_crosshair()
	if place_target != null:
		place_centre = place_target.global_position
	else:
		place_centre = aim_point + place_normal * clampf(place_radius * 0.2, 0.02, 0.4)
	# Never let the middle of a web sit inside whatever the crosshair found.
	var clearance := place_normal.dot(place_centre - aim_point)
	if clearance < 0.02:
		place_centre += place_normal * (0.02 - clearance)
	place_valid = true
	var pattern := current_pattern()
	if pattern != null:
		estimated_cost = _estimate_cost(pattern, place_rim())


## Grows the web while the key is held, and stops when the next size over
## costs more silk than we have. Running out is the ceiling rather than an
## error at the end: the ghost simply stops getting bigger, with the price on
## screen, instead of letting you hold down a key for a web you cannot buy.
func _grow_placement(delta: float) -> void:
	if place_capped or place_radius >= _max_place_radius():
		_update_placement()
		return
	var previous := place_radius
	place_radius = minf(place_radius + _place_growth_rate() * delta,
		_max_place_radius())
	_update_placement()
	if _silk.can_afford(estimated_cost) or previous <= _min_place_radius():
		return
	place_radius = previous
	place_capped = true
	_update_placement()


## Whatever prey is sitting on the line of sight, nearer than the surface the
## crosshair found. Generous about alignment, the way every other pick in the
## game is, because a fly is a small thing to have to centre exactly.
func _prey_under_crosshair() -> Node3D:
	if _view == null or _spider == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var limit := from.distance_to(aim_point)
	var tolerance: float = maxf(_stage().body_height, 0.3)

	var best: Node3D = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		if prey.is_bundled() or prey.is_stuck():
			continue
		var offset := prey.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > limit:
			continue
		var off_axis := (offset - direction * along).length()
		if off_axis > tolerance or off_axis >= best_score:
			continue
		best_score = off_axis
		best = prey
	return best


## Smallest web worth spinning at this size.
func _min_place_radius() -> float:
	return maxf(_stage().body_height * 1.2, 0.2)


## Biggest, before silk has its say. A strand limit is how far one thread can
## span, so a web that wide across is the natural reading of it — using it as
## a radius gave a Huntsman a ten-metre web it could never have paid for.
func _max_place_radius() -> float:
	return maxf(_stage().max_strand_length * 0.5, _min_place_radius() * 2.0)


func _place_growth_rate() -> float:
	return (_max_place_radius() - _min_place_radius()) / maxf(place_grow_time, 0.05)


# --- build mode ---------------------------------------------------------

func toggle() -> void:
	if building:
		stop()
	else:
		start()


func start() -> void:
	if building:
		return
	building = true
	_end_chain()
	if not _is_unlocked(current_pattern()):
		_select_first_unlocked()
	notice.emit("Build mode: %s" % _pattern_name())
	state_changed.emit()


func stop() -> void:
	if not building:
		return
	building = false
	_end_chain()
	problem = Problem.NONE
	estimated_cost = 0.0
	state_changed.emit()


## Go to wherever the crosshair is, trailing silk. This is the game's main
## verb and it has no mode around it: moving and building are the same act, so
## the web ends up being a record of where you went.
func place() -> void:
	if placing_design:
		place_design()
		return
	if _awaiting_grapple:
		return
	if current_pattern() == null:
		return
	_update_aim()

	if problem != Problem.NONE:
		notice.emit(problem_text())
		return

	_launched_from = _line_start()
	_pending_ride = aimed_line()
	if _pending_ride != null:
		# Joining the road network rather than extending it: no new silk, you
		# just get on.
		aim_point = Geometry3D.get_closest_point_to_segment(aim_point,
			_pending_ride.point_a, _pending_ride.point_b)
	if _climb != null and _climb.grapple_to(aim_point, aim_normal):
		_pending_anchor = aim_point
		_awaiting_grapple = true
		return
	_arrive_at(aim_point)


func _on_grappled(_point: Vector3, _normal: Vector3) -> void:
	if not _awaiting_grapple:
		return
	_awaiting_grapple = false
	_arrive_at(_pending_anchor)


## Landed. The line behind is the silk dragged on the way, which is all there
## is to building now — no anchor list to keep in your head, no mode to be in.
func _arrive_at(point: Vector3) -> void:
	if _pending_ride != null:
		var line := _pending_ride
		_pending_ride = null
		if is_instance_valid(line) and _climb != null and _climb.ride_line(line):
			return
	if building:
		# The scripted run: saved designs and the test suite still walk an
		# explicit ring and weave it with finish().
		add_anchor(point)
		return
	if _launched_from.distance_to(point) > 0.01:
		_lay_line(_launched_from, point)
	_loop_source = -1
	state_changed.emit()


## Where a dragged line starts: the end of a scripted run, or simply where the
## spider is standing.
func _line_start() -> Vector3:
	if building and anchors.size() > 0:
		return anchors[anchors.size() - 1]
	if _spider != null:
		return _spider.global_position
	return aim_point


## Drops an anchor at an explicit world point, laying silk from the last one.
## Grappling calls this on arrival; tests and scripted builds can call it
## directly to skip the journey.
func add_anchor(point: Vector3) -> bool:
	var pattern := current_pattern()
	if not building or pattern == null:
		return false
	if anchors.size() >= max_chain:
		notice.emit("That is as long a run as this silk will take")
		return false
	if anchors.size() > 0:
		if _lay_line(anchors[anchors.size() - 1], point) == null:
			return false
	anchors.append(point)
	state_changed.emit()
	# Came back round to where it started: that encloses something.
	if anchors.size() >= 3 and pattern.shape == WebPattern.Shape.NET \
			and point.distance_to(anchors[0]) <= _snap_radius():
		finish()
	return true


## Strings one frame line and charges for it. This is what walking the frame
## costs — the inside of a web is priced separately, when it is woven.
func _lay_line(from: Vector3, to: Vector3) -> WebStrand:
	var pattern := drag_pattern()
	if pattern == null:
		return null
	var dials := tuning_for(pattern)
	var strand := WebStrand.spin(dials.apply_to(pattern), from, to, _quality())
	if strand == null:
		notice.emit("That line has nowhere to go")
		return null
	if not _silk.can_afford(strand.silk_cost):
		notice.emit("Not enough silk for that line — %d needed" % ceili(strand.silk_cost))
		strand.free()
		return null
	_silk.spend(strand.silk_cost)
	strand.tuning = dials.copy()
	strand.place_in(_resolve_container())
	_chain.append(strand)
	_loop_source = -1
	web_built.emit(strand)
	return strand


## What gets dragged between anchors: the chosen pattern if it is a strand,
## otherwise plain frame line waiting to be woven into.
func drag_pattern() -> WebPattern:
	var pattern := current_pattern()
	if pattern != null and pattern.shape == WebPattern.Shape.STRAND:
		return pattern
	return _pattern_by_id(FRAME_PATTERN)


## Takes the last anchor back, pulling its line down, or leaves build mode.
func undo() -> void:
	if placing_design:
		toggle_design_mode()
		return
	if not building:
		return
	if anchors.is_empty():
		stop()
		notice.emit("Build mode off")
		return
	if not _chain.is_empty():
		var strand: WebStrand = _chain.pop_back()
		if is_instance_valid(strand):
			_silk.refill(strand.demolish())
	anchors.remove_at(anchors.size() - 1)
	state_changed.emit()


## Closes the loop and weaves the inside of it. The frame is already up — the
## spider walked it — so only the silk inside is spun and paid for here.
func finish() -> void:
	if not building:
		return
	var pattern := current_pattern()
	if pattern == null:
		return

	if pattern.shape == WebPattern.Shape.STRAND:
		var laid := _chain.size()
		_end_chain()
		notice.emit("%d line%s laid" % [laid, "" if laid == 1 else "s"])
		return

	if anchors.size() < 3:
		# Not walking a run: weave whatever ring is under the crosshair instead.
		if fill_aimed_loop():
			_end_chain()
			return
		notice.emit("Walk three anchors, or look at a ring of silk")
		return

	# Close the ring if the spider has not already walked back to the start.
	var last := anchors[anchors.size() - 1]
	if last.distance_to(anchors[0]) > _snap_radius():
		if _lay_line(last, anchors[0]) == null:
			return

	var dials := tuning_for(pattern)
	var web := WebNet.spin(dials.apply_to(pattern), anchors, _quality(), weave, false)
	if web == null:
		notice.emit("Nothing to weave in there")
		_end_chain()
		return
	if not _silk.can_afford(web.silk_cost):
		notice.emit("Not enough silk to weave it — %d needed" % ceili(web.silk_cost))
		web.free()
		return

	web.tuning = dials.copy()
	_silk.spend(web.silk_cost)
	web.place_in(_resolve_container())
	_end_chain()
	state_changed.emit()
	web_built.emit(web)
	notice.emit("%s woven (%d silk)" % [pattern.display_name, roundi(web.silk_cost)])


## Area the current chain encloses, or zero if it does not enclose anything.
func enclosed_area() -> float:
	if anchors.size() < 3:
		return 0.0
	var normal := WebGeometry.plane_normal(anchors)
	var total := Vector3.ZERO
	for i in anchors.size():
		total += anchors[i].cross(anchors[(i + 1) % anchors.size()])
	return absf(total.dot(normal)) * 0.5


func _end_chain() -> void:
	anchors.clear()
	_chain.clear()
	_awaiting_grapple = false


func cycle(step: int) -> void:
	if placing_design:
		cycle_design(step)
		return
	var available := unlocked_patterns()
	if available.size() <= 1:
		return
	var current := current_pattern()
	var index := available.find(current)
	index = wrapi(index + step, 0, available.size())
	pattern_index = patterns.find(available[index])
	anchors.clear()
	state_changed.emit()
	notice.emit(_pattern_name())


## Dials for a pattern, made on demand the first time it is asked for.
func tuning_for(pattern: WebPattern) -> WebTuning:
	if pattern == null:
		return WebTuning.new()
	if not tunings.has(pattern.id):
		tunings[pattern.id] = WebTuning.new()
	return tunings[pattern.id]


## Dials for the pattern on the end of the cursor.
func current_tuning() -> WebTuning:
	return tuning_for(current_pattern())


## Flips between the two ways of weaving the inside of a web.
func toggle_weave() -> void:
	weave = WebGeometry.Weave.INSCRIBED if weave == WebGeometry.Weave.STRETCHED \
		else WebGeometry.Weave.STRETCHED
	state_changed.emit()
	notice.emit("Weave: %s" % weave_name())


func weave_name() -> String:
	if weave == WebGeometry.Weave.INSCRIBED:
		return "inscribed — even spiral inside the frame"
	return "stretched — the web is the shape you drew"


## Points the tuning keys at the next dial along.
func cycle_dial(step: int) -> void:
	var count := WebTuning.DIAL_NAMES.size()
	selected_dial = wrapi(selected_dial + step, 0, count) as WebTuning.Dial
	state_changed.emit()
	notice.emit(WebTuning.DIAL_HINTS[selected_dial])


## Turns the selected dial. Every one of them costs something to gain
## something, so there is no setting that is simply better.
func adjust_dial(step: int) -> void:
	var pattern := current_pattern()
	if pattern == null:
		return
	var tuning := tuning_for(pattern)
	if not tuning.nudge(selected_dial, step):
		notice.emit("%s is as far as it goes" % WebTuning.DIAL_NAMES[selected_dial])
		return
	state_changed.emit()
	notice.emit("%s   %s" % [tuning.bar(selected_dial), tuning.hint(selected_dial)])


## Puts every dial on this pattern back to the middle.
func reset_dials() -> void:
	var pattern := current_pattern()
	if pattern == null:
		return
	tunings[pattern.id] = WebTuning.new()
	state_changed.emit()
	notice.emit("%s dials back to standard" % pattern.display_name)


## The pattern as it would actually be spun right now, dials included.
func tuned_pattern() -> WebPattern:
	var pattern := current_pattern()
	if pattern == null:
		return null
	return tuning_for(pattern).apply_to(pattern)


func current_pattern() -> WebPattern:
	if patterns.is_empty():
		return null
	return patterns[clampi(pattern_index, 0, patterns.size() - 1)]


func unlocked_patterns() -> Array[WebPattern]:
	var available: Array[WebPattern] = []
	for pattern in patterns:
		if _is_unlocked(pattern):
			available.append(pattern)
	return available


# --- saved designs ------------------------------------------------------

func current_design() -> WebDesign:
	if designs.is_empty():
		return null
	return designs[clampi(design_index, 0, designs.size() - 1)]


## Records the rig under the crosshair — the web plus everything wired to it —
## as a design that can be put down again anywhere.
func save_aimed_design() -> WebDesign:
	var web := aimed_web()
	if web == null:
		notice.emit("Look at a web to keep it as a design")
		return null
	var design := DesignLibrary.capture(web, _facing(), _growth.stage_index)
	if design == null:
		notice.emit("Nothing there worth keeping")
		return null
	design.display_name = _unique_design_name(design.display_name)
	if not DesignLibrary.store(design):
		notice.emit("Could not save that design")
		return null
	designs.append(design)
	design_index = designs.size() - 1
	state_changed.emit()
	notice.emit("Kept \"%s\" — %d web%s" % [design.display_name, design.piece_count(),
		"" if design.piece_count() == 1 else "s"])
	return design


func toggle_design_mode() -> void:
	if placing_design:
		placing_design = false
		state_changed.emit()
		notice.emit("Designs away")
		return
	if designs.is_empty():
		notice.emit("No saved designs yet — look at a web and press B to keep one")
		return
	stop()
	placing_design = true
	state_changed.emit()
	notice.emit(current_design().summary())


func cycle_design(step: int) -> void:
	if designs.size() <= 1:
		return
	design_index = wrapi(design_index + step, 0, designs.size())
	state_changed.emit()
	notice.emit(current_design().summary())


## Where the selected design would land right now: turned to face the way the
## player is looking, and pushed clear of the surface rather than half inside it.
func design_transform() -> Transform3D:
	var design := current_design()
	var frame := DesignLibrary.yaw_basis(_facing())
	if design == null:
		return Transform3D(frame, aim_point)
	var local_normal := frame.transposed() * aim_normal
	var origin := aim_point + aim_normal * design.extent_along(local_normal)
	return Transform3D(frame, origin)


## Spins a whole saved rig where the player is looking, wiring included.
## Nothing is charged, and nothing is placed, unless all of it can be built.
func place_design() -> bool:
	var design := current_design()
	if design == null:
		return false
	if not aim_valid:
		notice.emit("Nowhere to put that")
		return false

	var placement := design_transform()
	var quality := _quality()
	var spun: Array[WebStructure] = []
	var centres := PackedVector3Array()
	var total := 0.0

	for piece in design.piece_count():
		var pattern := _pattern_by_id(design.pattern_ids[piece])
		if pattern == null:
			return _abandon(spun, "That design uses silk you no longer have a recipe for")
		if not _is_unlocked(pattern):
			return _abandon(spun, "%s needs a bigger spider" % pattern.display_name)
		var points := PackedVector3Array()
		var centre := Vector3.ZERO
		for local in design.anchors_for(piece):
			var world: Vector3 = placement * local
			points.append(world)
			centre += world
		if points.size() < pattern.min_anchors:
			return _abandon(spun, "That design is missing anchors")
		centres.append(centre / float(points.size()))

		var dials := design.tuning_for(piece)
		var tuned := dials.apply_to(pattern)
		var web: WebStructure = null
		if tuned.shape == WebPattern.Shape.STRAND:
			web = WebStrand.spin(tuned, points[0], points[1], quality)
		else:
			web = WebNet.spin(tuned, points, quality, design.weave_for(piece))
		if web == null:
			return _abandon(spun, "That design won't hold together there")
		web.tuning = dials
		spun.append(web)
		total += web.silk_cost

	for i in design.link_count():
		var span: float = centres[design.link_from[i]].distance_to(centres[design.link_to[i]])
		total += link_base_cost + span * link_silk_per_metre * quality

	if not _silk.can_afford(total):
		return _abandon(spun, "Not enough silk for %s — %d needed"
			% [design.display_name, ceili(total)])

	_silk.spend(total)
	var container := _resolve_container()
	for web in spun:
		web.place_in(container)
	for i in design.link_count():
		spun[design.link_from[i]].link_to(spun[design.link_to[i]])

	notice.emit("%s spun (%d silk)" % [design.display_name, roundi(total)])
	web_built.emit(spun[0])
	return true


## Throws away a half-built rig without charging for it.
func _abandon(spun: Array[WebStructure], reason: String) -> bool:
	for web in spun:
		web.free()
	notice.emit(reason)
	return false


func _pattern_by_id(id: String) -> WebPattern:
	for pattern in patterns:
		if pattern.id == id:
			return pattern
	return null


func _unique_design_name(base: String) -> String:
	var taken := PackedStringArray()
	for design in designs:
		taken.append(design.display_name)
	if not taken.has(base):
		return base
	var suffix := 2
	while taken.has("%s %d" % [base, suffix]):
		suffix += 1
	return "%s %d" % [base, suffix]


## Direction the player is looking, flattened later into the design's forward.
func _facing() -> Vector3:
	return _view.aim_forward() if _view != null else Vector3.FORWARD


# --- rings of silk ------------------------------------------------------

## Every area the player's silk currently encloses, anywhere in the world.
## Lines count as joined where they cross as well as where they share an end,
## so three strands slung across a gap enclose the triangle in the middle.
func loops() -> Array:
	var strands: Array = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand != null and not strand.is_queued_for_deletion():
			strands.append(strand)
	if strands.size() != _loop_source:
		_loop_source = strands.size()
		_loops = WebGraph.find_loops(strands, _merge_radius())
	return _loops


## The ring under the crosshair, if there is one.
func aimed_loop():
	if _view == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var reach := _stage().anchor_range * 4.0
	var best = null
	var best_score := 1.0
	for loop in loops():
		var offset: Vector3 = loop.centre - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > reach:
			continue
		var miss := (offset - direction * along).length()
		var score: float = miss / maxf(loop.radius, 0.001)
		if score < best_score:
			best_score = score
			best = loop
	return best


## Weaves the ring under the crosshair. The silk around it is already up, so
## only the inside is spun and charged for.
func fill_aimed_loop() -> bool:
	var loop = aimed_loop()
	if loop == null:
		return false
	var pattern := current_pattern()
	if pattern == null or pattern.shape != WebPattern.Shape.NET:
		return false
	var dials := tuning_for(pattern)
	var web := WebNet.spin(dials.apply_to(pattern), loop.points, _quality(), weave, false)
	if web == null:
		notice.emit("Nothing to weave in there")
		return false
	if not _silk.can_afford(web.silk_cost):
		notice.emit("Not enough silk to weave it — %d needed" % ceili(web.silk_cost))
		web.free()
		return false
	web.tuning = dials.copy()
	_silk.spend(web.silk_cost)
	web.place_in(_resolve_container())
	_loop_source = -1
	state_changed.emit()
	web_built.emit(web)
	notice.emit("%s woven into the ring (%d silk)" % [pattern.display_name, roundi(web.silk_cost)])
	return true


## How close two bits of silk have to be to count as touching.
func _merge_radius() -> float:
	return maxf(_stage().body_height * 0.5, 0.05)


# --- trigger links ------------------------------------------------------

## Wires one web to another, a press at each end. A web that is wired up sets
## off whatever hangs off it — a tripline across a doorway springing a snare on
## the other side of the room — which is how a pile of webs becomes a machine.
func toggle_link() -> void:
	var node := aimed_node()

	if link_source == null:
		if node == null:
			notice.emit("Look at a web or a device to wire it up")
			return
		if not node.can_signal():
			notice.emit("A %s never has anything to report" % node.label())
			return
		link_source = node
		notice.emit("Wiring from the %s — now look at what it should set off"
			% node.label())
		state_changed.emit()
		return

	var source := link_source
	link_source = null
	state_changed.emit()

	if node == null or node == source:
		notice.emit("Wiring cancelled")
		return
	link_nodes(source, node)


## Runs a signal line between two specific things, skipping the aiming. Both
## ends are [SilkNode]s, so a web setting off a device and a device setting off
## a web cost and behave exactly the same. Returns false, and spends nothing,
## if the pair cannot be wired or cannot be paid for.
func link_nodes(source: SilkNode, target: SilkNode) -> bool:
	if source == null or not is_instance_valid(source):
		notice.emit("That end of the line is gone")
		return false
	if target == null or not is_instance_valid(target):
		notice.emit("Nothing there to set off")
		return false
	if not source.can_signal():
		notice.emit("A %s never has anything to report" % source.label())
		return false
	if not target.can_receive_signal():
		notice.emit("A %s can't do anything with a signal" % target.label())
		return false
	if not source.can_link_to(target):
		notice.emit("Those two are already wired together")
		return false

	var span := source.signal_point().distance_to(target.signal_point())
	var cost := link_base_cost + span * link_silk_per_metre * _quality()
	if not _silk.spend(cost):
		notice.emit("Not enough silk for the line — %d needed" % ceili(cost))
		return false

	source.link_to(target)
	notice.emit("%s now sets off the %s (%d silk)"
		% [source.label(), target.label(), roundi(cost)])
	return true


## Forgets a half-finished wiring job.
func cancel_link() -> void:
	if link_source == null:
		return
	link_source = null
	state_changed.emit()
	notice.emit("Wiring cancelled")


func is_linking() -> bool:
	return link_source != null and is_instance_valid(link_source)


# --- existing webs ------------------------------------------------------

## A line under the crosshair, close enough to grapple onto and ride. Silk is
## thin, so this is a proximity-to-the-ray pick like every other one.
func aimed_line() -> WebStrand:
	if _view == null or building:
		# A scripted anchor run is placing anchors, not looking for a lift.
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var reach: float = from.distance_to(aim_point) + _stage().body_height
	# Silk is a couple of centimetres across, so a fixed tolerance is either
	# impossible to aim at or steals every grapple. Scale it with distance
	# instead: a fixed slice of the screen, roughly a crosshair's width, which
	# is how wide the line actually looks when you are pointing at it.
	var span := from.distance_to(aim_point)
	var tolerance: float = maxf(_stage().body_height * 0.5, span * 0.055)

	var best: WebStrand = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand == null or not is_instance_valid(strand):
			continue
		var pair := Geometry3D.get_closest_points_between_segments(
			from, from + direction * reach, strand.point_a, strand.point_b)
		var along := (pair[0] - from).dot(direction)
		if along <= _stage().body_height or along > reach:
			continue
		var gap := pair[0].distance_to(pair[1])
		if gap > tolerance or gap >= best_score:
			continue
		best_score = gap
		best = strand
	return best


## The wireable thing under the crosshair — a device if one is right there,
## otherwise a web. Devices win ties on purpose: they are small and deliberately
## placed, so if one is under the crosshair you meant it, even sitting on a web.
func aimed_node() -> SilkNode:
	if _view == null:
		return null
	var device := SilkDevice.aimed_from(get_tree(), _view.aim_origin(),
		_view.aim_forward(), _stage().anchor_range,
		maxf(_stage().body_height * 0.8, 0.25))
	if device != null:
		return device
	return aimed_web()


## The web the player is looking at, if any. Tolerant, because silk is thin.
func aimed_web() -> WebStructure:
	if _view == null:
		return null
	var from := _view.aim_origin()
	var direction := _view.aim_forward()
	var reach := _stage().anchor_range

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * reach,
		GameLayers.WEB, _exclusions())
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var web := _web_from(hit.get("collider"))
		if web != null:
			return web

	# Fall back to the closest web near the line of sight.
	var best: WebStructure = null
	var best_score := INF
	var tolerance: float = maxf(0.35, _stage().body_height)
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web == null:
			continue
		var offset := web.global_position - from
		var along := offset.dot(direction)
		if along <= 0.0 or along > reach:
			continue
		var distance := (offset - direction * along).length()
		var span := tolerance
		var net := web as WebNet
		if net != null:
			span += net.radius
		if distance > span:
			continue
		if distance < best_score:
			best_score = distance
			best = web
	return best


## Pulls down the web under the crosshair. Returns the silk recovered.
func demolish_aimed() -> float:
	var web := aimed_web()
	if web == null:
		notice.emit("Nothing to pull down")
		return 0.0
	var label := web.pattern.display_name
	var refund := web.demolish()
	_silk.refill(refund)
	_loop_source = -1
	notice.emit("%s pulled down (+%d silk)" % [label, roundi(refund)])
	return refund


# --- aiming -------------------------------------------------------------

func _update_aim() -> void:
	var pattern := current_pattern()
	aim_valid = false
	problem = Problem.NO_SURFACE
	estimated_cost = 0.0
	if pattern == null:
		return
	if not _is_unlocked(pattern):
		problem = Problem.LOCKED
		return

	var stage := _stage()
	# A scripted run stays inside the tier's reach; free grappling does not,
	# which is the whole point of it.
	var reach := UNLIMITED_REACH
	if building:
		reach = stage.anchor_range
	elif grapple_reach > 0.0:
		reach = grapple_reach
	if not _cast_surface(reach):
		return
	problem = Problem.NONE

	if building and anchors.size() >= pattern.max_anchors:
		problem = Problem.FULL
		return
	# A scripted run measures from its last anchor and is held to the span
	# limit. Free grappling measures from the spider and is limited only by how
	# far it can see, which is what makes getting about feel quick.
	if building and anchors.is_empty():
		return

	var span := _line_start().distance_to(aim_point)
	if building and span > stage.max_strand_length:
		problem = Problem.TOO_FAR
		return
	if span < stage.body_height * 0.25:
		problem = Problem.TOO_CLOSE
		return

	var dragged := drag_pattern()
	if dragged != null:
		estimated_cost = dragged.cost_for(span, 0.0)
		if not _silk.can_afford(estimated_cost):
			problem = Problem.NO_SILK


## Design placement only needs somewhere solid to sit against, not the anchor
## rules that govern spinning a web by hand.
func _update_design_aim() -> void:
	aim_valid = false
	problem = Problem.NO_SURFACE
	estimated_cost = 0.0
	var design := current_design()
	if design == null:
		return
	if not _cast_surface(_stage().anchor_range):
		return
	problem = Problem.NONE
	estimated_cost = design.cost_at(_quality())
	if estimated_cost > _silk.current:
		problem = Problem.NO_SILK


## Raycast down the crosshair for a surface. Fills in the aim fields.
func _cast_surface(reach: float) -> bool:
	if _view == null:
		return false
	var from := _view.aim_origin()
	var to := from + _view.aim_forward() * reach
	var space := get_world_3d().direct_space_state
	# Silk is something to anchor to as well as something to stand on.
	var query := PhysicsRayQueryParameters3D.create(from, to,
		GameLayers.WORLD | GameLayers.WEB_WALK, _exclusions())
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	aim_point = hit["position"]
	aim_normal = hit.get("normal", Vector3.UP)
	# Lift off the surface a touch so silk doesn't z-fight the wall.
	aim_point += aim_normal * _stage().body_height * 0.08
	aim_valid = true
	return true


## Rough silk figure for the HUD. The real cost is measured off the finished
## layout when the web is actually spun.
func _estimate_cost(pattern: WebPattern, points: PackedVector3Array) -> float:
	if points.size() < 2:
		return pattern.silk_base_cost
	if pattern.shape == WebPattern.Shape.STRAND:
		var length := points[0].distance_to(points[1])
		if pattern.walkable:
			length *= 2.4
		return pattern.cost_for(length, 0.0)
	if points.size() < 3:
		var rim := 0.0
		for i in range(points.size() - 1):
			rim += points[i].distance_to(points[i + 1])
		return pattern.cost_for(rim, 0.0)

	var perimeter := 0.0
	for i in points.size():
		perimeter += points[i].distance_to(points[(i + 1) % points.size()])
	var area := _polygon_area(points)
	var mean_radius: float = sqrt(maxf(area, 0.0001) / PI)
	var spokes: float = float(pattern.radial_count) * mean_radius
	var spiral: float = float(pattern.ring_count) * TAU * mean_radius * 0.5
	return pattern.cost_for(perimeter + spokes + spiral, area)


func _polygon_area(points: PackedVector3Array) -> float:
	var normal := WebGeometry.plane_normal(points)
	var total := Vector3.ZERO
	for i in points.size():
		total += points[i].cross(points[(i + 1) % points.size()])
	return absf(total.dot(normal)) * 0.5


# --- text for the HUD ---------------------------------------------------

func problem_text() -> String:
	match problem:
		Problem.NO_SURFACE:
			return "No surface in reach"
		Problem.TOO_FAR:
			return "Too far to span — %.1fm limit" % _stage().max_strand_length
		Problem.TOO_CLOSE:
			return "Too close to the last anchor"
		Problem.FULL:
			return "Anchors full — press F to spin"
		Problem.NO_SILK:
			return "Not enough silk — %d needed" % ceili(estimated_cost)
		Problem.LOCKED:
			return "%s needs a bigger spider" % _pattern_name()
	return ""


func hint_text() -> String:
	if placing_design:
		return "Left mouse to spin it here, wheel to change design, right mouse to put it away"
	if not building:
		return ""
	var pattern := current_pattern()
	if pattern == null:
		return ""
	if pattern.shape == WebPattern.Shape.STRAND:
		return "Click to grapple across, dragging %s   ·   F to stop" % pattern.display_name
	if anchors.size() < 3:
		var ring = aimed_loop()
		if ring != null:
			return "F to weave this ring — %.2f m² enclosed" % ring.area
		return "Click to grapple — %d anchor%s of 3" % [anchors.size(),
			"" if anchors.size() == 1 else "s"]
	return "Encloses %.2f m² — F to weave, or grapple back to the first anchor" \
		% enclosed_area()


# --- internals ----------------------------------------------------------

func _pattern_name() -> String:
	var pattern := current_pattern()
	return pattern.display_name if pattern != null else "—"


func _stage() -> GrowthStage:
	if _growth == null:
		return GrowthStage.new()
	return _growth.current_stage()


func _quality() -> float:
	return _stage().silk_quality


func _is_unlocked(pattern: WebPattern) -> bool:
	if pattern == null:
		return false
	if _growth == null:
		return pattern.unlock_stage == 0
	return pattern.is_unlocked_at(_growth.stage_index)


## The wheel has to start on something Q can actually spin. It used to start
## on whatever sorted first — frame line, which is a strand — and entering
## build mode was what quietly fixed that. Taking build mode away left the
## wheel parked on a pattern the place key refuses, so holding Q did nothing
## whatsoever and said so in a toast that is easy to miss.
func _select_first_spinnable() -> void:
	for i in patterns.size():
		if patterns[i].shape == WebPattern.Shape.NET and _is_unlocked(patterns[i]):
			pattern_index = i
			return
	_select_first_unlocked()


func _select_first_unlocked() -> void:
	for i in patterns.size():
		if _is_unlocked(patterns[i]):
			pattern_index = i
			return


func _snap_radius() -> float:
	return maxf(_stage().body_height * 0.8, _stage().max_strand_length * 0.12)


func _exclusions() -> Array[RID]:
	var list: Array[RID] = []
	if _spider != null:
		list.append(_spider.get_rid())
	return list


func _web_from(collider: Variant) -> WebStructure:
	var node := collider as Node
	while node != null:
		var web := node as WebStructure
		if web != null:
			return web
		node = node.get_parent()
	return null


func _resolve_container() -> Node3D:
	var container := get_node_or_null(web_container_path) as Node3D
	if container != null:
		return container

	# Otherwise keep webs tidy under a "Webs" node in the level, making one if
	# the level hasn't got around to providing it.
	var host := get_tree().current_scene
	if host == null and _spider != null:
		host = _spider.get_parent()
	if host == null:
		host = get_parent()

	container = host.get_node_or_null("Webs") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "Webs"
		host.add_child(container)
	return container


func _build_preview_nodes() -> void:
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.vertex_color_use_as_albedo = true
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.no_depth_test = true
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_preview_mesh = ImmediateMesh.new()
	_preview = MeshInstance3D.new()
	_preview.name = "BuildPreview"
	_preview.mesh = _preview_mesh
	_preview.material_override = _preview_material
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.top_level = true
	add_child(_preview)
	_preview.transform = Transform3D.IDENTITY

	_cursor_material = StandardMaterial3D.new()
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cursor_material.no_depth_test = true
	_cursor_mesh = SphereMesh.new()
	_cursor_mesh.radial_segments = 8
	_cursor_mesh.rings = 4
	_cursor = MeshInstance3D.new()
	_cursor.name = "AnchorCursor"
	_cursor.mesh = _cursor_mesh
	_cursor.material_override = _cursor_material
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.top_level = true
	add_child(_cursor)
	_cursor.visible = false


func _draw_preview() -> void:
	_preview_mesh.clear_surfaces()
	if placing:
		_draw_place_ghost()
		return
	if placing_design:
		_draw_design_ghost()
		return
	var pattern := current_pattern()
	if pattern == null:
		return

	var good := pattern.color
	good.a = 1.0
	var bad := Color(1.0, 0.35, 0.3, 1.0)
	var line_color := good if problem == Problem.NONE else bad
	var tick: float = maxf(_stage().body_height * 0.35, 0.03)

	# Nothing being walked: show the ring under the crosshair instead.
	if anchors.is_empty() and pattern.shape == WebPattern.Shape.NET:
		var ring = aimed_loop()
		if ring != null:
			_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
			var ring_colour := Color(0.6, 1.0, 0.7, 1.0)
			for i in ring.points.size():
				_line(ring.points[i], ring.points[(i + 1) % ring.points.size()], ring_colour)
				_line(ring.centre, ring.points[i], Color(0.6, 1.0, 0.7, 0.3))
			_preview_mesh.surface_end()

	var points := anchors.duplicate()
	if points.is_empty() and not building and aim_valid:
		# Free grappling: the line you would leave runs from where you stand.
		points.append(_line_start())
	if aim_valid:
		points.append(aim_point)

	# One lone aim point draws no lines — only the cursor below — and opening an
	# empty surface is an error.
	if points.size() >= 2 or anchors.size() >= 1:
		_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
		for i in range(points.size() - 1):
			var colour := line_color if i == points.size() - 2 else good
			_line(points[i], points[i + 1], colour)
		if pattern.shape == WebPattern.Shape.NET and points.size() >= 3:
			var closing := good
			closing.a = 0.4
			_line(points[points.size() - 1], points[0], closing)
		for anchor in anchors:
			_cross(anchor, tick, good)
		_preview_mesh.surface_end()

	_cursor.visible = aim_valid
	if aim_valid:
		_cursor_mesh.radius = tick * 0.5
		_cursor_mesh.height = tick
		_cursor_material.albedo_color = Color(line_color.r, line_color.g, line_color.b, 0.7)
		_cursor.global_position = aim_point


## The web about to be spun, growing while the key is held.
func _draw_place_ghost() -> void:
	_cursor.visible = false
	if not place_valid and not throwing:
		return
	var rim := place_charge_ring() if throwing else place_rim()
	if rim.size() < 3:
		return
	var pattern := current_pattern()
	var tint: Color = pattern.color if pattern != null else Color(1, 1, 1, 1)
	tint.a = 1.0
	if not _silk.can_afford(estimated_cost):
		tint = Color(1.0, 0.4, 0.35, 1.0)
	var spoke := Color(tint.r, tint.g, tint.b, 0.35)
	var hub := place_charge_centre() if throwing else place_centre
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
	for i in rim.size():
		_line(rim[i], rim[(i + 1) % rim.size()], tint)
		_line(hub, rim[i], spoke)
	_preview_mesh.surface_end()


## Ghost of a saved rig where it would land, so the player can line it up
## before spending anything.
func _draw_design_ghost() -> void:
	var design := current_design()
	_cursor.visible = aim_valid and design != null
	if design == null or not aim_valid:
		return

	var placement := design_transform()
	var color := Color(0.85, 0.95, 1.0, 1.0)
	if problem != Problem.NONE:
		color = Color(1.0, 0.35, 0.3, 1.0)
	var faint := Color(color.r, color.g, color.b, 0.3)

	var centres := PackedVector3Array()
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material)
	for piece in design.piece_count():
		var world := PackedVector3Array()
		var centre := Vector3.ZERO
		for local in design.anchors_for(piece):
			var point: Vector3 = placement * local
			world.append(point)
			centre += point
		if world.is_empty():
			centres.append(placement.origin)
			continue
		centre /= float(world.size())
		centres.append(centre)
		if world.size() == 2:
			_line(world[0], world[1], color)
			continue
		for i in world.size():
			_line(world[i], world[(i + 1) % world.size()], color)
			_line(centre, world[i], faint)
	for i in design.link_count():
		_line(centres[design.link_from[i]], centres[design.link_to[i]],
			Color(0.5, 0.8, 1.0, 0.7))
	_preview_mesh.surface_end()

	var tick: float = maxf(_stage().body_height * 0.35, 0.03)
	_cursor_mesh.radius = tick * 0.5
	_cursor_mesh.height = tick
	_cursor_material.albedo_color = Color(color.r, color.g, color.b, 0.7)
	_cursor.global_position = aim_point


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_preview_mesh.surface_set_color(color)
	_preview_mesh.surface_add_vertex(a)
	_preview_mesh.surface_set_color(color)
	_preview_mesh.surface_add_vertex(b)


func _cross(point: Vector3, size: float, color: Color) -> void:
	_line(point - Vector3.RIGHT * size, point + Vector3.RIGHT * size, color)
	_line(point - Vector3.UP * size, point + Vector3.UP * size, color)
	_line(point - Vector3.BACK * size, point + Vector3.BACK * size, color)
