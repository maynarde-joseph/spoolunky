class_name StandIn
extends RefCounted

## Something to wear a body nothing wears yet, so it can be let loose, checked
## and photographed before the world has anywhere for it to live.
##
## A [CreatureBody] says what a creature looks like and how it moves; a
## [PreySpecies] says the rest — how big it is, how hard it fights, where it turns
## up. Bodies get drawn ahead of the places they will live in, and until then
## this makes up the rest: enough to walk one, fly one and catch one, and nothing
## a spider could meet, because only the checks and the pictures ever make one.

const BODIES_DIR := "res://game/data/bodies"

## How big a stand-in is. Any size would do — a body is drawn in its own unit and
## scaled to fit — so this is one the rooms the checks and pictures build suit.
const RADIUS := 0.08

## The bodies nothing wears yet that do not walk, by file name: the ones that
## fly, and of those the ones that swim — which, for a creature, is flying in
## water. A body not named here walks.
const FLIERS := ["bat", "parrot", "fish", "shark", "octopus"]
const SWIMMERS := ["fish", "shark", "octopus"]


## Every body there is, each on the species that wears it or on a stand-in: the
## species first, in the order the catalogue keeps them, then the rest by name.
static func every_body() -> Array[PreySpecies]:
	var all: Array[PreySpecies] = []
	var worn := {}
	for kind in PreyLibrary.load_species():
		if kind.body != null:
			all.append(kind)
			worn[kind.body.resource_path] = true
	var dir := DirAccess.open(BODIES_DIR)
	if dir == null:
		return all
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		var path := BODIES_DIR.path_join(file_name)
		if not file_name.ends_with(".tres") or worn.has(path):
			continue
		var body := ResourceLoader.load(path) as CreatureBody
		if body != null:
			all.append(wearing(body, file_name.get_basename()))
	return all


## A species for [param body], called [param id], that gets about the way the
## animal would.
static func wearing(body: CreatureBody, id: String) -> PreySpecies:
	var kind := PreySpecies.new()
	kind.id = id
	kind.display_name = id.capitalize()
	kind.body = body
	kind.body_radius = RADIUS
	kind.flying = FLIERS.has(id)
	kind.move_speed = RADIUS * (12.0 if kind.flying else 6.0)
	kind.wander_radius = RADIUS * 30.0
	kind.wander_height = Vector2(RADIUS * 3.0, RADIUS * 12.0)
	kind.wander_interval = 2.0
	kind.lure_susceptibility = 0.0
	kind.aggression = 0.0
	kind.spawn_weight = 0.0
	return kind


## Whether [param kind] is something that does its flying in water.
static func swims(kind: PreySpecies) -> bool:
	return kind.flying and SWIMMERS.has(kind.id)


## What [param kind] is doing when it gets about: flying, swimming or walking.
static func going(kind: PreySpecies) -> String:
	if swims(kind):
		return "swimming"
	return "flying" if kind.flying else "walking"
