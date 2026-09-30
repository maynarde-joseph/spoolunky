class_name SpiderSpells
extends Node3D

## What the spider can cast, which of it is in hand, and how long until each is
## ready again.
##
## Right mouse casts whatever is in hand: a tap casts it at once, and holding
## winds it up — bigger, longer — until you let go. [b]Q[/b] moves the hand on to
## the next spell that is open. Silk is the first spell and is still thrown by
## the [WebBuilder] exactly as it always was; all this decides is that silk is
## what the key means right now. Every other spell is cast from here.
##
## The limit is the web's: a wait, never a bill (see §5 of the design). Each
## spell waits on its own, so casting one never costs you another, and a trait
## can shorten every wait at once — see [method SpiderTraits.cast_scale].
##
## Which spells are open is decided the way a gate decides who passes: a rung of
## the ladder, or any trait the spell names as a key — see [method is_open]. The
## book is read afresh whenever the spider grows or a trait comes, and anything
## newly open is announced.

## Something opened, the hand moved, or a wait ran out. The strip redraws off this.
signal changed()

## A spell became castable. Carries it, for the message.
signal opened(spell: SpiderSpell)

## Something was cast. [param at] is where it went.
signal cast(spell: SpiderSpell, at: Vector3)

## Said out loud to the player. The spider passes these through.
signal notice(text: String)

## Leave empty to load every spell in the spells folder.
@export var book: Array[SpiderSpell] = []

## How long winding a spell up to its full size takes, in seconds. The web's own
## figure, so everything the spider casts winds up in the same second.
@export var charge_time := 0.9

## How big the glow held over the spider's back is while a spell winds up, in body
## heights, from a tap to a full wind-up. The same span the ball of silk has.
@export var held_bodies := Vector2(0.12, 0.3)

## Which spell is in hand, as an index into [member book].
var selected := 0

## True while the cast key is held on a spell other than silk.
var charging := false

## How far through the wind-up, 0 to 1.
var charge := 0.0

## Seconds left before each spell can be cast again, by id, and the wait each
## one started from. Only spells that are waiting are in them.
var _cooling := {}
var _spans := {}

## Spell id to whether it was open the last time the book was read, so what
## opens can be told apart from what was open all along.
var _open := {}

var _spider: SpiderPlayer
var _growth: SpiderGrowth
var _traits: SpiderTraits
var _view: SpiderCamera
var _builder: WebBuilder
var _held: MeshInstance3D
var _held_material: StandardMaterial3D
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D


func _ready() -> void:
	if book.is_empty():
		book = SpellLibrary.load_spells()


func setup(spider: SpiderPlayer, growth: SpiderGrowth, traits: SpiderTraits,
		view: SpiderCamera, builder: WebBuilder) -> void:
	_spider = spider
	_growth = growth
	_traits = traits
	_view = view
	_builder = builder
	if _growth != null:
		_growth.stage_changed.connect(_on_stage_changed)
	if _traits != null:
		_traits.changed.connect(_on_traits_changed)
	# Quietly: what a spiderling starts with is not news.
	_read_the_book(false)


func _process(delta: float) -> void:
	var ran_out := false
	for id in _cooling.keys():
		var left: float = _cooling[id] - delta
		if left <= 0.0:
			_cooling.erase(id)
			_spans.erase(id)
			ran_out = true
		else:
			_cooling[id] = left
	if ran_out:
		changed.emit()
	if _builder != null:
		# One owner for the framing: the builder eases it, for its own wind-up and
		# for this one alike. Two things easing one number is two things fighting.
		_builder.framing_held = charging
	_update_held()
	_update_marker()


# --- the book -----------------------------------------------------------

## The spell in hand, or null if the book is empty.
func current() -> SpiderSpell:
	if book.is_empty():
		return null
	return book[clampi(selected, 0, book.size() - 1)]


func by_id(spell_id: String) -> SpiderSpell:
	for spell in book:
		if spell.id == spell_id:
			return spell
	return null


## Whether [param spell] can be cast by this spider: its rung reached, or one of
## its keys owned. The same either-key rule a gate uses, so the size is what you
## can always count on and the trait is what luck may hand you first.
func is_open(spell: SpiderSpell) -> bool:
	if spell == null:
		return false
	var rung := _growth.stage_index if _growth != null else 0
	if rung >= spell.unlock_stage:
		return true
	if _traits != null:
		for key in spell.keys:
			if _traits.has(key):
				return true
	return false


