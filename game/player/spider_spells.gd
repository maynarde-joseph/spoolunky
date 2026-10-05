class_name SpiderSpells
extends Node3D

## What the spider can cast, which of it is in hand, and how long until each is
## ready again.
##
## Right mouse casts whatever is in hand: tap it and it goes at once, hold it and it
## winds up — bigger, further, longer — while its magic circle forms, until you let
## go. Silk is thrown: a ball of it wraps the first fly it touches, on the spot.
## Every other spell does something in the world and does its kitchen step to any
## wrapped fly it reaches, wherever that is lying:
##
## * the **water spiral** runs along the ground, holds the first fly it meets, and
##   washes every bundle it passes;
## * the **gust** blows flies down its lane — over fences, into a pen — and dries;
## * **lightning** stuns every fly it strikes, and tenderises;
## * **fire** sends flies fleeing, and cooks;
## * the **pullback** hauls every loose bundle in reach to your feet, and pulls
##   apart what is cooked;
## * **clay** comes up as a pillar that throws what stands on it — or, aimed at a
##   bundle, as a crust round it.
##
## What can follow what in the kitchen is [Prep]'s to say.
##
## The disc on Tab, the wheel and the number keys take a spell in hand: every
## spell is known from the start, in [member SpiderSpell.order]. The grapple is not
## a spell: it is left mouse, always there and waiting for nothing.

## The hand moved, or a wait ran out. The strip redraws off this.
signal changed()

## Something was cast. [param at] is where it went.
signal cast(spell: SpiderSpell, at: Vector3)

## Said out loud to the player. The spider passes these through.
signal notice(text: String)

## Leave empty to load every spell in the spells folder.
@export var book: Array[SpiderSpell] = []

## How far a spell reaches, in metres.
@export var reach := 40.0

## How far off the cross a fly can be, in degrees beyond its own outline, and still
## be what a ball of silk is thrown at.
@export var pick_angle := 2.5

## Which spell is in hand, as an index into [member book].
var selected := 0

## The spell that was in hand before this one, for [method swap_back].
var _before: SpiderSpell = null

## Seconds left before each spell can be cast again, by id, and the wait each one
## started from. Only spells that are waiting are in them.
var _cooling := {}
var _spans := {}

## Seconds left of the moment after a cast, while the front legs are still up.
var _casting := 0.0

## How long winding a spell up to its full size takes, in seconds.
@export var charge_time := 0.9

## True while the cast key is held, and how far through the wind-up, 0 to 1.
var charging := false
var charge := 0.0

## The circle drawn while a spell winds up, until it goes.
var _circle: MagicCircle = null

var _spider: SpiderPlayer
var _view: SpiderCamera


func _ready() -> void:
	if book.is_empty():
		book = Catalogue.spells()


func setup(spider: SpiderPlayer, view: SpiderCamera) -> void:
	_spider = spider
	_view = view


func _process(delta: float) -> void:
	_casting = maxf(0.0, _casting - delta)
	_update_circle()
	if _view != null:
		_view.aim_blend = move_toward(_view.aim_blend, charge if charging else 0.0, delta * 4.0)
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


# --- the hand -----------------------------------------------------------

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


## Every spell, first to last: all of them are in hand to choose from.
func hand() -> Array[SpiderSpell]:
	return book.duplicate()


func in_hand(spell: SpiderSpell) -> bool:
	return book.has(spell)


## Takes the next spell in hand, going [param step] along. False if there is only
## the one.
func cycle(step := 1) -> bool:
	if book.size() < 2 or charging:
		return false
	_hold(book[posmod(maxi(book.find(current()), 0) + step, book.size())])
	changed.emit()
	notice.emit("%s in hand" % current().display_name)
	return true


