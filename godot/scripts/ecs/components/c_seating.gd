extends ECSComponent
class_name CSeating

## CSeating is whether a character is sat down, and what they got up from.
##
## Sitting is not a place the walk can reach: it moves the body onto the cushion, drops
## the eye, turns the shoulders square to the bench and takes the legs away. All of that
## has to be undone exactly on standing, so what was true before is kept here rather
## than recomputed from a carriage that may have moved on.

var seated: bool = false

## Where the eye sat and which way the body faced before it took a seat.
var stood_eye_height_metres: float = 0.0
var stood_facing_radians: float = 0.0
var stood_at := Vector3.ZERO

## How far away a seat can be and still be sat in. An arm's length: far enough that
## standing beside a bench is enough, near enough that it is unambiguous which one.
var reach_metres: float = 1.4

## How far above the cushion the eye ends up. A seated adult is roughly this much taller
## than what they are sitting on.
var seated_eye_above_cushion_metres: float = 0.72

## How far forward of the anchor to park him. The sitting clip is authored with the
## pelvis a third of a metre behind the rig's own origin, so dropping the root on the
## cushion puts his backside inside the seat back and his thighs come out of the
## upholstery. Measured off the clip: hips at -6.931 for a root at -6.600.
var seated_forward_offset_metres: float = 0.33

## The seat currently occupied, so standing releases the one that was taken rather than
## whichever is nearest by then.
var seat: CSeat = null

## How far the camera swings to get off the bench and over the aisle, set on sitting
## down. Standing it is nothing: the shot rides behind the shoulder. Seated there is a
## wall where behind used to be.
var camera_yaw_radians: float = 0.0
