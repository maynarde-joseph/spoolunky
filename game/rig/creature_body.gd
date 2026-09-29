class_name CreatureBody
extends Resource

## What a creature looks like and how it moves: the bones, the mesh skinned to
## them, and the motion that poses them.
##
## Each kind of animal is a script that extends this — [InsectBody] is the first —
## and each species of that kind is a .tres of it, so what makes a wasp look
## different from a bee is numbers in a file. A [PreySpecies] points at one, and
## [method make_view] puts it together under the creature.
##
## A body is drawn in its own unit, the creature's body radius. The view is scaled
## by the species' [member PreySpecies.body_radius], so the body says what shape
## the creature is and the species says how big it is.

## Built the first time a creature wears this body, and shared by every one after:
## the bones are each creature's own, but what hangs off them is the same.
var _mesh: ArrayMesh
var _skin: Skin


## A view of this body, ready to go under a creature.
func make_view() -> CreatureView:
	var view := CreatureView.new()
	view.body = self
	return view


## Adds the bones to [param skeleton].
func build_bones(_skeleton: Skeleton3D) -> void:
	pass


## The mesh, skinned to the bones [method build_bones] made.
func build_mesh(_skeleton: Skeleton3D) -> ArrayMesh:
	return null


## What will pose the bones.
func make_motion() -> CreatureMotion:
	return CreatureMotion.new()


## How far below the middle of the body its feet reach when it stands, in body
## radii — where the ground has to be for it to stand on it. Zero with no feet.
func reach_down() -> float:
	return 0.0


## The mesh for [param skeleton], built once.
func mesh_for(skeleton: Skeleton3D) -> ArrayMesh:
	if _mesh == null:
		_mesh = build_mesh(skeleton)
	return _mesh


## The skin for [param skeleton], built once. Every skeleton [method build_bones]
## makes has the same rest pose, so one skin fits them all.
func skin_for(skeleton: Skeleton3D) -> Skin:
	if _skin == null:
		_skin = skeleton.create_skin_from_rest_transforms()
	return _skin
