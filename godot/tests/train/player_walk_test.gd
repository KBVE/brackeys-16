# GdUnitTestSuite
extends GdUnitTestSuite

const SCENE := "res://scenes/train/train.scn"
const STEP := 1.0 / 60.0


## Walking used to add to world X whatever the player was looking at, so turning
## round and pressing forward walked you backwards. Direction has to come from
## the camera basis, and this is the test that says so.
func test_walking_follows_the_way_the_player_faces() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var player: CharacterBody3D = train.get_node("Screen/Frame/World/Player")

	var start := player.position.x
	train._walk(1.0, STEP)
	var forward_gain := player.position.x - start
	assert_float(forward_gain).override_failure_message(
		"facing down the train, walking forward should raise world X"
	).is_greater(0.0)

	train._facing = PI
	train._apply_shot()
	await runner.simulate_frames(1)
	start = player.position.x
	train._walk(1.0, STEP)
	assert_float(player.position.x - start).override_failure_message(
		"turned around, the same forward input has to walk the other way"
	).is_less(0.0)


## The shell keeps the player inside the carriage; without it a long enough walk
## leaves the train entirely.
func test_the_player_cannot_walk_out_through_a_wall() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var player: CharacterBody3D = train.get_node("Screen/Frame/World/Player")

	train._facing = PI * 0.5
	train._apply_shot()
	await runner.simulate_frames(1)
	for i in range(40):
		train._walk(1.0, STEP)
		await runner.simulate_frames(1)
	assert_float(absf(player.position.z)).override_failure_message(
		"the player walked out sideways through the carriage wall"
	).is_less(Consist.INTERIOR_HALF_Z)
