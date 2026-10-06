class_name LevelRun
extends Node3D

## A level being played: built from its data, with the spider in it, the clock
## running, and the bag waiting at the exit.
##
## The clock starts the first time the spider moves. The exit opens when the
## spider has the flies the level asks for — all of them, unless it says fewer.
## Fall out of the level or touch the red and it starts again at once: a restart
## is a key away (R) and costs nothing but the time.

## Done: the flies are in the bag. [param best] is the best time before this one,
## or a negative number for none.
signal finished(time: float, best: float)

## Asked to start again: a fall, a hazard, or R.
signal restart_requested()

const GROUP := "level_run"
const PROGRESS := "user://progress.json"

var level: Dictionary = {}

## The file it came from, which best times are kept under. Empty for a level that
## has never been saved.
var source := ""

var weaver: Weaver
var exit: ExitBag
var hud: GameHUD
var world: Node3D

var flies_total := 0
var flies_needed := 0
var time := 0.0
var running := false
var done := false

## Whether keys need the mouse caught. Off for headless checks.
var require_captured_mouse := true

var _channels := {}
var _start := Transform3D.IDENTITY


## The level [param node] is playing in, if any.
static func current(node: Node) -> LevelRun:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as LevelRun


func setup(data: Dictionary, from_path := "") -> void:
	level = data
	source = from_path


func _ready() -> void:
	add_to_group(GROUP)
	LevelSky.dress(self)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	LevelBuilder.build(level, world, false)
	for node in get_tree().get_nodes_in_group(LevelBuilder.GROUP):
		if not world.is_ancestor_of(node):
			continue
		var thing: Dictionary = node.get_meta(LevelBuilder.THING)
		match String(thing.get("type", "")):
			"start":
				_start = (node as Node3D).global_transform
			"exit":
				exit = node as ExitBag
	flies_total = get_tree().get_nodes_in_group(Fly.GROUP).filter(
		func(n: Node) -> bool: return world.is_ancestor_of(n)).size()
	var asked := int(level.get("flies_needed", 0))
	flies_needed = flies_total if asked <= 0 else mini(asked, flies_total)

	weaver = Weaver.new()
	weaver.name = "Weaver"
	weaver.max_webs = maxi(int(level.get("webs", 3)), 1)
	weaver.kill_y = float(level.get("kill_y", -20.0))
	weaver.require_captured_mouse = require_captured_mouse
	weaver.container = world
	add_child(weaver)
	weaver.put_at(_start.translated(Vector3.UP * 0.4))
	weaver.fell.connect(func() -> void: lose("Fell"))
	if exit != null:
		exit.entered.connect(_try_exit)
		exit.set_open(flies_needed == 0)

	hud = GameHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)


func _physics_process(delta: float) -> void:
	if done:
		return
	if not running and (weaver.moving_velocity().length() > 0.5 or weaver.webs().size() > 0):
		running = true
	if running:
		time += delta
	if exit != null:
		var open := caught() >= flies_needed
		if open != exit.open:
			exit.set_open(open)
			if open and flies_needed > 0:
				weaver.notify("The bag is open — get to the exit")
		if open and exit.holds(weaver):
			_try_exit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()


## How many flies are on the spider's line.
func caught() -> int:
	return weaver.fly_line.count() if weaver != null else 0


## Powers [param channel] on or off — a plate pressed or let up. A channel is on
## while anything is powering it.
func power(channel: String, on: bool) -> void:
	if channel == "":
		return
	var count := int(_channels.get(channel, 0)) + (1 if on else -1)
	_channels[channel] = maxi(count, 0)


func is_powered(channel: String) -> bool:
	return int(_channels.get(channel, 0)) > 0


## Lost: start again.
func lose(reason: String) -> void:
	if done:
		return
	weaver.notify(reason)
	restart_requested.emit()


func _try_exit() -> void:
	if done or exit == null or caught() < flies_needed:
		if exit != null and not done and caught() < flies_needed:
			weaver.notify("The bag wants %d more fl%s" % [flies_needed - caught(),
				"y" if flies_needed - caught() == 1 else "ies"])
		return
	done = true
	weaver.fly_line.pour_into(exit.mouth())
	var best := best_time()
	if source != "" and (best < 0.0 or time < best):
		_keep_best(time)
	finished.emit(time, best)


## The best time this level has been done in, or a negative number.
func best_time() -> float:
	return LevelRun.best_for(source)


static func best_for(path: String) -> float:
	if path == "":
		return -1.0
	var all := _progress()
	return float(all.get(path, -1.0))


func _keep_best(seconds: float) -> void:
	var all := _progress()
	all[source] = snappedf(seconds, 0.001)
	var file := FileAccess.open(PROGRESS, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(all, "\t"))


static func _progress() -> Dictionary:
	var text := FileAccess.get_file_as_string(PROGRESS)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}
