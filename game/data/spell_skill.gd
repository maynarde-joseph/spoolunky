@tool
class_name SpellSkill
extends Resource

## One thing the spell tree has to learn: a spell, a spell's second tier, a way a
## spell works off your silk or another spell, or a shorter wait.
##
## The tree is laid out in rows, one to a rank, Apprentice Spooder at the top and
## Grand Spooder at the foot — see [SpellTree]. A skill sits in its rank's row,
## can be learned once the spider has reached that rank, and costs points the
## ranks hand out. Everything about one is here, so a skill is a .tres in
## [code]res://game/data/skills/[/code] and the tree grows a card for it with
## nothing else to edit.

## What learning it does.
enum Kind {
	## Opens a spell, and puts it in the loadout if there is room.
	SPELL,
	## A spell's second tier: bigger, stronger or longer — see the tier numbers.
	TIER,
	## Something a spell does to silk, or to another spell's work, that it did not
	## do before. The code that does it asks [method SpellTree.knows].
	INTERACTION,
	## A shorter wait, for one spell or for all of them.
	CUT,
}

## What each kind is called on a card.
const KIND_NAMES := ["Spell", "Tier II", "Interaction", "Quicker"]

@export var id := ""
@export var display_name := ""

## What it does, in a sentence or two, for its card.
@export_multiline var description := ""

@export var kind: Kind = Kind.SPELL

## The rank whose row it sits in, counted from nought: an Apprentice's is 0.
@export_range(0, 4) var row := 0

## Where it sits in its row, left to right.
@export var column := 0

## What it costs, in points.
@export_range(1, 5) var cost := 1

## The skills it stands on, by id: every one of them has to be learned first.
@export var requires := PackedStringArray()

## The spell it is about, by id: the one it opens, the one it raises a tier, the
## one whose wait it cuts. A cut with none cuts every spell's, silk's included.
@export var spell := ""


@export_group("Tier")

## What a second tier multiplies its spell's reach, its harm and how long it
## lasts by.
@export var size_scale := 1.0
@export var power_scale := 1.0
@export var duration_scale := 1.0


@export_group("Interaction")

## What it lets happen, by name.
@export var interaction := &""


@export_group("Cut")

## What it multiplies the wait by: 0.8 is a fifth shorter.
@export_range(0.1, 1.0, 0.05) var cooldown_scale := 1.0


## One line of what it does, off its own numbers, for the card.
func effect_line() -> String:
	match kind:
		Kind.SPELL:
			var opened := SpellLibrary.find(spell)
			return "opens %s" % (opened.display_name if opened != null else spell)
		Kind.TIER:
			var parts := PackedStringArray()
			if not is_equal_approx(size_scale, 1.0):
				parts.append("%+d%% reach" % roundi((size_scale - 1.0) * 100.0))
			if not is_equal_approx(power_scale, 1.0):
				parts.append("%+d%% harm" % roundi((power_scale - 1.0) * 100.0))
			if not is_equal_approx(duration_scale, 1.0):
				parts.append("%+d%% longer" % roundi((duration_scale - 1.0) * 100.0))
			return ", ".join(parts)
		Kind.CUT:
			var shorter := roundi((1.0 - cooldown_scale) * 100.0)
			if spell.is_empty():
				return "every spell waits %d%% less" % shorter
			var cut := SpellLibrary.find(spell)
			return "%s waits %d%% less" % [cut.display_name if cut != null else spell, shorter]
	return "a new interaction"


## What its kind is called, for its card.
func kind_name() -> String:
	return KIND_NAMES[clampi(kind, 0, KIND_NAMES.size() - 1)]
