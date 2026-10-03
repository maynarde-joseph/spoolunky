class_name SpiderSpells
extends Node3D

## What the spider can cast, which of it is in hand, and how long until each is
## ready again.
##
## Right mouse casts whatever is in hand: a tap casts it at once, and holding
## winds it up — bigger, longer — until you let go. The number keys take a spell in
## hand — silk on 1, always, and the loadout on 2 to 6 — and the wheel moves the
## hand along them. Silk is still thrown by the [WebBuilder] exactly as it always
## was; all this decides is that silk is what the key means right now. Every other
## spell is cast from here.
##
## The limit is the web's: a wait, never a bill (see §5 of the design). Each
## spell waits on its own, so casting one never costs you another, and the tree can
## shorten the waits — see [method wait_for].
##
## Which spells the spider has, which are on its keys, and how far each has come
## are the [SpellTree]'s: a spell is learned there, put in the loadout there, and
## raised a tier there, and the interactions it learns are what this asks
## [method SpellTree.knows] before doing them.

## Something opened, the hand moved, or a wait ran out. The strip redraws off this.
signal changed()

## A spell was learned. Carries it, for the message.
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

## How wide a pillar of clay is, from its middle to the middle of a face, in body
## heights, and how far out the circle round its foot goes, in those half-widths:
## out past its corners, which stand nearly half as far out again.
const PILLAR_BODIES := 0.6
const PILLAR_RING := 1.6

## How far in front of the spider fire's circle hangs, and water's, in body heights:
## on the line the breath or the spit will take, so it leaves through the middle of
## it.
@export var circle_ahead := 0.75

## How wide that circle is, in body heights, from a tap to a full wind-up.
@export var circle_bodies := Vector2(0.28, 0.5)

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

var _spider: SpiderPlayer
var _growth: SpiderGrowth
var _traits: SpiderTraits
var _view: SpiderCamera
var _builder: WebBuilder
var _tree: SpellTree
## The circle drawn while a spell winds up, until it goes.
var _circle: MagicCircle = null

## Lines out to the webs a Pullback will call in, while it winds up.
var _pull_lines: MeshInstance3D
var _pull_mesh: ImmediateMesh
var _pull_paint: StandardMaterial3D
## Where a spit of water will come down, and the strip a gust of wind will blow
## down, while they wind up.
var _splash: MeshInstance3D
var _splash_paint: StandardMaterial3D
var _path: MeshInstance3D
var _path_paint: StandardMaterial3D


## Every spell and interaction known and the loadout's limit lifted: the tree's
## switch, reached from here. See [member SpellTree.open_all] and
## [member SpiderPlayer.all_spells_open].
var open_all: bool:
	get:
		return _tree != null and _tree.open_all
	set(value):
		if _tree != null:
			_tree.open_all = value


func _ready() -> void:
	if book.is_empty():
		book = SpellLibrary.load_spells()


func setup(spider: SpiderPlayer, growth: SpiderGrowth, traits: SpiderTraits,
		view: SpiderCamera, builder: WebBuilder, tree: SpellTree = null) -> void:
	_spider = spider
	_growth = growth
	_traits = traits
	_view = view
	_builder = builder
	_tree = tree
	if _tree != null:
		_tree.changed.connect(_read_the_book)
		_tree.learned.connect(_on_learned)
	_read_the_book()


## The spider's tree: what it knows, and what is on its keys.
func tree() -> SpellTree:
	return _tree


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
	_update_splash()
	_update_path()
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


## Whether [param spell] can be cast by this spider: silk always, anything else
## once the tree has it learned.
func is_open(spell: SpiderSpell) -> bool:
	if spell == null:
		return false
	if spell.form == SpiderSpell.Form.SILK:
		return true
	return _tree != null and _tree.knows_spell(spell.id)


## Every spell this spider can cast, in order.
func open_spells() -> Array[SpiderSpell]:
	var found: Array[SpiderSpell] = []
	for spell in book:
		if is_open(spell):
			found.append(spell)
	return found


## What the number keys hold, 1 first: silk, then the loadout. With everything
## open, every spell in the book, in its order.
func hand() -> Array[SpiderSpell]:
	var found: Array[SpiderSpell] = []
	for spell in book:
		if spell.form == SpiderSpell.Form.SILK:
			found.append(spell)
			break
	if _tree == null:
		return found
	if _tree.open_all:
		for spell in book:
			if spell.form != SpiderSpell.Form.SILK:
				found.append(spell)
		return found
	for spell_id in _tree.loadout:
		var spell := by_id(spell_id)
		if spell != null and is_open(spell) and not found.has(spell):
			found.append(spell)
	return found


