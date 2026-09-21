class_name SilkPool
extends Node

## The spider's silk supply.
##
## Silk is the only currency in the game: webs cost it, prey refunds it, and
## it trickles back slowly on its own so a broke player is slowed down rather
## than stuck.

signal changed(current: float, maximum: float)
signal depleted()

@export var maximum := 45.0
@export var regen_per_second := 1.6

## Spend nothing and never run out. A sandbox switch, not a game rule: silk is
## meant to be the thing that makes you think about where a web goes, and while
## the building controls are still being worked out it only gets in the way.
## Press J in the sandbox, or clear this, to feel the economy again.
@export var unlimited := true

var current := 45.0


func _ready() -> void:
	current = maximum


func _process(delta: float) -> void:
	if unlimited:
		if current < maximum:
			current = maximum
			changed.emit(current, maximum)
		return
	if current >= maximum:
		return
	current = minf(maximum, current + regen_per_second * delta)
	changed.emit(current, maximum)


func can_afford(cost: float) -> bool:
	return unlimited or current >= cost


## Spends silk if there is enough. Returns false and spends nothing if not.
func spend(cost: float) -> bool:
	if cost <= 0.0 or unlimited:
		return true
	if current < cost:
		return false
	current -= cost
	changed.emit(current, maximum)
	if current <= 0.0:
		depleted.emit()
	return true


func refill(amount: float) -> void:
	if amount <= 0.0:
		return
	current = minf(maximum, current + amount)
	changed.emit(current, maximum)


## Growing gives a bigger reservoir, and tops it up by the same amount so
## levelling up never feels like a downgrade.
func set_capacity(new_maximum: float) -> void:
	var gained: float = maxf(0.0, new_maximum - maximum)
	maximum = new_maximum
	current = minf(maximum, current + gained)
	changed.emit(current, maximum)


func fraction() -> float:
	if unlimited:
		return 1.0
	return clampf(current / maxf(maximum, 0.001), 0.0, 1.0)


## Flips the sandbox switch and says which way it went.
func toggle_unlimited() -> bool:
	unlimited = not unlimited
	if unlimited:
		current = maximum
	changed.emit(current, maximum)
	return unlimited
