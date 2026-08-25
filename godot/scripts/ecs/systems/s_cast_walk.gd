extends ECSSystem
class_name SCastWalk

## SCastWalk walks everyone the player does not.
##
## The movement is arithmetic, not physics: a passenger has no [CharacterBody3D] and
## wants none. What the aisle needs is a line down the middle of it, and putting five
## capsules in a corridor two metres wide buys nothing but a bill for the collisions
## between them.
##
## It runs whether or not a rig exists, because [CErrand.at] is where the character is
## and the rig is only what that looks like. A conductor who walked only while watched
## would arrive at the dining car the moment the player turned to look down the train.
##
## The speeds it writes into [CLocomotion] are the ones actually covered, so a character
## held up by a shut door has legs that stop with them.

func _on_update(delta: float) -> void:
	for entry: Dictionary in multi_view([CErrand, CLocomotion, CGait, CCharacterRig]):
		_step(entry[&"CErrand"], entry[&"CLocomotion"], entry[&"CCharacterRig"].live(), delta)


func _step(errand: CErrand, locomotion: CLocomotion, rig: CharacterRig, delta: float) -> void:
	if not errand.stationed:
		return
	_choose_target(errand, delta)

	var was_at := errand.at
	var toward := errand.target - errand.at
	# The aisle is one dimension and the width of it is another. Walking the length
	# first and stepping aside at the end keeps a character on the centre line, which
	# is where the seats are not.
	var along := Vector3(toward.x, 0.0, 0.0)
	var step := along if absf(toward.x) > errand.arrive_metres else Vector3(0.0, 0.0, toward.z)
	if step.length() > errand.arrive_metres:
		errand.at += step.normalized() * minf(
			errand.walk_metres_per_second * delta, step.length())
		_turn_toward(errand, step.normalized(), locomotion, delta)
	else:
		errand.at.x = errand.target.x
		errand.at.z = errand.target.z
		_turn_to(errand, errand.resting_facing_radians, locomotion, delta)

	_report_speed(errand, locomotion, errand.at - was_at, delta)
	if rig != null:
		rig.position = errand.at
		rig.rotation.y = errand.facing_radians


## A patrol turns round at each end and waits a moment before setting off again.
## Everyone else is going where their room is, which [SCastBody] has already written
## into the station.
func _choose_target(errand: CErrand, delta: float) -> void:
	if errand.patrol_metres <= 0.0:
		errand.target = errand.station
		return
	var reach := errand.patrol_metres * 0.5
	var end := errand.station + Vector3(reach if errand.patrol_outbound else -reach, 0.0, 0.0)
	if errand.at.distance_to(end) > errand.arrive_metres:
		errand.target = end
		return
	if errand.pausing_seconds <= 0.0:
		errand.pausing_seconds = errand.patrol_pause_seconds
	errand.pausing_seconds -= delta
	errand.target = end
	if errand.pausing_seconds <= 0.0:
		errand.patrol_outbound = not errand.patrol_outbound


## The yaw that puts a character's front along [param direction], in the same measure
## the player's facing is kept in: [SLocomotion] reads a facing plus the rig's own
## offset, and so does everything downstream of it.
static func facing_for(direction: Vector3, yaw_offset_radians: float) -> float:
	return wrapf(atan2(-direction.x, -direction.z) - yaw_offset_radians, -PI, PI)


func _turn_toward(errand: CErrand, direction: Vector3, locomotion: CLocomotion,
		delta: float) -> void:
	_turn_to(errand, facing_for(direction, locomotion.forward_yaw_offset_radians),
		locomotion, delta)


func _turn_to(errand: CErrand, wanted: float, locomotion: CLocomotion, delta: float) -> void:
	var turn := wrapf(wanted - errand.facing_radians, -PI, PI)
	errand.facing_radians = wrapf(errand.facing_radians + clampf(turn,
		-errand.turn_radians_per_second * delta,
		errand.turn_radians_per_second * delta), -PI, PI)
	locomotion.facing_radians = errand.facing_radians


## Distance actually covered, split into the two axes the blend space wants. Taken from
## where they ended up rather than from what they were asked to do, so a character who
## did not move has legs that know it.
func _report_speed(errand: CErrand, locomotion: CLocomotion, covered: Vector3,
		delta: float) -> void:
	var forward := SLocomotion.forward_of(locomotion)
	var right := SLocomotion.right_of(locomotion)
	locomotion.forward_metres_per_second = forward.dot(covered) / maxf(delta, 0.0001)
	locomotion.strafe_metres_per_second = right.dot(covered) / maxf(delta, 0.0001)
	locomotion.eye_height_metres = errand.at.y
