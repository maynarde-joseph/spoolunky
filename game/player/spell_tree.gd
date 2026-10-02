class_name SpellTree
extends Node

## What the spider has learned to cast, and how far it has come.
##
## **Ranks are earned.** Everything the spider catches and everything it eats is
## experience, worth more the bigger the creature was and more again for one that
## fought back, and enough of it is the next rank: Apprentice Spooder to Grand
## Spooder. Each rank hands out [constant POINTS_PER_RANK] points and opens its own
## row of the tree.
##
## **Points are spent in the tree.** Each row holds a few skills — a spell, a
## spell's second tier, a way a spell works off your silk or off another spell, or
## a shorter wait (see [SpellSkill]) — and a skill can be learned once its row is
## open, what it stands on is learned, and there are the points for it. There are
## never the points for all of it: what you learn is the kind of spider you are.
##
## **Five of the spells you know are on the keys.** The loadout is keys 2 to 6;
## silk is always on 1 and never takes a slot. A spell learned goes into the
## loadout if there is room, and the tree screen moves them in and out.
##
## [member open_all] is the switch a level uses for testing: every spell and every
## interaction known from the start and the loadout's limit lifted. Tiers and
## shorter waits are still bought with points, so the numbers a level is played at
## are the spells' own until the spider earns better.

## Something was learned, the loadout changed, or experience came in. The tree and
## the strip redraw off this.
signal changed()

## A new rank, by number: 1 is Adept.
signal ranked_up(rank: int)

## A skill was learned.
signal learned(skill: SpellSkill)

## What the ranks are called, first to last.
const RANKS := ["Apprentice Spooder", "Adept Spooder", "Journeyman Spooder",
	"Master Spooder", "Grand Spooder"]

## Points each rank hands out — the first, Apprentice, included.
const POINTS_PER_RANK := 2

## How many spells the loadout holds, beside silk.
const LOADOUT_SIZE := 5

## Experience a catch is worth, for each size class of what was caught, and a meal
## for each size class of what was eaten. Something that fought back is worth
## [constant FIGHTER_WORTH] times as much, a boss [constant BOSS_WORTH] times.
const CATCH_XP := 10.0
const MEAL_XP := 5.0
const FIGHTER_WORTH := 1.5
const BOSS_WORTH := 3.0

## Leave empty to load every skill in the skills folder.
@export var skills: Array[SpellSkill] = []

## Experience each rank takes, counted from the start: Apprentice at nought.
@export var rank_xp := PackedFloat32Array([0.0, 100.0, 250.0, 500.0, 900.0])

## Every spell and every interaction known, and the loadout's limit lifted.
var open_all := false:
	set(value):
		if open_all == value:
			return
		open_all = value
		changed.emit()

var xp := 0.0
var rank := 0

## Skill id to true, for everything learned.
var owned := {}

## The spells on keys 2 to 6, by id, in order.
var loadout := PackedStringArray()

## Skill id to true, for what was handed over rather than bought: it cost nothing.
## See [method grant].
var _given := {}


func _ready() -> void:
	if skills.is_empty():
		skills = SkillLibrary.load_skills()


# --- ranks --------------------------------------------------------------

## What rank [param which] is called — the spider's own by default.
func rank_name(which := -1) -> String:
	var at := rank if which < 0 else which
	return RANKS[clampi(at, 0, RANKS.size() - 1)]


## Whether there is a rank past this one.
func is_top_rank() -> bool:
	return rank >= RANKS.size() - 1


## Experience still needed for the next rank, or nought at the top.
func xp_to_next() -> float:
	if is_top_rank():
		return 0.0
	return maxf(0.0, rank_xp[rank + 1] - xp)


## 0 to 1 toward the next rank; 1 at the top.
func rank_progress() -> float:
	if is_top_rank():
		return 1.0
	var floor_xp := rank_xp[rank]
	return clampf((xp - floor_xp) / maxf(rank_xp[rank + 1] - floor_xp, 0.001), 0.0, 1.0)


## Takes in [param amount] of experience. Returns how many ranks that was.
func earn(amount: float) -> int:
	if amount <= 0.0:
		return 0
	xp += amount
	var gained := 0
	while not is_top_rank() and xp >= rank_xp[rank + 1]:
		rank += 1
		gained += 1
		ranked_up.emit(rank)
	changed.emit()
	return gained


## What catching a [param kind] is worth. A practice target off a post is worth
## nothing: it is not in the world.
func catch_worth(kind: PreySpecies) -> float:
	return CATCH_XP * _size_worth(kind)


## What eating [param kind] to the end is worth.
func meal_worth(kind: PreySpecies) -> float:
	return MEAL_XP * _size_worth(kind)


func _size_worth(kind: PreySpecies) -> float:
	if kind == null or kind.resource_path.begins_with(TrainingDummy.SPECIES_DIR):
		return 0.0
	var worth := float(maxi(kind.size_class, 1))
	if kind.boss:
		worth *= BOSS_WORTH
	elif kind.hostile:
		worth *= FIGHTER_WORTH
	return worth


## A catch: something taken for keeps by the spider's silk.
func credit_catch(kind: PreySpecies) -> int:
	return earn(catch_worth(kind))


## A meal, drunk to the end.
func credit_meal(kind: PreySpecies) -> int:
	return earn(meal_worth(kind))


## Points still to spend: two a rank, the first included, less what is learned.
func points() -> int:
	var spent := 0
	for skill in skills:
		if owned.get(skill.id, false) and not _given.get(skill.id, false):
			spent += skill.cost
	return (rank + 1) * POINTS_PER_RANK - spent


