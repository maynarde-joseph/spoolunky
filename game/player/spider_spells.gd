class_name SpiderSpells
extends Node3D

## What the spider can cast, which of it is in hand, and how long until each is
## ready again.
##
## Right mouse casts whatever is in hand: a tap casts it at once, and holding
## winds it up — bigger, longer — until you let go. The number keys take a spell in
## hand, and the wheel moves the hand along to the next one that is open. Silk is
## the first spell and is still thrown by
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

## How fast a web called back by the Pullback comes, in body heights a second.
@export var pull_pace := 18.0

## How wide a whirl a Gust lifts off wet ground is, from the middle to the rim, in
## body heights, from a tap to a full wind-up.
const SPIRAL_BODIES := Vector2(1.3, 1.6)

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
## The circle drawn while a spell winds up, until it goes.
var _circle: MagicCircle = null

## Lines out to the webs a Pullback will call in, while it winds up.
var _pull_lines: MeshInstance3D
var _pull_mesh: ImmediateMesh
var _pull_paint: StandardMaterial3D
## The fan a spray of water or a gust of wind will cover, while it winds up.
var _fan: MeshInstance3D
var _fan_paint: StandardMaterial3D


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
	_update_circle()
	_update_fan()
	_update_pull_lines()


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
			notice.emit("%s in hand" % current().display_name)
			return true
	return false


## Takes the spell on number key [param key] in hand: the book's first spell is 1,
## its second 2, and so on, open or not, so a key means the same spell all game.
## A wind-up under way is given up — the key is the player saying what they want in
## hand now, and a key that waited on the throw it interrupted would feel dead.
## False if there is no such spell, or it is shut, or already in hand.
func take(key: int) -> bool:
	var index := key - 1
	if index < 0 or index >= book.size():
		return false
	var spell := book[index]
	if not is_open(spell):
		notice.emit("%s opens with %s" % [spell.display_name, opens_with(spell)])
		return false
	if index == selected:
		return false
	cancel_cast()
	selected = index
	changed.emit()
	notice.emit("%s in hand" % spell.display_name)
	return true


## The number key that takes [param spell] in hand, or 0 if it is not in the book.
func key_for(spell: SpiderSpell) -> int:
	return book.find(spell) + 1


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
	_cast_circle(spell, clampf(wound, 0.0, 1.0))
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
		SpiderSpell.Form.DOUSE:
			return _douse(spell, wound)
		SpiderSpell.Form.GUST:
			return _blow(spell, wound)
		SpiderSpell.Form.LIGHTNING:
			return _strike(spell, wound)
		SpiderSpell.Form.FIRE:
			return _erupt(spell, wound)
		SpiderSpell.Form.PULLBACK:
			return _pull_back(spell, wound)
	push_warning("%s has a form nothing casts yet" % spell.display_name)
	return {"cast": false}


# --- lightning, water and wind --------------------------------------------

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
	var radius := spell.size_at(wound) * body_height()
	var strike := LightningStrike.call_down(_host(), at, radius, stun, jumps,
		body_height() * 0.6, spell.colour)
	if strike == null:
		return {"cast": false}
	# Where it comes down from: a second circle over the first, face down.
	var top := at + Vector3.UP * maxf(radius * LightningStrike.FALL, LightningStrike.FALL_LEAST)
	var sky := MagicCircle.draw(_host(), MagicCircle.facing(top, Vector3.DOWN), radius * 0.8,
		spell.colour, spell.sigil)
	if sky != null:
		sky.release()
	var said := PackedStringArray()
	if not strike.shocked.is_empty():
		said.append("%d stunned" % strike.shocked.size())
	if not strike.charged.is_empty():
		said.append("%d web%s live for %ds" % [strike.charged.size(),
			"" if strike.charged.size() == 1 else "s", roundi(stun * LightningStrike.LIVE_FOR)])
	if not said.is_empty():
		notice.emit("Lightning — " + ", ".join(said))
	return {"cast": true, "at": at}


