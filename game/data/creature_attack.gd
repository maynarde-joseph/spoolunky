class_name CreatureAttack
extends Resource

## One thing a creature can do to the spider: a bite, a dive, a spit, a sweep.
##
## Every attack is the same three beats, because that is what makes being on the
## end of one fair. A **wind-up** you can see: the creature stops, turns to you,
## and a tell in the attack's colour shows where it is going to land. Then the
## **strike**. Then a **recovery**, in which it stands open — the moment to put
## silk on it. What differs from one attack to the next is the strike.
##
## [CreatureFighter] carries them out. A species lists its own in
## [member PreySpecies.attacks]; the plain bite is one of them like any other, so
## even the bite is told before it lands.

enum Kind {
	BITE,    ## closes the last step and bites, there and then: what everything has
	LUNGE,   ## a straight dash at where you were when it committed: a dive, a charge
	SPIT,    ## a glob thrown at you, which a web in the way stops
	TONGUE,  ## a line out to you that drags you in, unless something is in the way
	BURST,   ## everything round it at once: a screech, a stamp, a gust
	SWEEP,   ## an arc in front of it: a slash, a tail; it can cut silk it passes
	SUMMON,  ## calls others of a kind out of the dark
}

@export var id := ""
@export var display_name := ""
@export var kind := Kind.BITE

@export_group("When")

## Furthest off the spider may be for this to be worth starting, in metres from the
## creature's middle to the spider's.
@export var reach := 1.0

## Nearest — a dive needs room to dive. Nought for no minimum.
@export var min_reach := 0.0

## How often it is picked against the others it could use as well.
@export var weight := 1.0

## Seconds after it starts before it can be started again.
@export var cooldown := 3.0

## Whether it comes after you to get this in reach. One that does not is kept for
## when you come to it: the sting of something that would rather spit, the bite of
## something that would rather sit and wait.
@export var chases := true

@export_group("Beats")

## The tell: seconds it stands winding up before it goes.
@export var wind_up := 0.5

## How long the strike can last, for the ones that take time: the longest a dive
## flies, the longest a tongue hauls.
@export var strike_time := 0.6

## Seconds it stands open afterwards.
@export var recover := 0.6

@export_group("What it does")

## Taken off the spider's condition when it lands.
@export var damage := 3.0

## How hard it throws the spider when it lands, in metres a second: away from the
## creature, or along a dive.
@export var knockback := 0.0

## Seconds the spider is dazed for when it lands: no moving and no casting.
@export var daze := 0.0

## Metres a second: how fast a lunge dashes, a spit flies or a tongue hauls.
@export var speed := 8.0

## How far round it a burst reaches, or a sweep, in metres from its middle.
@export var radius := 1.5

## How wide a sweep is, in degrees.
@export var arc := 140.0

## Whether it cuts the silk it passes: lines and webs in a sweep's arc, a burst's
## round, or a lunge's path. The spider standing on a line that is cut falls.
@export var cuts_silk := false

## For a lunge: seconds it is stuck fast if it goes into a wall instead of into
## you — a drill in the bark. Nought, and a miss is only a miss.
@export var stuck_on_miss := 0.0

## For a summon: the hostile species it calls, by id, and how many of them it will
## have out at once.
@export var summons := ""
@export var summon_count := 2

@export_group("Look")

## The colour of the tell, and of anything it throws.
@export var tell_colour := Color(1.0, 0.35, 0.2)
