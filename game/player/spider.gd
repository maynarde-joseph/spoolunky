class_name SpiderPlayer
extends Player

## The spider: a magic spider with a fly farm to run.
##
## Extends the character-controller template's player with what makes it a
## spider: it walks up walls as if they were the floor (see [SpiderClimb]), it
## grapples anywhere it can see on a thread of silk ([SpiderGrapple]), and it
## casts — silk to catch with, and the rest of its spells to cook with
## ([SpiderSpells]). A catch goes on a line ([SilkTether]) to a prep table, comes
## off it as a dish into the bag ([SpiderInventory]), and the bag is emptied at the
## market. What the farm is built from is put down by the [FarmBuilder], which the
## shop sends it out with.
##
## Each job is a child node of its own; this one reads the keys and hands them
## out.

## Something worth putting on screen happened.
signal notice(text: String)

## Fell out of the world and got put back.
signal respawned()

## The shop was asked for. The HUD owns the screen; this only says that the key was
## pressed.
signal shop_toggled()

@export var input_grapple := "grapple"
@export var input_cast := "cast"
@export var input_interact := "interact"
@export var input_let_go := "let_go"
@export var input_shop := "shop"
@export var input_rotate := "build_rotate"
@export var input_demolish := "demolish"
@export var input_toggle_camera := "toggle_camera"
@export var input_cycle_look := "cycle_look"
@export var input_next_spell := "spell_next"
@export var input_prev_spell := "spell_prev"
@export var input_spell_disc := "spell_disc"

## How tall the body is, in metres. Its collider, its eye height, its stride and
## the camera's distance all follow from this.
@export var body_height := 0.7

## Ground speed, in metres a second, and how hard a jump pushes off.
@export var move_speed := 3.8
@export var jump_velocity := 10.0

## How far away something can be and still be within reach of F, in metres.
@export var interact_reach := 3.0

## How much the view opens up at speed. Pure sugar, and most of what makes a
## grapple feel fast.
@export var speed_fov_gain := 18.0

## Falling below this puts the spider back where it started.
@export var kill_plane := -60.0

## Ignore the spider's keys while the mouse is free, so clicking round a menu does
## not throw silk. Off for automated tests and headless runs, where the display
## server cannot capture the mouse at all.
@export var require_captured_mouse := true

@onready var climb: SpiderClimb = $Climb
@onready var grappler: SpiderGrapple = $Grapple
@onready var view: SpiderCamera = $View
@onready var body: SpiderBody = $Body
@onready var bag: SpiderInventory = $Bag
@onready var tether: SilkTether = $Tether
@onready var spells: SpiderSpells = $Spells
## The ring of spells held up round the cross, with the world slowed, while its key
## is down.
@onready var disc: SpiderDisc = $Disc
@onready var builder: FarmBuilder = $Builder

var _spawn_transform: Transform3D
var _base_fov := 0.0

## Whether the disc was brought up by its key, and whether that key has been seen
## held since: a disc left up is a world left slowed, so a lost key-up is watched
## for. See [method _watch_the_disc].
var _disc_from_key := false
var _disc_key_seen := false


func _ready() -> void:
	super()
	add_to_group("spider")
	_spawn_transform = global_transform

	# The template shares these shapes between every instance of the scene, and
	# sizing the body edits them in place — so take our own copies first.
	collision.shape = collision.shape.duplicate()
	head_check.shape = head_check.shape.duplicate()

	collision_layer = GameLayers.PLAYER
	collision_mask = GameLayers.WORLD

	view.setup(self, get_node_or_null("Head/FirstPersonCameraReference"))
	view.face(-global_basis.z)
	climb.setup(self, view)
	grappler.setup(self, view, climb)
	tether.setup(self, view, climb)
	spells.setup(self, view)
	disc.setup(self, spells)
	builder.setup(self, view)
	if body != null:
		body.setup(self)
	for part: Node in [grappler, tether, spells, builder]:
		part.connect("notice", notify)
	_apply_size()


