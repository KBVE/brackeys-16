extends ECSComponent
class_name CInput

## CInput is one frame of movement and aim intent, already in movement units.
##
## A held key is a rate and a mouse or a drag is a distance, so [SPlayerControl]
## resolves both into the same unit before anything downstream sees them.

var walk_units: float = 0.0
var strafe_units: float = 0.0
var turn_units: float = 0.0
var pitch_units: float = 0.0
