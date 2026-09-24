class_name WebStructure
extends SilkNode

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

## The last catch was taken out by the spider, so the web is coming down.
signal emptied(web: WebStructure)

## Something has pulled itself free.
signal prey_lost(web: WebStructure, prey: Node3D)

## Something crossed an alert web (tripline).
signal tripped(web: WebStructure, intruder: Node3D)

## Durability, armed state or similar changed — the HUD should re-read us.
signal state_changed(web: WebStructure)


## The pattern this web was spun from.
var pattern: WebPattern

## Silk that went into it, used to work out the demolition refund.

## The builder's silk quality at the time of spinning. Bigger spider, better web.
var quality := 1.0

## Dial settings this web was spun with, kept so it can be saved into a design.
var tuning: WebTuning = null

## How the inside of this web was woven.
var weave: WebGeometry.Weave = WebGeometry.Weave.STRETCHED

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
var catch_shape: CollisionShape3D

## What this web took the moment it went up, and how much of that it wrapped
## outright. Read straight after placing, for the notice.
var caught_on_arrival := 0
var bundled_on_arrival := 0
var material: StandardMaterial3D

## The anchor points this web was spun across, in world space. Kept so a web
## can be captured into a reusable design.
var anchors := PackedVector3Array()

var _tense_timer := 0.0
var _snared: Array[Node3D] = []
var _trip_cooldown := 0.0

## World position the web was spun around; applied when it is placed.
var _origin := Vector3.ZERO


func _ready() -> void:
	super()
	add_to_group("silk_webs")
	if pattern != null and pattern.trigger == WebPattern.Trigger.LURE:
		add_to_group("silk_lures")
	if catch_area != null:
		catch_area.body_entered.connect(_on_body_entered)
		catch_area.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	_tick_signal(delta)
	_prune_snared()
	if _trip_cooldown > 0.0:
		_trip_cooldown -= delta
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
	catch_what_is_already_here()


