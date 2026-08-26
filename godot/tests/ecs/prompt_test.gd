# GdUnitTestSuite
extends GdUnitTestSuite

const SCENE := "res://scenes/train/train.scn"


func _prompt(train: Node) -> CPrompt:
	return train._prompt


func _player(train: Node) -> CharacterBody3D:
	return train.get_node("Screen/Frame/World/Player")


## The nearest door to the player, and where to stand to be at it.
func _a_door() -> Dictionary:
	for entry: Dictionary in Ecs.world.multi_view([CDoor, ECSViewComponent]):
		return entry
	return {}


func _stand_at(train: Node, at: Vector3) -> void:
	_player(train).global_position = Vector3(at.x, _player(train).global_position.y, at.z)


## Standing at a shut door, the key opens it, and the label has to be able to say so
## before the player finds out by pressing it.
func test_a_door_within_reach_offers_to_open() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var door := _a_door()
	var leaf: Node3D = door[&"ECSViewComponent"].view as Node3D
	door[&"CDoor"].is_open = false

	# Beside the leaf rather than in its doorway, which is a different answer.
	_stand_at(train, leaf.global_position + Vector3(0.5, 0.0, -0.8))
	await runner.simulate_frames(4)

	assert_bool(_prompt(train).action == CPrompt.OPEN_THE_DOOR).override_failure_message(
		"open_the_door was expected, got %s" % _prompt(train).action).is_true()
	assert_bool(_prompt(train).within_reach).is_true()
	assert_bool(_prompt(train).refusal == CPrompt.NOTHING).override_failure_message(
		"no refusal was expected, got %s" % _prompt(train).refusal).is_true()


## An open door offers the other half of the same key.
func test_an_open_door_offers_to_shut() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var door := _a_door()
	var leaf: Node3D = door[&"ECSViewComponent"].view as Node3D
	door[&"CDoor"].is_open = true

	_stand_at(train, leaf.global_position + Vector3(0.5, 0.0, -0.8))
	await runner.simulate_frames(4)
	assert_bool(_prompt(train).action == CPrompt.SHUT_THE_DOOR).override_failure_message(
		"shut_the_door was expected, got %s" % _prompt(train).action).is_true()


## [SDoor] refuses to shut a door on the player standing in it. The label says why,
## because a key that does nothing and says nothing reads as a broken key.
func test_standing_in_the_doorway_is_said_out_loud() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var door := _a_door()
	var leaf: Node3D = door[&"ECSViewComponent"].view as Node3D
	door[&"CDoor"].is_open = true

	_stand_at(train, leaf.global_position)
	await runner.simulate_frames(4)
	assert_bool(_prompt(train).refusal == CPrompt.IN_THE_DOORWAY).override_failure_message(
		"in_the_doorway was expected, got %s" % _prompt(train).refusal).is_true()


## A door somebody is walking through will not shut for the press either, because
## [SDoorTraffic] holds it. Same key, same nothing, and worth a different sentence.
func test_a_door_held_by_traffic_says_somebody_is_coming() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var door := _a_door()
	var leaf: Node3D = door[&"ECSViewComponent"].view as Node3D
	door[&"CDoor"].is_open = true

	# The count is recomputed from nothing every tick by [SDoorTraffic], which is what
	# stops a freed rig propping a door open for the rest of the run. Which also means
	# it cannot be set by hand while that system is running, so for the length of this
	# test it is not: what is under test is the sentence, not the counting.
	Ecs.remove_system(&"door_traffic")
	await runner.simulate_frames(2)
	door[&"CDoor"].held_open_by = 1

	_stand_at(train, leaf.global_position + Vector3(0.5, 0.0, -0.8))
	await runner.simulate_frames(4)
	assert_bool(_prompt(train).refusal == CPrompt.HELD_OPEN).override_failure_message(
		"held_open was expected, got %s" % _prompt(train).refusal).is_true()
	door[&"CDoor"].held_open_by = 0


## A locked door is the one refusal that was already reported to React, and the label
## should not be the last thing to hear about it.
func test_a_locked_door_says_locked() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var door := _a_door()
	var leaf: Node3D = door[&"ECSViewComponent"].view as Node3D
	door[&"CDoor"].is_locked = true

	_stand_at(train, leaf.global_position + Vector3(0.5, 0.0, -0.8))
	await runner.simulate_frames(4)
	assert_bool(_prompt(train).refusal == CPrompt.LOCKED).override_failure_message(
		"locked was expected, got %s" % _prompt(train).refusal).is_true()
	door[&"CDoor"].is_locked = false


## A bench with somebody in it answers nothing when the key is pressed, and a player
## standing at a full row was told nothing at all, which reads as a bench that is broken
## rather than one that is occupied.
func test_a_row_of_taken_benches_says_taken() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var seats: Array = Ecs.world.view(&"CSeat")
	assert_array(seats).is_not_empty()

	# Stand at one bench and fill everything within arm's length of it, which is what a
	# carriage looks like once the cast have settled.
	var seat: CSeat = seats[0]
	_stand_at(train, Vector3(seat.at.x, 0.0, -signf(seat.at.z) * 0.4))
	var sitter := CSeating.new()
	var filled: Array[CSeat] = []
	for other: CSeat in seats:
		if other.at.distance_to(seat.at) > 3.0:
			continue
		other.taken_by = sitter
		filled.append(other)
	await runner.simulate_frames(4)

	assert_bool(_prompt(train).action == CPrompt.SIT_DOWN).override_failure_message(
		"a bench should still be offered, got %s" % _prompt(train).action).is_true()
	assert_bool(_prompt(train).refusal == CPrompt.TAKEN).override_failure_message(
		"taken was expected, got %s" % _prompt(train).refusal).is_true()

	for other: CSeat in filled:
		other.taken_by = null


## Nothing to do is the common case, and it has to read as nothing: a label that always
## says something is a label nobody reads.
##
## Tested in the guard's van rather than a saloon. Standing in the aisle of a carriage
## with benches down both sides, a bench is always within arm's length, and offering to
## sit down is the right answer there.
func test_a_bare_carriage_offers_nothing() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(10)
	var train: Node = runner.scene()
	var consist: Consist = train.get_node("Screen/Frame/World/Consist")
	var aboard := GameContent.carriage_locations()
	var van := aboard.find(&"guard_van")
	assert_int(van).override_failure_message("the consist has lost its guard's van").is_greater_equal(0)

	# The middle of the van, which is the length of half a carriage from either door.
	_stand_at(train, Vector3((van - (consist.carriage_count - 1) / 2.0) * consist.pitch,
		0.0, 0.0))
	await runner.simulate_frames(4)
	assert_bool(_prompt(train).offers_anything()).override_failure_message(
		"a bare carriage offered %s" % _prompt(train).action).is_false()