## Takes the spell in slot [param key] in hand, counted from 1: what the number
## keys do. False if nothing is in the slot, or it is already in hand.
func take(key: int) -> bool:
	var index := key - 1
	if index < 0 or index >= book.size():
		return false
	var spell := book[index]
	if spell == current():
		return false
	cancel_cast()
	_hold(spell)
	changed.emit()
	notice.emit("%s in hand" % spell.display_name)
	return true


## The slot [param spell] is in, counted from 1, or 0 if it is in none.
func key_for(spell: SpiderSpell) -> int:
	return book.find(spell) + 1


## Takes [param spell_id] in hand. False if there is no such spell.
func select(spell_id: String) -> bool:
	var spell := by_id(spell_id)
	if spell == null:
		return false
	_hold(spell)
	changed.emit()
	return true


## Takes back in hand the spell that was in hand before this one: a quick swap
## between two.
func swap_back() -> bool:
	if _before == null or _before == current() or charging:
		return false
	var back := _before
	_hold(back)
	changed.emit()
	notice.emit("%s in hand" % back.display_name)
	return true


func _hold(spell: SpiderSpell) -> void:
	var was := current()
	selected = book.find(spell)
	if was != null and was != spell:
		_before = was


# --- waiting ------------------------------------------------------------

func cooling(spell: SpiderSpell) -> bool:
	return spell != null and _cooling.has(spell.id)


func cooldown_left(spell: SpiderSpell) -> float:
	return float(_cooling.get(spell.id, 0.0)) if spell != null else 0.0


## 0 to 1, for the strip. 1 means ready.
func cooldown_progress(spell: SpiderSpell) -> float:
	if spell == null:
		return 1.0
	var span: float = _spans.get(spell.id, 0.0)
	if span <= 0.0:
		return 1.0
	return clampf(1.0 - cooldown_left(spell) / span, 0.0, 1.0)


## Everything ready at once, for a check that casts twice and is not about the
## wait.
func forget_waits() -> void:
	_cooling.clear()
	_spans.clear()
	changed.emit()


## Whether the spider is winding a spell up or in the moment of a cast, front legs
## up.
func casting() -> bool:
	return charging or _casting > 0.0


# --- casting ------------------------------------------------------------

## The cast key went down: the spell in hand starts winding up.
func begin_cast() -> bool:
	var spell := current()
	if spell == null or charging:
		return false
	if cooling(spell):
		notice.emit("%s — %.1fs" % [spell.display_name, cooldown_left(spell)])
		return false
	charging = true
	charge = 0.0
	changed.emit()
	return true


## Held down: winds it up.
func track(delta: float) -> void:
	if charging:
		charge = clampf(charge + delta / maxf(charge_time, 0.05), 0.0, 1.0)


## Let go: casts whatever the wind-up reached.
func release_cast() -> bool:
	if not charging:
		return false
	charging = false
	var wound := charge
	charge = 0.0
	var went := cast_now(current(), wound)
	changed.emit()
	return went


## Gives up a wind-up without casting.
func cancel_cast() -> void:
	if charging:
		charging = false
		charge = 0.0
		changed.emit()


## Casts [param spell] where the cross is, wound up to [param wound] from 0 for a
## tap to 1 for a full wind-up. Returns whether anything went. It is what letting
## go of the key does, and what a check calls to cast without a key.
func cast_now(spell: SpiderSpell, wound := 0.0) -> bool:
	if spell == null or _spider == null or _view == null:
		return false
	if cooling(spell):
		notice.emit("%s — %.1fs" % [spell.display_name, cooldown_left(spell)])
		return false
	wound = clampf(wound, 0.0, 1.0)
	var at := _spider.global_position
	match spell.form:
		SpiderSpell.Form.SILK:
			_throw_silk(spell, wound)
			at = aim_target().get("point", at)
		SpiderSpell.Form.WATER_SPIRAL:
			at = _spiral(spell, wound)
		SpiderSpell.Form.GUST:
			at = _gust(spell, wound)
		SpiderSpell.Form.LIGHTNING:
			at = _lightning(spell, wound)
		SpiderSpell.Form.FIRE:
			at = _fire(spell, wound)
		SpiderSpell.Form.PULLBACK:
			at = _pullback(spell, wound)
		SpiderSpell.Form.EARTH:
			at = _clay(spell, wound)
	_release_circle(spell, wound)
	_start_wait(spell)
	_casting = 0.35
	cast.emit(spell, at)
	changed.emit()
	return true