# --- the tree -----------------------------------------------------------

func by_id(skill_id: String) -> SpellSkill:
	for skill in skills:
		if skill.id == skill_id:
			return skill
	return null


## The skills in row [param which], left to right.
func row(which: int) -> Array[SpellSkill]:
	var found: Array[SpellSkill] = []
	for skill in skills:
		if skill.row == which:
			found.append(skill)
	return found


## Whether the spider's rank has opened row [param which].
func row_open(which: int) -> bool:
	return which <= rank


## Whether [param skill_id] is learned — or, with everything open, a spell or an
## interaction, which [member open_all] hands over.
func has(skill_id: String) -> bool:
	if owned.get(skill_id, false):
		return true
	if not open_all:
		return false
	var skill := by_id(skill_id)
	return skill != null and (skill.kind == SpellSkill.Kind.SPELL
		or skill.kind == SpellSkill.Kind.INTERACTION)


## Whether [param skill] could be learned now: its row open, what it stands on
## learned, and the points for it.
func can_learn(skill: SpellSkill) -> bool:
	return skill != null and why_not(skill).is_empty()


## Why [param skill] cannot be learned now, or nothing if it can.
func why_not(skill: SpellSkill) -> String:
	if skill == null:
		return "no such skill"
	if has(skill.id):
		return "learned"
	if not row_open(skill.row):
		return "opens at %s" % rank_name(skill.row)
	for needed in skill.requires:
		if not has(needed):
			var first := by_id(needed)
			return "needs %s" % (first.display_name if first != null else needed)
	if points() < skill.cost:
		return "%d point%s — %d to spend" % [skill.cost, "" if skill.cost == 1 else "s", points()]
	return ""


## Learns [param skill], if it can be learned. A spell goes into the loadout if
## there is room for it.
func learn(skill: SpellSkill) -> bool:
	if not can_learn(skill):
		return false
	_take(skill)
	return true


## Hands [param skill_id] over whatever its row, its cost or what it stands on —
## for a reward, and for a check that is about what a skill does rather than how
## it is bought. Points are not touched: a skill given is not a skill bought.
func grant(skill_id: String) -> bool:
	var skill := by_id(skill_id)
	if skill == null or owned.get(skill_id, false):
		return false
	_take(skill, false)
	return true


func _take(skill: SpellSkill, paid := true) -> void:
	owned[skill.id] = true
	if not paid:
		_given[skill.id] = true
	if skill.kind == SpellSkill.Kind.SPELL and not loadout.has(skill.spell) \
			and loadout.size() < LOADOUT_SIZE:
		loadout.append(skill.spell)
	learned.emit(skill)
	changed.emit()



## Whether the spider can cast [param spell_id]. Silk it always can.
func knows_spell(spell_id: String) -> bool:
	if spell_id == "silk" or (open_all and not spell_id.is_empty()):
		return true
	for skill in skills:
		if skill.kind == SpellSkill.Kind.SPELL and skill.spell == spell_id \
				and owned.get(skill.id, false):
			return true
	return false


## Whether the spider has learned the interaction called [param what].
func knows(what: StringName) -> bool:
	if open_all:
		return true
	for skill in skills:
		if skill.kind == SpellSkill.Kind.INTERACTION and skill.interaction == what \
				and owned.get(skill.id, false):
			return true
	return false


## What the learned tiers of [param spell_id] multiply its reach, its harm and how
## long it lasts by, as x, y and z.
func tier(spell_id: String) -> Vector3:
	var scale := Vector3.ONE
	for skill in skills:
		if skill.kind == SpellSkill.Kind.TIER and skill.spell == spell_id \
				and owned.get(skill.id, false):
			scale *= Vector3(skill.size_scale, skill.power_scale, skill.duration_scale)
	return scale


## Whether [param spell_id] has a second tier learned.
func has_tier(spell_id: String) -> bool:
	return tier(spell_id) != Vector3.ONE


## What the learned cuts multiply [param spell_id]'s wait by.
func wait_scale(spell_id: String) -> float:
	var scale := 1.0
	for skill in skills:
		if skill.kind == SpellSkill.Kind.CUT and owned.get(skill.id, false) \
				and (skill.spell.is_empty() or skill.spell == spell_id):
			scale *= skill.cooldown_scale
	return scale


# --- the loadout --------------------------------------------------------

## Whether [param spell_id] is in the loadout.
func is_slotted(spell_id: String) -> bool:
	return loadout.has(spell_id)


## Whether the loadout has room for another spell.
func has_room() -> bool:
	return open_all or loadout.size() < LOADOUT_SIZE


## Puts [param spell_id] in the loadout, at the end. False if it is not known, is
## already in, or there is no room.
func slot(spell_id: String) -> bool:
	if spell_id == "silk" or not knows_spell(spell_id) or loadout.has(spell_id) \
			or not has_room():
		return false
	loadout.append(spell_id)
	changed.emit()
	return true


## Takes [param spell_id] out of the loadout. False if it was not in.
func unslot(spell_id: String) -> bool:
	var at := loadout.find(spell_id)
	if at < 0:
		return false
	loadout.remove_at(at)
	changed.emit()
	return true


## Back to an Apprentice who has learned nothing, for a check.
func forget_all() -> void:
	xp = 0.0
	rank = 0
	owned.clear()
	_given.clear()
	loadout.clear()
	changed.emit()
