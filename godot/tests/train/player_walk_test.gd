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


## The camera is behind him now, so he is looked at rather than looked out of: the
## face is drawn, the head is whole, and he is not walking the aisle bald or naked.
func test_the_body_is_dressed_and_whole_for_the_camera_behind_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var body: PlayerBody = runner.scene().get_node("Screen/Frame/World/Player/Rig")

	assert_object(body.skeleton).is_not_null()
	var visible_meshes: Array[StringName] = []
	for child: Node in body.skeleton.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			visible_meshes.append(StringName(child.name))

	# the head-only body names its mesh after the file it was cut from, so match the
	# stem rather than a name that moves when the source does
	var wears_skin := false
	for name: StringName in visible_meshes:
		wears_skin = wears_skin or String(name).begins_with("RegularMale")
	assert_bool(wears_skin).override_failure_message(
		"no skin is drawn, so the collar has no neck and the head no face"
	).is_true()
	for face: StringName in [&"Eyes", &"Eyebrows"]:
		assert_array(visible_meshes).override_failure_message(
			"%s is hidden, so the camera behind him is looking at a faceless head" % face
		).contains([face])
	assert_int(visible_meshes.size()).override_failure_message(
		"no outfit or hair was grafted on, so he is bald and undressed"
	).is_greater(4)


## The whole point of the boom: the camera sits behind the player rather than inside
## his eyes, and far enough back to see him.
func test_the_camera_rides_a_boom_behind_the_player() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var train: Node = runner.scene()
	var player: CharacterBody3D = train.get_node("Screen/Frame/World/Player")
	var camera: Camera3D = train.get_node("Screen/Frame/World/Player/Boom/Mount/Camera3D")

	var behind := player.global_position - camera.global_position
	assert_float(behind.length()).override_failure_message(
		"the camera is sitting on top of the player, so there is no third person"
	).is_greater(0.5)
	assert_float(SLocomotion.forward_of(_locomotion_of(train)).dot(behind.normalized())) \
		.override_failure_message(
			"the camera drifted round in front of him and is filming his face"
		).is_greater(0.0)


## A and D used to turn. They strafe now, and strafing has to leave the body facing
## the way it already faced or the aisle swings every time you sidestep.
func test_strafing_moves_sideways_without_turning() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var player: CharacterBody3D = train.get_node("Screen/Frame/World/Player")
	var facing := _locomotion_of(train).facing_radians

	var start := player.position.z
	runner.simulate_action_press("move_right")
	await runner.simulate_frames(10)
	runner.simulate_action_release("move_right")

	assert_float(absf(player.position.z - start)).override_failure_message(
		"strafing right moved the player nowhere across the aisle"
	).is_greater(0.01)
	assert_float(_locomotion_of(train).facing_radians).override_failure_message(
		"strafing turned the body, so the view swung with it"
	).is_equal_approx(facing, 0.001)


## Past straight up or straight down the yaw the body carries stops meaning anything
## on screen, so the head stops before either.
func test_the_head_cannot_pitch_past_its_bounds() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var boom: SpringArm3D = train.get_node("Screen/Frame/World/Player/Boom")
	var locomotion := _locomotion_of(train)

	locomotion.pitch_radians = -100.0
	await runner.simulate_frames(2)
	assert_float(boom.rotation.x).override_failure_message(
		"the boom swung past straight down"
	).is_greater(-PI * 0.5)

	locomotion.pitch_radians = 100.0
	await runner.simulate_frames(2)
	assert_float(boom.rotation.x).override_failure_message(
		"the boom swung past straight up"
	).is_less(PI * 0.5)


## The evidence in this game is clicked on, so the pointer never gets captured. It
## was, briefly, and there was then no way to click anything at all.
func test_the_pointer_stays_available_for_picking() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(30)

	assert_int(Input.mouse_mode).override_failure_message(
		"the pointer was captured, so nothing in the carriage can be clicked"
	).is_equal(Input.MOUSE_MODE_VISIBLE)


## Mouse motion never reaches a headless run, so this drives the seam the window
## hands it to instead: pixels in, head turned and pitched.
func test_mouse_motion_turns_and_pitches_the_head() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var locomotion := _locomotion_of(train)
	var facing := locomotion.facing_radians

	train._control.accumulate_look(Vector2(200.0, 120.0), 720.0)
	await runner.simulate_frames(2)

	assert_float(locomotion.facing_radians).override_failure_message(
		"moving the mouse right did not turn the head right"
	).is_less(facing)
	assert_float(locomotion.pitch_radians).override_failure_message(
		"moving the mouse down did not pitch the head down"
	).is_less(0.0)


## The carriage mesh bottoms out fifteen centimetres above the collision floor, so a
## rig placed on the collider stands buried to the ankles in floorboards.
func test_he_stands_on_the_floor_he_can_see() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var train: Node = runner.scene()
	var body: PlayerBody = train.get_node("Screen/Frame/World/Player/Rig")
	var toes := body.skeleton.find_bone(&"LeftToes")
	assert_int(toes).is_greater(-1)

	var at: Vector3 = body.skeleton.global_transform \
		* body.skeleton.get_bone_global_pose(toes).origin
	assert_float(at.y).override_failure_message(
		"his toes are under the floorboards"
	).is_greater(Consist.DRAWN_FLOOR_Y - 0.01)
	# the deck sits above the underframe; anything near zero is the car's underside
	assert_float(Consist.DRAWN_FLOOR_Y).override_failure_message(
		"the drawn floor is back under the carriage, where the underframe is"
	).is_greater(1.0)
	assert_float(at.y).override_failure_message(
		"he is hovering above the floor"
	).is_less(Consist.DRAWN_FLOOR_Y + 0.1)


