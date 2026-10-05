extends SceneTree

## Renders the farm to PNG files, for checking how it reads without playing it.
## Needs a display; on a headless machine run it through xvfb:
##
##     xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 \\
##         --path . --script res://tests/screenshot_farm.gd -- stocked
##
## `start` photographs the farm as a new game finds it: the starter pen. `stocked`
## adds crops, a compost heap, a sugar bowl and a few wild flies drawn in, and puts
## a wrapped fly half-cooked on the starter's prep table, and photographs that.
## The shots land in the user data folder as `farm_<setup>_<view>.png`; the paths
## are printed on the way out.

const VIEWS := {
	"start": [],
	"above": [Vector3(-22.0, 26.0, 30.0), Vector3(-2.0, 0.0, 10.0)],
	"pen": [Vector3(-10.0, 4.5, 18.5), Vector3(-4.0, 0.6, 10.0)],
	"crops": [Vector3(4.0, 3.0, 18.0), Vector3(2.0, 0.4, 10.0)],
	"kitchen": [Vector3(3.6, 2.4, 16.4), Vector3(3.0, 0.8, 13.0)],
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


## Crops beside the starter pen, a compost heap and a sugar bowl in it, and wild
## flies drawn in.
func _stock(farm: Farm) -> void:
	farm.build(Catalogue.structure("melon_patch"), Vector2i(13, 15))
	farm.build(Catalogue.structure("berry_bush"), Vector2i(14, 15))
	farm.build(Catalogue.structure("herb_bed"), Vector2i(13, 16))
	farm.build(Catalogue.structure("compost_heap"), Vector2i(9, 18))
	farm.build(Catalogue.structure("sugar_bowl"), Vector2i(11, 15))
	for built in farm.structures():
		if built is CropPlot:
			(built as CropPlot).growth = 0.9
	for i in 4:
		farm.call_wild()


## A grown fly, wrapped, on the starter's table, washed, tenderised and cooked.
func _kitchen(farm: Farm) -> void:
	var table: PrepTable = null
	for built in farm.structures():
		if built is PrepTable:
			table = built
	var fly := farm.add_insect(Catalogue.insect("fly"), table.global_position + Vector3(0.0, 1.5, 0.0), 1.0)
	fly.quality = 0.7
	fly.wrap()
	table.take_on(fly)
	table.apply(Prep.Step.WASH)
	table.apply(Prep.Step.TENDERISE)
	table.apply(Prep.Step.COOK)
