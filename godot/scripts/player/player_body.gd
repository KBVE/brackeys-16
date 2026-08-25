extends Node3D
class_name PlayerBody

## PlayerBody is the skinned body under the player's camera.
##
## Built in code rather than authored, because the pieces that matter are all
## derived: the model scale comes from the rig's own head bone against the eye
## height the carriage was measured at, and the animation tree is three clips.
##
## Everything it loads lives under res://assets/player, which tools/build_player_kit.gd
## copies out of the shared Quaternius library. Nothing here reaches into
## res://assets/characters, because the Web export excludes all of it.

const ANIMATION_LIBRARY_PATH := "res://assets/player/animations/player_animations.res"
const ANIMATION_LIBRARY_NAME := &"player"

const IDLE_CLIP := "player/Idle"
const WALK_FORWARD_CLIP := "player/Walk_Fwd"
const WALK_BACKWARD_CLIP := "player/Walk_Bwd"

const BLEND_POSITION_PARAMETER := "parameters/gait/blend_position"
const TIME_SCALE_PARAMETER := "parameters/pace/scale"

## Quaternius characters are modelled facing +Z, and Godot walks a body down -Z.
const MODEL_FACES_BACKWARD_DEGREES := 180.0

@export var body_model: PackedScene = preload("res://assets/player/models/Regular_Male_FullBody.glb")

## The head bone is inside the camera in first person, so it is collapsed rather
## than drawn across the whole screen.
@export var first_person: bool = true

@export var head_bone_name: StringName = &"Head"

## Measuring the eye mesh rather than the head bone, which sits at the top of the
## neck: hanging the camera off the bone puts it in the throat, and the shoulders
## fill the screen.
@export var eye_mesh_name: StringName = &"Eyes"

## Quaternius outfits are separate skinned meshes over the same 65 bone rig, so
## dressing the player is grafting their MeshInstance3D onto this skeleton. Wear all
## four covering slots or the bare skin shows through where a piece is missing.
@export var outfit_pieces: Array[PackedScene] = [
	preload("res://assets/player/models/outfits/Male_Noble_Body.glb"),
	preload("res://assets/player/models/outfits/Male_Noble_Arms.glb"),
	preload("res://assets/player/models/outfits/Male_Noble_Legs.glb"),
	preload("res://assets/player/models/outfits/Male_Noble_Feet.glb"),
]

## Skin, eyes and eyebrows are one mesh with the head, so in first person they come
## off together and the camera is left with no head to see the inside of. Collapsing
## the head bone instead leaves the neck verts pinched into a cone.
@export var skin_meshes: Array[StringName] = [&"RegularMale", &"Eyes", &"Eyebrows"]

## Where the camera sits above the floor. The rig is scaled until its head bone
## reaches this, so the carriage stays the thing that decides how tall the player is.
@export var eye_height_metres: float = 2.60

## The train's camera is a quarter turn off the body, so the visible rig has to be too.
@export var forward_yaw_offset_radians: float = -PI * 0.5

## Ground speed the walk clips were animated at, before the rig is scaled up. Sets
## how fast the legs cycle for a given speed.
@export var walk_clip_metres_per_second: float = 1.4

## Seconds for the gait blend to catch up, so a knocked-back step does not snap the
## legs between clips.
@export var blend_seconds: float = 0.12

@export var time_scale_limits := Vector2(0.6, 1.8)

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree

var _rig: Node3D
var _model_scale := 1.0
var _blend := 0.0

func _ready() -> void:
	_rig = body_model.instantiate() as Node3D
	add_child(_rig)
	skeleton = _find_skeleton(_rig)
	if skeleton == null:
		push_error("PlayerBody: no Skeleton3D in %s" % body_model.resource_path)
		return
	_model_scale = _scale_for_eye_height()
	_rig.scale = Vector3.ONE * _model_scale
	_rig.rotation.y = forward_yaw_offset_radians + deg_to_rad(MODEL_FACES_BACKWARD_DEGREES)
	_rig.position.y = -eye_height_metres
	for piece: PackedScene in outfit_pieces:
		_graft(piece)
	if first_person:
		_undress_the_skin()
	_build_animation()


