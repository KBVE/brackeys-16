extends ECSSystem
class_name SCastBody

## SCastBody is the seam between where a passenger is and whether anyone can see them.
##
## [SPassengerPlace] decides where all of them are, always, from their timeline. Almost
## none of that is on screen: the player stands in one carriage and [Consist] draws two
## either side. So a passenger owns a [CharacterRig] only while their carriage is drawn,
## and the moment it is culled the rig goes with it.
##
## Assembling one rig is five glb instantiations and a graft each, which is a frame the
## player feels. [constant BUILDS_PER_TICK] spreads that out, and is the number that
## decides how large the cast can grow: doubling the passengers costs one more tick of
## catching up, not one more spike.

## Rigs built per tick, at most. One is enough to keep up with a walking player and
## small enough to hide inside a frame.
const BUILDS_PER_TICK := 1

## Metres either side of a carriage centre a passenger can be placed, so five of them
## in one carriage do not stand in a heap.
const PLACEMENT_SPREAD := 7.0

## How far off the middle of the aisle they stand. The player walks the centre line and
## the seats are against the walls.
const AISLE_HALF_WIDTH := 0.95

var carriage_pitch: float = 21.0
var carriage_count: int = 1

## Carriages either side of the viewer that hold a rig. Matches Consist.mesh_window, or
## passengers pop in inside a carriage that is already drawn.
var carriage_window: int = 2

## How tall a passenger stands. The rig scales to reach it and their eyes land where
## that puts them, the same way the player's does.
var stature_metres: float = 1.75
var floor_height_metres: float = 0.0

## The rig's yaw offset, the same quarter turn the player's takes.
var forward_yaw_offset_radians: float = -PI * 0.5

## What built rigs are parented to. Freed with the scene, which is why nothing here
## outlives one.
var cast_root: Node3D

## Location id to carriage index, from the authored locations. Built once: the consist
## does not change shape mid-run.
var _carriage_of: Dictionary = {}

func _on_update(_delta: float) -> void:
	if cast_root == null:
		return
	if _carriage_of.is_empty():
		_map_carriages()

	var here := _viewer_carriage()
	var built := 0
	for entry: Dictionary in multi_view([CPassenger, CLocation, CAppearance, CCharacterRig]):
		var rig_slot: CCharacterRig = entry[&"CCharacterRig"]
		var carriage: int = _carriage_of.get(entry[&"CLocation"].location_id, -1)
		var within_the_drawn_window := carriage >= 0 and here >= 0 \
			and absi(carriage - here) <= carriage_window

		if not within_the_drawn_window:
			if rig_slot.rig != null:
				rig_slot.rig.queue_free()
				rig_slot.rig = null
			continue
		if rig_slot.rig != null:
			continue
		if built >= BUILDS_PER_TICK:
			continue
		rig_slot.rig = _build(entry[&"CAppearance"], carriage)
		built += 1


## Their carriage, or -1 while nobody is aboard yet.
func _viewer_carriage() -> int:
	var occupants: Array = view(&"COccupant")
	return occupants[0].carriage_index if not occupants.is_empty() else -1


func _map_carriages() -> void:
	var aboard := GameContent.carriage_locations()
	for i in range(aboard.size()):
		_carriage_of[aboard[i]] = i


func _build(appearance: CAppearance, carriage: int) -> CharacterRig:
	var rig := CharacterRig.from_appearance(appearance)
	rig.stature_metres = stature_metres
	rig.floor_height_metres = floor_height_metres
	rig.forward_yaw_offset_radians = forward_yaw_offset_radians
	rig.position = _place(appearance, carriage)
	rig.rotation.y = _facing(appearance)
	cast_root.add_child(rig)
	return rig


## Where in the carriage they stand. Off their own seed, so a passenger is found in the
## same spot every time their carriage is walked back into, and two of them in one
## carriage are not in the same spot as each other.
func _place(appearance: CAppearance, carriage: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = appearance.character_seed
	var along := (carriage - (carriage_count - 1) / 2.0) * carriage_pitch \
		+ rng.randf_range(-PLACEMENT_SPREAD, PLACEMENT_SPREAD)
	var side := AISLE_HALF_WIDTH if rng.randf() < 0.5 else -AISLE_HALF_WIDTH
	return Vector3(along, floor_height_metres, side)


## Facing across the aisle rather than along it, turned to whichever side they are not
## standing on, so they read as someone at a window rather than someone marching.
func _facing(appearance: CAppearance) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = appearance.character_seed
	rng.randf_range(-PLACEMENT_SPREAD, PLACEMENT_SPREAD)
	var toward_negative_z := rng.randf() < 0.5
	return forward_yaw_offset_radians + (PI * 0.5 if toward_negative_z else -PI * 0.5)


## Systems are freed with the scene that added them, and a rig that outlived its slot
## would leave a component pointing at a freed node.
func _exit_tree() -> void:
	if _world == null:
		return
	for entry: Dictionary in multi_view([CPassenger, CCharacterRig]):
		var rig_slot: CCharacterRig = entry[&"CCharacterRig"]
		if rig_slot.rig != null:
			rig_slot.rig.queue_free()
			rig_slot.rig = null