## Whether [param spell] is on a number key.
func in_hand(spell: SpiderSpell) -> bool:
	return hand().has(spell)


## What learns a spell not learned yet: its skill, and the row it is in.
func opens_with(spell: SpiderSpell) -> String:
	if spell == null:
		return ""
	if _tree != null:
		for skill in _tree.skills:
			if skill.kind == SpellSkill.Kind.SPELL and skill.spell == spell.id:
				return "%s, %s" % [skill.display_name, _tree.rank_name(skill.row)]
	return "the tree"


## Takes the next spell on the keys in hand, going [param step] along them. False
## — and nothing moves — if nothing else is on them, or while something is being
## wound up: the hand does not change what it is holding mid-throw.
func cycle(step := 1) -> bool:
	if book.is_empty() or charging or (_builder != null and _builder.aiming):
		return false
	var keys := hand()
	if keys.size() < 2:
		return false
	var at := maxi(keys.find(current()), 0)
	selected = book.find(keys[posmod(at + step, keys.size())])
	changed.emit()
	notice.emit("%s in hand" % current().display_name)
	return true


## Takes the spell on number key [param key] in hand: silk on 1, the loadout on 2
## onward. A wind-up under way is given up — the key is the player saying what they
## want in hand now, and a key that waited on the throw it interrupted would feel
## dead. False if nothing is on the key, or it is already in hand.
func take(key: int) -> bool:
	var keys := hand()
	var index := key - 1
	if index < 0:
		return false
	if index >= keys.size():
		notice.emit("Nothing on [%d] — put a spell there in the tree [E]" % key)
		return false
	var spell := keys[index]
	if spell == current():
		return false
	cancel_cast()
	selected = book.find(spell)
	changed.emit()
	notice.emit("%s in hand" % spell.display_name)
	return true


## The number key that takes [param spell] in hand, or 0 if it is on none.
func key_for(spell: SpiderSpell) -> int:
	return hand().find(spell) + 1


## Takes [param spell_id] in hand. False if it is not on a key.
func select(spell_id: String) -> bool:
	for spell in hand():
		if spell.id == spell_id:
			selected = book.find(spell)
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


## How long [param spell] makes you wait, after what the spider has learned and
## what it has become.
func wait_for(spell: SpiderSpell) -> float:
	if spell == null:
		return 0.0
	var scale := _traits.cast_scale() if _traits != null else 1.0
	if _tree != null:
		scale *= _tree.wait_scale(spell.id)
	return spell.cooldown * scale


## How far [param spell] reaches at [param wound], in body heights, after its
## tier: [method SpiderSpell.size_at] with what the tree has made of it.
func size_of(spell: SpiderSpell, wound: float) -> float:
	return spell.size_at(wound) * (_tree.tier(spell.id).x if _tree != null else 1.0)


## How hard [param spell] hits at [param wound], after its tier.
func power_of(spell: SpiderSpell, wound: float) -> float:
	return spell.power_at(wound) * (_tree.tier(spell.id).y if _tree != null else 1.0)


## How long what [param spell] leaves lasts at [param wound], after its tier.
func duration_of(spell: SpiderSpell, wound: float) -> float:
	return spell.duration_at(wound) * (_tree.tier(spell.id).z if _tree != null else 1.0)


## Whether the spider has learned the interaction called [param what]. See
## [method SpellTree.knows].
func knows(what: StringName) -> bool:
	return _tree != null and _tree.knows(what)


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
			return _breathe(spell, wound)
		SpiderSpell.Form.PULLBACK:
			return _pull_back(spell, wound)
		SpiderSpell.Form.EARTH:
			return _raise(spell, wound)
	push_warning("%s has a form nothing casts yet" % spell.display_name)
	return {"cast": false}


# --- lightning, water and wind --------------------------------------------

## Lightning comes down on what the cross is on — a creature, a web, the floor.
## Aimed at open air, it comes down through it to whatever is underneath: whatever
## of [param mask] is there.
func _ground(target: Dictionary, mask := GameLayers.WORLD | GameLayers.WEB_WALK) -> Dictionary:
	if target.get("hit", false):
		return target
	var point: Vector3 = target.get("point", Vector3.ZERO)
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * cast_reach(),
		mask, exclusions())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return target
	return {"point": hit.get("position", point), "normal": hit.get("normal", Vector3.UP),
		"prey": null, "hit": true}