func _physics_process(delta: float) -> void:
	var active := accepts_input()
	var input_axis := Vector2.ZERO
	var jump_tapped := false
	var jump_held := false
	var sprint := false
	if active:
		input_axis = Input.get_vector(input_left_action_name, input_right_action_name,
			input_back_action_name, input_forward_action_name)
		jump_tapped = Input.is_action_just_pressed(input_jump_action_name)
		jump_held = Input.is_action_pressed(input_jump_action_name)
		sprint = Input.is_action_pressed(input_sprint_action_name)

	# Keep the rig current before anything asks it which way forward is.
	view.update(body_height, climb.view_up())
	climb.update_orientation(delta)

	if climb.handles_movement():
		# Spiders do not obey the floor, so the climb component drives the body and
		# the template's bob and footstep bookkeeping is fed by hand.
		sprint_ability.set_active(sprint)
		climb.step(delta, input_axis, jump_tapped, sprint)
		_horizontal_velocity = climb.tangent_velocity
		_check_landed()
		if climb.is_attached():
			_check_step(delta)
		_check_head_bob(delta, input_axis)
	else:
		# Swimming stays with the character controller.
		climb.release()
		move(delta, input_axis, jump_tapped, false, sprint, false, jump_held)

	if global_position.y < kill_plane:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO
		disc.settle()
		climb.stand_upright()
		view.settle()
		respawned.emit()
		notify("Fell out of the world — put you back")


## Mouse look goes straight to the camera rig, which keeps it in world terms. The
## body then turns to follow the camera rather than the other way round — that is
## what stops the mouse axes scrambling when you walk onto a wall. While the disc
## is up the mouse moves its pointer instead, and the view holds still.
func rotate_head(mouse_axis: Vector2) -> void:
	if disc != null and disc.is_open:
		disc.steer(mouse_axis)
		return
	view.look(mouse_axis)


## Whether keys should reach the spider at all.
func accepts_input() -> bool:
	return not require_captured_mouse or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not accepts_input():
		return
	if builder.active and _building_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(input_grapple):
		grapple()
	elif event.is_action_pressed(input_cast):
		# Nothing is cast from behind the disc: the pointer is where the mouse is.
		if not disc.is_open:
			spells.begin_cast()
	elif event.is_action_released(input_cast):
		spells.release_cast()
	elif event.is_action_pressed(input_interact):
		interact()
	elif event.is_action_pressed(input_let_go):
		if tether.is_towing():
			tether.cut()
	elif event.is_action_pressed(input_demolish):
		builder.demolish_aimed()
	# Tab held, the disc: the spells in a ring round the cross, and the world slowed
	# while you choose. Letting go takes whatever the pointer is on; a tap swaps back
	# to the spell in hand before this one.
	elif event.is_action_pressed(input_spell_disc):
		_disc_from_key = disc.open()
		_disc_key_seen = false
	elif event.is_action_released(input_spell_disc):
		_disc_from_key = false
		disc.close()
	elif event.is_action_pressed(input_next_spell):
		spells.cycle(1)
	elif event.is_action_pressed(input_prev_spell):
		spells.cycle(-1)
	elif _spell_key_input(event):
		pass
	elif event.is_action_pressed(input_shop):
		shop_toggled.emit()
	elif event.is_action_pressed(input_toggle_camera):
		view.toggle_mode()
		notify("Camera: %s" % ("third person" if view.third_person else "first person"))
	elif event.is_action_pressed(input_cycle_look) and body != null:
		body.cycle_look()
		notify("Spider: %s" % body.look_name())
	else:
		return
	get_viewport().set_input_as_handled()


## The mouse buttons and R while building: left puts down, right puts away, R
## turns. Returns whether the event was one of them.
func _building_input(event: InputEvent) -> bool:
	if event.is_action_pressed(input_grapple):
		builder.place()
	elif event.is_action_pressed(input_cast):
		builder.stop()
	elif event.is_action_pressed(input_rotate):
		builder.rotate_piece()
	else:
		return false
	return true


