class_name SpiderPlayer
extends Player

## The spider.
##
## Extends the character-controller template's player with the four things
## that make this game a spider game: a body that grows when it eats, webs it
## can shoot, lines it can run, and the ability to walk up a wall as if it were
## the floor.
##
## Growth is applied physically rather than as a stat line — the collider, the
## eye height, the stride and the camera's near plane all move with the size
## tier, so the room really does shrink around you.

## Something worth putting on screen happened.
signal notice(text: String)

## The spider changed size tier.
signal grew(stage: GrowthStage, index: int)

## Fell out of the world and got put back.
signal respawned()
## Something got a bite in. [param left] is 0 to 1.
signal hurt(amount: float, left: float)
## Driven off: the meal is gone, the line is cut and you have been thrown clear.
signal routed()

## The player asked for the tree. The HUD owns the screen; this only says
## that the key was pressed.
signal skill_tree_toggled()

@export var input_build_mode := "web_build_mode"
@export var input_place_anchor := "web_place"
@export var input_cancel_anchor := "web_cancel"
@export var input_finish_web := "web_finish"
@export var input_next_pattern := "web_next_pattern"
@export var input_prev_pattern := "web_prev_pattern"
@export var input_remove_web := "web_remove"
@export var input_link_web := "web_link"
@export var input_save_design := "web_save_design"
@export var input_design_mode := "web_design_mode"
@export var input_dial_select := "web_dial_select"
@export var input_dial_down := "web_dial_down"
@export var input_dial_up := "web_dial_up"
@export var input_dial_reset := "web_dial_reset"
@export var input_weave_toggle := "web_weave_toggle"
@export var input_ride := "web_ride"
@export var input_toggle_camera := "toggle_camera"
@export var input_device_mode := "device_mode"
@export var input_throw_mode := "web_throw_mode"
@export var input_tether := "web_tether"
@export var input_shoot := "web_shoot"
@export var input_skill_tree := "skill_tree"

## How much the view opens up at speed. Pure sugar, and most of what makes a
## zipline feel fast.
@export var speed_fov_gain := 18.0

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

## Biomass swallowed per second, at a bite power of one.
##
## A meal is a few seconds you spend standing still, and that is the whole point
## of it: eating used to be one click and instantly over, which meant nowhere was
## safer than anywhere else and a web was decoration. Scaled by bite power, so
## growing does not turn a fly into a sitting.
@export var feed_rate := 3.4
@export var input_interact := "interact"

## Falling below this puts the spider back where it started.
@export var kill_plane := -60.0

## Ignore build and feeding input while the mouse is free, so clicking around a
## menu doesn't spin a web. Turn off for automated tests and headless runs,
## where the display server cannot capture the mouse at all.
@export var require_captured_mouse := true

@onready var growth: SpiderGrowth = $Growth
@onready var web_builder: WebBuilder = $WebBuilder
@onready var climb: SpiderClimb = $Climb
@onready var view: SpiderCamera = $View
@onready var body: SpiderBody = $Body
@onready var bag: SpiderInventory = $Bag
@onready var device_placer: DevicePlacer = $DevicePlacer
@onready var tether: SilkTether = $Tether
@onready var traits: SpiderTraits = $Traits

var _spawn_transform: Transform3D
var _stage: GrowthStage
var _tier := -1
var _pitch := 0.0
var _base_fov := 0.0

## Whether the web now growing was started by the place key, and whether that
## key has actually been seen held down since. The release poll needs both:
## it exists to catch a swallowed key-up, and must not touch a placement
## something else started, nor fire before the key has ever registered.
var _placing_from_key := false
var _place_key_seen := false


