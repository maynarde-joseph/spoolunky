class_name CreatureMotion
extends SkeletonModifier3D

## Poses a creature's bones every frame from a few plain facts about what it is
## doing: which [enum Pose] it is in, how fast it is going, how much fight it has
## left. Each kind of body has its own motion, which is where knowing how an
## insect flies lives; this one only holds the facts.
##
## It runs inside the skeleton's own update, after everything else has had its say
## for the frame, so what it poses is what gets drawn. The spider's gait found the
## catch in that: once the frame is drawn, the skeleton hands back its rest pose,
## so a motion that wants to be checked records what it drew itself.

## What the creature is doing, as far as its body is concerned.
enum Pose {
	FLYING,      ## in the air under its own power
	WALKING,     ## on its feet, moving or standing
	STRUGGLING,  ## caught, and fighting it
	SPENT,       ## caught, and fought out
	CURLED,      ## wrapped up, or dead
}

var pose: Pose = Pose.FLYING

## Speed along the ground or through the air, in body radii a second.
var speed := 0.0

## How fast it is rising, or sinking if negative, in body radii a second.
var climb := 0.0

## How much fight it has left, 0 to 1. Only means anything while it struggles.
var effort := 0.0

## Seconds into its life, started somewhere different for every creature so that
## a swarm does not beat its wings in step.
var clock := 0.0


## Finds the bones this poses. Called once, when the skeleton is built.
func bind(_skeleton: Skeleton3D, _body: CreatureBody) -> void:
	pass
