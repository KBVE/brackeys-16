extends ECSSystem
class_name SPosture

## SPosture decides whether the body is walking, leaving the floor, in the air or
## arriving, and tells the rig when that answer changes.
##
## The decision is here rather than in an [AnimationNodeStateMachine] because the thing
## it is decided from is [CLocomotion], which the rig cannot see and should not: a
## passenger and the player run the same rig off different locomotion.

func _on_update(delta: float) -> void:
	for entry: Dictionary in multi_view([CLocomotion, CPosture, CCharacterRig]):
		var rig: CharacterRig = entry[&"CCharacterRig"].rig
		if rig == null:
			continue
		_step(entry[&"CLocomotion"], entry[&"CPosture"], rig, delta)


func _step(locomotion: CLocomotion, posture: CPosture, rig: CharacterRig,
		delta: float) -> void:
	var airborne := locomotion.airborne()
	if airborne:
		# rising is the launch and falling is the fall, which is the whole state machine
		posture.state = CPosture.LAUNCHING if locomotion.rise_metres_per_second > 0.0 \
			else CPosture.AIRBORNE
		posture.landing_seconds_left = 0.0
	elif posture.was_airborne:
		posture.state = CPosture.LANDING
		posture.landing_seconds_left = posture.landing_seconds
	elif posture.landing_seconds_left > 0.0:
		posture.landing_seconds_left -= delta
		if posture.landing_seconds_left <= 0.0:
			posture.state = CPosture.AFOOT
	else:
		posture.state = CPosture.AFOOT
	posture.was_airborne = airborne

	if posture.state != posture.requested:
		posture.requested = posture.state
		rig.set_posture(posture.state)
