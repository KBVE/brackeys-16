extends ECSSystem
class_name SDoorTraffic

## SDoorTraffic opens the doors for everybody who is not the player.
##
## The player asks with [F] and [SDoor] answers. Nobody else has hands to ask with, so
## a door in front of a walking character opens because they are walking through it and
## shuts once they are not.
##
## Recounted from nothing every tick rather than incremented and decremented. A rig is
## thrown away the moment its carriage stops being drawn, and a count that survived that
## would leave a door standing open on a character who no longer exists.
##
## A character standing still does not hold anything: the escort posted either side of
## the guard's van door would otherwise hold it open all night.

## How close a walking character has to be for the door to answer them. Wider than the
## player's own reach, because a door that opens as it is arrived at has already been
## walked into.
const HOLD_METRES := 3.4

## Below this they count as standing rather than walking.
const WALKING_METRES_PER_SECOND := 0.05

func _on_update(_delta: float) -> void:
	var walkers: Array[Vector3] = []
	for entry: Dictionary in multi_view([CErrand, CLocomotion]):
		var errand: CErrand = entry[&"CErrand"]
		if not errand.stationed:
			continue
		var locomotion: CLocomotion = entry[&"CLocomotion"]
		var speed := Vector2(locomotion.forward_metres_per_second,
			locomotion.strafe_metres_per_second).length()
		if speed > WALKING_METRES_PER_SECOND:
			walkers.append(errand.at)

	for entry: Dictionary in multi_view([CDoor, ECSViewComponent]):
		var leaf: Node3D = entry[&"ECSViewComponent"].view as Node3D
		if leaf == null:
			continue
		var door: CDoor = entry[&"CDoor"]
		door.held_open_by = 0
		for walker: Vector3 in walkers:
			# Height is left out of it: a door leaf is measured from its hinge at the
			# floor and a character from their eyes, and the two are never level.
			var flat := Vector2(leaf.global_position.x - walker.x,
				leaf.global_position.z - walker.z)
			if flat.length() <= HOLD_METRES:
				door.held_open_by += 1
