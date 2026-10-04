class_name Dungeon
extends RefCounted

## The dungeon: a run down floor after floor of rooms made by hand and laid out at
## random, under a sky that is mostly rock.
##
## What the scene holds is only what does not change from floor to floor — the sky,
## the spider and its HUD, and the [DungeonRun] that lays each floor out and puts it
## down when the scene opens, and the next when the spider drops down the pit. Open
## it and press F6 to start a run; set the run's seed to walk the same dungeon twice.
##
## This is the generator of record; `tools/bake_level.gd` saves what it makes to
## [constant SCENE]. The rooms are scenes of their own, in `game/world/dungeon/`.

const SCENE := "res://game/world/dungeon.tscn"

## What the HUD calls the place, before a floor names itself.
const NAME := "The Dungeon"


static func build(level: Node3D) -> void:
	Site.sky(level, "deep")
	var run := DungeonRun.new()
	run.name = "Run"
	level.add_child(run)
	# Put down for now anywhere; the run moves it to the first floor's way in.
	Site.spider(level, Vector3(0.0, 2.0, 0.0))
