extends ECSComponent
class_name CLocomotion

var forward_yaw_offset_radians: float = -PI * 0.5

var facing_radians: float = 0.0

## Where the head is aimed. The body never carries this: pitching a
## [CharacterBody3D] would tilt the collision capsule with it.
var pitch_radians: float = 0.0
var eye_height_metres: float = 1.64
var turn_radians_per_unit: float = 2.4

## How fast the view returns to level once the player stops aiming it.
var pitch_recentre_radians_per_second: float = 2.5
var walk_metres_per_unit: float = 4.0

## Signed along the walking direction, so backing up reads negative. Written by
## [SLocomotion] from distance actually covered, which is zero against a wall.
var forward_metres_per_second: float = 0.0
