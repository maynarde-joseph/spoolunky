class_name SpiderSpells
extends Node3D

## What the spider can cast, which of it is in hand, and how long until each is
## ready again.
##
## Right mouse casts whatever is in hand. Silk is thrown — a ball of it that wraps
## the first fly it touches, on the spot. Every other spell is a kitchen step: cast
## at a prep table, or at the bundle lying on one, it does its one thing to the
## bundle — the water spiral washes it, the gust dries it, lightning tenderises it,
## clay crusts it, fire cooks it and the pullback pulls it — and the rules for what
## can follow what are [Prep]'s. Cast anywhere else it still goes off, and does
## nothing but look like magic.
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
	if book.size() < 2:
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
	if _before == null or _before == current():
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


## Whether the spider is in the moment of a cast, front legs up.
func casting() -> bool:
	return _casting > 0.0


# --- casting ------------------------------------------------------------

## The cast key went down: casts what is in hand.
func begin_cast() -> bool:
	return cast_now(current())


## The cast key came up. Nothing waits on it: a spell goes when the key goes down.
func release_cast() -> bool:
	return false


## Nothing is ever held, so there is nothing to give up; kept for the disc, which
## asks before it opens.
func cancel_cast() -> void:
	pass


## Casts [param spell] where the cross is. Returns whether anything went.
func cast_now(spell: SpiderSpell) -> bool:
	if spell == null or _spider == null or _view == null:
		return false
	if cooling(spell):
		notice.emit("%s — %.1fs" % [spell.display_name, cooldown_left(spell)])
		return false
	var at := Vector3.ZERO
	if spell.form == SpiderSpell.Form.SILK:
		if not _throw_silk(spell):
			return false
		at = aim_target().get("point", _spider.global_position)
	else:
		at = _kitchen(spell)
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
## silk gets there — or straight down the cross. Whatever it hits is wrapped.
func _throw_silk(spell: SpiderSpell) -> bool:
	var from := _view.aim_origin()
	var heading := _view.aim_forward()
	var quarry := shot_target()
	if quarry != null:
		var lead := SilkShot.intercept(from, SilkShot.pace_for(body_height()),
			quarry.global_position, quarry.velocity) - from
		if lead.length_squared() > 0.000001:
			heading = lead.normalized()
	var shot := SilkShot.fire(from, heading, body_height(), exclusions())
	shot.catch_radius = maxf(body_height() * 0.12, 0.05)
	shot.colour = spell.colour.darkened(0.6)
	shot.limit_to(reach)
	shot.landed.connect(_on_silk_landed)
	shot.launch_from(_host(), from)
	return true


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


# --- the kitchen ----------------------------------------------------------

## A kitchen spell: it goes off where the cross is, and if that is a prep table —
## or a bundle on one — it does its step to what is on the table. Returns where it
## went.
func _kitchen(spell: SpiderSpell) -> Vector3:
	var target := aim_target()
	var table := target.get("table") as PrepTable
	var point: Vector3 = target.get("point", _spider.global_position)
	if table != null:
		point = table.hold_point() + Vector3.UP * 0.15
	_show(spell, point, target.get("normal", Vector3.UP))
	var step := Prep.step_for(spell.form)
	if table == null:
		var insect := target.get("insect") as Insect
		if insect != null and insect.is_bundle():
			notice.emit("Put it on a prep table first — the kitchen is where it gets %s"
				% Prep.DONE[step])
		return point
	var reason := table.apply(step)
	if not reason.is_empty():
		notice.emit(reason)
		return point
	var dish := table.bundle.as_dish()
	notice.emit("%s — %s · %d coins" % [String(Prep.DONE[step]).capitalize(), dish.label(),
		dish.value()])
	return point


## The spell going off at [param point]: a magic circle there, and the spell's own
## look.
func _show(spell: SpiderSpell, point: Vector3, normal: Vector3) -> void:
	var host := _host()
	var height := body_height()
	var up := normal if normal.length_squared() > 0.000001 else Vector3.UP
	var circle := MagicCircle.draw(host, MagicCircle.facing(point + up * 0.03, up),
		height * 0.8, spell.colour, spell.sigil)
	if circle != null:
		circle.release()
	match spell.form:
		SpiderSpell.Form.WATER_SPIRAL:
			WaterSpiral.rise(host, point - Vector3.UP * 0.15, height * 0.75, 1.0, spell.colour)
		SpiderSpell.Form.GUST:
			var from := _spider.global_position
			var toward := point - from
			Gust.blow(host, from, toward, Vector2(toward.x, toward.z).length() + height,
				height * 0.8, spell.colour)
		SpiderSpell.Form.LIGHTNING:
			LightningStrike.call_down(host, point, height * 1.2, spell.colour)
		SpiderSpell.Form.FIRE:
			var heading := point - breath_origin()
			FireBreath.breathe(host, breath_origin(), heading, heading.length() + height, 0.9,
				height, spell.colour, self)
		SpiderSpell.Form.PULLBACK:
			SilkPull.pull(host, _spider.global_position + Vector3.UP * height * 0.3, point,
				height * 0.03, spell.colour)
		SpiderSpell.Form.EARTH:
			ClayCrust.raise(host, point, height * 0.6, spell.colour)


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
	return {"point": hit.get("position", from), "normal": hit.get("normal", Vector3.UP),
		"insect": insect, "table": table, "hit": true}


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
