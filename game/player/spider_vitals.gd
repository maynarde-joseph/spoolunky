class_name SpiderVitals
extends Node

## What the spider can take, and what happens when it runs out.
##
## Running out is not death. You drop the catch, you are thrown clear, and you
## walk home — the cost of losing a fight is the trip back, which is enough. A
## sandbox with no save has no business killing you.

## Something bit you: how much it took, and the share you have left.
signal hurt(amount: float, left: float)

## Driven off. Everything you were carrying is on the floor behind you.
signal routed()

## Said out loud to the player. The spider passes these through.
signal notice(text: String)

## What the spider can take before it is driven off, at a bite power of one.
##
## Scaled by the tier, so the same wasp that nearly kills a spiderling is a
## nuisance to a Huntsman — the ladder is the difficulty curve, and this is where
## that is actually felt rather than read.
@export var stamina := 10.0

## Stamina back per second, once nothing has bitten you for [member mend_delay].
@export var mend_rate := 1.6

## Quiet seconds before it starts coming back.
@export var mend_delay := 3.0

var health := 0.0

var _spider: SpiderPlayer
var _climb: SpiderClimb
var _tether: SilkTether
var _jaws: SpiderFeeding
## Seconds still to wait before stamina starts coming back. Public because it is
## real state a readout can show, and because a test that wants to watch mending
## has to be able to say "nothing has bitten me for a while".
var quiet := 0.0


func setup(spider: SpiderPlayer, climb: SpiderClimb, tether: SilkTether,
		jaws: SpiderFeeding) -> void:
	_spider = spider
	_climb = climb
	_tether = tether
	_jaws = jaws
	health = max_stamina()


## What the spider can take at this size. Bigger is tougher, which is the whole
## reward for growing: the thing that was hunting you last tier is food now.
func max_stamina() -> float:
	return stamina * maxf(_spider.stage().bite_power, 1)


## 0 to 1.
func condition() -> float:
	var top := max_stamina()
	return clampf(health / top, 0.0, 1.0) if top > 0.0 else 0.0


func is_hurt() -> bool:
	return condition() < 0.999


## Growing mends you, all the way. It is the payoff for a hard trip and it is what
## makes a tier read as relief rather than as a bigger number.
func fill() -> void:
	health = max_stamina()


## Trims what is left to fit a body that just changed size without changing tier —
## a trait reshaping you rather than a meal growing you.
##
## It keeps the absolute number and caps it, so a trait that makes you tougher
## leaves you with the same stamina against a higher maximum, which reads as a
## wound that got no smaller. The comment this replaced claimed it kept the same
## *share*; the code has always capped. Keeping the code, because which of the two
## the game wants is a design question and not a question about this refactor.
func cap_to_max() -> void:
	health = minf(health, max_stamina())


## Something bit you. Interrupts whatever you were drinking, because a meal you
## are being attacked during is exactly the meal you should not be finishing.
##
## [param from] is what did it, so being driven off can throw you away from it.
func take_bite(amount: float, from: Node3D = null) -> void:
	if amount <= 0.0:
		return
	quiet = mend_delay
	health = maxf(health - amount, 0.0)
	if _jaws != null and _jaws.meal != null:
		_jaws.stop("Bitten — you lost the mouthful")
	hurt.emit(amount, condition())
	if health <= 0.0:
		_route(from)


## Driven off. Not death and not a reload: you lose the catch and the ground you
## had made, and you are thrown clear with nothing left to take another hit with
## for a few seconds.
func _route(from: Node3D) -> void:
	if _tether != null and _tether.is_towing():
		_tether.cut()
	var away := Vector3.UP
	if from != null and is_instance_valid(from):
		var off := _spider.global_position - from.global_position
		if off.length_squared() > 0.000001:
			away = off.normalized()
	_climb.release()
	_spider.velocity = (away + Vector3.UP * 1.4).normalized() \
		* _spider.stage().jump_velocity * 1.3
	routed.emit()
	notice.emit("Driven off — you dropped everything and ran")


## Comes back on its own after a quiet spell, so a bad trip costs you time
## rather than a restart.
func mend(delta: float) -> void:
	if quiet > 0.0:
		quiet = maxf(0.0, quiet - delta)
		return
	var top := max_stamina()
	if health < top:
		health = minf(top, health + mend_rate * maxf(_spider.stage().bite_power, 1) * delta)
