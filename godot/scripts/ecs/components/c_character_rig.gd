extends ECSComponent
class_name CCharacterRig

## CCharacterRig points at the skinned body that shows what [CLocomotion] is doing.
##
## Separate from [ECSViewComponent], which on this entity is already the
## [CharacterBody3D] the physics moves.

var rig: PlayerBody

func _init(r: PlayerBody = null) -> void:
	rig = r
