class_name DesignLibrary
extends RefCounted

## The player's own catalogue.
##
## A design is captured from webs already standing in the world — point at one,
## and the whole wired rig it belongs to is recorded — and written to the user
## folder as a .tres. So the build wheel stops being only what the game shipped
## with and becomes partly the player's own.

const DESIGN_DIR := "user://designs"


## Every design the player has saved, oldest first.
static func load_all() -> Array[WebDesign]:
	var designs: Array[WebDesign] = []
	var dir := DirAccess.open(DESIGN_DIR)
	if dir == null:
		return designs
	var files := dir.get_files()
	files.sort()
	for file in files:
		var file_name := file.trim_suffix(".remap")
		if not file_name.ends_with(".tres"):
			continue
		var design := ResourceLoader.load(DESIGN_DIR.path_join(file_name)) as WebDesign
		if design != null:
			designs.append(design)
	return designs


## Writes a design to the user folder. Returns false if it could not be saved.
static func store(design: WebDesign) -> bool:
	if design == null or design.id.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(DESIGN_DIR):
		var made := DirAccess.make_dir_recursive_absolute(DESIGN_DIR)
		if made != OK:
			push_warning("Could not make %s" % DESIGN_DIR)
			return false
	var path := DESIGN_DIR.path_join("%s.tres" % design.id)
	design.take_over_path(path)
	return ResourceSaver.save(design, path) == OK


static func forget(design: WebDesign) -> bool:
	if design == null or design.id.is_empty():
		return false
	var path := DESIGN_DIR.path_join("%s.tres" % design.id)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


## Records the rig [param root] belongs to — itself plus every web wired to or
## from it, however many hops away — as a reusable design.
##
## [param facing] is the direction the player was looking, which becomes the
## design's "forward" so it can be turned to face them again when replaced.
static func capture(root: WebStructure, facing: Vector3, stage_index := 0) -> WebDesign:
	if root == null or not is_instance_valid(root):
		return null

	var rig := _connected_rig(root)
	if rig.is_empty():
		return null

	var frame := yaw_basis(facing)
	var inverse := frame.transposed()
	var centre := _rig_centre(rig)

	var design := WebDesign.new()
	design.made_at_stage = stage_index
	design.made_at_quality = root.quality
	for web in rig:
		design.pattern_ids.append(web.pattern.id)
		design.anchor_counts.append(web.anchors.size())
		design.recorded_silk += web.silk_cost
		var dials: WebTuning = web.tuning if web.tuning != null else WebTuning.new()
		design.tuning_tension.append(dials.tension)
		design.tuning_weight.append(dials.weight)
		design.tuning_mesh.append(dials.mesh)
		for anchor in web.anchors:
			design.anchors.append(inverse * (anchor - centre))

	for index in rig.size():
		for target in rig[index].links:
			var target_index := rig.find(target)
			if target_index >= 0:
				design.link_from.append(index)
				design.link_to.append(target_index)

	design.display_name = _name_for(rig)
	design.id = _slug(design.display_name) + "_" + str(Time.get_unix_time_from_system()).replace(".", "")
	return design


## Rotation that turns the design's forward onto a direction, flattened so a
## rig never ends up tipped on its side by where the player happened to look.
static func yaw_basis(facing: Vector3) -> Basis:
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() < 0.000001:
		flat = Vector3.FORWARD
	return Basis.looking_at(flat.normalized(), Vector3.UP)


## The web and everything wired to it, in a stable order.
static func _connected_rig(root: WebStructure) -> Array[WebStructure]:
	var found: Array[WebStructure] = []
	var queue: Array[WebStructure] = [root]
	while not queue.is_empty():
		var web: WebStructure = queue.pop_front()
		if web == null or not is_instance_valid(web) or found.has(web):
			continue
		if web.anchors.is_empty() or web.pattern == null:
			continue
		found.append(web)
		for target in web.links:
			queue.append(target)
		for source in web.linked_sources():
			queue.append(source)
	return found


static func _rig_centre(rig: Array[WebStructure]) -> Vector3:
	var total := Vector3.ZERO
	var count := 0
	for web in rig:
		for anchor in web.anchors:
			total += anchor
			count += 1
	if count == 0:
		return Vector3.ZERO
	return total / float(count)


static func _name_for(rig: Array[WebStructure]) -> String:
	var names := PackedStringArray()
	for web in rig:
		var label := web.pattern.display_name
		if not names.has(label):
			names.append(label)
	if names.size() == 1:
		return names[0] + " rig"
	if names.size() > 3:
		return "%s + %d more" % [names[0], names.size() - 1]
	return " + ".join(names)


static func _slug(text: String) -> String:
	var slug := ""
	for character in text.to_lower():
		if character.is_valid_identifier() or character.is_valid_int():
			slug += character
		elif slug.length() > 0 and not slug.ends_with("_"):
			slug += "_"
	return slug.trim_suffix("_").left(40)
