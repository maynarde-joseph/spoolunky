class_name Insect
extends CharacterBody3D

## One of the farm's insects: a hatchling put down in a pen, kept fed and watered
## until it is grown, then wrapped, dragged off and cooked.
##
## While it is alive it keeps to its own ground — the region of the farm it is
## standing in, which for anything worth raising is a pen (see [FarmGrid]). It
## wanders about in there, and when it gets hungry or thirsty it goes to a trough
## or a pond in the same pen and eats or drinks. Kept fed, watered and with room to
## move, it grows towards market weight and its grade climbs; let it go hungry or
## thirsty, or pack too many in, and it stops growing and its grade slips back. A
## flier is held by its pen the same as a walker: it keeps to its own ground and
## will not go over a fence.
##
## Hit with silk, it is a bundle on the spot (see [method wrap]): it stops, falls,
## and lies there until something puts a line on it. A bundle on a prep table is
## what the kitchen spells work on — see [method apply] and [Prep] — and what comes
## off the table is a [Dish].
##
## What kind of insect it is comes from an [InsectSpecies], so one script serves
## them all and a new one is a .tres.

## Wrapped in silk: a bundle from now on, until it is cut free.
signal wrapped(insect: Insect)

## Cut free of its silk, and back on its feet.
signal freed(insect: Insect)

## Put down on a prep table, or taken off one.
signal docked(insect: Insect, table: Node3D)

## Off the farm for good: made into a dish. It is gone the frame after this.
signal taken(insect: Insect)

## What it is doing.
enum State {
	WANDER,    ## going about its pen
	TO_FOOD,   ## on its way to a trough
	EATING,
	TO_WATER,  ## on its way to a pond
	DRINKING,
	BUNDLE,    ## wrapped in silk, going nowhere on its own
}

const GROUP := "insects"

## How far out its collider goes, as a share of its body radius. A little past the
## body, so a thrown ball of silk that grazes it still counts.
const HITBOX_SCALE := 1.15

## How big a hatchling is, as a share of a grown one.
const HATCHLING := 0.45

## Hunger or thirst, 0 to 1, at which it goes looking for food or water.
const PECKISH := 0.5

## Hunger or thirst past which it is suffering: it neither grows nor keeps, and its
## grade slips back.
const STARVING := 0.85

## Seconds a meal and a drink take.
const EAT_TIME := 2.5
const DRINK_TIME := 2.0

## Seconds it spends going one way before it picks somewhere new, either side of
## this.
const WANDER_TIME := Vector2(2.5, 6.0)

## How far it wanders from where it is when it is loose on open ground, in metres.
## In a pen it goes anywhere in the pen.
const LOOSE_RANGE := 4.0

## How long it keeps trying to get somewhere it is not getting any nearer to, in
## seconds, before it gives up and goes somewhere else.
const PATIENCE := 2.0

## How much faster its grade climbs with a shade tree in the pen, and with a
## sugar bowl.
const SHADE_KEEP := 1.25
const SUGAR_KEEP := 1.5

## How fast its grade slips back while it suffers, against how fast it climbs.
const SLIP := 0.35

## The bundle's shape, in body radii: wide, a little flattened, and long — and
## no taller than the hitbox it rests on, so it lies on the ground rather than in
## it.
const COCOON := Vector3(1.3, HITBOX_SCALE, 1.9)

var kind: InsectSpecies

## How far it has grown, 0 for a hatchling to 1 for market weight.
var growth := 0.0

## How well it has been kept, 0 to 1: its grade. See [method Dish.grade_of].
var quality := 0.0

## How hungry and how thirsty it is, 0 just fed to 1 starving.
var hunger := 0.0
var thirst := 0.0

var state: State = State.WANDER

## What the kitchen has done to it, in order, while it is a bundle. See [Prep].
var steps: Array[int] = []

## The prep table it is lying on, if it is on one.
var table: Node3D = null

## Whether it was being kept well last it was looked at: in a pen, fed and watered.
var content := false

var _rng := RandomNumberGenerator.new()
var _farm: Farm
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _height := 0.8
var _ground := 0.0
var _ground_left := 0.0
var _wander_left := 0.0
var _goal: FarmStructure = null
var _busy_left := 0.0
var _stuck := 0.0
var _closest := INF
var _tow_pull := Vector3.ZERO
var _gravity := 9.8
var _view: CreatureView
var _hitbox: CollisionShape3D
var _cocoon: MeshInstance3D
var _cocoon_paint: StandardMaterial3D
var _cocoon_shape := Vector3.ONE
var _shown := -1.0


