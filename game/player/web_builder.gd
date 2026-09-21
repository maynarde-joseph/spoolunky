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

## Pattern dragged between anchors when the chosen one is a net.
const FRAME_PATTERN := "frame_line"

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
var link_source: WebStructure = null

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


func _process(_delta: float) -> void:
	if placing_design:
		_update_design_aim()
	elif building:
		_update_aim()
	_draw_preview()


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


## Drops an anchor at the aim point, or closes the web if the player clicked
## back on the first anchor.
func place() -> void:
	if placing_design:
		place_design()
		return
	if not building or _awaiting_grapple:
		return
	var pattern := current_pattern()
	if pattern == null:
		return
	_update_aim()

	if problem != Problem.NONE:
		notice.emit(problem_text())
		return

	# Going there is the point: an anchor is somewhere the spider has been, and
	# the line behind it is silk it dragged on the way.
	if _climb != null and _climb.grapple_to(aim_point, aim_normal):
		_pending_anchor = aim_point
		_awaiting_grapple = true
		return
	add_anchor(aim_point)


func _on_grappled(_point: Vector3, _normal: Vector3) -> void:
	if not _awaiting_grapple:
		return
	_awaiting_grapple = false
	add_anchor(_pending_anchor)


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
	var web := aimed_web()

	if link_source == null:
		if web == null:
			notice.emit("Look at a web to wire it up")
			return
		if not web.can_signal():
			notice.emit("A %s never has anything to report" % web.pattern.display_name)
			return
		link_source = web
		notice.emit("Wiring from the %s — now look at what it should set off"
			% web.pattern.display_name)
		state_changed.emit()
		return

	var source := link_source
	link_source = null
	state_changed.emit()

	if web == null or web == source:
		notice.emit("Wiring cancelled")
		return
	link_webs(source, web)


## Runs a signal line between two specific webs, skipping the aiming. Returns
## false, and spends nothing, if the pair cannot be wired or cannot be paid for.
func link_webs(source: WebStructure, target: WebStructure) -> bool:
	if source == null or not is_instance_valid(source):
		notice.emit("That web is gone")
		return false
	if target == null or not is_instance_valid(target):
		notice.emit("Nothing there to set off")
		return false
	if not source.can_signal():
		notice.emit("A %s never has anything to report" % source.pattern.display_name)
		return false
	if not target.can_receive_signal():
		notice.emit("A %s can't do anything with a signal" % target.pattern.display_name)
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
		% [source.pattern.display_name, target.pattern.display_name, roundi(cost)])
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
	if not _cast_surface(stage.anchor_range):
		return
	problem = Problem.NONE

	if anchors.size() >= pattern.max_anchors:
		problem = Problem.FULL
		return

	if anchors.size() > 0:
		var last := anchors[anchors.size() - 1]
		var span := last.distance_to(aim_point)
		if span > stage.max_strand_length:
			problem = Problem.TOO_FAR
			return
		if span < stage.body_height * 0.25:
			problem = Problem.TOO_CLOSE
			return

	if anchors.size() > 0:
		var dragged := drag_pattern()
		if dragged != null:
			estimated_cost = dragged.cost_for(
				anchors[anchors.size() - 1].distance_to(aim_point), 0.0)
			if estimated_cost > _silk.current:
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
	if placing_design:
		_draw_design_ghost()
		return
	if not building:
		_cursor.visible = false
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
