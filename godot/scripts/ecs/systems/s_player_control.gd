extends ECSSystem
class_name SPlayerControl

## SPlayerControl turns keys, sticks, mice and swipes into [CInput].
##
## Nothing here touches a transform. It is the only place that reads [Input], so a
## replay or a test can drive the same entity by writing [CInput] directly and
## calling [method set_update] false.
##
## Pointers and touchscreens do not share a scheme. A mouse looks, because it has a
## second axis a keyboard is already covering for; a finger cannot look and walk at
## once, so a drag stays what it was, turn across and walk up.

## Screen heights a finger or a mouse travels for one unit, so a gesture covers the
## same arc on any display.
var drag_screens_per_unit: float = 2.6
var mouse_screens_per_unit: float = 2.6

var _drag_units := Vector2.ZERO
var _look_units := Vector2.ZERO


## Touch. Across is turn, up is walk.
func accumulate_drag(relative_pixels: Vector2, window_height: float) -> void:
	if window_height > 0.0:
		_drag_units += relative_pixels / window_height * drag_screens_per_unit


## Mouse. Across is turn, up is pitch.
func accumulate_look(relative_pixels: Vector2, window_height: float) -> void:
	if window_height > 0.0:
		_look_units += relative_pixels / window_height * mouse_screens_per_unit


func _on_update(delta: float) -> void:
	# a held key is a rate, so it scales with frame time; a gesture is already a
	# distance, so it must not. Swap either sign to invert that axis.
	var walk_units := Input.get_axis(&"move_down", &"move_up") * delta + _drag_units.y
	var strafe_units := Input.get_axis(&"move_left", &"move_right") * delta
	# the drag and the mouse disagree on purpose: a finger pushes the world the way
	# a map moves under it, a mouse points the head the way it moves
	var turn_units := _drag_units.x - _look_units.x
	var pitch_units := -_look_units.y
	# a finger that is dragging is looking, the same as a held right button, so the
	# crosshair comes up on a touchscreen without a second thing to press
	var holding_look := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or not _drag_units.is_zero_approx()
	# the middle button, because left picks up evidence and right is already the look
	var recentring_view := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	_drag_units = Vector2.ZERO
	_look_units = Vector2.ZERO
	for intent: CInput in view(&"CInput"):
		intent.walk_units = walk_units
		intent.strafe_units = strafe_units
		intent.turn_units = turn_units
		intent.pitch_units = pitch_units
		intent.holding_look = holding_look
		intent.recentring_view = recentring_view