## Makes one of [param species], [param grown] of the way to market weight, ready
## to be dropped into the world.
static func of(species: InsectSpecies, grown := 0.0) -> Insect:
	var insect := Insect.new()
	insect.kind = species
	insect.growth = clampf(grown, 0.0, 1.0)
	if species != null:
		insect.name = species.display_name.replace(" ", "")
	return insect


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = GameLayers.INSECT
	collision_mask = GameLayers.WORLD
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_rng.randomize()
	_farm = Farm.of(self)
	_home = global_position
	_ground = global_position.y - radius() * HITBOX_SCALE if not flies() else 0.0
	_find_ground()
	_settle_mode()
	_build()
	_wander_left = 0.0


func _physics_process(delta: float) -> void:
	if state == State.BUNDLE:
		_lie(delta)
		return
	_keep(delta)
	_decide(delta)
	_move(delta)
	_fit()


# --- what it is ----------------------------------------------------------

## How big it is now, as the radius of its body in metres.
func radius() -> float:
	var grown := kind.adult_radius if kind != null else 0.26
	return grown * lerpf(HATCHLING, 1.0, clampf(growth, 0.0, 1.0))


## How fast it gets about now, in metres a second: a hatchling is slower.
func pace() -> float:
	var top := kind.move_speed if kind != null else 1.2
	return top * lerpf(0.6, 1.0, clampf(growth, 0.0, 1.0))


func flies() -> bool:
	return kind != null and kind.flying


## Whether it is at market weight.
func is_grown() -> bool:
	return growth >= 1.0


func is_bundle() -> bool:
	return state == State.BUNDLE


## Whether it is standing on its legs rather than holding itself up in the air:
## a walker always, a flier when it has come down to eat or drink.
func on_its_feet() -> bool:
	if not flies():
		return true
	return state == State.EATING or state == State.DRINKING \
		or (_goal != null and _landing())


## Its grade, A1 to A5, as a number. See [method Dish.grade_of].
func grade() -> int:
	return Dish.grade_of(quality)


## How heavy it is to drag, in the tether's units: one for nothing much, more
## the bigger it has grown.
func weight() -> float:
	return 1.0 + radius() / 0.25 * 0.8


## A line about it for the readout under the cross: what it is, how far grown, its
## grade, and what it wants.
func describe() -> String:
	var label := kind.display_name if kind != null else "Insect"
	if is_bundle():
		var line := "%s bundle · %s · %s" % [label, _size_word(), Dish.grade_name(grade())]
		if not steps.is_empty():
			line += " · %s" % Prep.done_text(steps)
		return line
	var wants := PackedStringArray()
	if hunger >= PECKISH:
		wants.append("hungry")
	if thirst >= PECKISH:
		wants.append("thirsty")
	if not content and wants.is_empty():
		wants.append("not penned" if not in_pen() else "crowded")
	var line := "%s · %s · %s" % [label, _size_word(), Dish.grade_name(grade())]
	if not wants.is_empty():
		line += " · " + ", ".join(wants)
	return line


func _size_word() -> String:
	if is_grown():
		return "grown"
	return "%d%% grown" % floori(growth * 100.0)


## The farm region it is standing in, or -1 if there is no farm or it is off it.
func region() -> int:
	if _farm == null:
		return -1
	return _farm.grid.region_id(_farm.grid.cell_at(global_position))


## Whether it is in a pen.
func in_pen() -> bool:
	return _farm != null and _farm.grid.is_pen(region())


# --- being kept ----------------------------------------------------------

## Hunger and thirst creep up; kept well, it grows and its grade climbs; let it
## suffer, and its grade slips back.
func _keep(delta: float) -> void:
	if kind == null:
		return
	hunger = minf(1.0, hunger + delta / maxf(kind.hunger_time, 1.0))
	thirst = minf(1.0, thirst + delta / maxf(kind.thirst_time, 1.0))
	var suffering := hunger >= STARVING or thirst >= STARVING
	var penned := in_pen()
	content = penned and not suffering
	if content:
		var room := _farm.room_in(region()) if _farm != null else 1.0
		growth = minf(1.0, growth + delta / maxf(kind.grow_time, 1.0) * lerpf(0.35, 1.0, room))
		quality = minf(1.0, quality + delta / maxf(kind.grade_time, 1.0) * room * _comfort())
	elif suffering:
		quality = maxf(0.0, quality - delta / maxf(kind.grade_time, 1.0) * SLIP)


## How much faster than plain its grade climbs here: shade, and sugar.
func _comfort() -> float:
	if _farm == null:
		return 1.0
	var here := region()
	var comfort := 1.0
	if _farm.has_in(here, "shade_tree"):
		comfort *= SHADE_KEEP
	if _farm.has_in(here, "sugar_bowl"):
		comfort *= SUGAR_KEEP
	return comfort


