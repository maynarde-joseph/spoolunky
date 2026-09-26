class_name WebSuite
extends TestSuite

## The sandbox the web checks run in, and the one thing they were missing: a way
## back to a known state.
##
## The suite used to thread one spider and one level through three dozen checks
## in a fixed order, and the state went with them. Webs piled up — fifty-odd by
## the end — so a fly spawned next to the spider landed in one and was stuck
## rather than loose. The spider ate its way up the ladder, so a check written
## against a spiderling ran against a Huntsman and passed for the wrong reason;
## one of them passed while asserting nothing at all. A check that fed the spider
## to make its own premise true left it fed for the fourteen after it. Traits
## were bought last, deliberately, because buying one is permanent. Six of the
## seven CI rounds the feeding work cost were this, not the game.
##
## So: [method reset] puts the arena back, and a check that needs more than a
## bare spiderling in an empty room asks for it out loud. The fields below are
## named as the parameters they replace, so a check reads the same as it did —
## it just no longer has to be handed its own world.

const LEVEL_PATH := "res://addons/character-controller/example/main/level.tscn"

## Somewhere flat and open, away from the level's furniture.
const HOME := Vector3(12, 0.5, 0)

var level: Node
var spider: SpiderPlayer
var builder: WebBuilder
var webs: Node3D
var traits: SpiderTraits
var placer: DevicePlacer

## What the builder looked like before any check touched it, captured once so the
## reset can put it back without this file holding a list of defaults that drifts
## away from the builder's own.
var _builder_was := {}

## Which way the camera was facing the world when the level was opened. Checks
## toggle it and some of them only put it back on the happy path.
var _was_third_person := false


## Opens the sandbox and finds everything in it. Returns whether it worked, so a
## suite can stop rather than fail three dozen checks against a null.
func open_sandbox() -> bool:
	level = await open(LEVEL_PATH)
	if level == null:
		return false

	spider = root.get_tree().get_first_node_in_group("spider") as SpiderPlayer
	if not check(spider != null, "spider is in the level"):
		return false

	webs = level.get_node("Webs") as Node3D
	builder = spider.web_builder
	traits = spider.traits
	placer = spider.device_placer
	builder.notice.connect(note)
	placer.notice.connect(note)

	for field in _BUILDER_STATE:
		_builder_was[field] = builder.get(field)
	_was_third_person = spider.view.third_person

	# Headless has no mouse to capture, so without this the spider ignores every
	# key. It used to be set by whichever check happened to run first, which meant
	# every other check was getting its input for free from that one.
	spider.require_captured_mouse = false

	spider.global_position = HOME
	await physics_frame
	return true


## Builder state a check is allowed to set and the reset has to put back. The shot
## cooldown is the one that bit: two checks zero it so they can fire twice in a
## row, and every check after them then saw a game with no cooldown at all — four
## of them were asserting that a wait exists against a builder that had none.
const _BUILDER_STATE := [
	"pattern_index", "weave", "design_index", "placing_design", "shot_cooldown",
]


# --- back to a known state ----------------------------------------------

## Everything a check is entitled to assume: a bare spiderling, standing at
## [constant HOME] in an empty room, holding nothing and being held by nothing.
##
## Called between sections rather than inside them, so a section is still free to
## grow the spider or leave webs standing while it makes its point.
func reset() -> void:
	release_all()
	drop_everything()
	rewind_builder()
	rewind_view()
	clear_webs()
	clear_prey()
	clear_props()
	rewind_growth()
	place(HOME)
	await physics_frame
	await physics_frame


## Puts the camera back the way the level had it. Which way it faces changes where
## a shot leaves from and where the crosshair lands, so a check that toggles it and
## returns early leaves the next one aiming from somewhere else.
func rewind_view() -> void:
	if spider == null:
		return
	if spider.view.third_person != _was_third_person:
		spider.view.toggle_mode()
	spider.view.aim_blend = 0.0
	spider.view.update(spider.stage().body_height)


## Puts the builder back as the level built it: nothing half-built, nothing in
## flight, the wheel on its first pattern and the cooldown as the game sets it.
func rewind_builder() -> void:
	if builder == null:
		return
	if builder.placing:
		builder.cancel_place()
	if builder.building:
		builder.stop()
	builder.cancel_shot()
	builder.cancel_link()
	builder.charge = 0.0
	# Ready to fire, which is what a check that is not about the cooldown wants.
	builder._cooling = 0.0
	for field in _builder_was:
		builder.set(field, _builder_was[field])
	builder.designs.clear()