func _ready() -> void:
	super()
	add_to_group("spider")
	_spawn_transform = global_transform

	# The template shares these shapes between every instance of the scene,
	# and growing edits them in place — so take our own copies first.
	collision.shape = collision.shape.duplicate()
	head_check.shape = head_check.shape.duplicate()

	collision_layer = GameLayers.PLAYER
	collision_mask = GameLayers.WORLD | GameLayers.WEB_WALK

	view.setup(self, get_node_or_null("Head/FirstPersonCameraReference"))
	view.face(-global_basis.z)
	climb.setup(self, growth, view)
	web_builder.setup(self, growth, view, climb)
	device_placer.setup(self, bag, growth, view)
	tether.setup(self, growth, view, climb)
	growth.shaped_by(traits)
	web_builder.notice.connect(_on_notice)
	device_placer.notice.connect(_on_notice)
	climb.notice.connect(_on_notice)
	tether.notice.connect(_on_notice)
	climb.jumped.connect(_on_jumped)
	climb.line_dropped.connect(_on_line_dropped)
	climb.line_cut.connect(_on_line_cut)
	growth.stage_changed.connect(_on_stage_changed)
	growth.apply_initial()
	health = max_stamina()


func _physics_process(delta: float) -> void:
	var active := _accepts_input()
	var input_axis := Vector2.ZERO
	var jump_tapped := false
	var jump_held := false
	var sprint := false
	var down := false
	var release_line := false

	if active:
		input_axis = Input.get_vector(input_left_action_name, input_right_action_name,
			input_back_action_name, input_forward_action_name)
		jump_tapped = Input.is_action_just_pressed(input_jump_action_name)
		jump_held = Input.is_action_pressed(input_jump_action_name)
		sprint = Input.is_action_pressed(input_sprint_action_name)
		down = Input.is_action_pressed(input_crouch_action_name)
		# Right mouse means "undo anchor" while building, "let go" while hanging.
		release_line = not _web_tool_active() and not _device_tool_active() \
			and Input.is_action_just_pressed(input_cancel_anchor)
		if Input.is_action_just_pressed(input_fly_mode_action_name):
			fly_ability.set_active(not fly_ability.is_actived())

	# Keep the rig current before anything asks it which way forward is.
	view.update(stage().body_height)
	climb.update_orientation(delta)

	if climb.handles_movement():
		# Spiders don't obey the floor, so the climb component drives the body
		# and we feed the template's bob and footstep bookkeeping by hand.
		sprint_ability.set_active(sprint and climb.is_attached() and input_axis.y >= 0.5)
		climb.step(delta, input_axis, jump_tapped, sprint, down, jump_held, release_line)
		_horizontal_velocity = climb.tangent_velocity
		_check_landed()
		if climb.is_attached():
			_check_step(delta)
		_check_head_bob(delta, input_axis)
	else:
		# Swimming and free-fly stay with the character controller.
		climb.release()
		move(delta, input_axis, jump_tapped, down, sprint, down, jump_held)

	if global_position.y < kill_plane:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO
		climb.release()
		respawned.emit()
		notice.emit("Fell out of the world — put you back")


## Mouse look goes straight to the camera rig, which keeps it in world terms.
## The body then turns to follow the camera rather than the other way round —
## that is what stops the mouse axes scrambling when you walk onto a wall.
func rotate_head(mouse_axis: Vector2) -> void:
	view.look(mouse_axis)


## True while the web builder owns the mouse buttons — spinning a web by hand
## or lining up a saved design.
func _web_tool_active() -> bool:
	return web_builder.building or web_builder.placing_design


## True while place mode owns the mouse buttons.
func _device_tool_active() -> bool:
	return device_placer != null and device_placer.active


