extends ECSComponent
class_name CCharacterRig

var rig: PlayerBody

func _init(r: PlayerBody = null) -> void:
	rig = r