## Water sprayed in a fan in front of the spider, out across the ground as far as
## the wind-up throws it. Everything the spray catches is soaked and stung, a flier
## comes down, and the ground stays wet for a while after: whatever stands on it
## stays soaked. Silk the spray reaches is soaked too, and a wet web does not burn.
## See [WetGround] and [WetSilk].
func _douse(spell: SpiderSpell, wound: float) -> Dictionary:
	var from := feet_ground()
	var heading := fan_heading()
	var far := fan_reach(spell, wound)
	var lasts := spell.duration_at(wound)
	var wet := WetGround.spill(_host(), from, heading, far, lasts, spell.colour)
	if wet == null:
		return {"cast": false}
	var harm := spell.power_at(wound)
	var soaked := 0
	for node in get_tree().get_nodes_in_group("prey"):
		var creature := node as Prey
		if creature == null or not is_instance_valid(creature) or creature.eaten:
			continue
		if not _in_spray(creature.global_position, from, heading, far, creature.hit_radius()):
			continue
		creature.soak(WetGround.SOAK + lasts * 0.5)
		creature.wound(harm)
		soaked += 1
	var webs := 0
	for node in get_tree().get_nodes_in_group("silk_webs"):
		var web := node as WebStructure
		if web != null and not web.is_queued_for_deletion() \
				and _spray_reaches(web, from, heading, far):
			WetSilk.soak(web, lasts)
			webs += 1
	var said := PackedStringArray()
	if soaked > 0:
		said.append("%d soaked" % soaked)
	if webs > 0:
		said.append("%d web%s wet — it will not burn" % [webs, "" if webs == 1 else "s"])
	if not said.is_empty():
		notice.emit("Douse — " + ", ".join(said))
	return {"cast": true, "at": from + heading * far * 0.5}


## Wind blown in a fan in front of the spider: everything loose in it is shoved away
## and stung — into a web, if one is in the way, which catches it — and a boss only
## takes the sting. Over ground Douse left wet it lifts the water into a whirl that
## runs on the way the wind blew, and holds the first thing it reaches. See [Gust]
## and [WaterSpiral].
func _blow(spell: SpiderSpell, wound: float) -> Dictionary:
	var from := feet_ground()
	var heading := fan_heading()
	var far := fan_reach(spell, wound)
	var height := body_height()
	var push := lerpf(Gust.PUSH.x, Gust.PUSH.y, wound) * height
	var gust := Gust.blow(_host(), from + Vector3.UP * height * 0.3, heading, far, push,
		spell.power_at(wound), spell.colour)
	if gust == null:
		return {"cast": false}
	var whirls := 0
	for node in get_tree().get_nodes_in_group(WetGround.GROUP):
		var wet := node as WetGround
		if wet == null or not wet.is_wet():
			continue
		var met: Variant = wet.met_by(from, heading, far)
		if met == null:
			continue
		var whirl := WaterSpiral.send(_host(), met, heading,
			lerpf(SPIRAL_BODIES.x, SPIRAL_BODIES.y, wound) * height, wet.reach + far * 0.5,
			WaterSpiral.PACE * height, spell.duration_at(wound), spell.power_at(wound) * 2.0,
			_traits != null and _traits.acid_water(), venom_strength(), wet.colour)
		wet.dry()
		if whirl != null:
			whirl.spent.connect(_on_whirl_spent)
			whirls += 1
	var said := PackedStringArray()
	if not gust.shoved.is_empty():
		said.append("%d blown back" % gust.shoved.size())
	if whirls > 0:
		said.append("the wet ground whirls up")
	if not said.is_empty():
		notice.emit("Gust — " + ", ".join(said))
	return {"cast": true, "at": from + heading * far * 0.5}


## Which way a fan of water or wind goes: flat along the ground, from the spider to
## what the cross is on — or the way the cross looks, if it is on the sky or at the
## spider's feet.
func fan_heading() -> Vector3:
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


