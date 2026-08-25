extends ECSSystem
class_name SPlayerControl

## SPlayerControl turns keys, sticks and swipes into [CInput].
##
## Nothing here touches a transform. It is the only place that reads [Input], so a
## replay or a test can drive the same entity by writing [CInput] directly and
## calling [method set_update] false.

## Screen heights a finger travels for one unit of movement, so a swipe covers the
## same arc on any display.
var drag_screens_per_unit: float = 2.6

var _drag_units := Vector2.ZERO


## Called by whoever owns the viewport, because the pixel-to-unit conversion needs
## a window height and a system has no window.
func accumulate_drag(relative_pixels: Vector2, window_height: float) -> void:
	if window_height <= 0.0:
		return
	_drag_units += relative_pixels / window_height * drag_screens_per_unit


func _on_update(delta: float) -> void:
	# a held key is a rate, so it scales with frame time; a drag is already a
	# distance, so it must not. Swap either sign to invert that axis.
	var turn_units := Input.get_axis(&"move_left", &"move_right") * delta - _drag_units.x
	var walk_units := Input.get_axis(&"move_down", &"move_up") * delta + _drag_units.y
	_drag_units = Vector2.ZERO
	for intent: CInput in view(&"CInput"):
		intent.turn_units = turn_units
		intent.walk_units = walk_units