## What it does next: hungry, it goes to eat; thirsty, to drink; otherwise it
## wanders.
func _decide(delta: float) -> void:
	match state:
		State.WANDER:
			_wander_left -= delta
			if hunger >= PECKISH and _go_to(_farm.food_for(self) if _farm != null else null):
				state = State.TO_FOOD
			elif thirst >= PECKISH and _go_to(_farm.water_for(self) if _farm != null else null):
				state = State.TO_WATER
			elif _wander_left <= 0.0 or _flat_distance(_target) < radius():
				_pick_wander_target()
		State.TO_FOOD, State.TO_WATER:
			if not _goal_still_good():
				_give_up()
			elif _goal.reached_by(self):
				_busy_left = EAT_TIME if state == State.TO_FOOD else DRINK_TIME
				state = State.EATING if state == State.TO_FOOD else State.DRINKING
			else:
				_target = _goal.approach_from(global_position, radius())
		State.EATING:
			_busy_left -= delta
			if _busy_left <= 0.0:
				if is_instance_valid(_goal) and _goal.feed(self):
					hunger = 0.0
				_give_up()
		State.DRINKING:
			_busy_left -= delta
			if _busy_left <= 0.0:
				if is_instance_valid(_goal) and _goal.water(self):
					thirst = 0.0
				_give_up()


## Heads for [param where], if there is somewhere to head for. Returns whether it
## set off.
func _go_to(where: FarmStructure) -> bool:
	if where == null:
		return false
	_goal = where
	_target = where.approach_from(global_position, radius())
	_stuck = 0.0
	_closest = INF
	return true


## Whether what it is heading for is still there, still in its pen, and still has
## something for it.
func _goal_still_good() -> bool:
	if _goal == null or not is_instance_valid(_goal) or _goal.is_queued_for_deletion():
		return false
	if _goal.region() != region():
		return false
	if state == State.TO_FOOD:
		return _goal.has_food_for(self)
	return true


## Back to wandering, and somewhere new to wander to.
func _give_up() -> void:
	_goal = null
	state = State.WANDER
	_pick_wander_target()


func _pick_wander_target() -> void:
	_wander_left = _rng.randf_range(WANDER_TIME.x, WANDER_TIME.y)
	_stuck = 0.0
	_closest = INF
	if kind != null and flies():
		_height = _rng.randf_range(kind.hover.x, kind.hover.y)
	var here := region()
	if _farm != null and _farm.grid.is_pen(here):
		_target = _farm.grid.point_in(here, _rng, radius() + 0.15)
		return
	# Loose on open ground, or with no farm at all: somewhere near, on the same
	# ground if there is ground to keep to.
	var from := global_position if _farm != null else _home
	for attempt in 6:
		var angle := _rng.randf() * TAU
		var reach := _rng.randf_range(0.5, LOOSE_RANGE)
		var spot := from + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		if _farm == null or _farm.grid.region_id(_farm.grid.cell_at(spot)) == here:
			_target = spot
			return
	_target = from


# --- moving --------------------------------------------------------------

func _move(delta: float) -> void:
	var busy := state == State.EATING or state == State.DRINKING
	var offset := _target - global_position
	offset.y = 0.0
	var wanted := Vector3.ZERO
	var near := radius() * 0.5
	if not busy and offset.length() > near:
		var slow := clampf(offset.length() / maxf(radius() * 2.0, 0.05), 0.35, 1.0)
		wanted = offset.normalized() * pace() * slow
	var before := global_position
	var was := region()
	var steer := clampf(delta * 6.0, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, wanted.x, steer)
	velocity.z = lerpf(velocity.z, wanted.z, steer)
	if flies():
		_ground_left -= delta
		if _ground_left <= 0.0:
			_find_ground()
		var up_to := _ground + (radius() * HITBOX_SCALE if on_its_feet() else _height)
		var bob := sin(Time.get_ticks_msec() * 0.003 + float(get_instance_id() % 97)) * 0.06 \
			if not on_its_feet() else 0.0
		velocity.y = clampf((up_to + bob - global_position.y) * 3.0, -2.5, 2.5)
	else:
		if is_on_floor():
			velocity.y = minf(velocity.y, 0.0)
		else:
			velocity.y -= _gravity * delta
	move_and_slide()
	# Kept to its own ground. A walker is held by the fences themselves, but a
	# flier is not, and neither is anything at the corner of a pen that is not a
	# rectangle: whatever would take it onto other ground takes it nowhere, and it
	# goes somewhere else instead.
	if _farm != null and was >= 0 and region() != was:
		global_position = Vector3(before.x, global_position.y, before.z)
		velocity.x = 0.0
		velocity.z = 0.0
		if state == State.WANDER:
			_pick_wander_target()
		else:
			_give_up()
		return
	_check_progress(delta, wanted)