## Takes the shot wait out of the way, for a check that fires several times over
## and is not about the wait itself.
##
## Worth asking for out loud: two checks used to set this and leave it set, so
## every check after them ran against a game with no cooldown — including four
## that were asserting a cooldown exists. [method reset] puts it back, so this
## reaches no further than the section that asks.
func ignore_shot_cooldown() -> void:
	builder.shot_cooldown = 0.0
	builder._cooling = 0.0


## Lets go of a meal and of anything on the line. Both outlive the check that
## started them: a spider still drinking carries on draining into the next one.
func drop_everything() -> void:
	if spider == null:
		return
	if spider.feeding != null:
		spider._end_feed()
	if spider.tether != null and spider.tether.cargo != null:
		spider.tether.cut()
	spider.climb.release()


## Back to a spiderling with an empty larder and no traits bought.
##
## Growth goes through the game's own path rather than being poked: apply_initial
## re-emits the stage change, which is what resizes the body and the collider.
## Setting stage_index alone leaves a Huntsman-shaped spiderling.
func rewind_growth() -> void:
	if spider == null:
		return
	spider.growth.biomass = 0.0
	spider.growth.apply_initial()
	spider.health = spider.max_stamina()
	spider._mending = 0.0
	if traits != null:
		traits.owned.clear()
		traits.larder.clear()
		traits.changed.emit()


## Feeds the spider up the ladder until it can bite [param size_class] — the one
## comparison the hunting rule turns on. Returns whether it got there.
##
## A check that wants a big spider says so here instead of eating its way there
## in the middle of making a different point, which is what left the spider fed
## for everything downstream.
func grow_to_bite(size_class: int) -> bool:
	while spider.stage().bite_power < size_class and spider.growth.next_stage() != null:
		spider.growth.feed(spider.growth.biomass_to_next() + 1.0, "test")
	var reached: bool = spider.stage().bite_power >= size_class
	if not reached:
		# Loud, because a premise that quietly fails to hold turns every check
		# after it into a check of something else.
		note("could not reach a bite of %d: stuck at %d, tier %d of %d, biomass %.0f"
			% [size_class, spider.stage().bite_power, spider.growth.stage_index,
			spider.growth.stages.size(), spider.growth.biomass])
	return reached


## Grows to a tier of the ladder. Absolute rather than relative, so it says the
## same thing wherever it is called from and repeating it does nothing.
func grow_to_tier(tier: int) -> int:
	while spider.growth.stage_index < tier and spider.growth.next_stage() != null:
		spider.growth.feed(spider.growth.biomass_to_next() + 1.0, "test")
	return spider.growth.stage_index


## Grows until the spider is big enough to spin something — the gate is the
## pattern's unlock_stage against the ladder. The premise most checks here
## actually have, said in the game's own terms rather than as a tier number.
func grow_to_spin(pattern_id: String) -> bool:
	var spun := pattern_named(pattern_id)
	if spun == null:
		return false
	grow_to_tier(spun.unlock_stage)
	return spider.growth.stage_index >= spun.unlock_stage


## Grows until every pattern on the wheel is available, for a check that ranges
## over all of them rather than testing one.
func grow_to_spin_anything() -> void:
	var top := 0
	for spun in builder.patterns:
		top = maxi(top, spun.unlock_stage)
	grow_to_tier(top)


## Puts the spider somewhere, standing still and facing level.
func place(at: Vector3) -> void:
	spider.climb.release()
	spider.global_position = at
	spider.velocity = Vector3.ZERO
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = 0.0


## Puts the spider on top of something and points it at the floor, which is where
## most of the placement checks want it.
func stand_on(at: Vector3) -> void:
	spider.climb.release()
	spider.global_position = at + Vector3(0, 0.6, 0)
	spider.velocity = Vector3.ZERO
	spider.view.face(Vector3(0, 0, -1))
	spider.view.pitch = -PI / 2.0


# --- clearing up --------------------------------------------------------

## Pulls down every web. The leak that cost the most: silk left standing catches
## the next check's prey, and a fly stuck in a web is not a loose fly.
func clear_webs() -> void:
	if not is_instance_valid(webs):
		return
	for child in webs.get_children():
		child.free()


func clear_prey() -> void:
	for node in root.get_tree().get_nodes_in_group("prey"):
		if is_instance_valid(node):
			node.free()


## Slabs and other scenery a check built to stand on.
func clear_props() -> void:
	if not is_instance_valid(level):
		return
	for child in level.get_children():
		if child.name.begins_with("TestSlab") or child.name.begins_with("TestProp"):
			child.free()


## Clears prey around a point but spares one, for a check that wants its own
## creature and no company.
func clear_prey_near(point: Vector3, radius: float, keep: Prey) -> void:
	for node in root.get_tree().get_nodes_in_group("prey"):
		var other := node as Prey
		if other == null or other == keep or not is_instance_valid(other):
			continue
		if point.distance_to(other.global_position) <= radius:
			other.queue_free()


