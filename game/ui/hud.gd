class_name SpiderHUD
extends CanvasLayer

## Everything on screen: the coins and the farm in the corner, the cross and what
## it is on, the spells along the foot, the bag, the build readout, the help, and
## the shop over the top of it all.
##
## Built in code, and it finds what it shows on its own — the spider by its group
## and the farm by its — so dropping a HUD into a scene with both is all it takes.
## It also owns the mouse: it frees it for the shop and takes it back after, and T
## and Esc free it on purpose.

const TITLE := "Put the Flies in the Bag"

const HELP_TEXT := """[ %s ]

WASD  move      Space  jump      Shift  sprint
walk into a wall to climb it — walls and ceilings are floors to a spider
Left mouse  grapple there   ·   on a wrapped fly: put a line on it
Q  let go of the line
Right mouse  cast what is in hand
1–7 / wheel / hold Tab  pick a spell

Right mouse: tap to cast, hold to wind a spell up bigger
Silk  wraps a fly on the spot
Water Spiral  holds a fly, washes bundles · Gust  blows flies along, dries
Lightning  stuns flies, tenderises · Fire Breath  scares flies, cooks
Pullback  hauls bundles to you, pulls cooked meat · Clay  a pillar, or a crust on a bundle

Wild flies come to troughs, compost heaps and melons: catch them, or let them
in through a gate and shut it behind them.
F  gates · pick ripe crops · fruit into a trough · herbs on a fly at the table
   take a dish · sell at the market · cut a plain bundle free
E  the shop: fences, gates, troughs, ponds, crops, a compost heap, prep tables
X  take down what the cross is on, for half back
L  camera   O  the spider's look   T  free the mouse   H  hide this"""

const BIG := 30

## Text sizes the disc shares.
const TITLE_SIZE := 28
const BODY_SIZE := 20
const SMALL_SIZE := 18
const BODY := 19
const SMALL := 16

## How long a message stays up, in seconds.
const TOAST_TIME := 3.4

var _spider: SpiderPlayer
var _farm: Farm
var _crosshair: Crosshair
var _disc: SpellDisc
var _shop: ShopScreen
var _coins: Label
var _farm_line: Label
var _bag_line: Label
var _readout: Label
var _build_line: Label
var _toast: Label
var _toast_left := 0.0
var _help: Label
var _strip: VBoxContainer
var _bag_list: Label


func _ready() -> void:
	_crosshair = Crosshair.new()
	_crosshair.name = "Crosshair"
	add_child(_crosshair)
	_disc = SpellDisc.new()
	_disc.name = "SpellDisc"
	add_child(_disc)

	var corner := VBoxContainer.new()
	corner.name = "Farm"
	corner.position = Vector2(24.0, 20.0)
	add_child(corner)
	_coins = _label(corner, "Coins", BIG, Color(1.0, 0.86, 0.45))
	_farm_line = _label(corner, "Stock", BODY, Color(0.86, 0.94, 0.82))
	_bag_line = _label(corner, "Bag", BODY, Color(0.95, 0.9, 0.82))

	_readout = _label(self, "Readout", BODY, Color(1, 1, 1, 0.95))
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.size = Vector2(900.0, 90.0)
	_build_line = _label(self, "Build", BODY, Color(0.75, 1.0, 0.78))
	_build_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_line.size = Vector2(1200.0, 40.0)
	_toast = _label(self, "Toast", 26, Color(1, 1, 1))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(1400.0, 40.0)
	_toast.modulate.a = 0.0
	_strip = VBoxContainer.new()
	_strip.name = "Spells"
	_strip.add_theme_constant_override("separation", 2)
	add_child(_strip)
	_bag_list = _label(self, "BagList", SMALL, Color(0.95, 0.9, 0.82))
	_bag_list.size = Vector2(460.0, 220.0)
	_bag_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bag_list.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_help = _label(self, "Help", SMALL, Color(1, 1, 1, 0.92))
	_help.text = HELP_TEXT % TITLE
	_help.size = Vector2(760.0, 520.0)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.visible = false
	_label(corner, "HelpHint", SMALL, Color(1, 1, 1, 0.6)).text = "H — help    E — shop"
	_lay_out()

	_shop = ShopScreen.new()
	_shop.name = "Shop"
	add_child(_shop)
	_shop.chosen.connect(_on_chosen)
	_bind.call_deferred()


