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
var _path: MeshInstance3D
var _path_material: StandardMaterial3D


## Every spell open, whatever the rung or the traits. See
## [member SpiderPlayer.all_spells_open].
var open_all := false:
	set(value):
		open_all = value
		if _spider != null:
			_read_the_book(false)


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
	_update_path()


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
## can always count on and the trait is what luck may hand you first — unless the
## whole book is open, which a level can hand the spider from the start.
func is_open(spell: SpiderSpell) -> bool:
	if spell == null:
		return false
	if open_all:
		return true
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
		SpiderSpell.Form.SPIRAL:
			return _whirl(spell, wound)
		SpiderSpell.Form.LIGHTNING:
			return _strike(spell, wound)
		SpiderSpell.Form.FIRE:
			return _hurl(spell, wound)
	push_warning("%s has a form nothing casts yet" % spell.display_name)
	return {"cast": false}


# --- lightning and water --------------------------------------------------

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
	var target := area_target(spell)
	var at: Vector3 = target.get("point", _spider.global_position)
	var stun := spell.duration_at(wound) * (_traits.stun_scale() if _traits != null else 1.0)
	var jumps := _traits.arc_bonus() if _traits != null else 0
	var strike := LightningStrike.call_down(_host(), at, spell.size_at(wound) * body_height(),
		stun, jumps, body_height() * 0.6, spell.colour)
	if strike == null:
		return {"cast": false}
	var said := PackedStringArray()
	if not strike.shocked.is_empty():
		said.append("%d stunned" % strike.shocked.size())
	if not strike.charged.is_empty():
		said.append("%d web%s live for %ds" % [strike.charged.size(),
			"" if strike.charged.size() == 1 else "s", roundi(stun * LightningStrike.LIVE_FOR)])
	if not said.is_empty():
		notice.emit("Lightning — " + ", ".join(said))
	return {"cast": true, "at": at}


## A whirl of water, sent out from under the spider along the ground the way you
## aim, as far as the wind-up sends it: what it passes over is soaked and slowed.
## See [WaterSpiral].
func _whirl(spell: SpiderSpell, wound: float) -> Dictionary:
	var eats := _traits != null and _traits.acid_water()
	var whirl := WaterSpiral.send(_host(), _spider.global_position, spiral_heading(),
		spell.size_at(wound) * body_height(), spiral_reach(spell, wound),
		WaterSpiral.PACE * body_height(), spell.duration_at(wound), eats, venom_strength(),
		spell.colour)
	if whirl == null:
		return {"cast": false}
	whirl.spent.connect(_on_whirl_spent)
	return {"cast": true, "at": whirl.end_point()}


## Which way a whirl goes: flat along the ground, from the spider to what the cross
## is on — or the way the cross looks, if it is on the sky or at the spider's feet.
func spiral_heading() -> Vector3:
	var target := aim_target(GameLayers.WORLD)
	var toward: Vector3 = target.get("point", Vector3.ZERO) - _spider.global_position
	toward.y = 0.0
	if not target.get("hit", false) or toward.length() < body_height():
		toward = _view.aim_forward()
		toward.y = 0.0
	if toward.length_squared() < 0.000001:
		toward = -_spider.global_basis.z
		toward.y = 0.0
	return toward.normalized() if toward.length_squared() > 0.000001 else Vector3.FORWARD


## How far a whirl wound up to [param wound] goes, in metres: its share of silk's
## reach.
func spiral_reach(spell: SpiderSpell, wound: float) -> float:
	return spell.travel_at(wound) * cast_reach()


func _on_whirl_spent(_whirl: WaterSpiral, slowed: Array[Prey]) -> void:
	var caught: Array[Prey] = []
	for creature in slowed:
		if is_instance_valid(creature) and not creature.eaten:
			caught.append(creature)
	if caught.size() == 1:
		notice.emit("The %s is soaked and slowed" % caught[0].species)
	elif caught.size() > 1:
		notice.emit("Water — %d soaked and slowed" % caught.size())


# --- fire -----------------------------------------------------------------

## A bolt of fire, thrown the way silk is — at the creature under the cross, led if
## it is moving, or at the line under it — that bursts where it lands and burns
## everything in the burst. Silk burns, so what it does to each creature is worth
## the silk on it (see [method Prey.burn]): little to something bare, all of it to
## something wrapped or held in a web. And a creature burned low is an easy catch.
##
## The silk itself goes up too: every web and every line the burst reaches burns
## away, and what a web was holding drops out of it — burned as hard as fire burns
## anything, and loose. See [method _on_fire_landed].
func _hurl(spell: SpiderSpell, wound: float) -> Dictionary:
	var from := _view.aim_origin()
	var heading := _view.aim_forward()
	var quarry := _builder.shot_target() if _builder != null else null
	if quarry != null:
		var lead := _builder.shot_lead(quarry) - from
		if lead.length_squared() > 0.000001:
			heading = lead.normalized()
	elif _builder != null:
		# A line is a hair across the view, so the same pick the grapple makes
		# decides whether the cross is on one; if it is, the bolt goes to the line
		# rather than past it to the wall behind.
		var line := _builder.aimed_line()
		if line != null:
			var pair := Geometry3D.get_closest_points_between_segments(from,
				from + heading * cast_reach(), line.point_a, line.point_b)
			var to_line: Vector3 = pair[1] - from
			if to_line.length_squared() > 0.000001:
				heading = to_line.normalized()
	var bolt := SilkShot.fire(from, heading, body_height(), exclusions())
	bolt.name = "FireBolt"
	bolt.catch_radius = 0.16 * body_height()
	bolt.colour = spell.colour
	bolt.glow = 1.6
	bolt.glows_own = true
	bolt.limit_to(cast_reach())
	bolt.landed.connect(_on_fire_landed.bind(spell, spell.power_at(wound),
		spell.size_at(wound) * body_height()))
	bolt.add_to_group("spell_effects")
	bolt.launch_from(_host(), from)
	return {"cast": true, "at": from + heading * cast_reach()}


