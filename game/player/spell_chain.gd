class_name SpellChain
extends RefCounted

## What the last spell left behind, and what each spell in hand would make of it:
## the chain the [SpiderDisc] offers in the moment after a cast.
##
## Every interaction between spells is the second acting on what the first left — a
## web, a puddle, a pool of lava, a web left live, a whirl (§3.2 of the design). So a
## chain is that second spell, cast straight at what the first left without aiming it
## again: spit, then flick to fire on the disc, and the breath goes to the puddle.
## Only the pairs that do something are offered, named for what they make, and only
## while what they act on is still there.
##
## A chained spell goes off as a tap, and waits its wait like any other. Aiming it
## yourself is still how to wind one up.

## How long the disc chains onto the last spell, in seconds of the game's own time —
## so the slow under the disc stretches it — from when it lands: the spit's drops
## down, the thrown web stuck, the puddle melted. A spell has to be somewhere before
## anything can be chained onto it, and a spit can be a second in the air.
const WINDOW := 2.0

## The last spell cast, where it went, the creature it went at if it went at one, and
## what it made: "spit", "web", "breath", "strike", "whirl" — and what those left,
## kept once they have gone: the "puddles" and "wet_webs" a spit left, the "lava" a
## breath melted.
var spell: SpiderSpell = null
var at := Vector3.ZERO
var prey: Prey = null
var made := {}

var _spells: SpiderSpells
## The game's own clock, in seconds, and when on it the last spell was cast, or
## landed, whichever came later.
var _clock := 0.0
var _when := -INF


func _init(spells: SpiderSpells) -> void:
	_spells = spells


## Moves the clock on by the game's own [param delta] — and watches a breath for the
## puddles it melts as it goes, each of them a landing.
func tick(delta: float) -> void:
	_clock += delta
	var breath := _alive("breath") as FireBreath
	if breath != null \
			and breath.melted.size() > (made.get("lava", []) as Array).size():
		made["lava"] = breath.melted.duplicate()
		_when = _clock


## A spell went: [param cast], and what its form said of where it went and what it
## made.
func note(cast: SpiderSpell, went: Dictionary) -> void:
	spell = cast
	at = went.get("at", Vector3.ZERO)
	prey = went.get("prey") as Prey
	made = {}
	for part in ["spit", "web", "breath", "strike", "whirl"]:
		if went.get(part) != null:
			made[part] = went[part]
	_when = _clock
	var spit := made.get("spit") as WaterSpit
	if spit != null:
		spit.landed.connect(_on_spit_landed)


## A web was spun: if the last spell was a thrown web still in the air, this is what
## it made, and where it landed.
func spun(web: WebStructure) -> void:
	if spell != null and spell.form == SpiderSpell.Form.SILK and web is WebNet \
			and not made.has("web") and _clock - _when <= WINDOW:
		made["web"] = web
		_when = _clock


func _on_spit_landed(spit: WaterSpit, _soaked: Array, _webs: int, _puddles: int) -> void:
	if made.get("spit") == spit:
		_read_spit()
		_when = _clock


## Whether the last spell is recent enough to chain onto.
func fresh() -> bool:
	return spell != null and _clock - _when <= WINDOW


## Forgets the last spell, so nothing chains onto it.
func clear() -> void:
	spell = null
	prey = null
	made = {}
	_when = -INF


## What each spell in hand would make of what the last spell left, by spell id: what
## it is called, what it is cast at — "point", and the "node" and "prey" there, which
## move with it — or nothing for a spell that needs no aim, whether it can go now,
## and if not, why not. Empty when the last spell left nothing anything acts on.
func options() -> Dictionary:
	var found := {}
	if spell == null or _spells == null:
		return found
	match spell.form:
		SpiderSpell.Form.SILK:
			_after_silk(found)
		SpiderSpell.Form.DOUSE:
			_after_water(found)
		SpiderSpell.Form.FIRE:
			_after_fire(found)
		SpiderSpell.Form.LIGHTNING:
			_after_lightning(found)
		SpiderSpell.Form.GUST:
			_after_wind(found)
	return found


# --- what each spell leaves, and what acts on it ---------------------------

## A thrown web: wetted, blown into, struck, burned, called back or flung.
func _after_silk(found: Dictionary) -> void:
	var web := _alive("web") as WebNet
	if web == null or web.is_queued_for_deletion():
		return
	var aim := {"point": web.signal_point(), "node": web}
	if _spells.knows(&"wet_silk"):
		_offer(found, "douse", "Wet web", aim)
	_offer(found, "gust", "Blow in", aim)
	_offer(found, "lightning", "Live web" if _spells.knows(&"live_silk") else "Shock web", aim)
	_offer(found, "fire", "Roast catch" if WetSilk.is_wet(web) else "Burn web", aim)
	if _spells.pullable_webs().has(web):
		_offer(found, "pullback", "Call back", {})
	else:
		_offer(found, "pullback", "Call back", {}, "too far")
	_offer(found, "earth", "Fling web", aim)


