class_name SilkNode
extends Node3D

## Anything that can be wired into the signal network.
##
## Webs are the obvious members, but not the only ones: a device dropped out of
## the spider's bag is wired up exactly the same way, which is what lets a
## tripline set off a venom spur and a snare ring a bell. Everything to do with
## links lives here so neither side has to know what the other is.

## This went off. Anything wired downstream hears about it.
signal fired(node: SilkNode)

## Something wired to this one went off.
signal signalled(node: SilkNode, source: SilkNode)

## How far a signal travels before it gives up, so two things wired into a loop
## cannot ring forever.
const MAX_SIGNAL_DEPTH := 6

## Signal lines are drawn cold and dashed so they read as wiring rather than as
## silk that holds something up.
const LINK_COLOR := Color(0.5, 0.8, 1.0, 0.65)

## What this sets off when it fires.
var links: Array[SilkNode] = []

var link_mesh: MeshInstance3D

var _linked_by: Array[SilkNode] = []
var _link_material: StandardMaterial3D
var _flash := 0.0


func _ready() -> void:
	add_to_group("silk_nodes")


## What sets this one off.
func linked_sources() -> Array[SilkNode]:
	return _linked_by.duplicate()


## Can this be the source of a signal — does anything ever happen to it?
func can_signal() -> bool:
	return true


## Can this do anything useful with a signal?
func can_receive_signal() -> bool:
	return true


func can_link_to(target: SilkNode) -> bool:
	if target == null or target == self or not is_instance_valid(target):
		return false
	if links.has(target):
		return false
	return can_signal() and target.can_receive_signal()


## Runs a signal line from here to something else. The two are now one machine.
func link_to(target: SilkNode) -> bool:
	if not can_link_to(target):
		return false
	links.append(target)
	target._linked_by.append(self)
	_rebuild_link_visual()
	_on_links_changed()
	return true


## Drops every signal line into or out of this.
func unlink_all() -> void:
	for target in links.duplicate():
		if is_instance_valid(target):
			target._linked_by.erase(self)
	links.clear()
	for source in _linked_by.duplicate():
		if is_instance_valid(source):
			source.links.erase(self)
			source._rebuild_link_visual()
			source._on_links_changed()
	_linked_by.clear()
	_rebuild_link_visual()


## Something set this off. Everything wired downstream hears.
func fire(depth := 0) -> void:
	_flash = 0.5
	_refresh_link_tint()
	fired.emit(self)
	if depth >= MAX_SIGNAL_DEPTH:
		return
	for target in links.duplicate():
		if is_instance_valid(target):
			target.receive_signal(self, depth + 1)


## Something wired to this one went off.
func receive_signal(source: SilkNode, depth: int) -> void:
	signalled.emit(self, source)
	_react_to_signal(source)
	_refresh_link_tint()
	fire(depth)


## How far this draws prey in, if it does at all.
func lure_radius() -> float:
	return 0.0


## Where a signal line attaches.
func signal_point() -> Vector3:
	return global_position


## A short name for this, for notices that talk about it.
func label() -> String:
	return name


## One line about this for the HUD when the player looks at it.
func status_line() -> String:
	return label()


## What this does about a signal. Subclasses say.
func _react_to_signal(_source: SilkNode) -> void:
	pass


## Called when a link is made or broken, for anything that needs to re-read.
func _on_links_changed() -> void:
	pass


## Fades the flash that runs down a line when a signal travels it.
func _tick_signal(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta)
	_refresh_link_tint()


func _refresh_link_tint() -> void:
	if _link_material == null:
		return
	var wire := LINK_COLOR
	if _flash > 0.0:
		wire = wire.lerp(Color(2.0, 1.9, 1.3, 1.0), clampf(_flash * 2.0, 0.0, 1.0))
	_link_material.albedo_color = wire


## Draws the signal lines out of this, so the player can read their own machine
## at a glance.
func _rebuild_link_visual() -> void:
	if link_mesh == null:
		_link_material = WebGeometry.silk_material()
		link_mesh = MeshInstance3D.new()
		link_mesh.name = "SignalLines"
		link_mesh.material_override = _link_material
		link_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		link_mesh.top_level = true
		add_child(link_mesh)
		link_mesh.transform = Transform3D.IDENTITY
	var strands := WebGeometry.StrandSet.new()
	var width := _link_width()
	for target in links:
		if is_instance_valid(target):
			_dashed_line(strands, signal_point(), target.signal_point(), width)
	link_mesh.mesh = WebGeometry.build_mesh(strands, LINK_COLOR)


func _link_width() -> float:
	return 0.006


## Signal lines are drawn dashed so they never read as structural silk — a thing
## that carries a message, not a thing that holds weight.
func _dashed_line(strands: WebGeometry.StrandSet, from: Vector3, to: Vector3,
		width: float) -> void:
	var span := from.distance_to(to)
	if span < 0.01:
		return
	var dashes: int = clampi(roundi(span / maxf(span * 0.05, 0.08)), 2, 60)
	var duty := 0.55
	for i in dashes:
		var start := float(i) / float(dashes)
		var end := minf(start + duty / float(dashes), 1.0)
		strands.add(from.lerp(to, start), from.lerp(to, end), width)