## Lightning, called down where you point: it stuns and hurts. See [LightningStrike].
func _strike(spell: SpiderSpell, wound: float) -> Dictionary:
	var target := area_target(spell)
	var at: Vector3 = target.get("point", _spider.global_position)
	var stun := duration_of(spell, wound) * (_traits.stun_scale() if _traits != null else 1.0)
	var jumps := _traits.arc_bonus() if _traits != null else 0
	var radius := size_of(spell, wound) * body_height()
	var strike := LightningStrike.call_down(_host(), at, radius, stun, jumps,
		body_height() * 0.6, spell.colour, power_of(spell, wound), knows(&"live_silk"),
		knows(&"live_lines"))
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
	if not strike.charged.is_empty() and strike.live:
		said.append("%d web%s live for %ds" % [strike.charged.size(),
			"" if strike.charged.size() == 1 else "s", roundi(stun * LightningStrike.LIVE_FOR)])
	elif not strike.charged.is_empty():
		said.append("through %d web%s" % [strike.charged.size(),
			"" if strike.charged.size() == 1 else "s"])
	if not said.is_empty():
		notice.emit("Lightning — " + ", ".join(said))
	return {"cast": true, "at": at}


## Water spat at the cross: a spray of drops out of the spider's jaws, arcing down
## round where it points — more of them, leaving bigger puddles, the longer it was
## wound up. What a drop hits is soaked and stung, and a flier comes down; where
## drops land on the ground they leave puddles, and whatever stands in one stays
## soaked. With Wet Silk learned, every web and line a drop goes through is soaked
## too, and a wet web does not burn — with Sodden Silk, it holds harder as well.
## See [WaterSpit], [WetGround] and [WetSilk].
func _douse(spell: SpiderSpell, wound: float) -> Dictionary:
	var at := spit_target()
	var mouthful := WaterSpit.spit(_host(), breath_origin(), at, spit_drops(wound),
		body_height(), puddle_wide(spell, wound), duration_of(spell, wound),
		power_of(spell, wound), spell.colour, knows(&"wet_silk"), knows(&"sodden_silk"))
	if mouthful == null:
		return {"cast": false}
	mouthful.landed.connect(_on_spit_landed)
	return {"cast": true, "at": at}


## Where a spit of water comes down: on whatever the cross is on — a creature, a
## line, a web, the world — by the same pick everything else aims with. A creature
## is spat at where it will be when the first drop comes down, as silk is thrown at
## where it is going: a lob takes a moment. On open sky, as far as silk reaches
## along the cross, and it falls on from there.
func spit_target() -> Vector3:
	var target := aim_target()
	var point: Vector3 = target.get("point", _spider.global_position)
	var quarry := target.get("prey") as Prey
	if quarry != null and is_instance_valid(quarry):
		point += quarry.velocity * WaterSpit.flight_time(breath_origin(), point, body_height())
	return point


## Which way a spit of water leaves the jaws: tipped up from the line to where it
## will come down, by as much as the arc it is spat on needs.
func spit_heading() -> Vector3:
	var going := WaterSpit.launch(breath_origin(), spit_target(), body_height())
	return going.normalized() if going.length_squared() > 0.000001 else _view.aim_forward()


## How many drops a spit wound up to [param wound] throws.
func spit_drops(wound: float) -> int:
	return roundi(lerpf(WaterSpit.DROPS.x, WaterSpit.DROPS.y, clampf(wound, 0.0, 1.0)))


## How wide a puddle each drop of a spit wound up to [param wound] leaves, from the
## middle to the rim, in metres.
func puddle_wide(spell: SpiderSpell, wound: float) -> float:
	return size_of(spell, wound) * body_height()


## How far from the cross a spit wound up to [param wound] wets, puddles and all,
## in metres: where its drops scatter to, and a puddle's width past that.
func splash_wide(spell: SpiderSpell, wound: float) -> float:
	return puddle_wide(spell, wound) * (WaterSpit.SCATTER + 1.0)


