# GdUnitTestSuite
extends GdUnitTestSuite

## &regression -> scripts have moved between folders several times (autoload/,
##                core/, ecs/core/, world/). Every move is a silent break until
##                something runs the scene: project.godot stores autoloads by
##                path, and the train scene stores its scripts by path too.

func test_every_autoload_script_still_exists() -> void:
	for setting: String in ProjectSettings.get_property_list().map(
			func(p: Dictionary) -> String: return p["name"]):
		if not setting.begins_with("autoload/"):
			continue
		var path := str(ProjectSettings.get_setting(setting)).trim_prefix("*")
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"%s points at %s, which no longer exists" % [setting, path]
		).is_true()


func test_the_main_scene_and_the_train_scene_both_load() -> void:
	for path: String in [
		str(ProjectSettings.get_setting("application/run/main_scene")),
		"res://scenes/train/train.scn",
	]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(
			"%s is missing" % path
		).is_true()


func test_tools_and_tests_are_excluded_from_every_export_preset() -> void:
	var presets := ConfigFile.new()
	assert_int(presets.load("res://export_presets.cfg")).is_equal(OK)
	for section: String in presets.get_sections():
		if not presets.has_section_key(section, "exclude_filter"):
			continue
		var filter := str(presets.get_value(section, "exclude_filter"))
		for excluded: String in ["tools/*", "tests/*"]:
			assert_str(filter).override_failure_message(
				"[%s] would ship %s" % [section, excluded]
			).contains(excluded)
