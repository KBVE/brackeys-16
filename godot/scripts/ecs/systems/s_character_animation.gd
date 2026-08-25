extends ECSSystem
class_name SCharacterAnimation

func _on_update(delta: float) -> void:
	for entry: Dictionary in multi_view([CLocomotion, CCharacterRig]):
		var rig: PlayerBody = entry[&"CCharacterRig"].rig
		if rig == null:
			continue
		rig.drive(entry[&"CLocomotion"].forward_metres_per_second, delta)
