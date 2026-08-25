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

## The seat currently occupied, so standing releases the one that was taken rather than
## whichever is nearest by then.
var seat: CSeat = null

## Which way the camera swings to get over the aisle, set on sitting down. It depends on
## the bench: from the near side the aisle is one way, from the far side the other, and
## a fixed quarter turn films one of them through the wall.
var camera_yaw_radians: float = 0.0
