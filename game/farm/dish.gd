class_name Dish
extends RefCounted

## Something the spider has made, in its bag until the market buys it: an insect,
## how well it was kept, and what the kitchen did to it.
##
## Its worth is the insect's own [member InsectSpecies.value], times how far it had
## grown, times its grade, times whatever the cooking made of it (see [Prep]). So a
## better dish comes from three places: a heavier insect, a better kept one, and
## more done to it on the table — the way beef is worth what the herd was fed and
## what the kitchen did with it.

## The grades, from how well an insect was kept — see [method grade_of] — and what
## each multiplies a dish's worth by. Wagyu's, near enough.
const GRADES := ["A1", "A2", "A3", "A4", "A5"]
const GRADE_WORTH := [1.0, 1.25, 1.6, 2.1, 2.8]

## What a hatchling's meat is worth against a grown one's: there is not much of it.
const LIGHTEST := 0.3

var species: InsectSpecies
var growth := 1.0
var grade := 1
var steps: Array[int] = []


static func make(kind: InsectSpecies, grown: float, kept: float, done: Array[int]) -> Dish:
	var dish := Dish.new()
	dish.species = kind
	dish.growth = clampf(grown, 0.0, 1.0)
	dish.grade = grade_of(kept)
	dish.steps = done.duplicate()
	return dish


## The grade an insect kept to [param quality], 0 to 1, is sold at: A1 to A5.
static func grade_of(quality: float) -> int:
	return clampi(1 + floori(clampf(quality, 0.0, 1.0) * 5.0), 1, 5)


static func grade_name(grade_number: int) -> String:
	return GRADES[clampi(grade_number, 1, 5) - 1]


## What it is called on the menu: "Tender Roast Bee".
func title() -> String:
	var insect := species.display_name if species != null else "Insect"
	return Prep.dish_name(insect, steps)


## What it is called on the label: the title and its grade.
func label() -> String:
	return "%s · %s" % [title(), grade_name(grade)]


## What the market pays for it, in coins.
func value() -> int:
	if species == null:
		return 0
	var weight := lerpf(LIGHTEST, 1.0, growth)
	var kept: float = GRADE_WORTH[clampi(grade, 1, 5) - 1]
	return maxi(1, roundi(float(species.value) * weight * kept * Prep.worth(steps)))


func is_cooked() -> bool:
	return steps.has(Prep.Step.COOK)