## Every spell this spider can cast, in order.
func open_spells() -> Array[SpiderSpell]:
	var found: Array[SpiderSpell] = []
	for spell in book:
		if is_open(spell):
			found.append(spell)
	return found


## What opens a shut spell, written out: its rung, and any trait that would open
## it first.
func opens_with(spell: SpiderSpell) -> String:
	if spell == null:
		return ""
	var ways := PackedStringArray()
	var stages: Array = _growth.stages if _growth != null else []
	if spell.unlock_stage < stages.size():
		ways.append((stages[spell.unlock_stage] as GrowthStage).display_name)
	else:
		ways.append("stage %d" % (spell.unlock_stage + 1))
	if _traits != null:
		for key in spell.keys:
			var gift := _traits.by_id(key)
			ways.append(gift.display_name if gift != null else key)
	return " or ".join(ways)


## Takes the next open spell in hand, going [param step] along the book. False
## — and nothing moves — if nothing else is open, or while something is being
## wound up: the hand does not change what it is holding mid-throw.
func cycle(step := 1) -> bool:
	if book.is_empty() or charging or (_builder != null and _builder.aiming):
		return false
	var count := book.size()
	for i in range(1, count):
		var index := posmod(selected + step * i, count)
		if is_open(book[index]):
			selected = index
			changed.emit()
			var spell := current()
			notice.emit("%s in hand — %s" % [spell.display_name, spell.description])
			return true
	return false


## Takes [param spell_id] in hand. False if it is not in the book or not open.
func select(spell_id: String) -> bool:
	for i in book.size():
		if book[i].id == spell_id and is_open(book[i]):
			selected = i
			changed.emit()
			return true
	return false


# --- waiting ------------------------------------------------------------

## Whether [param spell] is still waiting to be cast again.
func cooling(spell: SpiderSpell) -> bool:
	if spell == null:
		return false
	if spell.form == SpiderSpell.Form.SILK:
		return _builder != null and _builder.cooling()
	return _cooling.has(spell.id)


func cooldown_left(spell: SpiderSpell) -> float:
	if spell == null:
		return 0.0
	if spell.form == SpiderSpell.Form.SILK:
		return _builder.cooldown_left() if _builder != null else 0.0
	return float(_cooling.get(spell.id, 0.0))


## 0 to 1, for the strip. 1 means ready.
func cooldown_progress(spell: SpiderSpell) -> float:
	if spell == null:
		return 1.0
	if spell.form == SpiderSpell.Form.SILK:
		return _builder.cooldown_progress() if _builder != null else 1.0
	var span: float = _spans.get(spell.id, 0.0)
	if span <= 0.0:
		return 1.0
	return clampf(1.0 - cooldown_left(spell) / span, 0.0, 1.0)


## How long [param spell] makes you wait, after what the spider has become.
func wait_for(spell: SpiderSpell) -> float:
	if spell == null:
		return 0.0
	var scale := _traits.cast_scale() if _traits != null else 1.0
	return spell.cooldown * scale


## Everything ready at once, for a check that casts twice and is not about the
## wait.
func forget_waits() -> void:
	_cooling.clear()
	_spans.clear()
	changed.emit()


# --- casting ------------------------------------------------------------

## The cast key went down. Silk goes to the builder, which winds up its own ball;
## anything else starts winding up here.
func begin_cast() -> bool:
	var spell := current()
	if spell == null:
		return false
	if spell.form == SpiderSpell.Form.SILK:
		return _builder != null and _builder.begin_shot()
	if charging:
		return false
	charging = true
	charge = 0.0
	changed.emit()
	return true


## Held down: winds it up.
func track(delta: float) -> void:
	if not charging:
		return
	charge = clampf(charge + delta / maxf(charge_time, 0.05), 0.0, 1.0)


## Let go: casts whatever the wind-up reached.
func release_cast() -> bool:
	var spell := current()
	if spell != null and spell.form == SpiderSpell.Form.SILK:
		if _builder == null or not _builder.release_shot():
			return false
		cast.emit(spell, _builder.aim_point)
		return true
	if not charging:
		return false
	charging = false
	var wound := charge
	charge = 0.0
	var went := cast_now(spell, wound)
	changed.emit()
	return went