## The grapple: a bundle under the cross comes to you on a line; anything else is
## somewhere to go, and you go there. True if anything went.
func grapple() -> bool:
	if tether.take_aimed():
		return true
	return grappler.fire()


## The number keys: each takes its spell in hand. Returns whether the event was one
## of them.
func _spell_key_input(event: InputEvent) -> bool:
	for key in range(1, 10):
		if InputMap.has_action("spell_%d" % key) and event.is_action_pressed("spell_%d" % key):
			spells.take(key)
			return true
	return false


# --- F --------------------------------------------------------------------

## F: does whatever there is to do to the thing in front of you — opens a gate,
## takes a dish off a table, sells at the market, cuts a bundle free. Returns
## whether anything happened.
func interact() -> bool:
	var target := aimed_interactable()
	if target == null:
		notify("Nothing to do here")
		return false
	if target is Insect:
		var bundle := target as Insect
		if not bundle.steps.is_empty():
			# Something the kitchen has started on is a dish wherever it lies.
			if bag.is_full():
				notify("Your bag is full — sell what is in it at the market")
				return false
			var dish := bundle.take()
			bag.add(dish)
			notify("%s — %d coins at market" % [dish.label(), dish.value()])
			return true
		var why := bundle.cut_free()
		if why.is_empty():
			notify("Cut the %s free" % bundle.kind.display_name.to_lower())
			return true
		notify(why)
		return false
	return bool(target.call("interact", self))