func _start_wait(spell: SpiderSpell) -> void:
	if spell.cooldown > 0.0:
		_cooling[spell.id] = spell.cooldown
		_spans[spell.id] = spell.cooldown


# --- silk ---------------------------------------------------------------

## A ball of silk, thrown at the fly under the cross — where it will be when the
## silk gets there — or straight down the cross. Wound up, the ball is bigger, and
## easier to land. Whatever it hits is wrapped.
func _throw_silk(spell: SpiderSpell, wound: float) -> void:
	var from := _view.aim_origin()
	var heading := _view.aim_forward()
	var quarry := shot_target()
	if quarry != null:
		var lead := SilkShot.intercept(from, SilkShot.pace_for(body_height()),
			quarry.global_position, quarry.velocity) - from
		if lead.length_squared() > 0.000001:
			heading = lead.normalized()
	var shot := SilkShot.fire(from, heading, body_height(), exclusions())
	shot.catch_radius = spell.size_at(wound)
	shot.colour = spell.colour.darkened(0.6)
	shot.limit_to(reach)
	shot.landed.connect(_on_silk_landed)
	shot.launch_from(_host(), from)


func _on_silk_landed(_at: Vector3, _normal: Vector3, insect: Insect, _heading: Vector3) -> void:
	if insect == null or not is_instance_valid(insect):
		return
	if insect.wrap():
		notice.emit("Wrapped a %s — left-click the bundle to put a line on it" % insect.describe())


## The fly the next ball of silk will be thrown at, or null: the one nearest the
## cross whose outline comes within [member pick_angle] of it, in reach and in plain
## sight. A fly is small and does not keep still, and a hairline ray will not find
## one.
func shot_target() -> Insect:
	if _view == null or _view.camera == null or _spider == null:
		return null
	var eye := _view.camera.global_position
	var look := -_view.camera.global_basis.z.normalized()
	var from := _view.aim_origin()
	var best: Insect = null
	var best_slack := INF
	for node in get_tree().get_nodes_in_group(Insect.GROUP):
		var insect := node as Insect
		if insect == null or not is_instance_valid(insect) or insect.is_bundle():
			continue
		var at := insect.global_position
		if from.distance_to(at) > reach:
			continue
		var sight := at - eye
		var distance := sight.length()
		if distance < 0.001:
			continue
		var slack := rad_to_deg(look.angle_to(sight)) \
			- rad_to_deg(atan2(insect.radius() * Insect.HITBOX_SCALE, distance))
		if slack > pick_angle or slack >= best_slack:
			continue
		if not _in_sight(from, at):
			continue
		best_slack = slack
		best = insect
	return best


func _in_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, GameLayers.WORLD, exclusions())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- what each spell does -------------------------------------------------

## A spiral of water and wind along the ground the way the cross points: it holds
## the first fly it meets and washes every bundle it passes.
func _spiral(spell: SpiderSpell, wound: float) -> Vector3:
	var from := feet_ground()
	var heading := lane_heading()
	var whirl := WaterSpiral.send(_host(), from, heading, spell.size_at(wound),
		spell.travel_at(wound), 7.0, spell.duration_at(wound), spell.colour)
	if whirl != null:
		whirl.touched.connect(func(_whirl: WaterSpiral, insect: Insect) -> void:
			if insect.is_bundle():
				_prep(insect, Prep.Step.WASH)
			else:
				notice.emit("A fly is held in the water spiral"))
	return from + heading * spell.travel_at(wound) * 0.5