## How far a fan of water or wind wound up to [param wound] reaches, in metres.
func fan_reach(spell: SpiderSpell, wound: float) -> float:
	return spell.size_at(wound) * body_height()


## The ground under the spider, where water and wind leave from.
func feet_ground() -> Vector3:
	return _ground({"point": _spider.global_position, "hit": false}) \
		.get("point", _spider.global_position)


## Whether the spray thrown from [param from] reaches [param point]: in the fan,
## and within its height of the ground either way — it is thrown, so it catches
## fliers too.
func _in_spray(point: Vector3, from: Vector3, heading: Vector3, far: float,
		margin: float) -> bool:
	if not WetGround.in_fan(point, from, heading, far, margin):
		return false
	var rise := point.y - from.y
	return rise >= -far * 0.5 - margin and rise <= far * 0.5 + margin


## Whether any of [param web]'s silk is in the spray.
func _spray_reaches(web: WebStructure, from: Vector3, heading: Vector3, far: float) -> bool:
	var margin := body_height() * 0.2
	for anchor in web.anchors:
		if _in_spray(anchor, from, heading, far, margin):
			return true
	for step in range(1, 7):
		var middle := from + heading * far * float(step) / 6.0 + Vector3.UP * body_height()
		if _in_spray(web.nearest_silk(middle), from, heading, far, margin):
			return true
	return false


func _on_whirl_spent(_whirl: WaterSpiral, held: Array[Prey]) -> void:
	for creature in held:
		if is_instance_valid(creature) and not creature.eaten:
			notice.emit("The %s was held in the whirl" % creature.species)
			return


# --- fire -----------------------------------------------------------------

## A geyser of fire, out of the ground under the cross: under the creature it is on,
## the web or the line, or where it meets the floor. The ground glows where it will
## come up, and a moment later it bursts, throws everything in it up into the air
## and burns it. Silk burns, so what it does to each creature is worth the silk on
## it (see [method Prey.burn]): little to something bare, all of it to something
## wrapped or held in a web. And a creature burned low is an easy catch.
##
## The silk itself goes up too: every web and line in the column burns away, a web
## with the frame it was walked round on, and what a web was holding drops out of it
## burned. A wet web stands, and catches what the geyser throws up into it. See
## [FireGeyser].
##
## No ground under the cross, nothing cast: the wait is not spent on a geyser with
## nowhere to come up.
func _erupt(spell: SpiderSpell, wound: float) -> Dictionary:
	var target := area_target(spell)
	if not target.get("hit", false):
		notice.emit("No ground under the cross for a geyser to come up out of")
		return {"cast": false}
	var at: Vector3 = target.get("point", _spider.global_position)
	var geyser := FireGeyser.erupt(_host(), at, spell.size_at(wound) * body_height(),
		body_height(), spell.power_at(wound), spell.colour)
	if geyser == null:
		return {"cast": false}
	geyser.erupted.connect(_on_erupted)
	return {"cast": true, "at": at}


func _on_erupted(_geyser: FireGeyser, burned: Array[Prey], webs: int, lines: int) -> void:
	var said := PackedStringArray()
	if burned.size() == 1 and is_instance_valid(burned[0]):
		said.append("The %s burns — %d%% of it left" % [burned[0].species,
			roundi(burned[0].health() * 100.0)])
	elif burned.size() > 1:
		said.append("Fire — %d burned" % burned.size())
	if webs > 0:
		said.append("%d web%s burned away" % [webs, "" if webs == 1 else "s"])
	if lines > 0:
		said.append("%d line%s burned away" % [lines, "" if lines == 1 else "s"])
	if not said.is_empty():
		notice.emit(" · ".join(said))


