# GdUnitTestSuite
extends GdUnitTestSuite

func test_probe() -> void:
	var runner := scene_runner("res://scenes/train/train.scn")
	await runner.simulate_frames(20)
	var seen := 0
	for entry: Dictionary in Ecs.world.multi_view([CDoor, ECSViewComponent]):
		var leaf: Node3D = entry[&"ECSViewComponent"].view as Node3D
		prints("door leaf at %v  swing_sign=%.0f" % [leaf.global_position,
			entry[&"CDoor"].swing_sign])
		seen += 1
		if seen >= 12:
			break
	assert_bool(true).is_true()