## The rig ships at human scale and the carriage does not, so rather than pick a
## number, scale until the rig's own eyes land where the camera already is.
func _scale_for_eye_height() -> float:
	var rest_metres := rest_eye_height_metres()
	return eye_height_metres / rest_metres if rest_metres > 0.0 else 1.0


## How far the eyes sit above the model's feet, before any scaling.
func rest_eye_height_metres() -> float:
	for child: Node in skeleton.get_children():
		if child is MeshInstance3D and child.name == eye_mesh_name:
			return (child as MeshInstance3D).mesh.get_aabb().get_center().y
	var head := skeleton.find_bone(head_bone_name)
	if head < 0:
		push_error("PlayerBody: no %s mesh and no %s bone to measure against"
			% [eye_mesh_name, head_bone_name])
		return 0.0
	return skeleton.get_bone_global_rest(head).origin.y


## Grafts one outfit's meshes onto this skeleton. The piece arrives with a skeleton
## of its own, which is the same rig, so only the meshes move across.
func _graft(piece: PackedScene) -> void:
	if piece == null:
		return
	var worn: Node = piece.instantiate()
	var worn_skeleton := _find_skeleton(worn)
	if worn_skeleton == null:
		push_error("PlayerBody: no Skeleton3D in %s" % piece.resource_path)
		worn.free()
		return
	if worn_skeleton.get_bone_count() != skeleton.get_bone_count():
		push_error("PlayerBody: %s is rigged to %d bones, the body has %d"
			% [piece.resource_path, worn_skeleton.get_bone_count(), skeleton.get_bone_count()])
		worn.free()
		return
	for child: Node in worn_skeleton.get_children():
		if child is not MeshInstance3D:
			continue
		worn_skeleton.remove_child(child)
		child.owner = null
		skeleton.add_child(child)
		(child as MeshInstance3D).skeleton = NodePath("..")
	worn.free()


func _undress_the_skin() -> void:
	for name: StringName in skin_meshes:
		var mesh: Node = skeleton.find_child(String(name), false, false)
		if mesh is MeshInstance3D:
			(mesh as MeshInstance3D).visible = false


func _build_animation() -> void:
	var library: AnimationLibrary = load(ANIMATION_LIBRARY_PATH)
	animation_player = AnimationPlayer.new()
	_rig.add_child(animation_player)
	animation_player.root_node = animation_player.get_path_to(_rig)
	animation_player.add_animation_library(ANIMATION_LIBRARY_NAME, library)

	var gait := AnimationNodeBlendSpace1D.new()
	gait.min_space = -1.0
	gait.max_space = 1.0
	gait.sync = true
	gait.add_blend_point(_clip(WALK_BACKWARD_CLIP), -1.0, -1, &"backward")
	gait.add_blend_point(_clip(IDLE_CLIP), 0.0, -1, &"standing")
	gait.add_blend_point(_clip(WALK_FORWARD_CLIP), 1.0, -1, &"forward")

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node(&"gait", gait)
	blend_tree.add_node(&"pace", AnimationNodeTimeScale.new())
	blend_tree.connect_node(&"pace", 0, &"gait")
	blend_tree.connect_node(&"output", 0, &"pace")

	animation_tree = AnimationTree.new()
	animation_tree.tree_root = blend_tree
	_rig.add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.active = true


func _clip(clip_name: String) -> AnimationNodeAnimation:
	if not animation_player.has_animation(clip_name):
		push_error("PlayerBody: no animation %s" % clip_name)
		return null
	var node := AnimationNodeAnimation.new()
	node.animation = clip_name
	return node


## Called by [SCharacterAnimation] with the signed speed along the walking direction.
func drive(forward_metres_per_second: float, delta: float) -> void:
	if animation_tree == null:
		return
	var walking_metres_per_second := walk_clip_metres_per_second * _model_scale
	var wanted := clampf(forward_metres_per_second / walking_metres_per_second, -1.0, 1.0)
	_blend = lerpf(_blend, wanted, clampf(delta / maxf(blend_seconds, 0.0001), 0.0, 1.0))
	animation_tree.set(BLEND_POSITION_PARAMETER, _blend)
	animation_tree.set(TIME_SCALE_PARAMETER, clampf(
		absf(forward_metres_per_second) / walking_metres_per_second,
		time_scale_limits.x, time_scale_limits.y))


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