## Wind down a lane: every fly in it is blown on down it, and every bundle in it
## dried.
func _gust(spell: SpiderSpell, wound: float) -> Vector3:
	var from := feet_ground()
	var heading := lane_heading()
	var far := spell.travel_at(wound)
	var wide := spell.size_at(wound)
	Gust.blow(_host(), from + Vector3.UP * body_height() * 0.3, heading, far, wide, spell.colour)
	var push := lerpf(7.0, 10.0, wound)
	var blown := 0
	for insect in _insects():
		if not Gust.in_lane(insect.global_position, from, heading, far, wide, insect.radius()) \
				or insect.global_position.y - from.y > far * 0.5:
			continue
		if insect.is_bundle():
			_prep(insect, Prep.Step.DRY)
		else:
			insect.shove(heading * push + Vector3.UP * push * 0.2, spell.duration_at(wound))
			blown += 1
	if blown > 0:
		notice.emit("Gust — %d fl%s blown along" % [blown, "y" if blown == 1 else "ies"])
	return from + heading * far * 0.5


## Lightning where the cross is: every fly it strikes is stunned, every bundle
## tenderised.
func _lightning(spell: SpiderSpell, wound: float) -> Vector3:
	var target := area_target()
	var at: Vector3 = target["point"]
	var wide := spell.size_at(wound)
	LightningStrike.call_down(_host(), at, wide, spell.colour)
	var top := at + Vector3.UP * maxf(wide * LightningStrike.FALL, LightningStrike.FALL_LEAST)
	var sky := MagicCircle.draw(_host(), MagicCircle.facing(top, Vector3.DOWN), wide * 0.8,
		spell.colour, spell.sigil)
	if sky != null:
		sky.release()
	var stunned := 0
	for insect in _insects():
		var off := insect.global_position - at
		if Vector2(off.x, off.z).length() > wide + insect.radius() or off.y > 3.0 or off.y < -1.0:
			continue
		if insect.is_bundle():
			_prep(insect, Prep.Step.TENDERISE)
		else:
			insect.stun(spell.duration_at(wound))
			stunned += 1
	if stunned > 0:
		notice.emit("Lightning — %d fl%s stunned" % [stunned, "y" if stunned == 1 else "ies"])
	return at


## Fire out of the jaws along the cross, swept while it lasts: flies flee it, and
## every bundle it reaches is cooked.
func _fire(spell: SpiderSpell, wound: float) -> Vector3:
	var breath := FireBreath.breathe(_host(), breath_origin(), breath_heading(), spell.size_at(wound),
		spell.duration_at(wound), body_height(), spell.colour, self)
	if breath == null:
		return breath_origin()
	breath.touched.connect(func(_breath: FireBreath, insect: Insect) -> void:
		if insect.is_bundle():
			_prep(insect, Prep.Step.COOK)
		else:
			insect.scare(breath_origin()))
	return breath_origin() + breath_heading() * breath.reach


## Silk to every bundle in reach: a loose one is hauled to the spider's feet, and
## one that is cooked is pulled apart.
func _pullback(spell: SpiderSpell, wound: float) -> Vector3:
	var reach_of := spell.size_at(wound)
	var feet := _spider.global_position
	var hauled := 0
	for insect in _insects():
		if not insect.is_bundle() or insect.global_position.distance_to(feet) > reach_of:
			continue
		SilkPull.pull(_host(), feet + Vector3.UP * body_height() * 0.3, insect.global_position,
			body_height() * 0.03, spell.colour)
		if insect.steps.has(Prep.Step.COOK):
			_prep(insect, Prep.Step.PULL)
		elif insect.table == null and insect.global_position.distance_to(feet) > body_height() * 2.0:
			insect.fling_to(feet)
			hauled += 1
	if hauled > 0:
		notice.emit("Pullback — %d bundle%s coming to you" % [hauled, "" if hauled == 1 else "s"])
	return feet