# --- furnishing ---------------------------------------------------------

## A floor to stand on, away from the level's own geometry. Named TestSlab so
## [method clear_props] takes it away again.
##
## Called add_slab rather than slab because five checks already have a local
## called `slab`, and a local shadowing a method is reported at the call.
##
## [param host] is for a check that wants its scenery parented somewhere
## particular; the level itself is the right answer otherwise.
func add_slab(at: Vector3, size := Vector3(12, 0.5, 12), host: Node = null) -> StaticBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.name = "TestSlab"
	body.collision_layer = GameLayers.WORLD
	body.collision_mask = 0
	body.add_child(collider)
	var parent: Node = host if host != null else level
	parent.add_child(body)
	body.global_position = at
	return body


## A plain fly, the baseline everything else is measured against.
func spawn_fly(at: Vector3) -> Prey:
	return spawn("fly", at)


## Callers check what comes back, so this adds no check of its own — one per
## spawn buried the suite in "species 'fly' exists".
func spawn(id: String, at: Vector3) -> Prey:
	var prey := Prey.of(PreyLibrary.find(id))
	if prey == null:
		return null
	level.add_child(prey)
	prey.global_position = at
	return prey


# --- pointing and picking -----------------------------------------------

## Points the spider's crosshair at a spot in the world, yaw and pitch both.
func aim_at(point: Vector3) -> void:
	var offset := point - spider.view.aim_origin()
	var flat := Vector2(offset.x, offset.z).length()
	spider.view.face(Vector3(offset.x, 0.0, offset.z))
	spider.view.pitch = atan2(offset.y, maxf(flat, 0.0001))


func select_pattern(id: String) -> void:
	for i in builder.patterns.size():
		if builder.patterns[i].id == id:
			builder.pattern_index = i
			return
	check(false, "pattern '%s' exists" % id)


func pattern_named(id: String) -> WebPattern:
	for spun in builder.patterns:
		if spun.id == id:
			return spun
	check(false, "pattern '%s' exists" % id)
	return null


# --- reading the room ---------------------------------------------------

## Webs standing right now, in the order they were built.
func standing_webs() -> Array[WebStructure]:
	var found: Array[WebStructure] = []
	if not is_instance_valid(webs):
		return found
	for child in webs.get_children():
		var web := child as WebStructure
		if web != null and not web.is_queued_for_deletion():
			found.append(web)
	return found


func first_web() -> WebStructure:
	var standing := standing_webs()
	return null if standing.is_empty() else standing[0]


## Oldest web of a kind. Differs from [method newest_web] only in which end it
## takes, and both exist because a section that builds several of one pattern
## cares which — outside such a section a reset means there is only ever one.
func find_web(pattern_id: String) -> WebStructure:
	for web in standing_webs():
		if web.pattern.id == pattern_id:
			return web
	return null


func newest_web(pattern_id: String) -> WebStructure:
	var found: WebStructure = null
	for web in standing_webs():
		if web.pattern.id == pattern_id:
			found = web
	return found


func web_count() -> int:
	return standing_webs().size()


# --- eating -------------------------------------------------------------

## Eats, the way the player does: hold the key and let frames pass.
##
## Feeding is not one call — that is the point of it — so a check that wants a
## meal has to spend time on it like everybody else. Returns how much biomass the
## spider actually gained.
##
## Two presses, because that is what the player does: a creature still fighting a
## web is wrapped by the first and drunk by the second.
##
## The creature is pinned still, because a live one wanders out of reach inside
## the seconds a meal takes and then the check is measuring a chase — which is
## what happened to the larder. A check that is about reach tethers its catch
## instead, and is left alone here.
##
## [param frames] is an upper bound, not a duration: it stops as soon as the
## creature is empty, so no caller has to work out how many frames a beetle takes
## and get it wrong by six. That happened twice — a beetle at a bite of three
## needs about 306, and 300 looked generous. Pass a number you are sure is too
## big; a fast meal costs nothing.
func eat(prey: Prey, frames: int) -> float:
	var before := spider.growth.biomass
	prey.move_speed = 0.0
	Input.action_press("interact")
	spider._handle_prey(prey)
	if spider.feeding == null and is_instance_valid(prey) and not prey.eaten:
		await physics_frame
		spider._handle_prey(prey)
	var on_the_line: bool = spider.tether != null and spider.tether.cargo == prey
	for i in frames:
		if not on_the_line and is_instance_valid(prey) and not prey.eaten:
			prey.global_position = spider.global_position + Vector3(0.3, 0.1, 0.0)
		await physics_frame
		if not is_instance_valid(prey) or prey.eaten:
			break
	Input.action_release("interact")
	await process_frame
	await process_frame
	return spider.growth.biomass - before
