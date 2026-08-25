extends ECSSystem
class_name SLocomotion

func _on_update(delta: float) -> void:
	for entry: Dictionary in multi_view([CInput, CLocomotion, ECSViewComponent]):
		var body: CharacterBody3D = entry[&"ECSViewComponent"].view as CharacterBody3D
		if body == null:
			continue
		_step(entry[&"CInput"], entry[&"CLocomotion"], body, delta)


func _step(intent: CInput, locomotion: CLocomotion, body: CharacterBody3D, delta: float) -> void:
	# wraps rather than clamps: the player can turn all the way round and look
	# back down the train
	locomotion.facing_radians = wrapf(
		locomotion.facing_radians - intent.turn_units * locomotion.turn_radians_per_unit,
		-PI, PI)
	body.rotation.y = locomotion.facing_radians
	body.position.y = locomotion.eye_height_metres

	var forward := forward_of(locomotion)
	var metres := intent.walk_units * locomotion.walk_metres_per_unit
	var was_at := body.global_position
	# the step is already a distance, so it becomes a velocity only because
	# move_and_slide wants one; sliding is what carries the player along a wall
	# instead of stopping dead against it
	body.velocity = Vector3.ZERO if is_zero_approx(metres) \
		else forward * metres / maxf(delta, 0.0001)
	body.move_and_slide()
	locomotion.forward_metres_per_second = \
		forward.dot(body.global_position - was_at) / maxf(delta, 0.0001)


## Flattened, so looking is never a way to climb.
static func forward_of(locomotion: CLocomotion) -> Vector3:
	var yaw := locomotion.facing_radians + locomotion.forward_yaw_offset_radians
	return Vector3(-sin(yaw), 0.0, -cos(yaw))
