class_name WebStructure
extends Node3D

## A piece of silk that has been spun into the world.
##
## Subclassed by [WebNet] (closed webs that catch things) and [WebStrand]
## (two-point lines: triplines and bridges). Everything a web owns — its mesh,
## its catch volume, its durability — is built in code from a [WebPattern], so
## new kinds of web are data, not scenes.

## The web has been destroyed, by struggling prey or by the player.
signal torn(web: WebStructure)

## Something has become stuck in this web.
signal prey_caught(web: WebStructure, prey: Node3D)

## Something has pulled itself free.
signal prey_lost(web: WebStructure, prey: Node3D)

## Something crossed an alert web (tripline).
signal tripped(web: WebStructure, intruder: Node3D)

## This web went off: something was caught, crossed it or sprang it. Anything
## wired to it hears about this.
signal fired(web: WebStructure)

## A web wired to this one went off.
signal signalled(web: WebStructure, source: WebStructure)

## Durability, armed state or similar changed — the HUD should re-read us.
signal state_changed(web: WebStructure)

## How far a signal may travel down a chain of webs before it gives up, so a
## pair of webs wired into a loop cannot ring forever.
const MAX_SIGNAL_DEPTH := 6

## Signal lines are drawn cold and dashed so they read as wiring rather than
## as silk that holds something up.
const LINK_COLOR := Color(0.5, 0.8, 1.0, 0.65)


## The pattern this web was spun from.
var pattern: WebPattern

## Silk that went into it, used to work out the demolition refund.
var silk_cost := 0.0

## The builder's silk quality at the time of spinning. Bigger spider, better web.
var quality := 1.0

var durability := 1.0
var max_durability := 1.0

## Snares are spun under tension and spend it on the first thing they catch.
var armed := true

## Total metres of silk in the web, for the HUD and for repair costs.
var strand_length := 0.0

## Enclosed area in square metres. Zero for strands.
var area := 0.0

var mesh_instance: MeshInstance3D
var catch_area: Area3D
var material: StandardMaterial3D

## The anchor points this web was spun across, in world space. Kept so a web
## can be captured into a reusable design.
var anchors := PackedVector3Array()

## Webs this one sets off when it fires.
var links: Array[WebStructure] = []

var link_mesh: MeshInstance3D

var _linked_by: Array[WebStructure] = []
var _link_material: StandardMaterial3D
var _tense_timer := 0.0
var _flash := 0.0
var _snared: Array[Node3D] = []
var _trip_cooldown := 0.0

## World position the web was spun around; applied when it is placed.
var _origin := Vector3.ZERO


func _ready() -> void:
	add_to_group("silk_webs")
	if pattern != null and pattern.trigger == WebPattern.Trigger.LURE:
		add_to_group("silk_lures")
	if catch_area != null:
		catch_area.body_entered.connect(_on_body_entered)
		catch_area.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _trip_cooldown > 0.0:
		_trip_cooldown -= delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_refresh_tint()
	if _tense_timer > 0.0:
		_tense_timer -= delta
		if _tense_timer <= 0.0:
			_refresh_tint()
			state_changed.emit(self)


## Adds the finished web to the world at the spot it was spun.
func place_in(container: Node3D) -> void:
	container.add_child(self)
	# Silk lines were laid out in world space around _origin, so the web itself
	# must sit unrotated at that point whatever the container is doing.
	global_transform = Transform3D(Basis.IDENTITY, _origin)


## How hard this web holds on to prey. A web that has just been signalled is
## drawn tight and holds better for a few seconds.
func hold_strength() -> float:
	if pattern == null:
		return 0.0
	var hold := pattern.hold_strength * quality
	if _tense_timer > 0.0:
		hold *= pattern.tense_multiplier
	return hold


## True while this web is pulled taut by a signal from another one.
func is_tensed() -> bool:
	return _tense_timer > 0.0


## How far prey is pulled from this lure, if it is one.
func lure_radius() -> float:
	if pattern == null:
		return 0.0
	return pattern.lure_radius


## Can this web be the source of a signal — does anything ever happen to it?
## Webs that set this one off.
func linked_sources() -> Array[WebStructure]:
	return _linked_by.duplicate()


func can_signal() -> bool:
	return pattern != null and pattern.can_signal


## Can this web do anything useful with a signal? Snares spring; anything that
## catches prey tenses up. Wiring a bridge to a tripline would just be string.
func can_receive_signal() -> bool:
	if pattern == null:
		return false
	return pattern.trigger == WebPattern.Trigger.SNARE or pattern.catches_prey


