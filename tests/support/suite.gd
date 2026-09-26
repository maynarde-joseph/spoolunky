class_name TestSuite
extends SceneTree

## What every headless suite shares: the count, the verdict, and the handful of
## things a test does over and over.
##
## Each of the three suites had grown its own copy of check and finish, and they
## had drifted: one freed the level, one awaited two frames first, one took the
## level as an argument, and only one of them released held input between
## sections. A wrong verdict is the one bug a test suite cannot catch about
## itself, so it lives in one place now.
##
## A suite extends this, overrides [method run_checks], and gets the rest. The
## entry point still works the usual way:
##
##     godot --headless --script res://tests/world_smoke_test.gd
##
## One wrinkle worth knowing, because it looks like a broken suite: a new
## class_name does not resolve until the project has been imported, so a suite
## added in a fresh checkout reports `Could not find base class "TestSuite"`
## until `godot --headless --path . --import` has run once. The session hook
## does that at startup and so does CI.

var checks := 0
var failures := 0

## The scene under test, if the suite opened it through [method open]. Held so
## the verdict can tear it down even when a suite returns early.
var scene: Node


func _initialize() -> void:
	_drive.call_deferred()


func _drive() -> void:
	await run_checks()
	await _report()


## What a suite fills in. Everything else here is in service of it.
func run_checks() -> void:
	push_error("a suite has to override run_checks()")


# --- the verdict ---------------------------------------------------------

## Records one check and says how it went. Returns the condition, so a check
## that everything after it depends on can guard the rest:
##
##     if not check(spider != null, "the level has a spider in it"):
##         return
func check(condition: bool, message: String) -> bool:
	checks += 1
	if condition:
		print("  ok    %s" % message)
	else:
		failures += 1
		print("  FAIL  %s" % message)
	return condition


## An aside — a measurement, or a list of what was found. Indented past the
## checks and never counted, so reading down the left edge still gives the
## result and nothing else.
func note(text: String) -> void:
	print("        (%s)" % text)


func _report() -> void:
	# Input first: a suite that ended mid-press leaves a key down in global state,
	# and a body still being driven while the tree is torn down is a crash rather
	# than a failure.
	release_all()
	close()
	# Two frames for the queue to actually run the frees, so a node still in the
	# tree at exit does not get reported as a leak against the suite.
	await process_frame
	await process_frame
	print("")
	if failures == 0:
		print("%d checks passed" % checks)
	else:
		print("%d of %d checks FAILED" % [failures, checks])
	quit(1 if failures > 0 else 0)


# --- the scene ----------------------------------------------------------

## Loads a scene, makes it current and lets physics settle. Returns null and
## fails a check if the scene will not load, which is worth one line of its own:
## a suite whose level has gone missing otherwise fails at whatever it looked
## for first.
func open(path: String) -> Node:
	var packed := load(path) as PackedScene
	if not check(packed != null, "%s loads" % path.get_file()):
		return null
	close()
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	await process_frame
	return scene


## Puts a scene built in code under test, the same way [method open] does with
## one off disk.
func stage(node: Node) -> Node:
	close()
	scene = node
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	return scene


## Tears down whatever is staged. Safe to call when nothing is.
func close() -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.free()
	scene = null


# --- time and input -----------------------------------------------------

## Lets [param count] physics frames pass.
##
## Named the long way round on purpose: three tests already have a local called
## `frames`, and a local shadowing a method is a parse error at the call rather
## than at the declaration, which is a nasty half hour for whoever hits it.
func run_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Waits for something to become true, up to [param max_frames]. Returns
## whether it did, so the caller can check the result rather than the wait —
## which keeps a slow machine from reading as a broken game.
func wait_until(test: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if test.call():
			return true
		await physics_frame
	return test.call()


## Fires an action the way a device would, as an event through _input rather
## than as a flag on the Input singleton — which is the only way to test that
## something is actually wired to the action, instead of polling for it.
##
## Flushed immediately because input is accumulated by default: without this the
## event does not arrive until the frame after the one the caller is checking.
func send_action(action: StringName) -> void:
	_post(action, true)


## The matching release, for an action held across several frames.
func release_action(action: StringName) -> void:
	_post(action, false)


func _post(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Lets go of everything. Input is global state that outlives the test that set
## it, so a section ending mid-press used to walk the spider through the next
## one — which is the kind of failure that gets read as a game bug.
func release_all() -> void:
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --- looking around ----------------------------------------------------

## Every node below this one, the whole way down.
func all_under(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if not is_instance_valid(node):
		return found
	for child in node.get_children():
		found.append(child)
		found.append_array(all_under(child))
	return found
