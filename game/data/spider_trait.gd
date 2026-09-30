@tool
class_name SpiderTrait
extends Resource

## One evolutionary step the spider can take.
##
## Traits come from what you eat. Each one is carried by a few kinds of creature,
## and every meal of one you finish is a chance it passes to you — see
## [method SpiderTraits.digest] for how the odds are made. Biomass still grows you
## along the ladder in [GrowthStage]; this is the other thing a meal can do, so
## what you become is decided by what you hunt.
##
## A trait is almost entirely a set of multipliers over the current size tier,
## which is why so little code had to change to support them: everything in the
## game already reads its numbers from [method SpiderGrowth.current_stage], and
## that method now hands back a tier with the traits folded in.
##
## Drop a new .tres built from this script into
## [code]res://game/data/traits/[/code] and it appears in the tree — the shape
## of the tree is [member branch], [member depth] and [member requires], which
## is data, so there is no layout to edit and no code to change.

## The three ways a spider can go. Bulk is the old size ladder made into a
## choice; the other two are what you take instead of it.
enum Branch {
	## Bigger, heavier, stronger silk. The straight road.
	BULK,
	## Lighter and faster, and eventually you do not fall so much as descend.
	FLIGHT,
	## Nothing about your body; everything about what you can kill.
	VENOM,
}

const BRANCH_NAMES := ["Bulk", "Flight", "Venom"]

@export var id := "wing_buds"
@export var display_name := "Wing Buds"

## One line, in the tree, under the name.
@export var description := ""

@export var branch: Branch = Branch.FLIGHT

## How far down its branch this sits, 0 for a root. Only used to lay the tree
## out; what actually gates a trait is [member requires].
@export var depth := 0

## Trait ids that must already be owned. Empty for a root.
@export var requires: PackedStringArray = PackedStringArray()

## The creatures that carry it, by species id. Eat one and it may pass to you.
@export var carried_by := PackedStringArray(["fly"])

## The chance one meal of a carrier passes it on, for a spider on the first rung
## of the ladder. Every rung up raises it, and so does every meal it could have
## come from and did not — see [method SpiderTraits.odds].
@export_range(0.0, 1.0, 0.01) var chance := 0.1


@export_group("Body")

## Multiplies body height — and with it reach, anchor range and strand length,
## because those are what size means everywhere else in this game.
@export var body_scale := 1.0

@export var speed_scale := 1.0
@export var jump_scale := 1.0

## Multiplies how far silk goes without changing how big you are.
@export var reach_scale := 1.0


@export_group("Silk")

## Multiplies every web's hold strength and durability.
@export var quality_scale := 1.0


@export_group("Predation")

## Added to the tier's bite power: one more size class you can subdue.
@export var bite_bonus := 0

## Multiplies the biomass and silk taken out of a drained creature.
@export var drain_scale := 1.0

## How much of a fall the wings cancel. Summed across owned traits and capped
## short of 1, so a fall is flattened into a glide and never stopped.
@export_range(0.0, 0.9, 0.01) var glide := 0.0

## Fangs that work without a web. Anything inside your bite power can be
## drained where it stands, instead of having to be held first — and every dose
## of venom you spit is a fanged one.
@export var fangs := false


@export_group("Spells")

## Multiplies the wait between casts — every spell's, silk's included. Under one
## is quicker.
@export var cast_scale := 1.0


func branch_name() -> String:
	return BRANCH_NAMES[clampi(branch, 0, BRANCH_NAMES.size() - 1)]


## What it does, for the tree. Built from the numbers rather than written out,
## so a trait cannot advertise something it does not actually do.
func effect_line() -> String:
	# A plain Array, not a packed one: packed arrays are values, so a helper
	# handed one would quietly fill up a copy of it and hand nothing back.
	var parts: Array[String] = []
	_note(parts, "size", body_scale)
	_note(parts, "speed", speed_scale)
	_note(parts, "jump", jump_scale)
	_note(parts, "silk reach", reach_scale)
	_note(parts, "strength", quality_scale)
	_note(parts, "feeding", drain_scale)
	if bite_bonus != 0:
		parts.append("%+d bite" % bite_bonus)
	if glide > 0.0:
		parts.append("glide")
	if fangs:
		parts.append("kill without a web")
		parts.append("fanged venom")
	_note(parts, "spell wait", cast_scale)
	return "  ".join(PackedStringArray(parts))


static func _note(parts: Array[String], label: String, scale: float) -> void:
	if is_equal_approx(scale, 1.0):
		return
	parts.append("%+d%% %s" % [roundi((scale - 1.0) * 100.0), label])