func _on_spit_landed(spit: WaterSpit, soaked: Array[Prey], webs: int, _puddles: int) -> void:
	var said := PackedStringArray()
	if not soaked.is_empty():
		said.append("%d soaked" % soaked.size())
	if webs > 0:
		said.append("%d web%s wet — it will not burn" % [webs, "" if webs == 1 else "s"])
	if spit != null and not spit.slumped.is_empty():
		said.append("the clay slumps into mud")
	if not said.is_empty():
		notice.emit("Douse — " + ", ".join(said))


## Wind blown down a lane in front of the spider, as far as the wind-up sends it:
## everything loose in it is shoved on down the lane and stung — into a web past the
## end of it, if one is there, which catches it — and a boss only takes the sting. A
## web in the lane is blown down it, wrapping what it passes, and what it held comes
## down bundled where the wind drops it. With Waterspout learned, over a puddle Douse
## left it lifts the water into a whirl that runs on down the lane, and holds the
## first thing it reaches. See [Gust] and [WaterSpiral].
func _blow(spell: SpiderSpell, wound: float) -> Dictionary:
	var from := feet_ground()
	var heading := lane_heading()
	var far := lane_reach(spell, wound)
	var wide := lane_wide(spell, wound)
	var height := body_height()
	var push := lerpf(Gust.PUSH.x, Gust.PUSH.y, wound) * height \
		* (_tree.tier(spell.id).y if _tree != null else 1.0)
	var gust := Gust.blow(_host(), from + Vector3.UP * height * 0.3, heading, far, wide, push,
		power_of(spell, wound), spell.colour, height, _spider)
	if gust == null:
		return {"cast": false}
	# Only with Waterspout learned does wind take the water up at all.
	var whirl := _lift_water(spell, wound, from, heading, far, wide) \
		if knows(&"waterspout") else null
	var said := PackedStringArray()
	if not gust.shoved.is_empty():
		said.append("%d blown back" % gust.shoved.size())
	if not gust.blown.is_empty():
		said.append("%d web%s blown away" % [gust.blown.size(),
			"" if gust.blown.size() == 1 else "s"])
	if whirl != null:
		said.append("the water whirls up")
	if not said.is_empty():
		notice.emit("Gust — " + ", ".join(said))
	return {"cast": true, "at": from + heading * far * 0.5}


## The water a gust blown from [param from] along [param heading], [param far]
## metres and [param wide] either side, takes up: one whirl, off the puddle nearest
## the spider, running on to the end of the lane and half as far again — and every
## puddle in the lane dries, because the wind took all of it. Null if the lane
## crosses no puddle.
func _lift_water(spell: SpiderSpell, wound: float, from: Vector3, heading: Vector3,
		far: float, wide: float) -> WaterSpiral:
	var met: Array[WetGround] = []
	var nearest: WetGround = null
	var nearest_out := INF
	for node in get_tree().get_nodes_in_group(WetGround.GROUP):
		var wet := node as WetGround
		if wet == null or wet.is_queued_for_deletion() or not wet.met_by(from, heading, far, wide):
			continue
		met.append(wet)
		var out := (wet.centre - from).dot(heading)
		if out < nearest_out:
			nearest_out = out
			nearest = wet
	if nearest == null:
		return null
	var height := body_height()
	var whirl := WaterSpiral.send(_host(), nearest.centre, heading,
		lerpf(SPIRAL_BODIES.x, SPIRAL_BODIES.y, wound) * height,
		maxf(far - nearest_out, 0.0) + far * 0.5, WaterSpiral.PACE * height,
		duration_of(spell, wound), power_of(spell, wound) * 2.0,
		_traits != null and _traits.acid_water(), venom_strength(), nearest.colour)
	for wet in met:
		wet.dry()
	if whirl != null:
		whirl.spent.connect(_on_whirl_spent)
	return whirl


## Which way a gust of wind goes: flat along the ground, from the spider to what
## the cross is on — or the way the cross looks, if it is on the sky or at the
## spider's feet.
func lane_heading() -> Vector3:
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


## How far a lane of wind wound up to [param wound] blows, in metres: its share of
## silk's reach — the further the longer it was wound up — after its tier.
func lane_reach(spell: SpiderSpell, wound: float) -> float:
	return spell.travel_at(wound) * cast_reach() \
		* (_tree.tier(spell.id).x if _tree != null else 1.0)


## How wide a lane of wind is either side of its middle, in metres.
func lane_wide(spell: SpiderSpell, wound: float) -> float:
	return spell.size_at(wound) * body_height()


## The ground under the spider, where wind leaves from.
func feet_ground() -> Vector3:
	return _ground({"point": _spider.global_position, "hit": false}) \
		.get("point", _spider.global_position)