## Snaps the silk in tight and lets it spring out to full size.
##
## Purely how it looks. The web is its real size from the instant it exists,
## catch volume and all — a thrown bolt that only became dangerous once an
## animation finished would be a different thing from the web it is meant to
## be, and it is the same web either way.
func play_arrival(duration: float) -> void:
	if mesh_instance == null or duration <= 0.0 or not is_inside_tree():
		return
	mesh_instance.scale = Vector3.ONE * 0.12
	var tween := create_tween()
	tween.tween_property(mesh_instance, "scale", Vector3.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Anything standing in this web the moment it goes up is caught by it.
##
## An Area3D only ever reports arrivals, so without this, spinning a web over
## something already there would quietly miss — and spinning a web over
## something is one of the two things webs are for. A shape query rather than
## overlapping bodies, because overlaps are not known until physics has run a
## frame and a web should catch the instant it exists.
func catch_what_is_already_here() -> int:
	if catch_area == null or catch_shape == null or catch_shape.shape == null:
		return 0
	if pattern == null or not pattern.catches_prey:
		return 0
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = catch_shape.shape
	params.transform = catch_shape.global_transform
	params.collision_mask = GameLayers.PREY
	params.collide_with_areas = false
	var space := get_world_3d().direct_space_state
	var caught := 0
	bundled_on_arrival = 0
	for hit in space.intersect_shape(params, maxi(capacity(), 1)):
		var body := hit.get("collider") as Node3D
		if body == null or not is_instance_valid(body):
			continue
		if body.has_method("can_be_snared") and not body.can_be_snared():
			continue
		if "size_class" in body and body.size_class < pattern.min_catch_size:
			continue
		# Silk thrown over something it can hold takes it outright: wrapped
		# where it stood, and the bundle drops. Anything the silk is not up to
		# is caught the ordinary way and has to be fought for.
		if _takes_cleanly(body) and body.bundle():
			caught += 1
			bundled_on_arrival += 1
			prey_caught.emit(self, body)
			continue
		if _capture(body, 0.0, _catch_point(body)):
			caught += 1
	caught_on_arrival = caught
	if caught > 0:
		fire()
	return caught


## Whether this web can take something outright rather than hold it while it
## fights. Same number that decides whether a catch stays put at all, so a
## sheet web thrown at a wasp is no better than a sheet web left for one.
func _takes_cleanly(body: Node3D) -> bool:
	if not body.has_method("bundle") or not body.has_method("total_thrash"):
		return false
	return body.total_thrash() <= hold_strength() * Prey.ESCAPE_MARGIN


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


## A web reports if anything ever happens to it.
func can_signal() -> bool:
	return pattern != null and pattern.can_signal


## Snares spring; anything that catches prey tenses up. Wiring a bridge to a
## tripline would just be string.
func can_receive_signal() -> bool:
	if pattern == null:
		return false
	return pattern.trigger == WebPattern.Trigger.SNARE or pattern.catches_prey


## A wired web that is not a snare pulls itself taut for a few seconds.
func _react_to_signal(source: SilkNode) -> void:
	if not _spring_to_signal(source):
		_tense_timer = pattern.tense_duration
	_refresh_tint()
	state_changed.emit(self)


## Snares override this to whip out and grab something.
func _spring_to_signal(_source: SilkNode) -> bool:
	return false


func _on_links_changed() -> void:
	state_changed.emit(self)


func _link_width() -> float:
	return maxf(0.004 * quality, 0.002)


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


## Take the web down on purpose.
func demolish() -> void:
	unlink_all()
	for prey in _snared.duplicate():
		_release(prey, true)
	torn.emit(self)
	queue_free()


## Called by prey that has torn itself loose under its own steam. The web
## survives this: something getting away is the web losing, and taking the web
## away as well would be losing twice for one mistake.
func on_prey_escaped(prey: Node3D) -> void:
	if _snared.has(prey):
		_release(prey, false)


## Called when the spider takes a catch out — drained it, or wrapped it up and
## carried it off. Emptying a web by hand is what ends it.
##
## A web is a larder while it has something in it, and nothing once it does
## not: you leave it to fill, you come back and clear it out, and clearing it
## out costs you the web. That is the price of a catch, and it is a better one
## than a silk bill because it is paid at the moment you are being rewarded
## rather than at the moment you are trying something.
func on_prey_taken(prey: Node3D) -> void:
	var was_holding := _snared.has(prey)
	if was_holding:
		_release(prey, false)
	if was_holding and _snared.is_empty():
		emptied.emit(self)
		tear()


## Re-arm a sprung snare. Returns false if it did not need it.
func rearm() -> bool:
	if pattern == null or pattern.trigger != WebPattern.Trigger.SNARE or armed:
		return false
	armed = true
	_refresh_tint()
	state_changed.emit(self)
	return true


## True when the web has fired and is waiting to be set again.
func needs_rearm() -> bool:
	return pattern != null and pattern.trigger == WebPattern.Trigger.SNARE and not armed


func snared_count() -> int:
	return _snared.size()


func snared_prey() -> Array[Node3D]:
	return _snared.duplicate()


## Drops anything that stopped existing without telling us. Cheap, and it
## matters now that being full stops a web catching: one dead reference would
## otherwise retire the web permanently.
func _prune_snared() -> void:
	var live: Array[Node3D] = []
	for prey in _snared:
		if is_instance_valid(prey) and not prey.is_queued_for_deletion():
			live.append(prey)
	if live.size() == _snared.size():
		return
	_snared = live
	state_changed.emit(self)


## How many things this holds at once.
func capacity() -> int:
	return pattern.capacity if pattern != null else 0


## A full web stops catching. That is the whole reason to own a second site
## rather than keep spinning this one bigger.
func is_full() -> bool:
	return _snared.size() >= capacity()


## Catches that are not going anywhere — the part of a web that is a larder
## rather than a fight in progress.
func secured_count() -> int:
	var total := 0
	for prey in _snared:
		if is_instance_valid(prey) and prey.has_method("is_secured") and prey.is_secured():
			total += 1
	return total


func label() -> String:
	return pattern.display_name if pattern != null else name


## Short line for the HUD when the player looks at this web.
func status_line() -> String:
	var text := "%s  %d%%" % [label(), roundi(durability / maxf(max_durability, 0.001) * 100.0)]
	if needs_rearm():
		text += "  (sprung)"
	elif _snared.size() > 0:
		var held := secured_count()
		text += "  (%d/%d caught" % [_snared.size(), capacity()]
		if held < _snared.size():
			text += ", %d still fighting" % (_snared.size() - held)
		text += ")"
		if is_full():
			text += "  FULL"
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
	catch_shape = CollisionShape3D.new()
	catch_shape.shape = shape
	catch_shape.transform = collider_transform
	catch_area.add_child(catch_shape)
	add_child(catch_area)


## Solid surface for silk you can walk on. It sits on its own layer so that
## making a web stand up to a spider's feet does not also make it bounce prey
## off instead of catching it.
func _make_walk_surface(shape: Shape3D, collider_transform := Transform3D.IDENTITY) -> void:
	var body := StaticBody3D.new()
	body.name = "Walkway"
	body.collision_layer = GameLayers.WEB_WALK | GameLayers.WEB
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
	# An open mesh lets the small stuff walk straight through.
	if "size_class" in body and body.size_class < pattern.min_catch_size:
		return false
	if is_full():
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
	_refresh_link_tint()
