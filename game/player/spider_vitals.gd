class_name SpiderVitals
extends Node

## What the spider can take, and what happens when it runs out.
##
## Running out is not death. You drop the catch, you are thrown clear, and you
## walk home — the cost of losing a fight is the trip back, which is enough. A
## sandbox with no save has no business killing you.
##
## Two pools live here and they are not the same thing. **Condition** is what a
## bite takes and what being driven off costs; **wind** is what a sprint spends.
## Condition is the one you cannot get back by waiting somewhere safe. Wind is
## nothing but waiting: it is a tax on running, and the whole of it is that the
## tax goes up with what you are dragging.

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

## How many seconds of sprint the spider has in it, carrying nothing.
##
## Seconds rather than metres, and deliberately not scaled by the tier: a sprint
## lasts as long whatever size you are, and a bigger spider covers more ground in
## it because it is faster. Scaling this as well would be paying the ladder twice.
@export var wind := 4.0

## Seconds of sprint back per second of not sprinting. Under one on purpose — a
## sprint costs more than it gives back, so it is something you spend rather than
## something you hold down.
@export var wind_recovery := 0.8

## Quiet seconds after a sprint before the wind starts coming back.
@export var wind_delay := 0.7

## How much harder a sprint is per size class of cargo past the first.
##
## This is the point of the whole pool. Hauling a wasp home at a run should be a
## decision, and [member SilkTether.haul_drag] already makes it slower; this makes
## it *tiring*, which is the half that makes the slow version a real alternative
## rather than simply the worse one.
@export_range(0.0, 2.0, 0.05) var tow_effort := 0.55

## How much of the wind has to be back before a blown spider can sprint again.
##
## Without it, an empty tank buys you one frame of sprint per frame of recovery,
## which reads on screen as a stutter rather than as being out of breath.
@export_range(0.0, 1.0, 0.05) var second_wind := 0.35

var health := 0.0

## Seconds of sprint left.
var breath := 0.0

var _spider: SpiderPlayer
var _climb: SpiderClimb
var _tether: SilkTether
var _jaws: SpiderFeeding
## Seconds still to wait before stamina starts coming back. Public because it is
## real state a readout can show, and because a test that wants to watch mending
## has to be able to say "nothing has bitten me for a while".
var quiet := 0.0

## Quiet seconds still to wait before the wind comes back, and whether the spider
## is barred from sprinting until it has [member second_wind] of it again.
var wind_quiet := 0.0
var _blown := false


func setup(spider: SpiderPlayer, climb: SpiderClimb, tether: SilkTether,
		jaws: SpiderFeeding) -> void:
	_spider = spider
	_climb = climb
	_tether = tether
	_jaws = jaws
	health = max_stamina()
	breath = max_wind()


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


# --- wind ----------------------------------------------------------------

## Seconds of sprint a whole spider has. Not scaled by the tier — see
## [member wind].
func max_wind() -> float:
	return maxf(wind, 0.0001)


## 0 to 1, for the readout.
func wind_left() -> float:
	return clampf(breath / max_wind(), 0.0, 1.0)


## Whether a sprint would go at all, which is the thing a readout wants to say
## and the thing being out of breath actually means.
func can_sprint() -> bool:
	return not _blown and breath > 0.0


## How fast a sprint burns wind: one second a second on your own legs, more for
## every size class you are dragging behind you.
func sprint_effort() -> float:
	var load := _tether.cargo_weight() if _tether != null else 1.0
	return 1.0 + tow_effort * maxf(load - 1.0, 0.0)


## One frame of wanting to sprint. Returns whether the spider actually is.
##
## The asking and the spending are one call on purpose. Two — a `can_sprint()`
## the caller checks and a `spend()` it then calls — is two places that have to
## agree about what a sprint costs, and the version of that bug you get is a
## spider that runs at sprint speed for nothing.
func sprint(delta: float, wants: bool) -> bool:
	if not wants or _blown or breath <= 0.0:
		if wants and not _blown and breath <= 0.0:
			_blow()
		_catch_breath(delta)
		return false
	breath = maxf(0.0, breath - sprint_effort() * delta)
	wind_quiet = wind_delay
	if breath <= 0.0:
		_blow()
	return true


func _blow() -> void:
	if _blown:
		return
	_blown = true
	notice.emit("Out of breath")


## Wind back, after a moment of not asking for any.
func _catch_breath(delta: float) -> void:
	if wind_quiet > 0.0:
		wind_quiet = maxf(0.0, wind_quiet - delta)
		return
	if breath >= max_wind():
		return
	breath = minf(max_wind(), breath + wind_recovery * delta)
	if _blown and breath >= max_wind() * second_wind:
		_blown = false


## Comes back on its own after a quiet spell, so a bad trip costs you time
## rather than a restart.
func mend(delta: float) -> void:
	if quiet > 0.0:
		quiet = maxf(0.0, quiet - delta)
		return
	var top := max_stamina()
	if health < top:
		health = minf(top, health + mend_rate * maxf(_spider.stage().bite_power, 1) * delta)