func can_link_to(target: WebStructure) -> bool:
	if target == null or target == self or not is_instance_valid(target):
		return false
	if links.has(target):
		return false
	return can_signal() and target.can_receive_signal()


## Runs a signal line from this web to another. The two are now one machine.
func link_to(target: WebStructure) -> bool:
	if not can_link_to(target):
		return false
	links.append(target)
	target._linked_by.append(self)
	_rebuild_link_visual()
	state_changed.emit(self)
	return true


## Drops every signal line into or out of this web.
func unlink_all() -> void:
	for target in links.duplicate():
		if is_instance_valid(target):
			target._linked_by.erase(self)
	links.clear()
	for source in _linked_by.duplicate():
		if is_instance_valid(source):
			source.links.erase(self)
			source._rebuild_link_visual()
			source.state_changed.emit(source)
	_linked_by.clear()
	_rebuild_link_visual()


## Something set this web off. Everything wired downstream of it hears.
func fire(depth := 0) -> void:
	_flash = 0.5
	_refresh_tint()
	fired.emit(self)
	if depth >= MAX_SIGNAL_DEPTH:
		return
	for target in links.duplicate():
		if is_instance_valid(target):
			target.receive_signal(self, depth + 1)


## A web wired to this one went off.
func receive_signal(source: WebStructure, depth: int) -> void:
	signalled.emit(self, source)
	if not _react_to_signal(source):
		_tense_timer = pattern.tense_duration
	_refresh_tint()
	state_changed.emit(self)
	fire(depth)


## Where a signal line attaches. Nets use their middle rather than their origin.
func signal_point() -> Vector3:
	return global_position


## What this web does about a signal. Returning false means "just tense up".
func _react_to_signal(_source: WebStructure) -> bool:
	return false


## Struggling prey and passing brooms wear the web down.
func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	durability = maxf(0.0, durability - amount)
	_refresh_tint()
	state_changed.emit(self)
	if durability <= 0.0:
		tear()


## Destroy the web, freeing anything caught in it.
func tear() -> void:
	unlink_all()
	for prey in _snared.duplicate():
		_release(prey, true)
	torn.emit(self)
	queue_free()


## Take the web down on purpose. Returns the silk refunded.
func demolish(refund_fraction := 0.5) -> float:
	var refund := silk_cost * refund_fraction * (durability / maxf(max_durability, 0.001))
	unlink_all()
	for prey in _snared.duplicate():
		_release(prey, true)
	torn.emit(self)
	queue_free()
	return maxf(refund, 0.0)


## Called by prey that has torn itself loose under its own steam.
func on_prey_escaped(prey: Node3D) -> void:
	if _snared.has(prey):
		_release(prey, false)


## Re-arm a sprung snare. Returns false if it did not need it.
func rearm() -> bool:
	if pattern == null or pattern.trigger != WebPattern.Trigger.SNARE or armed:
		return false
	armed = true
	_refresh_tint()
	state_changed.emit(self)
	return true


## True when the player can usefully spend silk on this web.
func needs_rearm() -> bool:
	return pattern != null and pattern.trigger == WebPattern.Trigger.SNARE and not armed


func snared_count() -> int:
	return _snared.size()


func snared_prey() -> Array[Node3D]:
	return _snared.duplicate()


## Short line for the HUD when the player looks at this web.
func status_line() -> String:
	var text := "%s  %d%%" % [pattern.display_name, roundi(durability / maxf(max_durability, 0.001) * 100.0)]
	if needs_rearm():
		text += "  (sprung)"
	elif _snared.size() > 0:
		text += "  (%d caught)" % _snared.size()
	if links.size() > 0:
		text += "  → sets off %d" % links.size()
	if _linked_by.size() > 0:
		text += "  (wired)"
	return text


## Builds the mesh child from a set of silk lines. Called by subclasses.
func _build_visual(strands: WebGeometry.StrandSet) -> void:
	strand_length = strands.length
	var mesh := WebGeometry.build_mesh(strands, pattern.color)
	if mesh == null:
		return
	material = WebGeometry.silk_material()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Silk"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	_refresh_tint()


func _make_catch_area(shape: Shape3D, collider_transform := Transform3D.IDENTITY) -> void:
	catch_area = Area3D.new()
	catch_area.name = "Catch"
	catch_area.collision_layer = GameLayers.WEB
	catch_area.collision_mask = GameLayers.PREY
	catch_area.monitorable = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = collider_transform
	catch_area.add_child(collider)
	add_child(catch_area)