## A spit of water: the puddles its drops left — lava under fire and a whirl under
## wind, off the one nearest the spider, which is the one they reach first; a
## lightning rod under a strike, off the one nearest where it was aimed — or the
## creature it soaked; and a web it wetted, which comes back wet.
func _after_water(found: Dictionary) -> void:
	_read_spit()
	var jaws := _spells.breath_origin()
	var near_aim: WetGround = null
	var near_us: WetGround = null
	for node in made.get("puddles", []):
		var wet := node as WetGround if is_instance_valid(node) else null
		if wet == null or wet.is_queued_for_deletion() or not wet.is_wet():
			continue
		if near_aim == null or wet.centre.distance_to(at) < near_aim.centre.distance_to(at):
			near_aim = wet
		if near_us == null or wet.centre.distance_to(jaws) < near_us.centre.distance_to(jaws):
			near_us = wet
	if near_aim != null:
		var close := {"point": near_us.centre, "node": near_us}
		_offer(found, "fire", "Lava", close)
		_offer(found, "lightning", "Lightning rod", {"point": near_aim.centre, "node": near_aim})
		if _spells.knows(&"waterspout"):
			_offer(found, "gust", "Whirl", close)
	elif is_instance_valid(prey) and not prey.eaten and prey.is_wet():
		_offer(found, "lightning", "Double strike",
			{"point": prey.global_position, "node": prey, "prey": prey})
	if _spells.knows(&"wet_silk"):
		var pullable := {}
		for web in _spells.pullable_webs():
			pullable[web] = true
		for node in made.get("wet_webs", []):
			if is_instance_valid(node) and pullable.has(node) and WetSilk.is_wet(node):
				_offer(found, "pullback", "Wet web back", {})
				break


## What the last spit has left so far, kept: the spit itself is gone soon after its
## last drop is down, and what it left is not.
func _read_spit() -> void:
	var spit := _alive("spit") as WaterSpit
	if spit == null:
		return
	made["puddles"] = spit.puddles.duplicate()
	made["wet_webs"] = spit.wet_webs.duplicate()


## A breath of fire: the lava it made of a puddle — a fire rod under a strike, a spiral
## of fire under wind.
func _after_fire(found: Dictionary) -> void:
	var pool: Lava = null
	for node in made.get("lava", []):
		var lava := node as Lava if is_instance_valid(node) else null
		if lava != null and not lava.is_queued_for_deletion() and lava.molten():
			pool = lava
			break
	if pool == null:
		return
	var aim := {"point": pool.centre, "node": pool}
	_offer(found, "lightning", "Fire rod", aim)
	if _spells.knows(&"waterspout"):
		_offer(found, "gust", "Fire spiral", aim)


## A strike: the webs it left live, which strike what they pass when called back.
func _after_lightning(found: Dictionary) -> void:
	var strike := _alive("strike") as LightningStrike
	if strike == null or not _spells.knows(&"live_silk"):
		return
	var pullable := {}
	for web in _spells.pullable_webs():
		pullable[web] = true
	for web in strike.charged:
		if is_instance_valid(web) and WebCharge.of(web) != null and pullable.has(web):
			_offer(found, "pullback", "Live web back", {})
			return


## A gust: the whirl it lifted off a puddle, which a strike reaches into.
func _after_wind(found: Dictionary) -> void:
	var whirl := _alive("whirl") as WaterSpiral
	if whirl == null or whirl.is_queued_for_deletion() \
			or whirl.fiery or not whirl.spinning():
		return
	_offer(found, "lightning", "Strike whirl", {"point": whirl.eye(), "node": whirl})


## What the last spell made under [param part], if it is still there; null if it never
## was or has gone — burned, melted, spent.
func _alive(part: String) -> Object:
	var thing: Variant = made.get(part)
	return thing if is_instance_valid(thing) else null


## Offers spell [param id] as [param label], cast at [param aim], if it is in hand —
## and says whether it can go now: not while it waits, nor when what it acts on is out
## of its reach, unless [param why] already says why not.
func _offer(found: Dictionary, id: String, label: String, aim: Dictionary, why := "") -> void:
	var follow := _spells.by_id(id)
	if follow == null or not _spells.in_hand(follow):
		return
	if why == "" and _spells.cooling(follow):
		why = "%.1fs" % _spells.cooldown_left(follow)
	if why == "" and not aim.is_empty() and not _in_reach(follow, aim["point"]):
		why = "closer"
	found[id] = {"label": label, "aim": aim, "ready": why == "", "why": why}


## Whether [param follow], cast as a tap, gets to [param point]: a breath as far as it
## goes, a gust down its lane, anything else as far as silk does.
func _in_reach(follow: SpiderSpell, point: Vector3) -> bool:
	var height := _spells.body_height()
	match follow.form:
		SpiderSpell.Form.FIRE:
			return _spells.breath_origin().distance_to(point) \
				<= _spells.size_of(follow, 0.0) * height + height * 0.3
		SpiderSpell.Form.GUST:
			var off := point - _spells.feet_ground()
			off.y = 0.0
			return off.length() <= _spells.lane_reach(follow, 0.0) + height * 0.5
	return _spells.breath_origin().distance_to(point) <= _spells.cast_reach()