## Gives up on somewhere it is not getting any nearer to: round the back of a pond,
## jammed against a fence.
func _check_progress(delta: float, wanted: Vector3) -> void:
	if wanted == Vector3.ZERO:
		_stuck = 0.0
		return
	var gap := _flat_distance(_target)
	if gap < _closest - 0.05:
		_closest = gap
		_stuck = 0.0
		return
	_stuck += delta
	if _stuck >= PATIENCE:
		if state == State.WANDER:
			_pick_wander_target()
		else:
			_give_up()


## Whether a flier heading for something is near enough to come down for it.
func _landing() -> bool:
	return _goal != null and _flat_distance(_target) < radius() * 3.0 + 0.6


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Where the ground is under it, for a flier to keep its height off.
func _find_ground() -> void:
	_ground_left = 0.5
	if not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0,
		GameLayers.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_ground = (hit["position"] as Vector3).y


func _settle_mode() -> void:
	if flies() and state != State.BUNDLE:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		up_direction = Vector3.UP


# --- silk ----------------------------------------------------------------

## Wrapped on the spot: a bundle from now on. It stops whatever it was doing and
## drops, and lies where it lands until something drags it off. False if it is a
## bundle already.
func wrap() -> bool:
	if state == State.BUNDLE:
		return false
	state = State.BUNDLE
	_goal = null
	velocity = Vector3.ZERO
	_tow_pull = Vector3.ZERO
	_settle_mode()
	_show_cocoon()
	wrapped.emit(self)
	return true


## Cut out of its silk and let go, back on its feet wherever it is. Only something
## the kitchen has not started on: once it is washed or worse, it is not going
## back. Returns why not, or nothing if it went.
func cut_free() -> String:
	if state != State.BUNDLE:
		return "It is not wrapped"
	if not steps.is_empty():
		return "It is %s — it is not going back" % Prep.DONE[steps[-1]]
	if table != null:
		undock()
	state = State.WANDER
	_settle_mode()
	_show_cocoon()
	_pick_wander_target()
	freed.emit(self)
	return ""


## Dragged by something outside — a tether. Kept as a pull to be spent rather
## than applied on the spot, because whatever is towing it runs in its own physics
## step and the movement belongs in this one.
func tow(pull: Vector3) -> void:
	if table == null:
		_tow_pull += pull


## A bundle is dead weight: it falls whether or not the thing inside it could fly,
## and stays where it lands — unless something is dragging it, in which case it
## comes along and keeps the swing. On a table it lies still where the table holds
## it.
func _lie(delta: float) -> void:
	if table != null:
		_tow_pull = Vector3.ZERO
		velocity = Vector3.ZERO
		if is_instance_valid(table) and table.has_method("hold_point"):
			global_position = _resting_on(table)
		return
	var pull := _tow_pull
	_tow_pull = Vector3.ZERO
	if is_on_floor() and pull.length_squared() < 0.000001:
		velocity = Vector3.ZERO
		return
	# Scraped along rather than gliding: enough friction that it trails behind,
	# not so much that it refuses to come.
	var slow: float = 4.0 if pull.length_squared() < 0.000001 else 1.2
	velocity.x = move_toward(velocity.x, 0.0, delta * slow)
	velocity.z = move_toward(velocity.z, 0.0, delta * slow)
	velocity.y -= _gravity * delta
	velocity += pull
	move_and_slide()


# --- the kitchen ---------------------------------------------------------

## Put down on [param on]: it lies there, held, until it is taken off.
func dock(on: Node3D) -> void:
	table = on
	velocity = Vector3.ZERO
	_tow_pull = Vector3.ZERO
	if on.has_method("hold_point"):
		global_position = _resting_on(on)
	docked.emit(self, on)


## Where it lies on [param on]: its middle as far over the table's top as it is
## round, so the bundle sits on the board rather than in it.
func _resting_on(on: Node3D) -> Vector3:
	return (on.call("hold_point") as Vector3) + Vector3.UP * radius() * HITBOX_SCALE


## Taken off its table, to lie wherever it is.
func undock() -> void:
	if table == null:
		return
	table = null
	docked.emit(self, null)


