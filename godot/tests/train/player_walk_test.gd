# GdUnitTestSuite
extends GdUnitTestSuite

const SCENE := "res://scenes/train/train.scn"


func _locomotion_of(train: Node) -> CLocomotion:
	return train._locomotion


## Walking used to add to world X whatever the player was looking at, so turning
## round and pressing forward walked you backwards. Direction has to come from the
## facing the body carries, and this is the test that says so.
func test_walking_follows_the_way_the_player_faces() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var player: CharacterBody3D = train.get_node("Screen/Frame/World/Player")

	var start := player.position.x
	runner.simulate_action_press("move_up")
	await runner.simulate_frames(4)
	runner.simulate_action_release("move_up")
	assert_float(player.position.x - start).override_failure_message(
		"facing down the train, walking forward should raise world X"
	).is_greater(0.0)

	_locomotion_of(train).facing_radians = PI
	await runner.simulate_frames(1)
	start = player.position.x
	runner.simulate_action_press("move_up")
	await runner.simulate_frames(4)
	runner.simulate_action_release("move_up")
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

	_locomotion_of(train).facing_radians = PI * 0.5
	runner.simulate_action_press("move_up")
	await runner.simulate_frames(60)
	runner.simulate_action_release("move_up")
	assert_float(absf(player.position.z)).override_failure_message(
		"the player walked out sideways through the carriage wall"
	).is_less(Consist.INTERIOR_HALF_Z)


## The head is part of the skin mesh, and the camera is inside it. Hiding the skin
## is what takes the head off, so the outfit has to be there to cover what is left.
func test_first_person_wears_an_outfit_and_no_skin() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var body: PlayerBody = runner.scene().get_node("Screen/Frame/World/Player/Rig")

	assert_object(body.skeleton).is_not_null()
	var visible_meshes: Array[StringName] = []
	for child: Node in body.skeleton.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			visible_meshes.append(StringName(child.name))
	for skin: StringName in body.skin_meshes:
		assert_array(visible_meshes).override_failure_message(
			"%s is still drawn, so the player is looking at the inside of their own head"
				% skin
		).not_contains([skin])
	assert_int(visible_meshes.size()).override_failure_message(
		"the skin came off and no outfit was grafted on, so the player is invisible"
	).is_greater(0)


## The rig is human sized and the carriage is not, so the eyes have to end up where
## the camera already is rather than a metre below it.
func test_the_rig_is_scaled_until_its_eyes_reach_the_camera() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var body: PlayerBody = train.get_node("Screen/Frame/World/Player/Rig")
	var camera: Camera3D = train.get_node("Screen/Frame/World/Player/Camera3D")

	var eyes_at := body.skeleton.global_transform \
		* Vector3(0.0, body.rest_eye_height_metres(), 0.0)
	assert_float(eyes_at.y).override_failure_message(
		"the rig's eyes are not sitting at the camera"
	).is_equal_approx(camera.global_position.y, 0.05)


## The legs are driven by how far the body actually moved, so walking into a wall
## has to leave them standing still.
func test_the_gait_follows_the_distance_covered() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var body: PlayerBody = train.get_node("Screen/Frame/World/Player/Rig")

	assert_float(body.animation_tree.get(PlayerBody.BLEND_POSITION_PARAMETER)) \
		.override_failure_message("standing still, the gait should be idle").is_equal_approx(0.0, 0.05)

	runner.simulate_action_press("move_up")
	await runner.simulate_frames(20)
	assert_float(body.animation_tree.get(PlayerBody.BLEND_POSITION_PARAMETER)) \
		.override_failure_message("walking down the aisle and the legs are not moving") \
		.is_greater(0.5)

	_locomotion_of(train).facing_radians = PI * 0.5
	await runner.simulate_frames(60)
	runner.simulate_action_release("move_up")
	assert_float(body.animation_tree.get(PlayerBody.BLEND_POSITION_PARAMETER)) \
		.override_failure_message("pressed into a wall, the legs should stop rather than run on") \
		.is_less(0.5)