func _accepts_input() -> bool:
	return not require_captured_mouse or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return

	if event.is_action_pressed(input_device_mode):
		device_placer.toggle()
		if device_placer.active and web_builder.building:
			web_builder.stop()
	elif event.is_action_pressed(input_build_mode):
		if device_placer.active:
			device_placer.stop()
		_placing_from_key = web_builder.begin_place()
		_place_key_seen = false
	elif event.is_action_released(input_build_mode):
		_placing_from_key = false
		web_builder.commit_place()
	elif _device_tool_active() and event.is_action_pressed(input_next_pattern):
		device_placer.cycle(1)
	elif _device_tool_active() and event.is_action_pressed(input_prev_pattern):
		device_placer.cycle(-1)
	elif event.is_action_pressed(input_next_pattern):
		web_builder.cycle(1)
	elif event.is_action_pressed(input_prev_pattern):
		web_builder.cycle(-1)
	elif event.is_action_pressed(input_interact):
		_interact()
	elif event.is_action_pressed(input_remove_web):
		# Taking a device back is reversible and pulling a web down is not, so a
		# device under the crosshair always wins — including when the bag is too
		# full to take it, which must not silently tear the web down instead.
		if device_placer.aimed_device() != null:
			device_placer.pick_up_aimed()
		else:
			web_builder.demolish_aimed()
	elif event.is_action_pressed(input_link_web):
		web_builder.toggle_link()
	elif event.is_action_pressed(input_save_design):
		web_builder.save_aimed_design()
	elif event.is_action_pressed(input_design_mode):
		web_builder.toggle_design_mode()
	elif event.is_action_pressed(input_dial_select):
		web_builder.cycle_dial(1)
	elif event.is_action_pressed(input_dial_down):
		web_builder.adjust_dial(-1)
	elif event.is_action_pressed(input_dial_up):
		web_builder.adjust_dial(1)
	elif event.is_action_pressed(input_dial_reset):
		web_builder.reset_dials()
	elif event.is_action_pressed(input_weave_toggle):
		web_builder.toggle_weave()
	elif event.is_action_pressed(input_throw_mode):
		web_builder.toggle_throwing()
	elif event.is_action_pressed(input_tether):
		tether.toggle()
	# Right mouse is the web. A tap fires straight away; holding it drops you
	# into first person to aim, and a second held on a creature promises it.
	elif event.is_action_pressed(input_shoot):
		web_builder.begin_shot()
	elif event.is_action_released(input_shoot):
		web_builder.release_shot()
	elif event.is_action_pressed(input_skill_tree):
		skill_tree_toggled.emit()
	elif _hotbar_input(event):
		pass
	elif event.is_action_pressed(input_toggle_camera):
		view.toggle_mode()
		notice.emit("Camera: %s" % ("third person" if view.third_person else "first person"))
	elif _device_tool_active() and event.is_action_pressed(input_place_anchor):
		device_placer.place()
	elif _device_tool_active() and event.is_action_pressed(input_cancel_anchor):
		device_placer.stop()
	# Left mouse is always "silk connects me to that". What it does depends on
	# what you pointed at, not on a mode you are in: a surface pulls you over
	# to it, a line puts you on it, and something you have already caught comes
	# to you instead — which is the same act read the only way that makes sense
	# for a thing that is already wrapped up and going nowhere.
	elif event.is_action_pressed(input_place_anchor):
		if not tether.grab_aimed():
			web_builder.place()
	elif _web_tool_active() and event.is_action_pressed(input_cancel_anchor):
		web_builder.undo()
	elif event.is_action_pressed(input_ride):
		climb.toggle_ride()
	else:
		return
	get_viewport().set_input_as_handled()


## The bar: nine numbered pockets and the wheel. Returns whether the event was
## one of them, so the caller can stop looking.
func _hotbar_input(event: InputEvent) -> bool:
	if bag == null:
		return false
	if event.is_action_pressed("hotbar_next"):
		bag.scroll(1)
		return true
	if event.is_action_pressed("hotbar_prev"):
		bag.scroll(-1)
		return true
	for slot in SpiderInventory.SLOTS:
		if event.is_action_pressed("hotbar_%d" % (slot + 1)):
			bag.select(slot)
			return true
	return false


func _process(delta: float) -> void:
	_watch_for_release()
	_take_aim(delta)
	_feed(delta)
	_mend(delta)
	climb.haul = tether.drag_factor()
	climb.glide = traits.glide() if traits != null else 0.0
	view.update(stage().body_height)
	_rush(delta)
	if body != null:
		body.visible = view.third_person
		body.animate(delta, _horizontal_velocity.length())