## Does [param step] to it — see [Prep]. Returns why it could not, or nothing if it
## was done.
func apply(step: int) -> String:
	if state != State.BUNDLE:
		return "Wrap it first"
	var reason := Prep.why_not(steps, step)
	if not reason.is_empty():
		return reason
	steps.append(step)
	_show_cocoon()
	return ""


## What it would be as a dish, as it is now.
func as_dish() -> Dish:
	return Dish.make(kind, growth, quality, steps)


## Off the table and off the farm, as a dish: what it was made into. It is gone
## the frame after this.
func take() -> Dish:
	var dish := as_dish()
	undock()
	taken.emit(self)
	queue_free()
	return dish


# --- what you can see ----------------------------------------------------

## Body, hitbox and cocoon, from the species.
func _build() -> void:
	_hitbox = CollisionShape3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.shape = SphereShape3D.new()
	add_child(_hitbox)
	if kind != null and kind.body != null:
		_view = kind.body.make_view()
		_view.name = "Body"
		add_child(_view)
	_fit(true)
	_show_cocoon()


## Keeps the body, the hitbox and the cocoon the size it has grown to. Only when it
## has grown enough to see: rebuilding a shape every frame is waste.
func _fit(now := false) -> void:
	var size := radius()
	if not now and absf(size - _shown) < size * 0.02:
		return
	_shown = size
	(_hitbox.shape as SphereShape3D).radius = size * HITBOX_SCALE
	if _view != null:
		_view.resize(size)
	_size_cocoon()


## The bundle round it, the colour of what has been done to it: white silk, rinsed
## blue-white, dried pale, clay brown, roasted gold.
##
## Hung under the body, so it turns with the insect inside it and grows with it,
## and lying the way the insect lies — long, and resting on the ground, where a
## bundle hanging in a web used to be stood on end.
func _show_cocoon() -> void:
	var wrapped_up := state == State.BUNDLE
	if wrapped_up and _cocoon == null:
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		_cocoon_paint = StandardMaterial3D.new()
		_cocoon_paint.roughness = 0.85
		_cocoon = MeshInstance3D.new()
		_cocoon.name = "Cocoon"
		_cocoon.mesh = mesh
		_cocoon.material_override = _cocoon_paint
		_cocoon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _view != null:
			_view.add_child(_cocoon)
		else:
			add_child(_cocoon)
	if _cocoon == null:
		return
	_cocoon.visible = wrapped_up
	if not wrapped_up:
		return
	var look := cocoon_look(steps)
	_cocoon_paint.albedo_color = look["colour"]
	_cocoon_paint.roughness = look["rough"]
	_cocoon_paint.emission_enabled = float(look["glow"]) > 0.0
	_cocoon_paint.emission = look["colour"]
	_cocoon_paint.emission_energy_multiplier = look["glow"]
	_cocoon_shape = look["shape"]
	_size_cocoon()


## The cocoon's size, in the body's own unit when it hangs under the body and in
## metres when there is no body to hang it under.
func _size_cocoon() -> void:
	if _cocoon == null:
		return
	var unit := 1.0 if _view != null else radius()
	_cocoon.scale = _cocoon_shape * COCOON * unit


## How a bundle that has had [param done] looks: its colour, how rough it is, how
## much it glows, and how it is shaped against a plain one.
static func cocoon_look(done: Array[int]) -> Dictionary:
	var colour := Color(0.93, 0.93, 0.9)
	var rough := 0.85
	var glow := 0.0
	var shape := Vector3.ONE
	if done.has(Prep.Step.WASH):
		colour = Color(0.84, 0.92, 0.98)
		rough = 0.3
	if done.has(Prep.Step.DRY):
		colour = Color(0.96, 0.91, 0.78)
		rough = 0.9
	if done.has(Prep.Step.TENDERISE):
		colour = colour.lerp(Color(1.0, 0.94, 0.62), 0.35)
	if done.has(Prep.Step.CRUST):
		colour = Color(0.62, 0.42, 0.26)
		rough = 1.0
		shape = Vector3(1.12, 1.08, 1.12)
	if done.has(Prep.Step.COOK):
		if done.has(Prep.Step.CRUST):
			colour = Color(0.46, 0.28, 0.15)
		elif done.has(Prep.Step.DRY):
			colour = Color(0.86, 0.55, 0.2)
		else:
			colour = Color(0.78, 0.47, 0.2)
		if not done.has(Prep.Step.WASH):
			colour = colour.lerp(Color(0.45, 0.42, 0.38), 0.45)
		rough = 0.6
		glow = 0.12
	if done.has(Prep.Step.PULL):
		shape = Vector3(1.3, 0.75, 1.05)
		colour = colour.darkened(0.08)
	return {"colour": colour, "rough": rough, "glow": glow, "shape": shape}
