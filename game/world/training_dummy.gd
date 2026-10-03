class_name TrainingDummy
extends Node3D

## A creature on a post, with its combat numbers over its head.
##
## Everything about a fight is a number you cannot see: how much silk is on
## something, how much fight that has cost it, how long the venom has left, and
## whether the web you are about to spin could hold it. You can infer all of it
## from behaviour eventually, which is fine in play and useless when what you want
## to know is whether a change did what you meant.
##
## So this puts one of each up where you can hit it, prints what it is doing, and
## sets a fresh one out when you finish the last — a creature rather than a
## special case, so silk, venom, webs, hauling and eating all work on it exactly
## as they work on anything else.

## Where the species live. Deliberately not [constant PreyLibrary.SPECIES_DIR]:
## everything in that folder is in the game — it spawns, it fills the larder and
## eating it can change you — and a practice target is none of those things.
const SPECIES_DIR := "res://game/data/training"

## Seconds between finishing one and the next standing up.
@export var replace_after := 3.0

## Which of the three this post holds.
@export var species_id := "dummy_post"

## How far from the post the creature is allowed to wander before it is put back.
## A runner you have to chase across the room is not a target.
@export var leash := 9.0

var _kind: PreySpecies
var _standing: Prey
var _readout: Label3D
var _home := Vector3.ZERO
var _waiting := 0.0


func _ready() -> void:
	_home = global_position
	_kind = load(SPECIES_DIR.path_join("%s.tres" % species_id)) as PreySpecies
	_readout = Label3D.new()
	_readout.name = "Readout"
	_readout.font_size = 44
	_readout.pixel_size = 0.0035
	_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_readout.modulate = Color(0.06, 0.07, 0.1, 1.0)
	_readout.outline_modulate = Color(1.0, 1.0, 1.0, 0.9)
	_readout.outline_size = 18
	_readout.shaded = false
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_readout)
	# Close enough over the creature to read as belonging to it. The station's own
	# sign is up at 4.6m; these are not signs, they are what the thing under them
	# is doing.
	_readout.position = Vector3(0.0, 1.15, 0.0)
	# Something on it before the first physics frame: a blank sign in a room whose
	# every other sign has words on it reads as broken.
	_readout.text = "%s\nstanding up" % _title()
	# Deferred, because the creature goes next to the post rather than under it —
	# it has to be able to be hauled off, fall, and be taken away — and a parent
	# part way through setting up its own children refuses an add_child. That never
	# came up while the gym built itself at startup, because by then the level was
	# already in the tree; it does the moment the post is a node in the scene file.
	_stand_one_up.call_deferred()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_standing) or _standing.eaten:
		_waiting -= delta
		_readout.text = "%s\nback in %.0fs" % [_title(), maxf(_waiting, 0.0)]
		if _waiting <= 0.0:
			_stand_one_up()
		return

	# A runner that has wandered off is not a target any more. Put it back rather
	# than making the player fetch it.
	if not _standing.is_stuck() and not _standing.is_bundled() \
			and _standing.global_position.distance_to(_home) > leash:
		_standing.global_position = _home
		_standing.velocity = Vector3.ZERO
		# And make it stop chasing, not just stand somewhere else while it does.
		# A biter put back on its post kept its quarry, so it charged straight
		# off again — the post snapped it home two or three times a second and
		# from in front it read as one creature that would not let go.
		if _standing.is_hunting():
			_standing.break_off()

	_readout.text = _lines()


## What it is doing, in the numbers a fight is actually made of.
func _lines() -> String:
	var prey := _standing
	var text := "%s   size %d\n" % [_title(), prey.size_class]
	text += "bound   %s %d%%\n" % [_bar(prey.bound), roundi(prey.bound * 100.0)]
	if prey.is_poisoned():
		text += "venom   %.1fs\n" % prey.venom
	if prey.move_speed > 0.0:
		text += "speed   %.1f of %.1f\n" % [prey.current_speed(), prey.move_speed]
	else:
		text += "speed   stands still\n"
	# The number a web has to beat, which is the whole question when you are
	# deciding whether to spin one or put more silk on first.
	text += "fight   %.1f  (a web needs %.1f hold)\n" \
		% [prey.total_thrash(), prey.total_thrash() / Prey.ESCAPE_MARGIN]
	text += "left    %.0f of %.0f\n" % [prey.biomass, prey.full_biomass]
	text += _state_of(prey)
	return text


func _state_of(prey: Prey) -> String:
	if prey.is_bundled():
		return "bundled — pick it up"
	if prey.wrapped:
		return "wrapped"
	if prey.is_stuck():
		return "stuck, and fighting" if prey.is_fighting() else "stuck, and tired out"
	if prey.subdued:
		return "finished"
	return "loose"


func _bar(share: float) -> String:
	var lit := clampi(roundi(clampf(share, 0.0, 1.0) * 10.0), 0, 10)
	return "%s%s" % ["|".repeat(lit), ".".repeat(10 - lit)]


func _title() -> String:
	return _kind.display_name if _kind != null else species_id


func _stand_one_up() -> void:
	if _kind == null:
		return
	_standing = Prey.of(_kind)
	if _standing == null:
		return
	get_parent().add_child(_standing)
	_standing.global_position = _home + Vector3(0.0, 0.4, 0.0)
	# It can never see further than it is allowed to walk. A dummy whose species
	# out-ranges its own leash acquires you from outside the ground it is allowed
	# to cover, so it spends the whole fight being yanked back to its post — and
	# worse, it picks fights across the room with someone who never came to the
	# gym. Held here rather than in the `.tres` so the guarantee belongs to the
	# post, which is the thing that knows how far it will let the creature go.
	_standing.hunt_range = minf(_standing.hunt_range, leash * 0.6)
	_standing.eaten_by_spider.connect(_on_finished)
	_waiting = replace_after


func _on_finished(_prey: Prey) -> void:
	_waiting = replace_after