func _on_whirl_spent(_whirl: WaterSpiral, held: Array[Prey]) -> void:
	for creature in held:
		if is_instance_valid(creature) and not creature.eaten:
			notice.emit("The %s was held in the whirl" % creature.species)
			return


# --- fire -----------------------------------------------------------------

## Fire, breathed out of the spider's jaws along the cross for as long as the
## wind-up gave it, and swept wherever the cross goes while it lasts. It reaches as
## far as the wind-up sends it or the first wall, and burns what is in it the way
## fire burns: silk burns, so what it does to a creature is worth the silk on it
## (see [method Prey.burn]) — little to something bare, all of it to something
## wrapped or held in a web. And a creature burned low is an easy catch.
##
## The silk itself goes up too: every web and line the flame touches burns away, a
## web with the frame it was walked round on, and what a web was holding drops out
## of it burned. A wet web stands, and what it holds burns in it. See [FireBreath].
func _breathe(spell: SpiderSpell, wound: float) -> Dictionary:
	var breath := FireBreath.breathe(_host(), breath_origin(), breath_heading(),
		size_of(spell, wound) * body_height(), duration_of(spell, wound),
		power_of(spell, wound), body_height(), spell.colour, self)
	if breath == null:
		return {"cast": false}
	breath.finished.connect(_on_breath_finished)
	return {"cast": true, "at": breath_origin() + breath_heading() * breath.reach}


## Where a breath of fire comes from, or a spit of water: the spider's jaws, where
## its aim starts.
func breath_origin() -> Vector3:
	return _view.aim_origin()


## Which way a breath of fire goes: from the jaws to whatever the cross is on — the
## creature under it, a line, a web, the world — by the same pick everything else
## aims with, so a line the cross is on is a line the flame crosses. On open sky,
## the way the cross looks.
func breath_heading() -> Vector3:
	var target := aim_target()
	var toward: Vector3 = target.get("point", Vector3.ZERO) - breath_origin()
	if target.get("hit", false) and toward.length_squared() > 0.000001:
		return toward.normalized()
	return _view.aim_forward()


func _on_breath_finished(breath: FireBreath, burned: Array[Prey], webs: int,
		lines: int) -> void:
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
	if breath != null and not breath.steamed.is_empty():
		said.append("the water boils into steam")
	if not said.is_empty():
		notice.emit(" · ".join(said))


# --- earth ----------------------------------------------------------------

## A pillar of clay raised where the cross is, out of whatever it is on — up from
## the floor, out of a wall — as tall as the wind-up makes it: a square block, a
## face turned to the camera. What stands there is stunned and thrown off its top,
## hurt; the spider standing there is thrown up higher than it can jump; a web it
## comes up under is flung up off it. It stands for its time, then sinks back. See
## [ClayPillar].
func _raise(spell: SpiderSpell, wound: float) -> Dictionary:
	var target := pillar_target()
	if not target.get("hit", false):
		notice.emit("Nothing there to raise a pillar out of")
		return {"cast": false}
	var height := body_height()
	var at: Vector3 = target["point"]
	var camera := _spider.view.camera if _spider.view != null else null
	var pillar := ClayPillar.raise(_host(), at, target.get("normal", Vector3.UP), pillar_wide(),
		size_of(spell, wound) * height, duration_of(spell, wound), power_of(spell, wound),
		height, spell.colour, _spider,
		camera.global_basis.z if camera != null else Vector3.ZERO)
	if pillar == null:
		return {"cast": false}
	var said := PackedStringArray()
	if not pillar.struck.is_empty():
		said.append("%d %s" % [pillar.struck.size(), "stuck fast" if pillar.muddy else "thrown"])
	if pillar.spider_thrown:
		said.append("up you go")
	if not pillar.flung.is_empty():
		said.append("%d web%s flung" % [pillar.flung.size(), "" if pillar.flung.size() == 1 else "s"])
	if pillar.muddy:
		notice.emit("Mud Pillar — " + ", ".join(said) if not said.is_empty()
			else "Mud Pillar — out of the puddle")
	elif not said.is_empty():
		notice.emit("Clay Pillar — " + ", ".join(said))
	return {"cast": true, "at": at}