## The ground under what [param target] is on: where a geyser comes up. Looked for
## straight down, through silk and creatures, from just off the surface the cross is
## on — so a point on the floor finds that floor, one on a wall the floor at its
## foot, and one in the air the ground under it. No ground within reach, and it is
## not a hit.
func _ground_under(target: Dictionary) -> Dictionary:
	var point: Vector3 = target.get("point", Vector3.ZERO)
	var off: Vector3 = target.get("normal", Vector3.UP)
	var from := point + off * body_height() * 0.25
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * cast_reach(),
		GameLayers.WORLD, exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"point": point, "normal": Vector3.UP, "prey": target.get("prey"), "hit": false}
	return {"point": hit.get("position", point), "normal": hit.get("normal", Vector3.UP),
		"prey": target.get("prey"), "hit": true}


# --- pullback -------------------------------------------------------------

## Every web the spider has in reach, called back to it at once — the way the
## feathers come back to a blade dancer. Each comes off its anchors and flies
## straight in with what it holds, and wraps what it passes through on the way as
## one shot of that web would; a web lightning left live strikes it too. What the
## webs held lands at the spider's feet, bundled. See [WebPull].
##
## Nothing in reach, nothing cast: the wait is not spent on a call nobody answers.
func _pull_back(spell: SpiderSpell, wound: float) -> Dictionary:
	var webs := pullable_webs()
	if webs.is_empty():
		notice.emit("No web in reach to call back")
		return {"cast": false}
	for web in webs:
		# Off its anchors: the frame it was walked round on comes down as it goes,
		# rather than standing round the place it was.
		for line in web.frame():
			line.demolish()
		var pull := WebPull.call_in(_host(), web, _spider, pull_pace * body_height(),
			spell.size_at(wound) * body_height(), spell.power_at(wound), body_height())
		if pull != null:
			pull.arrived.connect(_on_pull_arrived)
	notice.emit("Pullback — %d web%s coming back" % [webs.size(), "" if webs.size() == 1 else "s"])
	return {"cast": true, "at": _spider.global_position}


## The spider's own webs that a Pullback would call in now: standing, in reach, and
## not already on their way.
func pullable_webs() -> Array[WebNet]:
	var found: Array[WebNet] = []
	if _builder == null or _spider == null:
		return found
	var coming := {}
	for node in get_tree().get_nodes_in_group(WebPull.GROUP):
		var pull := node as WebPull
		if pull != null and is_instance_valid(pull.web):
			coming[pull.web] = true
	for web in _builder.webs():
		if web.is_queued_for_deletion() or coming.has(web):
			continue
		if web.signal_point().distance_to(_spider.global_position) <= cast_reach():
			found.append(web)
	return found


func _on_pull_arrived(pull: WebPull, took: int) -> void:
	var hit := 0
	for creature in pull.hit:
		if is_instance_valid(creature):
			hit += 1
	var said := PackedStringArray()
	if took > 0:
		said.append("%d bundle%s at your feet" % [took, "" if took == 1 else "s"])
	if hit > 0:
		said.append("%d hit on the way" % hit)
	if not said.is_empty():
		notice.emit("A web came back — " + ", ".join(said))


## How hard a dose of the spider's acid water works: fanged, with fangs.
func venom_strength() -> float:
	return Prey.FANG_VENOM if _traits != null and _traits.has_fangs() else 1.0


# --- where a spell goes --------------------------------------------------