## Gives up a wind-up without casting, for when the key-up never came because
## something else took the input away.
func cancel_cast() -> void:
	if charging:
		charging = false
		charge = 0.0
		changed.emit()
	if _builder != null:
		_builder.cancel_shot()


## Casts [param spell] where the cross is, wound up to [param wound] from 0 for a
## tap to 1 for a full wind-up. Returns whether anything went. It is what letting
## go of the key does, and what a check calls to cast without a key.
func cast_now(spell: SpiderSpell, wound := 0.0) -> bool:
	if spell == null or not is_open(spell) or _spider == null:
		return false
	if spell.form == SpiderSpell.Form.SILK:
		if _builder == null:
			return false
		_builder.charge = clampf(wound, 0.0, 1.0)
		var thrown := _builder.shoot()
		_builder.charge = 0.0
		if thrown:
			cast.emit(spell, _builder.aim_point)
		return thrown
	if cooling(spell):
		notice.emit("%s — %.1fs" % [spell.display_name, cooldown_left(spell)])
		return false
	var went := _cast_form(spell, clampf(wound, 0.0, 1.0))
	if not went.get("cast", false):
		return false
	var span := wait_for(spell)
	if span > 0.0:
		_cooling[spell.id] = span
		_spans[spell.id] = span
	cast.emit(spell, went.get("at", _spider.global_position))
	changed.emit()
	return true


## What each form does. Returns whether it went, and where.
func _cast_form(spell: SpiderSpell, wound: float) -> Dictionary:
	match spell.form:
		SpiderSpell.Form.VENOM:
			return _spit(spell, wound)
		SpiderSpell.Form.SPIRAL:
			return _whirl(spell, wound)
		SpiderSpell.Form.LIGHTNING:
			return _strike(spell, wound)
	push_warning("%s has a form nothing casts yet" % spell.display_name)
	return {"cast": false}


# --- venom --------------------------------------------------------------

## A glob of venom, thrown the way silk is: at the creature under the cross, led
## if it is moving, and straight on if nothing is — the same bolt, drawn green.
## What it hits is dosed (see [method Prey.poison]) and softens from the inside
## for as long as the dose lasts, while you do something else.
##
## A dose does not stack; a second one tops the first back up. Fangs make it a
## fanged dose, which works a good deal harder.
func _spit(spell: SpiderSpell, wound: float) -> Dictionary:
	var from := _view.aim_origin()
	var heading := _view.aim_forward()
	var quarry := _builder.shot_target() if _builder != null else null
	if quarry != null:
		var lead := _builder.shot_lead(quarry) - from
		if lead.length_squared() > 0.000001:
			heading = lead.normalized()
	var glob := SilkShot.fire(from, heading, body_height(), exclusions())
	glob.name = "VenomGlob"
	glob.catch_radius = spell.size_at(wound) * body_height()
	glob.colour = spell.colour
	glob.glow = 1.6
	glob.glows_own = true
	glob.limit_to(cast_reach())
	glob.landed.connect(_on_glob_landed.bind(spell, spell.duration_at(wound), venom_strength()))
	glob.add_to_group("spell_effects")
	glob.launch_from(_host(), from)
	return {"cast": true, "at": from + heading * cast_reach()}


## Lightning comes down on what the cross is on — a creature, a web, the floor.
## Aimed at open air, it comes down through it to whatever is underneath.
func _ground(target: Dictionary) -> Dictionary:
	if target.get("hit", false):
		return target
	var point: Vector3 = target.get("point", Vector3.ZERO)
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * cast_reach(),
		GameLayers.WORLD | GameLayers.WEB_WALK, exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return target
	return {"point": hit.get("position", point), "normal": hit.get("normal", Vector3.UP),
		"prey": null, "hit": true}


## Lightning, called down where you point. See [LightningStrike].
func _strike(spell: SpiderSpell, wound: float) -> Dictionary:
	var target := area_target(spell, wound)
	var at: Vector3 = target.get("point", _spider.global_position)
	var stun := spell.duration_at(wound) * (_traits.stun_scale() if _traits != null else 1.0)
	var jumps := _traits.arc_bonus() if _traits != null else 0
	var strike := LightningStrike.call_down(_host(), at, spell.size_at(wound) * body_height(),
		stun, jumps, body_height() * 0.6, spell.colour)
	if strike == null:
		return {"cast": false}
	if not strike.shocked.is_empty():
		var through := ""
		if not strike.charged.is_empty():
			through = " — through %d web%s" % [strike.charged.size(),
				"" if strike.charged.size() == 1 else "s"]
		notice.emit("Lightning — %d stunned%s" % [strike.shocked.size(), through])
	return {"cast": true, "at": at}


