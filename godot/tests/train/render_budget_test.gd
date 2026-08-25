extends GdUnitTestSuite

## The scaler is what stands between a phone and 15 fps, and every one of its
## decisions is a timer with hysteresis. Those are exactly the rules that rot
## silently, so they are pinned here rather than left to be noticed on a device.

const FRAME := 1.0 / 60.0


func _run_at(budget: RenderBudget, fps: float, seconds: float) -> void:
	for _i in range(int(seconds / FRAME)):
		budget.sample(fps, FRAME)


func test_a_touchscreen_starts_below_full_resolution() -> void:
	var phone := RenderBudget.new()
	phone.begin(true, 3.0)
	assert_int(phone.shrink).override_failure_message(
		"a high density touchscreen has never held 60 at full resolution"
	).is_greater(RenderBudget.FASTEST_SHRINK)

	var desktop := RenderBudget.new()
	desktop.begin(false, 2.0)
	assert_int(desktop.shrink).is_equal(RenderBudget.FASTEST_SHRINK)


func test_a_slow_device_gives_up_pixels() -> void:
	var budget := RenderBudget.new()
	budget.begin(false, 1.0)
	_run_at(budget, 20.0, 6.0)
	assert_int(budget.shrink).override_failure_message(
		"20 fps for six seconds has to divide the resolution"
	).is_greater(RenderBudget.FASTEST_SHRINK)


func test_it_never_divides_past_the_floor() -> void:
	var budget := RenderBudget.new()
	budget.begin(true, 3.0)
	_run_at(budget, 5.0, 600.0)
	assert_int(budget.shrink).is_equal(RenderBudget.SLOWEST_SHRINK)


func test_headroom_is_taken_back_but_not_at_once() -> void:
	var budget := RenderBudget.new()
	budget.begin(true, 3.0)
	var started_at := budget.shrink

	_run_at(budget, 60.0, 4.0)
	assert_int(budget.shrink).override_failure_message(
		"four fast seconds is not yet proof; upgrading that eagerly is what oscillates"
	).is_equal(started_at)

	_run_at(budget, 60.0, 6.0)
	assert_int(budget.shrink).is_less(started_at)


func test_a_level_that_proved_slow_is_not_retried_immediately() -> void:
	var budget := RenderBudget.new()
	budget.begin(false, 1.0)
	_run_at(budget, 20.0, 6.0)
	var after_degrade := budget.shrink

	# the frame rate recovers precisely because the resolution dropped, which is
	# the trap: treating that as headroom walks straight back into the stutter
	_run_at(budget, 60.0, 10.0)
	assert_int(budget.shrink).override_failure_message(
		"recovering because we degraded is not evidence the old level works"
	).is_equal(after_degrade)


func test_antialiasing_goes_before_the_resolution_does() -> void:
	var budget := RenderBudget.new()
	budget.shrink = 1
	assert_int(budget.msaa()).is_equal(Viewport.MSAA_4X)
	budget.shrink = 2
	assert_int(budget.msaa()).is_equal(Viewport.MSAA_2X)
	budget.shrink = 3
	assert_int(budget.msaa()).is_equal(Viewport.MSAA_DISABLED)


## A hitch is not a workload. Streaming a carriage in, a tab coming back from the
## background and a garbage collection all arrive as one very long frame, and
## dropping a level for one is what made the whole run go soft mid-aisle.
func test_one_long_stall_does_not_cost_a_level() -> void:
	var budget := RenderBudget.new()
	budget.begin(false, 1.0)
	_run_at(budget, 60.0, 4.0)

	for _i in range(6):
		budget.sample(4.0, 0.30)

	assert_int(budget.shrink).override_failure_message(
		"a stall spent the resolution the player was already holding"
	).is_equal(RenderBudget.FASTEST_SHRINK)


## The wait before retrying a level doubles on every degrade. Without a ceiling and
## a way back, one bad minute puts the next attempt minutes out and the run never
## recovers what it gave up.
func test_a_bad_patch_is_forgiven_once_the_device_proves_itself() -> void:
	var patchy := RenderBudget.new()
	patchy.begin(false, 1.0)
	_run_at(patchy, 20.0, 30.0)
	assert_int(patchy.shrink).is_greater(RenderBudget.FASTEST_SHRINK)

	_run_at(patchy, 60.0, 120.0)
	assert_int(patchy.shrink).override_failure_message(
		"two clean minutes and it still will not give the pixels back"
	).is_equal(RenderBudget.FASTEST_SHRINK)