## Moving the collision floor to match the drawn one lifted the player, because his
## capsule is sized against the collider and depenetration pushed him out of it. The
## drawn floor is a drawing measurement and must stay one.
func test_fixing_the_drawn_floor_did_not_move_the_player() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var train: Node = runner.scene()
	var player: CharacterBody3D = train.get_node("Screen/Frame/World/Player")

	assert_float(player.global_position.y).override_failure_message(
		"the player is no longer pinned at eye height, so his collider is fighting the floor"
	).is_equal_approx(_locomotion_of(train).eye_height_metres, 0.02)


## A spring arm only stops at collision, and the carriage roof and bulkheads carry
## none. Looking down swings the arm up, and it used to sail out through the ceiling
## and film the run from outside, with the carriage's own red exterior across the
## frame and the player cut off at the waist behind it.
func test_the_camera_cannot_leave_the_carriage() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var train: Node = runner.scene()
	var camera: Camera3D = train.get_node("Screen/Frame/World/Player/Boom/Mount/Camera3D")
	var locomotion := _locomotion_of(train)

	for pitch: float in [-1.25, -0.55, 0.9]:
		locomotion.pitch_radians = pitch
		await runner.simulate_frames(2)
		var at := camera.global_position
		assert_float(at.y).override_failure_message(
			"looking at %f put the camera through the roof" % pitch
		).is_less(Consist.WALL_HEIGHT)
		assert_float(at.y).override_failure_message(
			"looking at %f put the camera under the floor" % pitch
		).is_greater(Consist.DRAWN_FLOOR_Y)
		assert_float(absf(at.z)).override_failure_message(
			"looking at %f put the camera out through a side wall" % pitch
		).is_less(Consist.INTERIOR_HALF_Z)


## He was two metres seventy, because the rig was scaled to a camera height measured
## when there was no body to compare it against. Stature is the input now.
func test_he_is_the_size_of_a_person() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var body: PlayerBody = runner.scene().get_node("Screen/Frame/World/Player/Rig")

	var drawn: float = body.rest_stature_metres() * body.get_child(0).scale.y
	assert_float(drawn).override_failure_message(
		"the drawn body is not the height he is supposed to be"
	).is_equal_approx(body.stature_metres, 0.01)
	assert_float(drawn).override_failure_message(
		"nobody is this tall; the rig is being scaled off something other than stature"
	).is_between(1.5, 2.0)

	assert_float(body.eye_height_metres() - Consist.DRAWN_FLOOR_Y).override_failure_message(
		"his eyes are not a person's height above the floor he stands on"
	).is_between(1.5, 1.7)


## The capsule was authored around the old camera height. Left at 2.75 its bottom
## sits under the floor, and depenetration lifts him a metre into the air every frame.
func test_the_capsule_is_the_size_of_the_man_inside_it() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var train: Node = runner.scene()
	var body: PlayerBody = train.get_node("Screen/Frame/World/Player/Rig")
	var shape: CollisionShape3D = train.get_node("Screen/Frame/World/Player/Body")
	var capsule: CapsuleShape3D = shape.shape

	assert_float(capsule.height).override_failure_message(
		"the capsule is not his height, so it will fight the floor"
	).is_equal_approx(body.stature_metres, 0.01)

	var bottom: float = train.get_node("Screen/Frame/World/Player").global_position.y \
		+ shape.position.y - capsule.height * 0.5
	assert_float(bottom).override_failure_message(
		"the bottom of the capsule is below the floor it stands on"
	).is_greater(Consist.FLOOR_Y - 0.05)


## A right-drag is a glance, not a setting. Left to stand, a look at the floor stayed a
## look at the floor, and nothing in the game brought the horizon back.
func test_the_view_returns_to_level_once_the_look_ends() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var locomotion := _locomotion_of(train)

	train._control.accumulate_look(Vector2(0.0, 200.0), 720.0)
	await runner.simulate_frames(2)
	assert_float(locomotion.pitch_radians).override_failure_message(
		"the look never pitched the view down, so there is nothing to recover from"
	).is_less(-0.2)

	await runner.simulate_frames(90)
	assert_float(locomotion.pitch_radians).override_failure_message(
		"the view never came back level, so a glance at the floor is permanent"
	).is_equal_approx(0.0, 0.05)


## The recentre must not fight the player while they are still aiming, or the view
## crawls back to level under the mouse.
func test_a_held_look_keeps_the_pitch_it_was_given() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(4)
	var train: Node = runner.scene()
	var locomotion := _locomotion_of(train)
	train._control.set_update(false)

	var intent: CInput = train._intent
	intent.holding_look = true
	intent.pitch_units = 0.0
	locomotion.pitch_radians = -0.6
	await runner.simulate_frames(20)

	assert_float(locomotion.pitch_radians).override_failure_message(
		"the view drifted back to level while the player was still holding the look"
	).is_equal_approx(-0.6, 0.01)


## Strafing used to play the standing clip, because the gait was a single forward axis
## and a sidestep reads as zero on it. He slid sideways on his heels.
func test_sidestepping_puts_the_legs_in_a_sideways_clip() -> void:
	var runner := scene_runner(SCENE)
	await runner.simulate_frames(6)
	var train: Node = runner.scene()
	var body: PlayerBody = train.get_node("Screen/Frame/World/Player/Rig")
	train._control.set_update(false)

	train._intent.strafe_units = 0.02
	await runner.simulate_frames(20)
	var blend: Vector2 = body.animation_tree.get(CharacterRig.BLEND_POSITION_PARAMETER)

	assert_float(blend.x).override_failure_message(
		"stepping right left the gait on the forward axis, so he is standing still and sliding"
	).is_greater(0.2)
	assert_float(absf(blend.y)).override_failure_message(
		"a pure sidestep leaked into the forward axis, so the legs are striding as well"
	).is_less(0.2)
