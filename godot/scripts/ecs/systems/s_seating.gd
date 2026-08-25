extends ECSSystem
class_name SSeating

## SSeating answers a use request with a chair, when there is one within reach.
##
## It runs between [SPlayerControl] and [SLocomotion], because sitting has to take the
## walk away in the same frame it is asked for: left until after the move, the first
## seated frame is spent sliding into the bench.
##
## Nothing here knows about doors. The same [member CInput.interact_requested] will be
## read by whatever else can answer it, and the nearest thing that can wins.

func _on_update(_delta: float) -> void:
	for entry: Dictionary in multi_view([CInput, CLocomotion, CSeating, CCharacterRig,
			ECSViewComponent]):
		var body: CharacterBody3D = entry[&"ECSViewComponent"].view as CharacterBody3D
		if body == null:
			continue
		_step(entry[&"CInput"], entry[&"CLocomotion"], entry[&"CSeating"],
			entry[&"CCharacterRig"].rig, body)


func _step(intent: CInput, locomotion: CLocomotion, seating: CSeating,
		rig: CharacterRig, body: CharacterBody3D) -> void:
	if seating.seated:
		# a seated body has no walk, and the request that would have moved it is the
		# one that gets it up again
		intent.walk_units = 0.0
		intent.strafe_units = 0.0
		intent.jump_requested = false
		if intent.interact_requested:
			# consumed, so one press is one answer: without this the door behind the
			# bench opens on the same press that got him out of it
			intent.interact_requested = false
			_stand(locomotion, seating, rig, body)
		return
	if not intent.interact_requested:
		return
	var seat := _free_seat_near(seating, body)
	if seat != null:
		intent.interact_requested = false
		_sit(locomotion, seating, rig, body, seat)


## The nearest free seat within reach, or null. Free is the whole point: a bench with a
## passenger already on it is not somewhere to sit, however close it is.
func _free_seat_near(seating: CSeating, body: CharacterBody3D) -> CSeat:
	var found: CSeat = null
	var nearest := seating.reach_metres
	for seat: CSeat in view(&"CSeat"):
		if not seat.free_to_take():
			continue
		# flat: the eye is a metre above the cushion and that metre is not a reason to
		# be out of reach of a seat you are standing beside
		var away := Vector2(body.global_position.x - seat.at.x,
			body.global_position.z - seat.at.z).length()
		if away < nearest:
			nearest = away
			found = seat
	return found


func _sit(locomotion: CLocomotion, seating: CSeating, rig: CharacterRig,
		body: CharacterBody3D, seat: CSeat) -> void:
	seating.stood_eye_height_metres = locomotion.eye_height_metres
	seating.stood_facing_radians = locomotion.facing_radians
	seating.stood_at = body.global_position
	seating.seated = true
	seating.seat = seat
	seat.taken_by = seating
	seating.camera_yaw_radians = -PI * 0.5 * signf(seat.at.z)
	locomotion.facing_radians = seat.facing_radians
	locomotion.eye_height_metres = seat.at.y + seating.seated_eye_above_cushion_metres
	locomotion.height_above_stance_metres = 0.0
	locomotion.rise_metres_per_second = 0.0
	body.velocity = Vector3.ZERO
	body.global_position = Vector3(seat.at.x, locomotion.eye_height_metres, seat.at.z)
	# the clip sits him on a floor, so the rig hangs from the deck rather than the eye
	if rig != null:
		rig.set_ground_drop(locomotion.eye_height_metres - Consist.FLOOR_Y)


func _stand(locomotion: CLocomotion, seating: CSeating, rig: CharacterRig,
		body: CharacterBody3D) -> void:
	if seating.seat != null:
		seating.seat.taken_by = null
		seating.seat = null
	seating.seated = false
	locomotion.eye_height_metres = seating.stood_eye_height_metres
	locomotion.facing_radians = seating.stood_facing_radians
	body.global_position = Vector3(body.global_position.x,
		locomotion.eye_height_metres, seating.stood_at.z)
	if rig != null:
		rig.set_ground_drop(rig.rest_ground_drop())
