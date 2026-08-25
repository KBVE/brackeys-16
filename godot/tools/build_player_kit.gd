extends SceneTree

## Copies everything the player is built from out of the shared Quaternius library
## and into [constant KIT_DIR], then bakes the three animation clips it plays.
##
## The point is the export filter. res://assets/characters is 40MB of animation
## libraries, five outfits and eight bodies shared with friendslop, and the Web
## preset excludes all of it. Godot applies exclude after include, so nothing can be
## named back in; the only way to ship one body is for that body to live somewhere
## the filter does not reach.
##
## Run headless after changing the outfit or the clip list, then let the editor
## import what lands:
## [codeblock]
## godot --headless --script tools/build_player_kit.gd
## godot --headless --import
## [/codeblock]

const LIBRARY_DIR := "res://assets/characters/quaternius_ubc"
const KIT_DIR := "res://assets/player"

const BODY := "models/Regular_Male_FullBody.glb"

const OUTFIT := [
	"models/outfits/Male_Noble_Body.glb",
	"models/outfits/Male_Noble_Arms.glb",
	"models/outfits/Male_Noble_Legs.glb",
	"models/outfits/Male_Noble_Feet.glb",
]

## Godot's use_name_suffixes strips the _Loop suffix on import and sets the loop mode
## from it, so these are the glTF names minus that suffix.
const CLIPS_BY_SOURCE := {
	"animations/UAL1.glb": ["Idle"],
	"animations/UAL2.glb": ["Walk_Fwd", "Walk_Bwd"],
}

const ANIMATION_LIBRARY := "animations/player_animations.res"

## The rig is seen from inside its own collar and nowhere else, so 512 is as much
## texture as it can show. At 1024 the same build is 8MB larger.
const TEXTURE_SIZE_LIMIT := 512

func _initialize() -> void:
	for path: String in ([BODY] + OUTFIT):
		_copy_model(path)
	_build_animation_library()
	print("player kit written to ", KIT_DIR)
	quit()


## glTF keeps its textures as sibling files rather than embedding them, so a model is
## only copied once the URIs it names have been.
func _copy_model(path: String) -> void:
	for texture_path: String in _textures_of("%s/%s" % [LIBRARY_DIR, path]):
		_copy_texture(texture_path)
	_copy(path)


func _textures_of(glb_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var glb := FileAccess.open(glb_path, FileAccess.READ)
	if glb == null:
		push_error("cannot read %s" % glb_path)
		return out
	glb.seek(12)
	var json := ""
	while glb.get_position() < glb.get_length():
		var length := glb.get_32()
		var kind := glb.get_32()
		if kind == 0x4E4F534A:
			json = glb.get_buffer(length).get_string_from_utf8()
			break
		glb.seek(glb.get_position() + length)
	var parsed: Dictionary = JSON.parse_string(json)
	for image: Dictionary in parsed.get("images", []):
		var uri: String = image.get("uri", "")
		if uri != "":
			out.append(glb_path.get_base_dir().path_join(uri).simplify_path()
				.trim_prefix(LIBRARY_DIR + "/"))
	return out


## The import settings are the copy's own, so the shared library keeps whatever
## friendslop needs from it and this kit gets what the web build needs.
func _copy_texture(path: String) -> void:
	_copy(path)
	var settings := ConfigFile.new()
	settings.load("%s/%s.import" % [LIBRARY_DIR, path])
	settings.set_value("params", "compress/mode", 2)
	settings.set_value("params", "process/size_limit", TEXTURE_SIZE_LIMIT)
	settings.set_value("params", "mipmaps/generate", true)
	settings.set_value("params", "detect_3d/compress_to", 0)
	settings.set_value("params", "compress/normal_map",
		1 if path.get_file().get_basename().ends_with("_Normal") else 0)
	_write_import(path, settings)


func _copy(path: String) -> void:
	var to := "%s/%s" % [KIT_DIR, path]
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	var copied := DirAccess.copy_absolute("%s/%s" % [LIBRARY_DIR, path], to)
	if copied != OK:
		push_error("could not copy %s: %d" % [path, copied])
		return
	if not FileAccess.file_exists("%s/%s.import" % [LIBRARY_DIR, path]):
		return
	var settings := ConfigFile.new()
	settings.load("%s/%s.import" % [LIBRARY_DIR, path])
	_write_import(path, settings)


## Only the [code]params[/code] survive. [code]remap[/code] carries the uid and the
## path of the file this was copied from, and two resources on one uid is a fight
## Godot resolves by dropping one of them. It writes fresh ones on the next import.
##
## The humanoid retarget lives in params as a [BoneMap] reference back into the
## shared library, which is where it should stay: it is read at import time, in an
## editor that has the whole library, and never shipped.
func _write_import(path: String, settings: ConfigFile) -> void:
	settings.erase_section("remap")
	settings.erase_section("deps")
	settings.save("%s/%s.import" % [KIT_DIR, path])


func _build_animation_library() -> void:
	var library := AnimationLibrary.new()
	for source: String in CLIPS_BY_SOURCE:
		var scene: Node = (load("%s/%s" % [LIBRARY_DIR, source]) as PackedScene).instantiate()
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		for clip_name: String in CLIPS_BY_SOURCE[source]:
			if not player.has_animation(clip_name):
				push_error("%s has no animation %s" % [source, clip_name])
				continue
			library.add_animation(clip_name, player.get_animation(clip_name).duplicate(true))
		scene.free()
	DirAccess.make_dir_recursive_absolute("%s/%s" % [KIT_DIR, ANIMATION_LIBRARY.get_base_dir()])
	var saved := ResourceSaver.save(library, "%s/%s" % [KIT_DIR, ANIMATION_LIBRARY],
		ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if saved != OK:
		push_error("could not save the animation library: %d" % saved)