## Puts everything where it goes on a screen of whatever size it is.
func _lay_out() -> void:
	var screen := get_viewport().get_visible_rect().size if get_viewport() != null \
		else Vector2(1920.0, 1080.0)
	var middle := screen * 0.5
	_readout.position = Vector2(middle.x - _readout.size.x * 0.5, middle.y + 36.0)
	_build_line.position = Vector2(middle.x - _build_line.size.x * 0.5, 22.0)
	_toast.position = Vector2(middle.x - _toast.size.x * 0.5, screen.y - 190.0)
	_strip.position = Vector2(24.0, screen.y - 30.0 - _strip.size.y)
	_bag_list.position = Vector2(screen.x - _bag_list.size.x - 24.0, screen.y - _bag_list.size.y - 24.0)
	_help.position = Vector2(screen.x - _help.size.x - 24.0, 20.0)


func _label(parent: Node, label_name: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func _bind() -> void:
	_spider = get_tree().get_first_node_in_group("spider") as SpiderPlayer
	_farm = Farm.of(self)
	if _spider == null:
		push_warning("HUD could not find the spider")
		return
	_crosshair.spider = _spider
	_disc.spider = _spider
	_spider.notice.connect(show_message)
	_spider.shop_toggled.connect(toggle_shop)
	_spider.spells.changed.connect(_build_strip)
	if _farm != null:
		_farm.notice.connect(show_message)
		_shop.setup(_farm)
	_build_strip()


func _process(delta: float) -> void:
	_lay_out()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left, 0.0, 1.0)
	if _spider == null:
		return
	_refresh_corner()
	_refresh_readout()
	_refresh_strip()
	_refresh_bag()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible
	# The shop frees the mouse, and a free mouse is exactly what stops the spider
	# reading its keys — so the way back out has to be handled here.
	elif _shop.open and (event.is_action_pressed("shop") or event.is_action_pressed("ui_cancel")):
		_shop.close()
	elif event.is_action_pressed("ui_cancel"):
		if _spider != null and _spider.builder.active:
			_spider.builder.stop()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("change_mouse_input"):
		var free := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventMouseButton and event.pressed and not _shop.open \
			and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		# A click on the game takes the mouse back.
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		return
	get_viewport().set_input_as_handled()


func show_message(text: String) -> void:
	_toast.text = text
	_toast_left = TOAST_TIME
	_toast.modulate.a = 1.0


## Opens the shop, or shuts it. Opening it puts away whatever was being built.
func toggle_shop() -> void:
	if _farm == null:
		show_message("No farm here to build on")
		return
	if not _shop.open and _spider != null:
		_spider.builder.active = false
		_spider.builder.stop()
	_shop.toggle()


func shop() -> ShopScreen:
	return _shop


func _on_chosen(what: Resource) -> void:
	if _spider != null:
		_spider.builder.begin(what as StructureKind)


# --- what it says now -----------------------------------------------------

