extends SceneTree

## Renders the farm to PNG files, for checking how it reads without playing it.
## Needs a display; on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --path . --script res://tests/screenshot_farm.gd -- stocked
##
## `empty` photographs the farm as a new game finds it. `stocked` builds a pen
## first — fence, gate, trough, pond, compost heap, sugar bowl — puts flies in it,
## and a wrapped fly half-cooked on a prep table beside it, and photographs that.
## The shots land in the user data folder as `farm_<setup>_<view>.png`; the paths
## are printed on the way out.

const VIEWS := {
	"start": [],
	"above": [Vector3(-26.0, 30.0, 34.0), Vector3(0.0, 0.0, 4.0)],
	"pen": [Vector3(-9.0, 4.5, 15.0), Vector3(-3.0, 0.6, 6.0)],
	"kitchen": [Vector3(4.6, 2.4, 13.4), Vector3(5.0, 0.8, 9.0)],
	"market": [Vector3(-8.0, 3.0, 19.0), Vector3(-8.0, 1.2, 27.5)],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var setup := "stocked" if args.is_empty() else args[0]
	var level := (load("res://game/world/farm.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var spider := level.get_node("Player") as SpiderPlayer
	spider.require_captured_mouse = false
	var farm := level.get_node("Farm") as Farm
	farm.coins = 5000
	if setup == "stocked":
		_stock(farm)
	for i in 240:
		await physics_frame
	if setup == "stocked":
		_kitchen(farm)
		for i in 30:
			await physics_frame
	var saved := PackedStringArray()
	for view in VIEWS:
		var spot: Array = VIEWS[view]
		var camera := spider.view.camera
		if not spot.is_empty():
			camera = Camera3D.new()
			level.add_child(camera)
			camera.look_at_from_position(spot[0], spot[1])
			camera.current = true
		else:
			spider.view.camera.current = true
		for i in 4:
			await process_frame
		var image := root.get_texture().get_image()
		var path := OS.get_user_data_dir().path_join("farm_%s_%s.png" % [setup, view])
		image.save_png(path)
		saved.append(path)
		if camera != spider.view.camera:
			camera.queue_free()
	for path in saved:
		print(path)
	quit()


## A pen of six by five cells west of the middle, with all a pen needs, and flies.
func _stock(farm: Farm) -> void:
	var fence := Catalogue.structure("fence")
	var from := Vector2i(6, 13)
	var to := Vector2i(12, 18)
	farm.build_run(fence, from, to)
	farm.build_gate(Catalogue.structure("gate"), Vector3i(FarmGrid.ACROSS_Z, 9, 18))
	farm.build(Catalogue.structure("trough"), Vector2i(7, 14))
	farm.build(Catalogue.structure("pond"), Vector2i(10, 14))
	farm.build(Catalogue.structure("compost_heap"), Vector2i(7, 16))
	farm.build(Catalogue.structure("sugar_bowl"), Vector2i(11, 16))
	farm.build(Catalogue.structure("shade_tree"), Vector2i(9, 17))
	farm.build(Catalogue.structure("prep_table"), Vector2i(14, 15))
	var fly := Catalogue.insect("fly")
	var middle := farm.grid.centre_of(Vector2i(9, 15))
	for i in 7:
		farm.add_insect(fly, middle + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-1.5, 1.5)),
			[0.2, 0.5, 1.0][i % 3])


## A grown fly, wrapped, on the table, washed and cooked.
func _kitchen(farm: Farm) -> void:
	var table := farm.structure_at(Vector2i(14, 15)) as PrepTable
	var fly := farm.add_insect(Catalogue.insect("fly"), table.global_position + Vector3(0.0, 1.5, 0.0), 1.0)
	fly.quality = 0.7
	fly.wrap()
	table.take_on(fly)
	table.apply(Prep.Step.WASH)
	table.apply(Prep.Step.TENDERISE)
	table.apply(Prep.Step.COOK)
