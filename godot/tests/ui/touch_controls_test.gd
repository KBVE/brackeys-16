# GdUnitTestSuite
extends GdUnitTestSuite

const SCREEN := Vector2(1600.0, 720.0)

## Two thumbs, the same as a phone: one on each half, neither on a button.
func _thumbs() -> TouchControls:
	var thumbs := TouchControls.new()
	thumbs.control = SPlayerControl.new()
	thumbs.size = SCREEN
	thumbs.visible = true
	auto_free(thumbs.control)
	return auto_free(thumbs)


func _touch(thumbs: TouchControls, finger: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = finger
	touch.position = at
	touch.pressed = down
	thumbs._input(touch)


func _drag(thumbs: TouchControls, finger: int, to: Vector2) -> void:
	var moved := InputEventScreenDrag.new()
	moved.index = finger
	moved.position = to
	thumbs._input(moved)


## The whole trick: one thumb does two jobs, and which one it did is decided when it
## comes off the glass rather than when it lands.
func test_a_tap_on_the_walking_half_is_a_jump() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, Vector2(1200.0, 500.0), true)
	thumbs._process(0.05)
	_touch(thumbs, 0, Vector2(1200.0, 500.0), false)

	assert_bool(thumbs.control._tapped_jump).override_failure_message(
		"a tap on the right half should jump").is_true()
	assert_bool(thumbs.control._tapped_interact).override_failure_message(
		"the walking thumb used the door as well").is_false()


func test_a_tap_on_the_looking_half_is_the_use_key() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, Vector2(300.0, 500.0), true)
	thumbs._process(0.05)
	_touch(thumbs, 0, Vector2(300.0, 500.0), false)

	assert_bool(thumbs.control._tapped_interact).override_failure_message(
		"a tap on the left half should use what is in front of him").is_true()
	assert_bool(thumbs.control._tapped_jump).override_failure_message(
		"the looking thumb jumped").is_false()


## A stick let go of at full deflection is a thumb coming off a stick, not a tap. Without
## this every walk across a carriage would end in a jump.
func test_a_stick_that_was_steered_does_not_also_fire_its_tap() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, Vector2(1200.0, 500.0), true)
	_drag(thumbs, 0, Vector2(1200.0, 380.0))
	thumbs._process(0.05)
	_touch(thumbs, 0, Vector2(1200.0, 380.0), false)

	assert_bool(thumbs.control._tapped_jump).override_failure_message(
		"a stick that was pushed still fired its tap"
	).is_false()


## Held too long is a thumb resting on the glass, whatever it did or did not travel.
func test_a_thumb_held_still_for_a_while_is_not_a_tap() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, Vector2(1200.0, 500.0), true)
	thumbs._process(TouchStick.TAP_SECONDS + 0.1)
	_touch(thumbs, 0, Vector2(1200.0, 500.0), false)

	assert_bool(thumbs.control._tapped_jump).is_false()


## Left looks and right walks, and neither reaches the other's axis.
func test_the_thumbs_drive_their_own_stick() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, Vector2(300.0, 400.0), true)
	_drag(thumbs, 0, Vector2(300.0 + SCREEN.y * TouchStick.THROW_SCREENS, 400.0))
	_touch(thumbs, 1, Vector2(1200.0, 400.0), true)
	_drag(thumbs, 1, Vector2(1200.0, 400.0 - SCREEN.y * TouchStick.THROW_SCREENS))
	thumbs._process(0.016)

	assert_float(thumbs.control.look_stick.x).override_failure_message(
		"the left thumb should be turning, at full deflection").is_equal_approx(1.0, 0.01)
	assert_float(thumbs.control.move_stick.y).override_failure_message(
		"the right thumb should be walking forward, at full deflection"
	).is_equal_approx(1.0, 0.01)
	assert_float(thumbs.control.move_stick.x).is_equal_approx(0.0, 0.01)
	assert_float(thumbs.control.look_stick.y).is_equal_approx(0.0, 0.01)


## Pushed past the edge of the stick, the thumb stays pinned at full rather than running
## away with the turn.
func test_a_thumb_past_the_throw_is_held_at_full() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, Vector2(300.0, 400.0), true)
	_drag(thumbs, 0, Vector2(300.0 + SCREEN.y, 400.0))
	thumbs._process(0.016)

	assert_float(thumbs.control.look_stick.length()).is_equal_approx(1.0, 0.01)


## The cluster sits inside the walking half. A thumb that came down on [F] meant [F],
## not the stick underneath it.
func test_the_buttons_are_pressed_rather_than_the_stick_under_them() -> void:
	var thumbs := _thumbs()
	_touch(thumbs, 0, thumbs._interact_at(), true)
	thumbs._process(0.016)
	assert_float(thumbs.control.move_stick.length()).override_failure_message(
		"pressing [F] started walking").is_equal_approx(0.0, 0.001)
	_touch(thumbs, 0, thumbs._interact_at(), false)
	assert_bool(thumbs.control._tapped_interact).is_true()

	_touch(thumbs, 1, thumbs._secondary_at(), true)
	_touch(thumbs, 1, thumbs._secondary_at(), false)
	assert_bool(thumbs.control._tapped_secondary).override_failure_message(
		"[G] did not ask for the second answer").is_true()