func _refresh_corner() -> void:
	if _farm == null:
		_coins.text = ""
		_farm_line.text = ""
	else:
		_coins.text = "%d coins" % _farm.coins
		var living := 0
		var grown := 0
		var wild := 0
		for insect in _farm.insects():
			if insect.is_bundle():
				continue
			if insect.wild:
				wild += 1
				continue
			living += 1
			grown += 1 if insect.is_grown() else 0
		_farm_line.text = "%d fl%s · %d grown · %d wild about · %d pen%s" % [living,
			"y" if living == 1 else "ies", grown, wild, _farm.grid.pens().size(),
			"" if _farm.grid.pens().size() == 1 else "s"]
	var bag := _spider.bag
	_bag_line.text = "Bag  %d / %d · %d dish%s, %d coins" % [bag.count() + bag.produce.size(),
		SpiderInventory.CAPACITY, bag.count(), "" if bag.count() == 1 else "es", bag.total_value()]
	_build_line.text = _spider.builder.hint() if _spider.builder.active else ""


## The line under the cross: what it is on, and what F would do to it — or, while
## building, why what is in hand cannot go where it is.
func _refresh_readout() -> void:
	var builder := _spider.builder
	if builder.active:
		_readout.text = "" if builder.valid else builder.reason
		_readout.modulate = Color(1.0, 0.6, 0.55)
		return
	_readout.modulate = Color(1, 1, 1)
	var lines := PackedStringArray()
	var what := aimed_text()
	if not what.is_empty():
		lines.append(what)
	var hint := _spider.interact_hint()
	if not hint.is_empty():
		lines.append(hint)
	elif _spider.tether.is_towing():
		lines.append("Q — let go of the %s" % _spider.tether.cargo_name().to_lower())
	_readout.text = "\n".join(lines)


## What the cross is on, in a line: a fly, something built, the market, a pen.
func aimed_text() -> String:
	var camera := _spider.view.camera
	if camera == null:
		return ""
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 60.0,
		GameLayers.WORLD | GameLayers.INSECT, [_spider.get_rid()])
	var hit := _spider.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var node := hit.get("collider") as Node
	while node != null:
		if node is Insect:
			return (node as Insect).describe()
		if node is FarmStructure:
			return (node as FarmStructure).describe()
		if node is ClayPillar:
			return "Clay pillar"
		if node is MarketStall:
			return (node as MarketStall).describe(_spider)
		node = node.get_parent()
	if _farm != null:
		var at := _farm.grid.cell_at(hit["position"])
		if _farm.grid.in_bounds(at) and _farm.grid.is_pen(_farm.grid.region_id(at)):
			return _farm.pen_summary(_farm.grid.region_id(at))
	return ""


func _build_strip() -> void:
	if _spider == null:
		return
	for child in _strip.get_children():
		child.queue_free()
	for spell in _spider.spells.hand():
		var line := _label(_strip, spell.id, BODY, spell.colour.lerp(Color.WHITE, 0.35))
		line.text = spell.display_name
	_refresh_strip()


func _refresh_strip() -> void:
	var spells := _spider.spells
	var holding := spells.current()
	for line: Label in _strip.get_children():
		var spell := spells.by_id(line.name)
		if spell == null:
			continue
		var step := Prep.step_for(spell.form)
		var verb := "Wrap" if step < 0 else String(Prep.VERB[step])
		var wait := "  %.1fs" % spells.cooldown_left(spell) if spells.cooling(spell) else ""
		if spell == holding and spells.charging:
			wait = "  " + "▮".repeat(roundi(spells.charge * 8.0)) + "▯".repeat(8 - roundi(spells.charge * 8.0))
		line.text = "%s %d  %s — %s%s" % ["▶" if spell == holding else "  ", spells.key_for(spell),
			spell.display_name, verb, wait]
		line.modulate.a = 1.0 if spell == holding else 0.62


func _refresh_bag() -> void:
	var lines := PackedStringArray()
	for picked in _spider.bag.produce:
		lines.append(picked.label())
	var dishes := _spider.bag.dishes
	for i in range(maxi(0, dishes.size() - 8), dishes.size()):
		lines.append("%s  %d" % [dishes[i].label(), dishes[i].value()])
	if dishes.size() > 8:
		lines.insert(0, "… and %d more" % (dishes.size() - 8))
	_bag_list.text = "\n".join(lines)