## Opens the view up: with speed, and with a throw being wound up.
##
## One owner for the field of view, because two things easing one number is two
## things fighting over it. Both terms add to the resting angle.
##
## The speed is the one along the surface, not [member velocity]. The two are
## close at rest, because move_and_slide absorbs the pull that holds a spider onto
## what it is standing on — but what it leaves behind is the *resolved* movement,
## so it picks up whatever a step or a slope slid the body sideways by. The
## along-surface velocity is the movement the spider actually asked for, which is
## the same number the legs are animated from, so now the view agrees with them.
func _rush(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if _base_fov <= 0.0:
		_base_fov = camera.fov
	var reference: float = maxf(stage().move_speed * 2.5, 0.001)
	var rush := clampf(_horizontal_velocity.length() / reference - 0.2, 0.0, 1.0)
	# Winding a throw up widens the view. Together with the raised pivot that is
	# the whole of the aim framing: the room opens out over the spider's back,
	# which is where the silk is about to go, and nothing had to move to do it.
	var aiming := clampf(view.aim_blend, 0.0, 1.0) * view.aim_fov_gain
	camera.fov = lerpf(camera.fov, _base_fov + rush * speed_fov_gain + aiming,
		clampf(delta * 6.0, 0.0, 1.0))


## Letting go spins the web. Watching the key as well as listening for its
## release event means a swallowed key-up cannot leave one growing for ever —
## but only after the key has been seen held, so this can never cut short a
## placement that was started some other way.
func _watch_for_release() -> void:
	if not _placing_from_key or not web_builder.placing:
		return
	if Input.is_action_pressed(input_build_mode):
		_place_key_seen = true
		return
	if not _place_key_seen:
		return
	_placing_from_key = false
	web_builder.commit_place()


## Feeds the lock while the shoot key is held, and lets go on your behalf if
## the key-up never arrived. Aiming can only start from the key, so a lost
## release would otherwise leave the spider staring down its own crosshair for
## ever — and the mouse being freed mid-aim is enough to lose one.
func _take_aim(delta: float) -> void:
	if not web_builder.aiming:
		return
	if _accepts_input() and Input.is_action_pressed(input_shoot):
		web_builder.track(delta)
		return
	web_builder.release_shot()


## Somewhere for a device across the level to put a message.
func notify(text: String) -> void:
	notice.emit(text)


## Current size tier.
func stage() -> GrowthStage:
	return growth.current_stage()


# --- taking a beating ---------------------------------------------------

## What the spider can take at this size. Bigger is tougher, which is the whole
## reward for growing: the thing that was hunting you last tier is food now.
func max_stamina() -> float:
	return stamina * maxf(stage().bite_power, 1)


## 0 to 1.
func condition() -> float:
	var top := max_stamina()
	return clampf(health / top, 0.0, 1.0) if top > 0.0 else 0.0


func is_hurt() -> bool:
	return condition() < 0.999


## Something bit you. Interrupts whatever you were drinking, because a meal you
## are being attacked during is exactly the meal you should not be finishing.
##
## [param from] is what did it, so being driven off can throw you away from it.
func take_bite(amount: float, from: Node3D = null) -> void:
	if amount <= 0.0:
		return
	_mending = mend_delay
	health = maxf(health - amount, 0.0)
	if feeding != null:
		_end_feed("Bitten — you lost the mouthful")
	hurt.emit(amount, condition())
	if health <= 0.0:
		_route(from)


## Driven off. Not death and not a reload: you lose the catch and the ground you
## had made, and you are thrown clear with nothing left to take another hit with
## for a few seconds. The cost of losing a fight is the trip home, which is
## enough — a sandbox with no save has no business killing you.
func _route(from: Node3D) -> void:
	if tether != null and tether.is_towing():
		tether.cut()
	var away := Vector3.UP
	if from != null and is_instance_valid(from):
		var off := global_position - from.global_position
		if off.length_squared() > 0.000001:
			away = off.normalized()
	climb.release()
	velocity = (away + Vector3.UP * 1.4).normalized() * stage().jump_velocity * 1.3
	routed.emit()
	notice.emit("Driven off — you dropped everything and ran")


## Comes back on its own after a quiet spell, so a bad trip costs you time
## rather than a restart.
func _mend(delta: float) -> void:
	if _mending > 0.0:
		_mending = maxf(0.0, _mending - delta)
		return
	var top := max_stamina()
	if health < top:
		health = minf(top, health + mend_rate * maxf(stage().bite_power, 1) * delta)


# --- feeding ------------------------------------------------------------

func _interact() -> void:
	var prey := _aimed_prey()
	if prey != null:
		_handle_prey(prey)
		return

	var web := web_builder.aimed_web()
	if web != null and web.needs_rearm():
		web.rearm()
		notice.emit("Snare set again")
		return

	notice.emit("Nothing in reach")


func _handle_prey(prey: Prey) -> void:
	var current := stage()
	if prey.size_class > current.bite_power and not prey.subdued:
		notice.emit("The %s is too big for you — grow first" % prey.species)
		return

	if prey.wrapped:
		_begin_feed(prey)
		return

	if prey.is_stuck():
		prey.wrap()
		notice.emit("Wrapped the %s" % prey.species)
		return

	# Much bigger than it? Then you can simply take it. Fangs halve what
	# "much" means: anything inside your bite power goes down where it stands,
	# which is the whole point of the venom branch — a kill that needs no web.
	var margin := 1 if traits != null and traits.has_fangs() else 2
	if current.bite_power >= prey.size_class * margin:
		_begin_feed(prey)
		return

	notice.emit("The %s isn't caught — get it into a web" % prey.species)


## Starts a meal. It finishes when the creature is empty or when you let go.
func _begin_feed(prey: Prey) -> bool:
	if prey == null or not is_instance_valid(prey) or prey.eaten:
		return false
	feeding = prey
	_meal = 0.0
	_meal_species = prey.species
	# Said on the way in, because a tap now takes a mouthful rather than the
	# whole creature, and without this a tap would look like nothing happened.
	notice.emit("Feeding on the %s — hold to drink" % prey.species)
	return true


## A mouthful a frame, while the key is held.
##
## What is being drained is either what the crosshair is on or **whatever is on
## your line**, at any distance: silk is a straw, and drinking down your own
## dragline is what makes eating on the move possible at all. That is the whole
## loop — take it, tether it, run, and drink on the way.
func _feed(delta: float) -> void:
	if feeding == null:
		return
	if not is_instance_valid(feeding) or feeding.eaten:
		_end_feed()
		return
	if not _accepts_input() or not Input.is_action_pressed(input_interact):
		_end_feed()
		return
	if not _in_reach(feeding):
		_end_feed("Out of reach — it has to be on your line or under the cross")
		return

	var yield_scale := traits.drain_scale() if traits != null else 1.0
	var bite: float = maxf(stage().bite_power, 1)
	var swallowed := feeding.drain(feed_rate * bite * delta)
	if swallowed <= 0.0:
		return
	var food := swallowed * yield_scale
	_meal += food
	# Banked as it comes, not at the end, so half a meal is half a meal. Fed
	# quietly: a notice a frame would bury everything else the HUD has to say.
	if growth.feed(food, _meal_species) > 0:
		_meal = 0.0
	# The larder counts creatures, not mouthfuls, so it is paid on the last one.
	if feeding.eaten:
		if traits != null:
			traits.record(feeding.kind)
		_end_feed()


## Whether a meal is close enough to keep drinking. On the line counts at any
## length; anything else has to be within reach of the fangs.
func _in_reach(prey: Prey) -> bool:
	if tether != null and tether.cargo == prey:
		return true
	var span := global_position.distance_to(prey.global_position)
	return span <= maxf(stage().reach * 2.5, stage().body_height * 4.0)


func _end_feed(reason := "") -> void:
	var species := _meal_species
	var got := _meal
	var finished := feeding == null or not is_instance_valid(feeding) or feeding.eaten
	feeding = null
	_meal = 0.0
	if reason != "":
		notice.emit(reason)
		return
	if got < 0.05:
		return
	if finished:
		notice.emit("Drained the %s  +%d biomass" % [species, roundi(got)])
	else:
		notice.emit("Half a %s  +%d biomass — the rest is still there"
			% [species, roundi(got)])


# --- growth -------------------------------------------------------------

func _on_stage_changed(new_stage: GrowthStage, index: int) -> void:
	var previous_height := _stage.body_height if _stage != null else new_stage.body_height
	_stage = new_stage
	_apply_stage(new_stage, previous_height)
	grew.emit(new_stage, index)
	# A trait reshapes the body and comes through here too, so the announcement
	# hangs off the tier actually moving rather than off this being called.
	if index > _tier and index > 0:
		# Growing mends you. It is the payoff for a hard trip and it is what makes
		# a tier read as relief rather than as a bigger number — you come out of
		# the fight that nearly finished you, eat, and stand up whole.
		health = max_stamina()
		notice.emit("You are a %s now" % new_stage.display_name)
	elif health > 0.0:
		# A trait reshaped the body without moving the tier. Keep the same share
		# of a possibly different maximum rather than the same absolute number.
		health = minf(health, max_stamina())
	_tier = index


## Resizes the body to match a size tier.
func _apply_stage(new_stage: GrowthStage, previous_height: float) -> void:
	var height := new_stage.body_height

	var capsule := collision.shape as CapsuleShape3D
	if capsule != null:
		# Squat and wide, like a spider — and short enough end to end that
		# rolling onto a wall doesn't sweep the collider through it.
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

	speed = new_stage.move_speed
	_normal_speed = new_stage.move_speed
	jump_height = new_stage.jump_velocity
	jump_ability.height = new_stage.jump_velocity
	floor_snap_length = height * 0.25
	step_interval = maxf(height * 3.0, 1.0)

	# The template's water probe is a fixed two metres long, which for a
	# coin-sized spider means "in water" a metre above the pond. Scale it with
	# the body like everything else.
	var water_probe := swim_ability.get_node_or_null("RayCast3D") as RayCast3D
	if water_probe != null:
		water_probe.position = Vector3(0, height * 0.5, 0)
		water_probe.target_position = Vector3(0, -height, 0)

	# Growing from the middle of the capsule would bury the feet in the floor.
	if previous_height < height:
		global_position.y += (height - previous_height) * 0.5

	if body != null:
		body.set_body_height(height)


# --- helpers ------------------------------------------------------------

## What holding the feed key is draining, if anything.
var feeding: Prey = null

## What is left, against [method max_stamina].
var health := 0.0
var _mending := 0.0

## How much has come out of this meal, for the readout and the notice.
var _meal := 0.0
var _meal_species := ""


## The prey nearest the middle of the screen, within reach.
func _aimed_prey() -> Prey:
	var origin := view.aim_origin()
	var forward := view.aim_forward()
	var current := stage()
	var range_limit: float = maxf(current.reach * 2.5, current.body_height * 4.0)

	var best: Prey = null
	var best_dot := 0.82
	for node in get_tree().get_nodes_in_group("prey"):
		var prey := node as Prey
		if prey == null or not is_instance_valid(prey) or prey.eaten:
			continue
		var offset := prey.global_position - origin
		var distance := offset.length()
		if distance > range_limit or distance < 0.0001:
			continue
		var alignment := offset.normalized().dot(forward)
		if alignment > best_dot:
			best_dot = alignment
			best = prey
	return best


func _on_line_dropped(_anchor: Vector3) -> void:
	notice.emit("On a line — Ctrl down, Space up, right mouse to let go")


func _on_line_cut() -> void:
	notice.emit("Let go of the line")


func _on_notice(text: String) -> void:
	notice.emit(text)
