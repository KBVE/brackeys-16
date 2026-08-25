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

func _on_update(delta: float) -> void:
	for entry: Dictionary in multi_view([CInput, CLocomotion, CSeating, CCharacterRig,
			CPointer, ECSViewComponent]):
		var body: CharacterBody3D = entry[&"ECSViewComponent"].view as CharacterBody3D
		if body == null:
			continue
		_step(entry[&"CInput"], entry[&"CLocomotion"], entry[&"CSeating"],
			entry[&"CPointer"], entry[&"CCharacterRig"].rig, body, delta)


func _step(intent: CInput, locomotion: CLocomotion, seating: CSeating,
		pointer: CPointer, rig: CharacterRig, body: CharacterBody3D, delta: float) -> void:
	if seating.moving():
		# folding onto the cushion or coming back off it. The walk is off and so is the
		# request that would answer, because a sit interrupted halfway is a body standing
		# in the bench.
		intent.walk_units = 0.0
		intent.strafe_units = 0.0
		intent.jump_requested = false
		intent.interact_requested = false
		intent.pointer_clicked = false
		_carry(locomotion, seating, rig, body, delta)
		return
	if seating.seated:
		# a seated body has no walk, and the request that would have moved it is the
		# one that gets it up again
		intent.walk_units = 0.0
		intent.strafe_units = 0.0
		intent.jump_requested = false
		if intent.interact_requested or intent.pointer_clicked:
			# consumed, so one press is one answer: without this the door behind the
			# bench opens on the same press that got him out of it
			intent.interact_requested = false
			intent.pointer_clicked = false
			_stand(locomotion, seating, rig, body)
		return

	# pointing first: a click names the bench, where [F] can only take the nearest one
	if intent.pointer_clicked and pointer.seat != null and pointer.seat.free_to_take():
		intent.pointer_clicked = false
		_sit(locomotion, seating, rig, body, pointer.seat)
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


## Moves the body along the sit-down or the stand-up, a share of the way for a share of
## the clip. Sitting used to be one frame: the body was on the cushion before the clip
## it plays there had begun, which read as a teleport with an animation after it.
##
## The eye and the facing are carried with it, so the shot swings across the aisle over
## the same second the shoulders do.
func _carry(locomotion: CLocomotion, seating: CSeating, rig: CharacterRig,
		body: CharacterBody3D, delta: float) -> void:
	if seating.settling_seconds_left > 0.0:
		seating.settling_seconds_left -= delta
	else:
		seating.rising_seconds_left -= delta
	var along := seating.moved_fraction()
	locomotion.facing_radians = lerp_angle(seating.facing_from, seating.facing_to, along)
	locomotion.eye_height_metres = lerpf(seating.eye_from, seating.eye_to, along)
	body.velocity = Vector3.ZERO
	var at := seating.moving_from.lerp(seating.moving_to, along)
	body.global_position = Vector3(at.x, locomotion.eye_height_metres, at.z)
	# the deck does not move while the eye does, so the drop is recomputed rather than
	# set once: the soles stay on the floor for the whole fold
	if rig != null:
		rig.set_ground_drop(locomotion.eye_height_metres - Consist.FLOOR_Y)
	if seating.moving():
		return
	# arrived. Standing gives the seat back here rather than when the stand was asked
	# for, so nobody else takes a bench that still has a body coming out of it.
	if seating.seated:
		return
	if seating.seat != null:
		seating.seat.taken_by = null
		seating.seat = null
	if rig != null:
		rig.set_ground_drop(rig.rest_ground_drop())


func _sit(locomotion: CLocomotion, seating: CSeating, rig: CharacterRig,
		body: CharacterBody3D, seat: CSeat) -> void:
	seating.stood_eye_height_metres = locomotion.eye_height_metres
	seating.stood_facing_radians = locomotion.facing_radians
	seating.stood_at = body.global_position
	seating.seated = true
	seating.seat = seat
	seat.taken_by = seating
	# directly behind a seated body is the back of the seat behind it, which the spring
	# arm collides with and pulls the camera to nothing. The only clear line is across
	# the aisle, and where that is depends on both the bench he is on and which of the
	# two directions his half of the pair faces.
	var toward_the_aisle := PI if seat.at.z > 0.0 else 0.0
	seating.camera_yaw_radians = toward_the_aisle - seat.facing_radians \
		- locomotion.forward_yaw_offset_radians
	locomotion.facing_radians = seat.facing_radians
	locomotion.eye_height_metres = seat.at.y + seating.seated_eye_above_cushion_metres
	locomotion.height_above_stance_metres = 0.0
	locomotion.rise_metres_per_second = 0.0
	body.velocity = Vector3.ZERO
	var sat_forward := SLocomotion.forward_of(locomotion) \
		* seating.seated_forward_offset_metres
	seating.moving_from = seating.stood_at
	seating.moving_to = Vector3(seat.at.x + sat_forward.x,
		locomotion.eye_height_metres, seat.at.z + sat_forward.z)
	seating.facing_from = seating.stood_facing_radians
	seating.facing_to = seat.facing_radians
	seating.eye_from = seating.stood_eye_height_metres
	seating.eye_to = locomotion.eye_height_metres
	seating.moving_seconds = rig.posture_clip_seconds(CPosture.SEATING) \
		if rig != null else 0.0
	seating.settling_seconds_left = seating.moving_seconds
	if not seating.moving():
		# no clip to wait for, which is every headless rig and any pack without a
		# sit-down. Straight onto the cushion, the way it was before there was one.
		locomotion.facing_radians = seating.facing_to
		body.global_position = seating.moving_to
		if rig != null:
			rig.set_ground_drop(locomotion.eye_height_metres - Consist.FLOOR_Y)
		return
	# the facing and the eye belong to the move now, so they start where the body is
	# rather than where it is going
	locomotion.facing_radians = seating.facing_from
	locomotion.eye_height_metres = seating.eye_from


func _stand(locomotion: CLocomotion, seating: CSeating, rig: CharacterRig,
		body: CharacterBody3D) -> void:
	seating.seated = false
	seating.moving_from = body.global_position
	seating.moving_to = Vector3(body.global_position.x,
		seating.stood_eye_height_metres, seating.stood_at.z)
	seating.facing_from = locomotion.facing_radians
	seating.facing_to = seating.stood_facing_radians
	seating.eye_from = locomotion.eye_height_metres
	seating.eye_to = seating.stood_eye_height_metres
	seating.moving_seconds = rig.posture_clip_seconds(CPosture.RISING) \
		if rig != null else 0.0
	seating.rising_seconds_left = seating.moving_seconds
	if seating.moving():
		return
	if seating.seat != null:
		seating.seat.taken_by = null
		seating.seat = null
	locomotion.eye_height_metres = seating.eye_to
	locomotion.facing_radians = seating.facing_to
	body.global_position = seating.moving_to
	if rig != null:
		rig.set_ground_drop(rig.rest_ground_drop())