func _on_fire_landed(at: Vector3, _normal: Vector3, struck: Node3D, _heading: Vector3,
		spell: SpiderSpell, power: float, reach: float) -> void:
	SpellFlash.burst(_host(), at, spell.colour, reach, 0.45)
	var burned: Array[Prey] = []
	var worst := 0.0
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey):
			continue
		if prey != struck and prey.global_position.distance_to(at) > reach + prey.hit_radius():
			continue
		var lost := prey.burn(power)
		if lost <= 0.0:
			continue
		burned.append(prey)
		SpellFlash.burst(_host(), prey.global_position, spell.colour, prey.hit_radius() * 2.5,
			0.6)
		worst = maxf(worst, lost)
	# Then the silk, once the creatures in it have burned as hard as a web makes
	# them: webs and lines alike, and the spider's own as much as any. A web goes
	# with the frame it was walked round on.
	var burning: Array[WebStructure] = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web != null and not web.is_queued_for_deletion() and web.reaches(at, reach):
			burning.append(web)
	var frames: Array[WebStructure] = []
	for web in burning:
		var net := web as WebNet
		if net == null:
			continue
		for line in _frame_of(net):
			if not burning.has(line) and not frames.has(line):
				frames.append(line)
	var nets := 0
	var lines := 0
	for web in burning + frames:
		_flare(web, spell.colour)
		web.tear()
		if web is WebNet:
			nets += 1
		elif not frames.has(web):
			lines += 1
	var said := PackedStringArray()
	if burned.size() == 1:
		said.append("The %s burns — %d%% of it left" % [burned[0].species,
			roundi(burned[0].health() * 100.0)])
	elif burned.size() > 1:
		said.append("Fire — %d burned" % burned.size())
	if nets > 0:
		said.append("%d web%s burned away" % [nets, "" if nets == 1 else "s"])
	if lines > 0:
		said.append("%d line%s burned away" % [lines, "" if lines == 1 else "s"])
	if not said.is_empty():
		notice.emit(" · ".join(said))


## The lines [param net] was walked round on — both ends on its own anchors — which
## go up with it rather than standing round the hole it leaves.
func _frame_of(net: WebNet) -> Array[WebStrand]:
	var found: Array[WebStrand] = []
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var strand := node as WebStrand
		if strand != null and not strand.is_queued_for_deletion() \
				and _is_anchor(net, strand.point_a) and _is_anchor(net, strand.point_b):
			found.append(strand)
	return found


static func _is_anchor(net: WebNet, point: Vector3) -> bool:
	for anchor in net.anchors:
		if anchor.distance_to(point) < 0.01:
			return true
	return false


## Fire running along [param web] as it goes: a bloom at both ends of a line and
## in its middle, or one over the whole of a web.
func _flare(web: WebStructure, colour: Color) -> void:
	var strand := web as WebStrand
	if strand != null:
		for share in [0.0, 0.5, 1.0]:
			SpellFlash.burst(_host(), strand.point_a.lerp(strand.point_b, share), colour,
				body_height() * 0.5, 0.5)
		return
	var net := web as WebNet
	if net != null:
		SpellFlash.burst(_host(), net.signal_point(), colour, maxf(net.radius, 0.05), 0.5)


## How hard a dose of the spider's acid water works: fanged, with fangs.
func venom_strength() -> float:
	return Prey.FANG_VENOM if _traits != null and _traits.has_fangs() else 1.0


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
	# Lit from inside, but not so bright that its colour washes out to white:
	# the colour is how you tell a bolt of fire from a ball of silk.
	_held_material.emission_energy_multiplier = lerpf(0.25, 0.9, charge)


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


## Where an area spell lands, and which way is up there: lightning comes down on
## what the cross is on, and through open air to whatever is under it.
func area_target(spell: SpiderSpell) -> Dictionary:
	if spell != null and spell.form == SpiderSpell.Form.LIGHTNING:
		return _ground(aim_target())
	return aim_target()


## Whether [param spell] lands on an area where you point, rather than being thrown
## at something or sent out along the ground.
func is_area(spell: SpiderSpell) -> bool:
	return spell.form == SpiderSpell.Form.LIGHTNING


## The strip a whirl will run along, as long and as wide as it will be, while it
## winds up: which way it goes, and how far. Laid flat from the floor under the
## spider, so on rough ground it is a guide rather than a promise.
func _update_path() -> void:
	var spell := current()
	var shown := charging and spell != null and spell.form == SpiderSpell.Form.SPIRAL \
		and _view != null and _spider != null
	if shown and _path == null:
		_build_path()
	if _path == null:
		return
	_path.visible = shown
	if not shown:
		return
	var heading := spiral_heading()
	var far := maxf(spiral_reach(spell, charge), 0.01)
	var wide := spell.size_at(charge) * body_height() * 2.0
	var floor_at: Vector3 = _ground({"point": _spider.global_position, "hit": false}) \
		.get("point", _spider.global_position)
	_path.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP),
		floor_at + heading * far * 0.5 + Vector3.UP * body_height() * 0.05)
	_path.scale = Vector3(wide, 1.0, far)
	_path_material.albedo_color = Color(spell.colour.r, spell.colour.g, spell.colour.b, 0.3)


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


func _build_path() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	_path_material = StandardMaterial3D.new()
	_path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_path = MeshInstance3D.new()
	_path.name = "SpellPath"
	_path.mesh = mesh
	_path.material_override = _path_material
	_path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_path.top_level = true
	_path.visible = false
	add_child(_path)


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