## Where the cross puts a spell: on the creature it is over if it is over one —
## the same pick the web makes — else where it meets the world, else as far as
## silk reaches. A dictionary of the point, the surface's normal and the creature,
## and the line, if it is on one.
##
## [param mask] is what the cross can stop on. Silk by default, webs and lines
## alike, because silk is something to aim at; a fan of water or wind looks straight
## through it to the floor.
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
	var found := {"point": from + forward * span, "normal": Vector3.UP, "prey": null,
		"hit": false}
	if not hit.is_empty():
		found = {"point": hit.get("position", from), "normal": hit.get("normal", Vector3.UP),
			"prey": hit.get("collider") as Prey, "hit": true}
	if (mask & GameLayers.WEB_WALK) != 0 and _builder != null:
		# A line is a hair across the view, and nothing to stand on, so no ray stops
		# on one: the same pick the grapple makes decides whether the cross is on one.
		var line := _builder.aimed_line()
		if line != null:
			var pair := Geometry3D.get_closest_points_between_segments(from,
				from + forward * span, line.point_a, line.point_b)
			var on_line: Vector3 = pair[1]
			if from.distance_to(on_line) < from.distance_to(found["point"]):
				return {"point": on_line, "normal": Vector3.UP, "prey": null, "hit": true,
					"line": line}
	return found


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

## The circle a spell is drawn in while it winds up: where it will come from, as
## wide as it will be, in its own colour and with its own star. Lightning's lies on
## what it will strike, and fire's on the ground the geyser will come up out of;
## water's and wind's lie under the spider's feet. Silk has no circle: it is the
## ball of silk, wound up by the builder.
func _update_circle() -> void:
	var spell := current()
	var held := charging and spell != null and spell.form != SpiderSpell.Form.SILK \
		and _spider != null and _view != null
	if not held:
		# Given up, or gone: either way it fades rather than vanishing.
		if _circle != null and is_instance_valid(_circle):
			_circle.release()
		_circle = null
		return
	var place := circle_at(spell, charge)
	if _circle == null or not is_instance_valid(_circle):
		_circle = MagicCircle.draw(_host(), place["where"], place["wide"], spell.colour,
			spell.sigil)
	else:
		_circle.hold(place["where"], place["wide"])


## The circle [param spell] leaves through, wound up to [param wound]: the one held
## through the wind-up, put where the spell went from, or one drawn there and then
## for a cast with no wind-up behind it. Either way it flares as the spell goes.
func _cast_circle(spell: SpiderSpell, wound: float) -> void:
	if spell.form == SpiderSpell.Form.SILK:
		return
	var place := circle_at(spell, wound)
	var circle := _circle if _circle != null and is_instance_valid(_circle) else null
	_circle = null
	if circle == null:
		circle = MagicCircle.draw(_host(), place["where"], place["wide"], spell.colour,
			spell.sigil)
	else:
		circle.hold(place["where"], place["wide"])
	if circle != null:
		circle.release()


## Where [param spell]'s circle goes, wound up to [param wound], and how wide it is:
## a dictionary of the transform it is drawn at and its radius in metres.
func circle_at(spell: SpiderSpell, wound: float) -> Dictionary:
	var height := body_height()
	match spell.form:
		SpiderSpell.Form.LIGHTNING, SpiderSpell.Form.FIRE:
			var target := area_target(spell)
			var up: Vector3 = target.get("normal", Vector3.UP)
			return {"where": MagicCircle.facing(target.get("point", _spider.global_position)
				+ up * height * 0.03, up), "wide": spell.size_at(wound) * height}
	var ground := _ground({"point": _spider.global_position, "hit": false})
	var floor_up: Vector3 = ground.get("normal", Vector3.UP)
	var wide := spell.size_at(wound) * height
	if spell.form == SpiderSpell.Form.PULLBACK:
		# Called to the spider, so drawn round it: the size it is matters less than
		# that it can be seen.
		wide = height * lerpf(1.0, 1.3, wound)
	return {"where": MagicCircle.facing(ground.get("point", _spider.global_position)
		+ floor_up * height * 0.03, floor_up), "wide": wide}


## Where an area spell lands, and which way is up there: lightning comes down on
## what the cross is on, and through open air to whatever is under it; a geyser
## comes up out of the ground under what the cross is on.
func area_target(spell: SpiderSpell) -> Dictionary:
	if spell != null and spell.form == SpiderSpell.Form.LIGHTNING:
		return _ground(aim_target())
	if spell != null and spell.form == SpiderSpell.Form.FIRE:
		return _ground_under(aim_target())
	return aim_target()