## Clay where the cross is: a crust round every bundle near it — or, with none
## there, a pillar out of the ground.
func _clay(spell: SpiderSpell, wound: float) -> Vector3:
	var target := area_target()
	var at: Vector3 = target["point"]
	var crusted := false
	for insect in _insects():
		if insect.is_bundle() and insect.global_position.distance_to(at) <= CRUST_REACH:
			ClayCrust.raise(_host(), insect.global_position, insect.radius() * 2.0, spell.colour)
			_prep(insect, Prep.Step.CRUST)
			crusted = true
	if not crusted:
		var ground := _ground({"point": at, "hit": false}) if target.get("table") != null else target
		ClayPillar.raise(_host(), ground["point"], PILLAR_WIDE, spell.size_at(wound),
			spell.duration_at(wound), _spider)
	return at


## How near the cross a bundle has to be for clay to crust it, in metres, and how
## wide a pillar is, from its middle to a face.
const CRUST_REACH := 1.2
const PILLAR_WIDE := 0.45


## Does [param step] to [param bundle] and says what came of it: the dish it is now,
## or why it could not be done.
func _prep(bundle: Insect, step: int) -> void:
	var reason := bundle.apply(step)
	if not reason.is_empty():
		notice.emit(reason)
		return
	var dish := bundle.as_dish()
	notice.emit("%s — %s · %d coins" % [String(Prep.DONE[step]).capitalize(), dish.label(), dish.value()])


func _insects() -> Array[Insect]:
	var found: Array[Insect] = []
	for node in get_tree().get_nodes_in_group(Insect.GROUP):
		var insect := node as Insect
		if insect != null and not insect.is_queued_for_deletion():
			found.append(insect)
	return found


# --- where a spell goes ----------------------------------------------------

## Where the cross puts a spell: what it meets — a fly, a prep table, the ground —
## or as far as a spell reaches. A dictionary of the point, the surface's normal,
## the insect if it is on one, the prep table if it is on one or on a bundle lying
## on one, and whether it hit anything.
func aim_target() -> Dictionary:
	var from := _view.aim_origin()
	var forward := _view.aim_forward()
	var query := PhysicsRayQueryParameters3D.create(from, from + forward * reach,
		GameLayers.WORLD | GameLayers.INSECT, exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"point": from + forward * reach, "normal": Vector3.UP, "insect": null,
			"table": null, "hit": false}
	var insect := hit.get("collider") as Insect
	var table := _table_under(hit.get("collider"))
	if insect != null and insect.table is PrepTable:
		table = insect.table as PrepTable
	var point: Vector3 = hit.get("position", from)
	if table != null and table.bundle != null:
		point = table.bundle.global_position
	elif insect != null:
		point = insect.global_position
	return {"point": point, "normal": hit.get("normal", Vector3.UP), "insect": insect,
		"table": table, "hit": true}


## Where an area spell lands: what the cross is on — and through open air, the
## ground under it.
func area_target() -> Dictionary:
	return _ground(aim_target())


func _ground(target: Dictionary) -> Dictionary:
	if target.get("hit", false):
		return target
	var point: Vector3 = target.get("point", Vector3.ZERO)
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * reach,
		GameLayers.WORLD, exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return target
	return {"point": hit.get("position", point), "normal": hit.get("normal", Vector3.UP),
		"insect": null, "table": null, "hit": true}


## The prep table [param collider] is, or is part of.
func _table_under(collider: Variant) -> PrepTable:
	var node := collider as Node
	while node != null:
		if node is PrepTable:
			return node as PrepTable
		node = node.get_parent()
	return null


## The prep table the cross is on, or the one under the bundle the cross is on.
func aimed_table() -> PrepTable:
	return aim_target().get("table") as PrepTable


## Which way a lane spell goes: flat along the ground, from the spider to what the
## cross is on — or the way the cross looks.
func lane_heading() -> Vector3:
	var toward: Vector3 = aim_target().get("point", Vector3.ZERO) - _spider.global_position
	toward.y = 0.0
	if toward.length() < body_height():
		toward = _view.aim_forward()
		toward.y = 0.0
	return toward.normalized() if toward.length_squared() > 0.000001 else Vector3.FORWARD


