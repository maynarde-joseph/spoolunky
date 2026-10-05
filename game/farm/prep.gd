class_name Prep
extends RefCounted

## The kitchen's rules: what each spell does to a bundle on a prep table, what has
## to come before what, and what a dish ends up called and worth.
##
## Every spell but silk is one step, and each step can be done once. Most of them
## have to come before the cooking — you cannot wash something already roasted —
## and the order between them is mostly yours, with three rules that make it a
## kitchen rather than a checklist:
##
## * **Dry what is washed.** There is nothing to dry on a bundle nobody rinsed.
## * **A crust seals it.** Once it is in clay, nothing else gets in until it is
##   cooked — so wash, dry and tenderise first.
## * **Pull what is cooked.** Raw meat does not come apart on a thread.
##
## Cooking is what turns a bundle into a dish. A bundle can be taken off the table
## raw, and sells for half; one cooked without being washed first comes out gritty.

enum Step {
	WASH,       ## the water spiral
	DRY,        ## the gust
	TENDERISE,  ## lightning
	CRUST,      ## the clay
	COOK,       ## fire
	PULL,       ## the pullback
}

## What each step multiplies a dish's worth by.
const WORTH := {
	Step.WASH: 1.3,
	Step.DRY: 1.15,
	Step.TENDERISE: 1.25,
	Step.CRUST: 1.3,
	Step.COOK: 1.6,
	Step.PULL: 1.2,
}

## What a dish cooked without being washed first is worth, against the same dish
## washed: the grit comes off on the plate.
const GRITTY := 0.6

## What something taken off the table uncooked is worth, against the same thing
## cooked.
const RAW := 0.5

## Each step as something done to a bundle, for saying what has been done.
const DONE := {
	Step.WASH: "washed",
	Step.DRY: "dried",
	Step.TENDERISE: "tenderised",
	Step.CRUST: "sealed in clay",
	Step.COOK: "cooked",
	Step.PULL: "pulled",
}

## Each step as something to do, for the readout.
const VERB := {
	Step.WASH: "Wash",
	Step.DRY: "Dry",
	Step.TENDERISE: "Tenderise",
	Step.CRUST: "Crust",
	Step.COOK: "Cook",
	Step.PULL: "Pull",
}


## The step a spell of [param form] does, or -1 for one that does none — silk,
## which catches rather than cooks.
static func step_for(form: SpiderSpell.Form) -> int:
	match form:
		SpiderSpell.Form.WATER_SPIRAL:
			return Step.WASH
		SpiderSpell.Form.GUST:
			return Step.DRY
		SpiderSpell.Form.LIGHTNING:
			return Step.TENDERISE
		SpiderSpell.Form.EARTH:
			return Step.CRUST
		SpiderSpell.Form.FIRE:
			return Step.COOK
		SpiderSpell.Form.PULLBACK:
			return Step.PULL
	return -1


## Why [param step] cannot be done to something that has had [param done], or
## nothing if it can.
static func why_not(done: Array[int], step: int) -> String:
	if step < 0:
		return "That is not a kitchen spell"
	if done.has(step):
		return "It is already %s" % DONE[step]
	var cooked := done.has(Step.COOK)
	match step:
		Step.WASH, Step.DRY, Step.TENDERISE:
			if cooked:
				return "It is cooked — too late to %s it" % String(VERB[step]).to_lower()
			if done.has(Step.CRUST):
				return "It is sealed in clay — nothing gets in until it is cooked"
			if step == Step.DRY and not done.has(Step.WASH):
				return "Wash it first — there is nothing to dry"
		Step.CRUST:
			if cooked:
				return "It is cooked — too late for a crust"
		Step.PULL:
			if not cooked:
				return "Only cooked meat will pull — cook it first"
	return ""


## Whether [param step] can be done to something that has had [param done].
static func can_do(done: Array[int], step: int) -> bool:
	return why_not(done, step).is_empty()


## What the steps in [param done] multiply a dish's worth by, together.
static func worth(done: Array[int]) -> float:
	var total := 1.0
	for step in done:
		total *= float(WORTH.get(step, 1.0))
	if not done.has(Step.COOK):
		total *= RAW
	elif not done.has(Step.WASH):
		total *= GRITTY
	return total


## What a dish of [param insect] that has had [param done] is called: "Roast Ant",
## "Pulled Tender Crispy Clay-baked Bee", "Washed Raw Fly".
static func dish_name(insect: String, done: Array[int]) -> String:
	var words := PackedStringArray()
	if done.has(Step.COOK):
		if done.has(Step.PULL):
			words.append("Pulled")
		if done.has(Step.TENDERISE):
			words.append("Tender")
		if done.has(Step.DRY):
			words.append("Crispy")
		if not done.has(Step.WASH):
			words.append("Gritty")
		words.append("Clay-baked %s" % insect if done.has(Step.CRUST) else "Roast %s" % insect)
		return " ".join(words)
	if done.has(Step.CRUST):
		words.append("Clay-wrapped")
	if done.has(Step.TENDERISE):
		words.append("Tender")
	if done.has(Step.DRY):
		words.append("Air-dried")
	elif done.has(Step.WASH):
		words.append("Washed")
	words.append("Raw %s" % insect)
	return " ".join(words)


## What has been done, in the order it was, for the readout: "washed, dried".
static func done_text(done: Array[int]) -> String:
	var said := PackedStringArray()
	for step in done:
		said.append(DONE[step])
	return ", ".join(said) if not said.is_empty() else "nothing yet"


## What could still be done, by the verbs for it: what the readout offers next.
static func next_text(done: Array[int]) -> String:
	var said := PackedStringArray()
	for step in Step.values():
		if can_do(done, step):
			said.append(VERB[step])
	return " · ".join(said)
