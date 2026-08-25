# GdUnitTestSuite
extends GdUnitTestSuite

const SCENE := "res://scenes/train/train.scn"

## Late enough that everybody has boarded and spread out along the train. At the
## departure the carriages are empty and every one of these would be a test of nothing.
const ABOARD_MINUTES := 21 * 60


## Through the clock system rather than by writing the minute: the minute is derived
## from a phase, and setting it by hand is overwritten on the next tick.
func _clock_to(minutes: int) -> void:
	Session.time_of_day.running = false
	var clock: SClock = Ecs.runner.get_system(&"clock")
	clock.set_minutes(Session.time_of_day, minutes)


func _rigs_in(train: Node) -> Array:
	var cast_root: Node = train.get_node_or_null("Screen/Frame/World/Cast")
	return cast_root.get_children().filter(func(n: Node) -> bool: return n is CharacterRig) \
		if cast_root != null else []


func _passengers_within(train: Node) -> int:
	var aboard := GameContent.carriage_locations()
	var here: int = train._occupant.carriage_index
	var window: int = train.get_node("Screen/Frame/World/Consist").mesh_window
	var count := 0
	for entry: Dictionary in Ecs.world.multi_view([CPassenger, CLocation]):
		var carriage := aboard.find(entry[&"CLocation"].location_id)
		if carriage >= 0 and absi(carriage - here) <= window:
			count += 1
	return count


func _looks_of(train: Node) -> Array:
	return _rigs_in(train).map(func(rig: CharacterRig) -> Array:
		return [rig.appearance.outfit, rig.appearance.hair, rig.appearance.cloth_tint,
			rig.appearance.stature_metres, rig.position])


func after_test() -> void:
	Session.time_of_day.running = true


## Nobody is built for a carriage that is not drawn, which is the whole reason the
## passengers are not five rigs standing in the scene from the start.
func test_only_passengers_in_a_drawn_carriage_have_a_body() -> void:
	var runner := scene_runner(SCENE)
	_clock_to(ABOARD_MINUTES)
	await runner.simulate_frames(30)
	var train: Node = runner.scene()

	var expected := _passengers_within(train)
	assert_int(expected).override_failure_message(
		"the evening was picked so that somebody is aboard and near the player"
	).is_greater(0)
	assert_int(_rigs_in(train).size()).override_failure_message(
		"every passenger in a drawn carriage should have been built by now"
	).is_equal(expected)


## One rig a tick. A cast that all arrived on the same frame would be a visible hitch
## the moment a carriage came into view, and the whole point of the budget is that a
## larger cast costs more ticks rather than a longer one.
func test_bodies_are_built_one_tick_at_a_time() -> void:
	var runner := scene_runner(SCENE)
	_clock_to(ABOARD_MINUTES)
	await runner.simulate_frames(2)
	var train: Node = runner.scene()
	var so_far := _rigs_in(train).size()

	await runner.simulate_frames(1)
	assert_int(_rigs_in(train).size() - so_far).override_failure_message(
		"a single frame should not add more than one body"
	).is_less_equal(SCastBody.BUILDS_PER_TICK)


## A passenger is evidence. Walking out of a carriage and back has to hand back the
## same person in the same place, not a fresh roll wearing somebody else's coat.
func test_a_rebuilt_passenger_is_the_same_person() -> void:
	var runner := scene_runner(SCENE)
	_clock_to(ABOARD_MINUTES)
	await runner.simulate_frames(30)
	var train: Node = runner.scene()

	var before := _looks_of(train)
	assert_array(before).is_not_empty()

	var bodies: SCastBody = Ecs.runner.get_system(&"cast_body")
	var window := bodies.carriage_window
	bodies.carriage_window = -1
	await runner.simulate_frames(2)
	assert_array(_rigs_in(train)).override_failure_message(
		"out of view, a passenger should not still be holding a rig"
	).is_empty()

	bodies.carriage_window = window
	await runner.simulate_frames(30)
	assert_array(_looks_of(train)).override_failure_message(
		"the same passengers should come back identical, down to where they stand"
	).is_equal(before)
