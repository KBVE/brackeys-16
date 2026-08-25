extends Node

## Renders the two plates tools/gen-itch-art.py prints on the itch.io paper: a header
## plate and a capsule plate, both captured at 2x the final size and downsampled there.
##
## Run windowed. Headless has no rendering device, so the grab comes back black.
## [codeblock]
## godot --path godot res://scenes/tools/itch_capture.tscn
## python3 tools/gen-itch-art.py
## [/codeblock]
##
## It adds the train scene beside itself instead of changing to it, because a scene
## change frees this node and the capture with it. Autoloads are live either way,
## which is the reason this is a scene the player boots into and not a SceneTree tool.

const SCENE := "res://scenes/train/train.scn"
const OUT_DIR := "res://reports/itch"

## Streaming loads, gas lamps and the cast settling all land inside two seconds. Under
## that the plate catches an unlit carriage with no passengers in it.
const SETTLE_FRAMES := 150

## Two frames after a resize: one for the window, one for the 3D viewport behind it.
const RESIZE_FRAMES := 4

## 2x the itch sizes. The engraving pass reads the downsample as press dot gain.
const PLATES := {
	"header": Vector2i(1920, 800),
	"capsule": Vector2i(1260, 1000),
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	add_sibling.call_deferred(load(SCENE).instantiate())
	await _frames(SETTLE_FRAMES)
	for plate in PLATES:
		await _capture(plate, PLATES[plate])
	get_tree().quit()


func _capture(plate: String, size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	get_window().size = size
	await _frames(RESIZE_FRAMES)
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, plate]
	var err := image.save_png(path)
	if err != OK:
		push_error("itch_capture: %s failed to write (%d)" % [path, err])
		return
	print("plate %s written: %dx%d" % [path, image.get_width(), image.get_height()])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
