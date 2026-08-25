# GdUnitTestSuite
extends GdUnitTestSuite

const SCENE := "res://scenes/train/train.scn"

## Late enough that the cast are aboard and standing in rooms they will later leave.
const ABOARD_MINUTES := 21 * 60

## When Lady Beaumont's timeline takes her from the corridor to her cabin, which is a
## carriage along and a door in between.
const SHE_RETIRES_MINUTES := 23 * 60 + 45


func _clock_to(minutes: int) -> void:
	Session.time_of_day.running = false
	var clock: SClock = Ecs.runner.get_system(&"clock")
	clock.set_minutes(Session.time_of_day, minutes)


func after_test() -> void:
	Session.time_of_day.running = true


func _doors() -> Array:
	return Ecs.world.multi_view([CDoor, ECSViewComponent])


## Nobody has hands to press [F] with but the player, so a door in front of a walking
## character has to open because they are walking through it.
func test_a_door_opens_for_somebody_walking_through_it() -> void:
	var runner := scene_runner(SCENE)
	_clock_to(ABOARD_MINUTES)
	await runner.simulate_frames(30)
	for entry: Dictionary in _doors():
		assert_int(entry[&"CDoor"].held_open_by).override_failure_message(
			"a standing cast should not be holding any door open"
		).is_equal(0)

	_clock_to(SHE_RETIRES_MINUTES)
	var opened := false
	for step in range(14):
		await runner.simulate_frames(60)
		for entry: Dictionary in _doors():
			if entry[&"CDoor"].held_open_by > 0 and entry[&"CDoor"].swing > 0.9:
				opened = true
	assert_bool(opened).override_failure_message(
		"walking the cast to their cabins should have swung a door open on the way"
	).is_true()


## The escort pace a few metres of the guard's van all night. On distance alone the end
## door flapped every time one of them turned round at that end of their beat.
func test_pacing_beside_a_door_does_not_work_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(20)

	var posted: Array[Vector3] = []
	for entry: Dictionary in Ecs.world.multi_view([CErrand, CAppearance]):
		if not entry["entity"].has(CPassenger):
			posted.append(entry[&"CErrand"].station)
	assert_array(posted).is_not_empty()

	# The doors of the van they are posted in, which are the only ones they come near.
	var theirs: Array = _doors().filter(func(entry: Dictionary) -> bool:
		var leaf: Node3D = entry[&"ECSViewComponent"].view as Node3D
		for station: Vector3 in posted:
			if absf(leaf.global_position.x - station.x) < 12.0:
				return true
		return false)
	assert_array(theirs).is_not_empty()

	var worked := 0
	for step in range(10):
		await runner.simulate_frames(45)
		for entry: Dictionary in theirs:
			if entry[&"CDoor"].swing > 0.5:
				worked += 1
	assert_int(worked).override_failure_message(
		"the escort turning round at the end of their beat should leave the door alone"
	).is_equal(0)
