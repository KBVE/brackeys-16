extends ECSComponent
class_name CCharacterRig

## CCharacterRig points at the skinned body an entity is seen as. On the player that
## is what [CLocomotion] is doing; on a passenger it is null until [SCastBody] builds
## one, and null again once their carriage is out of view.
##
## Separate from [ECSViewComponent], which on this entity is already the
## [CharacterBody3D] the physics moves.

var rig: CharacterRig

func _init(r: CharacterRig = null) -> void:
	rig = r