## What F would act on: the thing under the cross if it is near enough, or else the
## nearest thing in front of the spider that F does something to.
func aimed_interactable() -> Node3D:
	if view == null or view.camera == null or not is_inside_tree():
		return null
	var camera := view.camera
	var from := camera.global_position
	var reach := camera.global_position.distance_to(global_position) + interact_reach
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * reach,
		GameLayers.WORLD | GameLayers.INSECT, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var found := _interactable_under(hit.get("collider"))
		if found != null and _within_reach(found):
			return found
	# Nothing under the cross: the nearest thing in front, within reach.
	var best: Node3D = null
	var nearest := INF
	var ahead := -view.forward()
	ahead = Vector3(-ahead.x, 0.0, -ahead.z).normalized()
	for group in [FarmStructure.GROUP, MarketStall.GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node3D
			if thing == null or not _does_something(thing) or not _within_reach(thing):
				continue
			var off := thing.global_position - global_position
			off.y = 0.0
			if off.length() > 0.01 and off.normalized().dot(ahead) < 0.2:
				continue
			if off.length() < nearest:
				nearest = off.length()
				best = thing
	return best


func _interactable_under(collider: Variant) -> Node3D:
	var node := collider as Node
	while node != null:
		var insect := node as Insect
		if insect != null:
			if insect.table != null:
				return insect.table
			return insect if insect.is_bundle() else null
		if node is FarmStructure or node is MarketStall:
			return node as Node3D if _does_something(node as Node3D) else null
		node = node.get_parent()
	return null


## Whether F does anything to [param thing]: a gate, a table, the market.
func _does_something(thing: Node3D) -> bool:
	if thing is MarketStall or thing is PrepTable or thing is Trough or thing is CropPlot:
		return true
	return thing is Fence and (thing as Fence).is_gate


func _within_reach(thing: Node3D) -> bool:
	var off := thing.global_position - global_position
	var extra := 0.0
	if thing is FarmStructure:
		extra = (thing as FarmStructure).reach_radius()
	elif thing is MarketStall:
		extra = 1.8
	return Vector2(off.x, off.z).length() <= interact_reach + extra


## What F would do now, for the readout under the cross: empty if nothing.
func interact_hint() -> String:
	var target := aimed_interactable()
	if target == null:
		return ""
	if target is Insect:
		var bundle := target as Insect
		if not bundle.steps.is_empty():
			var dish := bundle.as_dish()
			return "F — take the %s (%d)" % [dish.title(), dish.value()]
		return "F — cut the %s free" % bundle.kind.display_name.to_lower()
	return String(target.call("interact_hint", self))


# --- every frame ------------------------------------------------------------

func _process(delta: float) -> void:
	_watch_the_disc()
	_take_aim(delta)
	climb.haul = tether.drag_factor()
	view.update(body_height, climb.view_up())
	_rush(delta)
	if body != null:
		body.visible = view.third_person
		body.animate(delta, _horizontal_velocity.length())


## Winds the spell in hand up while the cast key is held, and lets go on the
## player's behalf if the key-up never came — the mouse freed mid-wind-up is
## enough to lose one.
func _take_aim(delta: float) -> void:
	if not spells.charging:
		return
	if accepts_input() and Input.is_action_pressed(input_cast) and not builder.active:
		spells.track(delta)
	else:
		spells.release_cast()


## Opens the view up with speed. The speed is the one along the surface, which is
## the movement the spider actually asked for and the same number the legs are
## animated from.
func _rush(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if _base_fov <= 0.0:
		_base_fov = camera.fov
	var reference: float = maxf(move_speed * 2.5, 0.001)
	var rush := clampf(_horizontal_velocity.length() / reference - 0.2, 0.0, 1.0)
	# Winding a spell up widens the view, over the spider's back where it is going.
	var aiming := clampf(view.aim_blend, 0.0, 1.0) * view.aim_fov_gain
	camera.fov = lerpf(camera.fov, _base_fov + rush * speed_fov_gain + aiming,
		clampf(delta * 6.0, 0.0, 1.0))


## Puts the disc away when its key is no longer down, in case the key-up was lost.
## Only once the key has been seen held, so a disc brought up some other way is
## left alone.
func _watch_the_disc() -> void:
	if not disc.is_open:
		_disc_from_key = false
		return
	if not _disc_from_key:
		return
	if Input.is_action_pressed(input_spell_disc):
		_disc_key_seen = true
		return
	if not _disc_key_seen:
		return
	_disc_from_key = false
	disc.close()


## Somewhere for anything on the farm to put a message.
func notify(text: String) -> void:
	notice.emit(text)


## Thrown, at [param push], off whatever it was standing on.
func fling(push: Vector3) -> void:
	climb.fling(push)


## Sizes the body to [member body_height]: collider, eye, stride and speed.
func _apply_size() -> void:
	var height := body_height
	climb.body_height = height
	var capsule := collision.shape as CapsuleShape3D
	if capsule != null:
		# Squat and wide, like a spider — and short enough end to end that rolling
		# onto a wall does not sweep the collider through it.
		capsule.radius = height * 0.35
		capsule.height = height
	var head_sphere := head_check.shape as SphereShape3D
	if head_sphere != null:
		head_sphere.radius = height * 0.2
	head_check.target_position = Vector3(0, height * 0.25, 0)
	# Eye height keeps the template's proportions (0.64 on a 2m capsule).
	head.position.y = height * 0.32
	head_bob.bob_range = Vector2(0.07, 0.07) * (height / 2.0)
	_default_height = height
	height_in_crouch = height * 0.8
	crouch_ability.default_height = height
	crouch_ability.height_in_crouch = height_in_crouch
	speed = move_speed
	_normal_speed = move_speed
	jump_height = jump_velocity
	jump_ability.height = jump_velocity
	floor_snap_length = height * 0.25
	step_interval = maxf(height * 3.0, 1.0)
	# The template's water probe is a fixed two metres long: scale it with the body.
	var water_probe := swim_ability.get_node_or_null("RayCast3D") as RayCast3D
	if water_probe != null:
		water_probe.position = Vector3(0, height * 0.5, 0)
		water_probe.target_position = Vector3(0, -height, 0)
	if body != null:
		body.set_body_height(height)