## A whirl of water on the floor under where you point. See [WaterSpiral].
func _whirl(spell: SpiderSpell, wound: float) -> Dictionary:
	var target := area_target(spell, wound)
	var at: Vector3 = target.get("point", _spider.global_position)
	var eats := _traits != null and _traits.acid_water()
	var whirl := WaterSpiral.summon(_host(), at, spell.size_at(wound) * body_height(),
		spell.duration_at(wound), eats, venom_strength(), spell.colour)
	if whirl == null:
		return {"cast": false}
	return {"cast": true, "at": at}


## How hard a dose works: fanged, with fangs.
func venom_strength() -> float:
	return Prey.FANG_VENOM if _traits != null and _traits.has_fangs() else 1.0


func _on_glob_landed(at: Vector3, _normal: Vector3, struck: Node3D, _heading: Vector3,
		spell: SpiderSpell, dose: float, strength: float) -> void:
	SpellFlash.burst(_host(), at, spell.colour, body_height() * 0.5)
	# Into water, it goes into all of it: everything a whirl holds is dosed for as
	# long as it turns.
	for node in get_tree().get_nodes_in_group(WaterSpiral.GROUP):
		var whirl := node as WaterSpiral
		if whirl != null and whirl.spinning() and whirl.holds(at):
			whirl.poison(strength)
			notice.emit("Venom in the water — everything it holds is dosed")
	var prey := struck as Prey
	if prey == null or not is_instance_valid(prey):
		return
	if prey.poison(dose, strength):
		notice.emit("Venom in the %s — it softens for %ds" % [prey.species, roundi(dose)])
	else:
		notice.emit("The %s is past venom" % prey.species)


# --- where a spell goes --------------------------------------------------

## Where the cross puts a spell: on the creature it is over if it is over one —
## the same pick the web makes — else where it meets the world, else as far as
## silk reaches. A dictionary of the point, the surface's normal and the creature.
##
## [param mask] is what the cross can stop on. Silk by default, because a web is
## something to aim at; a whirl looks straight through it to the floor.
func aim_target(mask := GameLayers.WORLD | GameLayers.WEB_WALK) -> Dictionary:
	var from := _view.aim_origin()
	var forward := _view.aim_forward()
	var span := cast_reach()
	var quarry := _builder.shot_target() if _builder != null else null
	if quarry != null:
		return {"point": quarry.global_position, "normal": Vector3.UP, "prey": quarry,
			"hit": true}
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * span, mask,
		exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return {"point": hit.get("position", from), "normal": hit.get("normal", Vector3.UP),
			"prey": hit.get("collider") as Prey, "hit": true}
	return {"point": from + forward * span, "normal": Vector3.UP, "prey": null, "hit": false}


## How far a spell goes: as far as silk does. One reach for everything the spider
## throws, because two verbs that both mean "over there" with two different
## invisible limits is the fastest way to make a reach unreadable.
func cast_reach() -> float:
	if _builder != null:
		return _builder.silk_reach()
	return body_height() * 12.0


## What a spell's rays and sweeps pass through: the spider itself.
func exclusions() -> Array[RID]:
	var list: Array[RID] = []
	if _spider != null:
		list.append(_spider.get_rid())
	return list


func body_height() -> float:
	return _spider.stage().body_height if _spider != null else 0.25


## Where the level keeps what spells leave behind.
func _host() -> Node:
	var host := get_tree().current_scene
	if host == null and _spider != null:
		host = _spider.get_parent()
	return host


# --- what you can see ----------------------------------------------------

