extends ECSComponent
class_name CLocomotion

var forward_yaw_offset_radians: float = -PI * 0.5

var facing_radians: float = 0.0
var eye_height_metres: float = 2.60
var turn_radians_per_unit: float = 2.4
var walk_metres_per_unit: float = 4.0

## Signed along the walking direction, so backing up reads negative. Written by
## [SLocomotion] from distance actually covered, which is zero against a wall.
var forward_metres_per_second: float = 0.0