## Solid surface for webs you can walk on, e.g. a silk bridge.
func _make_walk_surface(shape: Shape3D, collider_transform := Transform3D.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.name = "Walkway"
	body.collision_layer = GameLayers.WORLD | GameLayers.WEB
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = collider_transform
	body.add_child(collider)
	add_child(body)


func _on_body_entered(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if pattern.trigger == WebPattern.Trigger.ALERT:
		_trip(body)
		return
	if not pattern.catches_prey:
		return
	var snap_time := 0.0
	if pattern.trigger == WebPattern.Trigger.SNARE and armed:
		armed = false
		snap_time = pattern.snap_hold_time
	if _capture(body, snap_time, _catch_point(body)):
		fire()


func _on_body_exited(body: Node3D) -> void:
	if _snared.has(body):
		_release(body, false)


func _trip(body: Node3D) -> void:
	if _trip_cooldown > 0.0:
		return
	if not body.has_method("on_tripped"):
		return
	_trip_cooldown = 1.0
	body.on_tripped(self, pattern.mark_time)
	tripped.emit(self, body)
	fire()


## Sticks one thing into this web. Shared by walking into it and by a snare
## whipping out to grab something that never touched it.
func _capture(body: Node3D, snap_time: float, point: Vector3) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if not body.has_method("on_snared") or _snared.has(body):
		return false
	if body.has_method("can_be_snared") and not body.can_be_snared():
		return false
	_snared.append(body)
	body.on_snared(self, point, snap_time)
	prey_caught.emit(self, body)
	_refresh_tint()
	state_changed.emit(self)
	return true


func _release(prey: Node3D, notify_prey: bool) -> void:
	_snared.erase(prey)
	if notify_prey and is_instance_valid(prey) and prey.has_method("on_freed"):
		prey.on_freed(self)
	prey_lost.emit(self, prey)
	state_changed.emit(self)


## Where in the web something that just hit it should stick. Overridden by nets.
func _catch_point(body: Node3D) -> Vector3:
	return body.global_position


func _refresh_tint() -> void:
	if material == null:
		return
	var wear := clampf(durability / maxf(max_durability, 0.001), 0.0, 1.0)
	var tint := Color(1, 1, 1, 1).lerp(Color(0.55, 0.5, 0.45, 0.8), 1.0 - wear)
	if needs_rearm():
		tint *= Color(0.65, 0.65, 0.7, 1.0)
	if _tense_timer > 0.0:
		tint = tint.lerp(Color(1.4, 1.3, 0.9, 1.0), 0.5)
	if _flash > 0.0:
		tint = tint.lerp(Color(2.0, 1.8, 1.2, 1.0), clampf(_flash * 2.0, 0.0, 1.0))
	material.albedo_color = tint
	if _link_material != null:
		var wire := LINK_COLOR
		if _flash > 0.0:
			wire = wire.lerp(Color(2.0, 1.9, 1.3, 1.0), clampf(_flash * 2.0, 0.0, 1.0))
		_link_material.albedo_color = wire


## Draws the signal lines out of this web, so the player can read their own
## machine at a glance.
func _rebuild_link_visual() -> void:
	if link_mesh == null:
		_link_material = WebGeometry.silk_material()
		link_mesh = MeshInstance3D.new()
		link_mesh.name = "SignalLines"
		link_mesh.material_override = _link_material
		link_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		link_mesh.top_level = true
		add_child(link_mesh)
		link_mesh.transform = Transform3D.IDENTITY
	var strands := WebGeometry.StrandSet.new()
	var width: float = maxf(0.004 * quality, 0.002)
	for target in links:
		if is_instance_valid(target):
			_dashed_line(strands, signal_point(), target.signal_point(), width)
	link_mesh.mesh = WebGeometry.build_mesh(strands, LINK_COLOR)


## Signal lines are drawn dashed so they never read as structural silk — a
## thing that carries a message, not a thing that holds weight.
func _dashed_line(strands: WebGeometry.StrandSet, from: Vector3, to: Vector3,
		width: float) -> void:
	var span := from.distance_to(to)
	if span < 0.01:
		return
	var dashes: int = clampi(roundi(span / maxf(span * 0.05, 0.08)), 2, 60)
	var duty := 0.55
	for i in dashes:
		var start := float(i) / float(dashes)
		var end := minf(start + duty / float(dashes), 1.0)
		strands.add(from.lerp(to, start), from.lerp(to, end), width)
