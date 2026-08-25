extends SceneTree

## Copies what the player is built from out of the shared Quaternius library into
## [constant KIT_DIR] and bakes the clips it plays. Run headless, then --import.
##
## It exists because Godot applies the export filter's exclude after its include, so
## the Web preset's exclusion of the 40MB res://assets/characters cannot be named back
## out of. Shipping one body means that body living where the filter does not reach.

const LIBRARY_DIR := "res://assets/characters/quaternius_ubc"
const KIT_DIR := "res://assets/player"

## Head and neck only: a full body under a full outfit is two skinned surfaces a
## millimetre apart, and the skin wins often enough to look like a hole in the coat.
## The outfit's Arms piece reaches the fingertips, so nothing is lost with the body.
const BODY := "models/Regular_Male_OnlyHead.glb"

const OUTFIT := [
	"models/hair/Hair_SimpleParted.glb",
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

## At 1024 the same build is 8MB larger, for texture no one gets close enough to see.
const TEXTURE_SIZE_LIMIT := 512

const GLTF_HEADER_BYTES := 12
const GLTF_JSON_CHUNK := 0x4E4F534A
const COMPRESS_MODE_VRAM_COMPRESSED := 2
const DETECT_3D_LEAVE_ALONE := 0
const NORMAL_MAP_ENABLED := 1
const NORMAL_MAP_DISABLED := 0
const NORMAL_MAP_SUFFIX := "_Normal"

func _initialize() -> void:
	for path: String in ([BODY] + OUTFIT):
		_copy_model(path)
	_build_animation_library()
	print("player kit written to ", KIT_DIR)
	quit()


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
	glb.seek(GLTF_HEADER_BYTES)
	var json := ""
	while glb.get_position() < glb.get_length():
		var length := glb.get_32()
		var kind := glb.get_32()
		if kind == GLTF_JSON_CHUNK:
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


func _copy_texture(path: String) -> void:
	_copy(path)
	var settings := ConfigFile.new()
	settings.load("%s/%s.import" % [LIBRARY_DIR, path])
	settings.set_value("params", "compress/mode", COMPRESS_MODE_VRAM_COMPRESSED)
	settings.set_value("params", "process/size_limit", TEXTURE_SIZE_LIMIT)
	settings.set_value("params", "mipmaps/generate", true)
	settings.set_value("params", "detect_3d/compress_to", DETECT_3D_LEAVE_ALONE)
	settings.set_value("params", "compress/normal_map",
		NORMAL_MAP_ENABLED if path.get_file().get_basename().ends_with(NORMAL_MAP_SUFFIX)
		else NORMAL_MAP_DISABLED)
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


## Only [code]params[/code] survives: [code]remap[/code] carries the uid of the file
## this was copied from, and two resources on one uid is a fight Godot settles by
## dropping one. Fresh ones are written on the next import.
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