## Where a pillar of clay comes up, and which way: out of the world where the cross
## meets it, along the way it faces. Clay comes out of the world, not out of silk
## or a creature: with the cross on either it comes up out of whatever is under it,
## so a pillar aimed at a web comes up under that web, not somewhere past it. Open
## air, out of whatever is underneath.
func pillar_target() -> Dictionary:
	var target := aim_target()
	if target.get("prey") != null or target.get("line") != null:
		target["hit"] = false
	elif target.get("hit", false):
		var world := aim_target(GameLayers.WORLD)
		if world.get("hit", false) and (world["point"] as Vector3).distance_to(
				target["point"]) < body_height() * 0.05:
			return world
		target["hit"] = false
	return _ground(target, GameLayers.WORLD)


## How wide a pillar of clay is, from its middle to the middle of a face, in metres.
func pillar_wide() -> float:
	return PILLAR_BODIES * body_height()


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
			size_of(spell, wound) * body_height(), power_of(spell, wound), body_height())
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
## alike, because silk is something to aim at; a lane of wind looks straight
## through it to the floor.
func aim_target(mask := GameLayers.WORLD | GameLayers.WEB_WALK) -> Dictionary:
	var from := _view.aim_origin()
	var forward := _view.aim_forward()
	var span := cast_reach()
	var quarry := _builder.shot_target() if _builder != null else null
	if quarry != null:
		return {"point": quarry.global_position, "normal": Vector3.UP, "prey": quarry,
			"hit": true}
	if (mask & GameLayers.WEB_WALK) != 0 and _builder != null:
		# A line is a hair across the view, and nothing to stand on, so no ray stops
		# on one: the same pick the grapple makes decides whether the cross is on one.
		var line := _builder.aimed_line()
		if line != null:
			return {"point": _builder.aimed_line_point(line), "normal": Vector3.UP,
				"prey": null, "hit": true, "line": line}
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

## The circle a spell is drawn in while it winds up: where it will come from, as
## wide as it will be, in its own colour and with its own star. Fire's and water's
## hang in front of the spider's jaws on the line the breath or the spit will take,
## water's with where it will come down laid on the ground; lightning's lies on what
## it will strike, and earth's where the pillar will come up; wind's lies under the
## spider's feet with the strip it will blow down. Silk has no circle: it is the
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
		SpiderSpell.Form.FIRE, SpiderSpell.Form.DOUSE:
			var heading := breath_heading() if spell.form == SpiderSpell.Form.FIRE \
				else spit_heading()
			return {"where": MagicCircle.facing(breath_origin() + heading * height
				* circle_ahead, heading),
				"wide": height * lerpf(circle_bodies.x, circle_bodies.y, wound)}
		SpiderSpell.Form.LIGHTNING:
			var target := area_target(spell)
			var up: Vector3 = target.get("normal", Vector3.UP)
			return {"where": MagicCircle.facing(target.get("point", _spider.global_position)
				+ up * height * 0.03, up), "wide": size_of(spell, wound) * height}
		SpiderSpell.Form.EARTH:
			# Round the foot of the pillar, out past its corners, so it shows.
			var foot := pillar_target()
			var out: Vector3 = foot.get("normal", Vector3.UP)
			return {"where": MagicCircle.facing(foot.get("point", _spider.global_position)
				+ out * height * 0.03, out), "wide": pillar_wide() * PILLAR_RING}
	var ground := _ground({"point": _spider.global_position, "hit": false})
	var floor_up: Vector3 = ground.get("normal", Vector3.UP)
	var wide := size_of(spell, wound) * height
	if spell.form == SpiderSpell.Form.PULLBACK:
		# Called to the spider, so drawn round it: the size it is matters less than
		# that it can be seen.
		wide = height * lerpf(1.0, 1.3, wound)
	return {"where": MagicCircle.facing(ground.get("point", _spider.global_position)
		+ floor_up * height * 0.03, floor_up), "wide": wide}


## Where an area spell lands, and which way is up there: lightning comes down on
## what the cross is on, and through open air — or a line, which carries nothing —
## to whatever is under it; a pillar comes up out of the world there.
func area_target(spell: SpiderSpell) -> Dictionary:
	if spell != null and spell.form == SpiderSpell.Form.EARTH:
		return pillar_target()
	if spell != null and spell.form == SpiderSpell.Form.LIGHTNING:
		var target := aim_target()
		if target.get("line") != null:
			target["hit"] = false
		return _ground(target)
	return aim_target()