## The ground under the spider, where a lane spell leaves from.
func feet_ground() -> Vector3:
	return _ground({"point": _spider.global_position, "hit": false}).get("point", _spider.global_position)


## Where a breath of fire comes from: the spider's jaws, where its aim starts.
func breath_origin() -> Vector3:
	return _view.aim_origin()


## Which way a breath of fire goes: from the jaws to whatever the cross is on.
func breath_heading() -> Vector3:
	var target := aim_target()
	var toward: Vector3 = target.get("point", Vector3.ZERO) - breath_origin()
	if target.get("hit", false) and toward.length_squared() > 0.000001:
		return toward.normalized()
	return _view.aim_forward()


## What a spell's rays pass through: the spider itself.
func exclusions() -> Array[RID]:
	var list: Array[RID] = []
	if _spider != null:
		list.append(_spider.get_rid())
	return list


func body_height() -> float:
	return _spider.body_height if _spider != null else 0.7


## Where the level keeps what spells leave behind.
func _host() -> Node:
	var host := get_tree().current_scene
	if host == null and _spider != null:
		host = _spider.get_parent()
	return host


# --- the circle -----------------------------------------------------------

## The circle a spell is drawn in while it winds up: where it will come from, as
## wide as it will be, in its own colour and with its own star. Silk has none: it
## is a ball held up in the front legs.
func _update_circle() -> void:
	var spell := current()
	var held := charging and spell != null and spell.form != SpiderSpell.Form.SILK \
		and _spider != null and _view != null
	if not held:
		if _circle != null and is_instance_valid(_circle):
			_circle.release()
		_circle = null
		return
	var place := circle_at(spell, charge)
	if _circle == null or not is_instance_valid(_circle):
		_circle = MagicCircle.draw(_host(), place["where"], place["wide"], spell.colour, spell.sigil)
	else:
		_circle.hold(place["where"], place["wide"])


## The circle the spell leaves through flares as it goes.
func _release_circle(spell: SpiderSpell, wound: float) -> void:
	if spell.form == SpiderSpell.Form.SILK:
		return
	var circle := _circle if _circle != null and is_instance_valid(_circle) else null
	_circle = null
	if circle == null:
		var place := circle_at(spell, wound)
		circle = MagicCircle.draw(_host(), place["where"], place["wide"], spell.colour, spell.sigil)
	if circle != null:
		circle.release()


## Where [param spell]'s circle goes, wound up to [param wound], and how wide it is:
## fire's in front of the jaws, facing the way it will go; lightning's and clay's on
## what they will strike; the spiral's, the gust's and the pullback's under the
## spider's feet, as wide as they will reach.
func circle_at(spell: SpiderSpell, wound: float) -> Dictionary:
	var height := body_height()
	match spell.form:
		SpiderSpell.Form.FIRE:
			var heading := breath_heading()
			return {"where": MagicCircle.facing(breath_origin() + heading * height * 0.75, heading),
				"wide": height * lerpf(0.28, 0.5, wound)}
		SpiderSpell.Form.LIGHTNING, SpiderSpell.Form.EARTH:
			var target := area_target()
			var up: Vector3 = target.get("normal", Vector3.UP)
			var wide := spell.size_at(wound) if spell.form == SpiderSpell.Form.LIGHTNING \
				else PILLAR_WIDE * 1.6
			return {"where": MagicCircle.facing(target["point"] + up * 0.03, up), "wide": wide}
	var feet := feet_ground()
	var wide := spell.size_at(wound)
	if spell.form == SpiderSpell.Form.PULLBACK:
		wide = spell.size_at(wound)
	return {"where": MagicCircle.facing(feet + Vector3.UP * 0.03, Vector3.UP), "wide": wide}
