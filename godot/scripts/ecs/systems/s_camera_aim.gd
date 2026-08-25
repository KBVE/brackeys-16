extends ECSSystem
class_name SCameraAim

## SCameraAim points the head. Yaw rides the body, so this is pitch and the fixed
## quarter turn that makes the camera look down the train rather than across it.

func _on_update(_delta: float) -> void:
	for entry: Dictionary in multi_view([CLocomotion, CCamera]):
		var eye: CCamera = entry[&"CCamera"]
		if eye.pivot == null:
			continue
		var locomotion: CLocomotion = entry[&"CLocomotion"]
		locomotion.pitch_radians = clampf(locomotion.pitch_radians,
			eye.lowest_pitch_radians, eye.highest_pitch_radians)
		eye.pivot.rotation = Vector3(locomotion.pitch_radians,
			locomotion.forward_yaw_offset_radians, 0.0)
		_keep_inside_the_carriage(eye)


## Runs after the arm has placed the camera, and only ever pulls it in.
func _keep_inside_the_carriage(eye: CCamera) -> void:
	if eye.camera == null:
		return
	var at := eye.camera.global_position
	var inside := Vector3(at.x,
		clampf(at.y, eye.lowest_y, eye.highest_y),
		clampf(at.z, -eye.interior_half_z, eye.interior_half_z))
	if inside != at:
		eye.camera.global_position = inside