## Whether [param spell] lands on an area where you point, rather than being sent
## out along the ground from the spider.
func is_area(spell: SpiderSpell) -> bool:
	return spell.form == SpiderSpell.Form.LIGHTNING or spell.form == SpiderSpell.Form.FIRE


## The fan a spray of water or a gust of wind will cover, laid on the ground in
## front of the spider while it winds up: which way it goes, and how far. Flat from
## the floor under the spider, so on rough ground it is a guide rather than a
## promise.
func _update_fan() -> void:
	var spell := current()
	var shown := charging and spell != null and _view != null and _spider != null \
		and (spell.form == SpiderSpell.Form.DOUSE or spell.form == SpiderSpell.Form.GUST)
	if shown and _fan == null:
		_build_fan()
	if _fan == null:
		return
	_fan.visible = shown
	if not shown:
		return
	var heading := fan_heading()
	var far := maxf(fan_reach(spell, charge), 0.01)
	_fan.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP).scaled(
		Vector3.ONE * far), feet_ground() + Vector3.UP * body_height() * 0.05)
	_fan_paint.albedo_color = Color(spell.colour.r, spell.colour.g, spell.colour.b, 0.28)


## A thin line out to every web a Pullback will call in, while it winds up: what
## is coming back, before it comes.
func _update_pull_lines() -> void:
	var spell := current()
	var shown := charging and spell != null and spell.form == SpiderSpell.Form.PULLBACK \
		and _spider != null
	if shown and _pull_lines == null:
		_pull_mesh = ImmediateMesh.new()
		_pull_paint = StandardMaterial3D.new()
		_pull_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pull_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pull_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pull_paint.vertex_color_use_as_albedo = true
		_pull_lines = MeshInstance3D.new()
		_pull_lines.name = "PullLines"
		_pull_lines.mesh = _pull_mesh
		_pull_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pull_lines.top_level = true
		add_child(_pull_lines)
	if _pull_lines == null:
		return
	_pull_mesh.clear_surfaces()
	_pull_lines.visible = shown
	if not shown:
		return
	_pull_lines.global_transform = Transform3D.IDENTITY
	var tint := Color(spell.colour.r, spell.colour.g, spell.colour.b, 0.55)
	for web in pullable_webs():
		WebGeometry.draw_line_into(_pull_mesh, _pull_paint, _spider.global_position,
			web.signal_point(), body_height() * 0.02, tint)


## How many webs the Pullback is showing lines to: for a check.
func pull_lines_shown() -> int:
	if _pull_lines == null or not _pull_lines.visible:
		return 0
	return _pull_mesh.get_surface_count()


## A fan of unit reach, opening [constant WetGround.SPREAD] either side of ahead.
func _build_fan() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 16
	for i in sides:
		var a := deg_to_rad(lerpf(-WetGround.SPREAD, WetGround.SPREAD, float(i) / float(sides)))
		var b := deg_to_rad(lerpf(-WetGround.SPREAD, WetGround.SPREAD,
			float(i + 1) / float(sides)))
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(Vector3(sin(a), 0.0, -cos(a)))
		tool.add_vertex(Vector3(sin(b), 0.0, -cos(b)))
	_fan_paint = StandardMaterial3D.new()
	_fan_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fan_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fan_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fan = MeshInstance3D.new()
	_fan.name = "SpellFan"
	_fan.mesh = tool.commit()
	_fan.material_override = _fan_paint
	_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fan.top_level = true
	_fan.visible = false
	add_child(_fan)


## How far out the fan reaches while a wind-up is held, in metres: for a check.
## Nought when no fan is showing.
func fan_shown() -> float:
	if _fan == null or not _fan.visible:
		return 0.0
	return _fan.global_basis.get_scale().x


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
			notice.emit("New spell: %s — [%d] to take it in hand"
				% [spell.display_name, key_for(spell)])
	changed.emit()
