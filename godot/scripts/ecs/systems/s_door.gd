extends ECSSystem
class_name SDoor

## SDoor answers [F] with the nearest door, and drives every leaf's swing.
##
## The reach test is done here rather than by an Area3D per door because the doors
## are children of carriages that get hidden as the player walks away: a hidden
## Area3D still reports overlaps, so proximity would have to be filtered anyway, and
## a distance against a handful of doors is cheaper than the bodies would be.
##
## Only the nearest door in reach answers, so standing in a vestibule between two
## cars opens the one being looked at rather than both.

func _on_update(delta: float) -> void:
	var asked := false
	var standing_at := Vector3.ZERO
	for entry: Dictionary in multi_view([CInput, CLocomotion, ECSViewComponent]):
		var body: Node3D = entry[&"ECSViewComponent"].view as Node3D
		if body == null:
			continue
		standing_at = body.global_position
		asked = entry[&"CInput"].interact_requested
		break

	var nearest: Dictionary = {}
	var nearest_distance := INF
	for entry: Dictionary in multi_view([CDoor, ECSViewComponent]):
		var leaf: Node3D = entry[&"ECSViewComponent"].view as Node3D
		if leaf == null:
			continue
		var door: CDoor = entry[&"CDoor"]
		_swing(door, leaf, delta)
		if not asked:
			continue
		var distance := leaf.global_position.distance_to(standing_at)
		if distance <= door.reach_metres and distance < nearest_distance:
			nearest_distance = distance
			nearest = entry

	if nearest.is_empty():
		return
	_answer(nearest[&"CDoor"], nearest_distance)


## Reports the attempt either way. A locked door that says nothing is
## indistinguishable from one the player failed to reach.
func _answer(door: CDoor, distance: float) -> void:
	if not door.is_locked:
		door.is_open = not door.is_open
	notify(GameEvents.DOOR_STATE, {
		"open": door.is_open,
		"locked": door.is_locked,
		"distance": snappedf(distance, 0.01),
	})


## Moves the leaf toward wherever the door should be, which is open if the player left
## it that way or if somebody is walking through it.
func _swing(door: CDoor, leaf: Node3D, delta: float) -> void:
	var wants := 1.0 if (door.is_open or door.held_open_by > 0) else 0.0
	if is_equal_approx(door.swing, wants):
		return
	door.swing = move_toward(door.swing, wants,
		delta / maxf(door.seconds_to_swing, 0.0001))
	# smoothstep, so the leaf eases into the stop instead of arriving at full speed
	# and halting on the frame it lands
	var eased: float = door.swing * door.swing * (3.0 - 2.0 * door.swing)
	leaf.rotation.y = eased * door.open_radians * door.swing_sign