## The spell glowing over the spider's back while it winds up — the web's ball,
## in the spell's colour. You can see the cast coming, and how big it has got.
func _update_held() -> void:
	var spell := current()
	var shown := charging and spell != null and _spider != null
	if shown and _held == null:
		_build_held()
	if _held == null:
		return
	_held.visible = shown
	if not shown:
		return
	var height := body_height()
	var wide := height * lerpf(held_bodies.x, held_bodies.y, charge)
	var back := _spider.climb.view_up() if _spider.climb != null else Vector3.UP
	_held.global_position = _spider.global_position + back * (height * 0.9 + wide)
	_held.scale = Vector3.ONE * maxf(wide, 0.005)
	_held_material.albedo_color = spell.colour
	_held_material.emission = spell.colour
	_held_material.emission_energy_multiplier = lerpf(0.6, 2.4, charge)


## A ring where an area spell will land, as wide as it will be, while it winds
## up. The crosshair says where; this says how much of it.
func _update_marker() -> void:
	var spell := current()
	var shown := charging and spell != null and is_area(spell) and _view != null
	if shown and _marker == null:
		_build_marker()
	if _marker == null:
		return
	_marker.visible = shown
	if not shown:
		return
	var target := area_target(spell)
	var radius := spell.size_at(charge) * body_height()
	var up: Vector3 = target.get("normal", Vector3.UP)
	_marker.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up.normalized())),
		target.get("point", Vector3.ZERO) + up * body_height() * 0.05)
	_marker.scale = Vector3.ONE * maxf(radius, 0.01)
	_marker_material.albedo_color = Color(spell.colour.r, spell.colour.g, spell.colour.b, 0.75)


## Where an area spell lands, and which way is up there, wound up to
## [param wound] — or to however far the wind-up has got, if not given.
##
## A whirl turns on the floor under where you point, as long as that floor is near
## enough for it to reach back up to the point; aimed at a wall, it turns in front
## of the wall rather than in it; over a drop, it turns in the air where you
## pointed.
func area_target(spell: SpiderSpell, wound := -1.0) -> Dictionary:
	if spell != null and spell.form == SpiderSpell.Form.LIGHTNING:
		return _ground(aim_target())
	if spell == null or spell.form != SpiderSpell.Form.SPIRAL:
		return aim_target()
	var target := aim_target(GameLayers.WORLD)
	var radius := spell.size_at(charge if wound < 0.0 else wound) * body_height()
	var point: Vector3 = target.get("point", Vector3.ZERO)
	var normal: Vector3 = target.get("normal", Vector3.UP)
	if target.get("prey") == null and normal.y < 0.5:
		point += normal * radius
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * body_height() * 0.1,
		point + Vector3.DOWN * radius * WaterSpiral.REACH_UP, GameLayers.WORLD, exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		normal = Vector3.UP
	else:
		point = hit.get("position", point)
		normal = hit.get("normal", Vector3.UP)
	return {"point": point, "normal": normal, "prey": target.get("prey")}


func is_area(spell: SpiderSpell) -> bool:
	return spell.form == SpiderSpell.Form.SPIRAL or spell.form == SpiderSpell.Form.LIGHTNING


func _build_held() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_held_material = StandardMaterial3D.new()
	_held_material.emission_enabled = true
	_held_material.roughness = 0.4
	_held = MeshInstance3D.new()
	_held.name = "HeldSpell"
	_held.mesh = mesh
	_held.material_override = _held_material
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.top_level = true
	_held.visible = false
	add_child(_held)


func _build_marker() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.93
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 4
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker = MeshInstance3D.new()
	_marker.name = "SpellMarker"
	_marker.mesh = mesh
	_marker.material_override = _marker_material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)


# --- keeping up with the spider ------------------------------------------

func _on_stage_changed(_stage: GrowthStage, _index: int) -> void:
	_read_the_book()


func _on_traits_changed() -> void:
	_read_the_book()


## Reads which spells are open, says so for any that have just opened, and moves
## the hand off anything that has shut.
func _read_the_book(announce := true) -> void:
	var fresh: Array[SpiderSpell] = []
	for spell in book:
		var now := is_open(spell)
		if now and not bool(_open.get(spell.id, false)):
			fresh.append(spell)
		_open[spell.id] = now
	if not is_open(current()):
		selected = 0
		for i in book.size():
			if is_open(book[i]):
				selected = i
				break
		if charging:
			cancel_cast()
	if announce:
		for spell in fresh:
			opened.emit(spell)
			notice.emit("New spell: %s — [Q] to take it in hand" % spell.display_name)
	changed.emit()