## Whether [param spell] lands on an area where you point, rather than leaving the
## spider: breathed, spat, blown or called back.
func is_area(spell: SpiderSpell) -> bool:
	return spell.form == SpiderSpell.Form.LIGHTNING or spell.form == SpiderSpell.Form.EARTH


## Where a spit of water will come down, laid on what the cross is on while it
## winds up: a round as wide as its drops will scatter, puddles and all.
func _update_splash() -> void:
	var spell := current()
	var shown := charging and spell != null and spell.form == SpiderSpell.Form.DOUSE \
		and _view != null and _spider != null
	if shown and _splash == null:
		_splash = _preview("SpellSplash", _disc())
		_splash_paint = _splash.material_override as StandardMaterial3D
	if _splash == null:
		return
	_splash.visible = shown
	if not shown:
		return
	var up: Vector3 = aim_target().get("normal", Vector3.UP)
	var wide := splash_wide(spell, charge)
	var lie := MagicCircle.facing(spit_target() + up * body_height() * 0.03, up)
	_splash.global_transform = Transform3D(lie.basis * Basis.from_scale(Vector3(wide, 1.0,
		wide)), lie.origin)
	_splash_paint.albedo_color = Color(spell.colour.r, spell.colour.g, spell.colour.b, 0.28)


## How far out from the cross the round a spit will come down in reaches while it
## winds up, in metres: for a check. Nought when none is showing.
func splash_shown() -> float:
	if _splash == null or not _splash.visible:
		return 0.0
	return _splash.global_basis.get_scale().x


## The strip a gust of wind will blow down, as long and as wide as it will be, laid
## on the ground ahead of the spider while it winds up — the way the water's was,
## when water went out along the ground. Flat from the floor under the spider, so on
## rough ground it is a guide rather than a promise.
func _update_path() -> void:
	var spell := current()
	var shown := charging and spell != null and spell.form == SpiderSpell.Form.GUST \
		and _view != null and _spider != null
	if shown and _path == null:
		var strip := PlaneMesh.new()
		strip.size = Vector2.ONE
		_path = _preview("SpellPath", strip)
		_path_paint = _path.material_override as StandardMaterial3D
	if _path == null:
		return
	_path.visible = shown
	if not shown:
		return
	var heading := lane_heading()
	var far := maxf(lane_reach(spell, charge), 0.01)
	var wide := lane_wide(spell, charge) * 2.0
	# Scaled along its own axes, not the world's: as wide as the lane across it and
	# as long as the gust down it, whichever way that is.
	_path.global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP)
		* Basis.from_scale(Vector3(wide, 1.0, far)), feet_ground() + heading * far * 0.5
		+ Vector3.UP * body_height() * 0.05)
	_path_paint.albedo_color = Color(spell.colour.r, spell.colour.g, spell.colour.b, 0.3)


## A see-through shape laid in the world while a spell winds up, hidden until it is
## wanted: where a spit will come down, or the strip a gust will blow down.
func _preview(part_name: String, shape: Mesh) -> MeshInstance3D:
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = shape
	part.material_override = paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.top_level = true
	part.visible = false
	add_child(part)
	return part


## A flat round of unit radius, lying in its own XZ plane.
func _disc() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 32
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(Vector3(cos(a), 0.0, sin(a)))
		tool.add_vertex(Vector3(cos(b), 0.0, sin(b)))
	return tool.commit()


## How far down the ground the strip runs while a gust winds up, in metres: for a
## check. Nought when no strip is showing.
func path_shown() -> float:
	if _path == null or not _path.visible:
		return 0.0
	return _path.global_basis.get_scale().z


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


# --- keeping up with the spider ------------------------------------------

## Reads what is on the keys afresh, and moves the hand off anything that has left
## them. Quiet: what is new is announced as it is learned — see [method _on_learned].
func _read_the_book() -> void:
	if not in_hand(current()):
		selected = 0
		for i in book.size():
			if book[i].form == SpiderSpell.Form.SILK:
				selected = i
				break
		if charging:
			cancel_cast()
	changed.emit()


func _on_learned(skill: SpellSkill) -> void:
	if skill.kind != SpellSkill.Kind.SPELL:
		return
	var spell := by_id(skill.spell)
	if spell == null:
		return
	opened.emit(spell)
	var key := key_for(spell)
	if key > 0:
		notice.emit("New spell: %s — [%d] to take it in hand" % [spell.display_name, key])
	else:
		notice.emit("New spell: %s — the loadout is full: make room in the tree [E]"
			% spell.display_name)
