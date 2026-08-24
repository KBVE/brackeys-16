# GdUnitTestSuite
extends GdUnitTestSuite

const SCENE := "res://scenes/train/train.scn"
const TRIS_PER_CARRIAGE := 32274
const EXPECTED_CHILDREN := ["Consist", "Rig", "WorldEnvironment", "Sun", "Backdrop", "Lighting", "Debug"]


func test_the_generated_scene_still_has_its_script() -> void:
	var root: Node = auto_free(load(SCENE).instantiate())
	assert_object(root.get_script()).override_failure_message(
		"train.scn has no script, run --import before build_train_scene.gd; could make a cmake?"
		+ "the builder loads train.gd by path and saves anyway if it fails to parse."
	).is_not_null()


func test_the_generated_scene_keeps_every_node_the_code_reaches_for() -> void:
	var root: Node = auto_free(load(SCENE).instantiate())
	for name: String in EXPECTED_CHILDREN:
		assert_object(root.get_node_or_null(name)).override_failure_message(
			"train.scn is missing %s, which Train reaches for by path" % name
		).is_not_null()
	## Might need a better way to handle this.
	assert_object(root.get_node_or_null("Backdrop/Terrain")).is_not_null()
	assert_object(root.get_node_or_null("Backdrop/Forest")).is_not_null()
	assert_object(root.get_node_or_null("Rig/Camera3D")).is_not_null()


func test_the_carriage_is_packed_once_not_twice() -> void:
	var root: Node = auto_free(load(SCENE).instantiate())
	var carriage_scene: PackedScene = root.get_node("Consist").carriage_scene
	assert_object(carriage_scene).override_failure_message(
		"Consist.carriage_scene is unset, so the train would spawn nothing, important for the start of the story."
	).is_not_null()
	var carriage: Node = auto_free(carriage_scene.instantiate())
	assert_int(_triangles(carriage)).override_failure_message(
		"one carriage should be %d triangles, double that means the builder packed "
		% TRIS_PER_CARRIAGE + "the glTF instance's children as well as the instance."
	).is_equal(TRIS_PER_CARRIAGE)


func _triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for surface in range(mesh.get_surface_count()):
			total += mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
	for child: Node in node.get_children():
		total += _triangles(child)
	return total


func test_the_consist_is_as_long_as_the_content_says() -> void:
	var root: Node = auto_free(load(SCENE).instantiate())
	assert_int(root.get_node("Consist").carriage_count).override_failure_message(
		"the scene spawns a different number of carriages than shared/data/locations "
		+ "authors a carriage index for, so a room would have no carriage or the "
		+ "reverse. Rebuild with build_train_scene.gd."
	).is_equal(GameContent.carriage_locations().size())
