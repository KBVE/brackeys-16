extends Node3D
class_name CharacterRig

## CharacterRig is one assembled Quaternius character: a head, whatever [Wardrobe]
## says it is wearing, and the animation tree that walks it.
##
## Built in code rather than authored, because the pieces that matter are all derived.
## The model scale comes from the rig's own eyes against the eye height the carriage
## was measured at, the outfit is a list of separate skinned meshes grafted onto one
## skeleton, and the animation tree is three clips.
##
## Everything it loads lives under [constant Wardrobe.KIT_DIR], which
## tools/build_cast_kit.gd copies out of the shared library. Nothing here reaches into
## res://assets/characters, because the Web export excludes all of it.
##
## [PlayerBody] is this dressed at build time. Passengers are this dressed from a
## rolled [CAppearance], built and thrown away by [SCastBody] as carriages come into
## view.

## Quaternius characters are modelled facing +Z, and Godot walks a body down -Z.
const MODEL_FACES_BACKWARD_DEGREES := 180.0

const IDLE_CLIP := "Idle"
const WALK_FORWARD_CLIP := "Walk_Fwd"
const WALK_BACKWARD_CLIP := "Walk_Bwd"
const WALK_LEFT_CLIP := "Walk_L"
const WALK_RIGHT_CLIP := "Walk_R"
const WALK_FORWARD_LEFT_CLIP := "Walk_Fwd_L"
const WALK_FORWARD_RIGHT_CLIP := "Walk_Fwd_R"
const WALK_BACKWARD_LEFT_CLIP := "Walk_Bwd_L"
const WALK_BACKWARD_RIGHT_CLIP := "Walk_Bwd_R"

const BLEND_POSITION_PARAMETER := "parameters/gait/blend_position"
const TIME_SCALE_PARAMETER := "parameters/pace/scale"

## Materials named this way carry hair rather than cloth, and take the hair tint.
const HAIR_MATERIAL_PREFIX := "MI_Hair"

## Crown to sole at rest, before scaling. Not measured from the meshes on the skeleton:
## the body a dressed character wears is [code]OnlyHead[/code], whose own mesh runs
## 1.469 to 1.810 and would scale him five times over, and the feet that reach the
## ground arrive later as an outfit piece. Measured off the shared rig instead: crown
## 1.8101 from the head, sole -0.0040 from the boots. Every UBC piece is the same 65
## bones in the same rest pose, so the span holds whatever anyone is wearing.
const REST_STATURE_METRES := 1.8141

## One tinted material per base material and colour, shared by every character that
## rolled the same pair. Skinned meshes do not batch, so this saves memory and shader
## setup rather than draw calls, and it is bounded by the size of the palettes.
static var _tinted_materials: Dictionary = {}

@export var body_model: PackedScene

## Grafted in order, so a pauldron authored after a sleeve lands over it. These are the
## outfit's own skinned meshes over the same 65 bone rig; wear all four covering slots
## or bare skin shows through where a piece is missing.
@export var outfit_pieces: Array[PackedScene] = []

@export var animation_library_path := "res://assets/player/animations/player_animations.res"
@export var animation_library_name := &"player"

@export var head_bone_name: StringName = &"Head"

## Measuring the eye mesh rather than the head bone, which sits at the top of the
## neck: hanging a camera off the bone puts it in the throat, and the shoulders fill
## the screen.
@export var eye_mesh_name: StringName = &"Eyes"

## How tall this character is, crown to sole. The rig is scaled to reach it and the
## eyes land wherever that puts them, so a person is a person first and the camera
## follows; scaling the other way around, to a chosen eye height, produced a man of
## nearly three metres before anyone measured him.
@export var stature_metres: float = 1.75

## Where the floor they stand on sits, measured from this node's origin. The feet go
## here; a floor that is not at zero otherwise buries them to the ankles.
@export var floor_height_metres: float = 0.0

## The train's camera is a quarter turn off the body, so the visible rig has to be too.
@export var forward_yaw_offset_radians: float = -PI * 0.5

## Applied to every grafted surface once the pieces are on. Null leaves every texture
## as it was authored, which is what the player does.
var appearance: CAppearance

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree

var _rig: Node3D
## How much the rig was scaled to reach [member stature_metres]. Read by [SCharacterAnimation],
## which needs it to know how fast the clips were authored relative to this body.
var model_scale := 1.0

## A rig for [param appearance], with everything it wears already loaded. The scene is
## not in the tree yet, so the caller sets its transform before the assembly in
## [method _ready] costs anything.
static func from_appearance(rolled: CAppearance) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.appearance = rolled
	rig.body_model = load(Wardrobe.kit_path(Wardrobe.body_model_of(rolled)))
	for piece: String in Wardrobe.pieces_of(rolled):
		rig.outfit_pieces.append(load(Wardrobe.kit_path(piece)))
	return rig


func _ready() -> void:
	_rig = body_model.instantiate() as Node3D
	add_child(_rig)
	skeleton = _find_skeleton(_rig)
	if skeleton == null:
		push_error("CharacterRig: no Skeleton3D in %s" % body_model.resource_path)
		return
	model_scale = _scale_for_stature()
	_rig.scale = Vector3.ONE * model_scale
	_rig.rotation.y = forward_yaw_offset_radians + deg_to_rad(MODEL_FACES_BACKWARD_DEGREES)
	_rig.position = _rig_offset()
	for piece: PackedScene in outfit_pieces:
		_graft(piece)
	if appearance != null:
		_recolour()
	_build_animation()


func _scale_for_stature() -> float:
	var rest_metres := rest_stature_metres()
	return stature_metres / rest_metres if rest_metres > 0.0 else 1.0


func _eyes_above_the_floor() -> float:
	return rest_eye_height_metres() * model_scale


## Where this character's eyes end up once he is scaled. Read by whatever is measured
## from the eye rather than the foot, which is the camera and the entity it rides on.
func eye_height_metres() -> float:
	return floor_height_metres + _eyes_above_the_floor()


func rest_stature_metres() -> float:
	return REST_STATURE_METRES


## How far the eyes sit above the model's feet, before any scaling.
func rest_eye_height_metres() -> float:
	for child: Node in skeleton.get_children():
		if child is MeshInstance3D and child.name == eye_mesh_name:
			return (child as MeshInstance3D).mesh.get_aabb().get_center().y
	var head := skeleton.find_bone(head_bone_name)
	if head < 0:
		push_error("CharacterRig: no %s mesh and no %s bone to measure against"
			% [eye_mesh_name, head_bone_name])
		return 0.0
	return skeleton.get_bone_global_rest(head).origin.y


## Where the model sits relative to this node. The node's origin is the eye, because
## that is what the entity is positioned by, so the model hangs below it by its own
## eye height and the feet come out on the floor.
func _rig_offset() -> Vector3:
	return Vector3(0.0, -_eyes_above_the_floor(), 0.0)


## Grafts one piece's meshes onto this skeleton. The piece arrives with a skeleton of
## its own, which is the same rig, so only the meshes move across.
func _graft(piece: PackedScene) -> void:
	if piece == null:
		return
	var worn: Node = piece.instantiate()
	var worn_skeleton := _find_skeleton(worn)
	if worn_skeleton == null:
		push_error("CharacterRig: no Skeleton3D in %s" % piece.resource_path)
		worn.free()
		return
	if worn_skeleton.get_bone_count() != skeleton.get_bone_count():
		push_error("CharacterRig: %s is rigged to %d bones, the body has %d"
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


## Tints every surface the character wears. Which tint a surface takes is read off the
## material it already carries rather than configured per mesh, because the piece a
## mesh came from does not survive the graft and the material name does: skin is the
## body's own material, hair is MI_Hair_*, and whatever is left is cloth.
func _recolour() -> void:
	var skin_material := Wardrobe.skin_material_of(appearance)
	for child: Node in skeleton.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var base := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base == null:
				continue
			var tint := appearance.cloth_tint
			if base.resource_name == String(skin_material):
				tint = appearance.skin_tint
			elif base.resource_name.begins_with(HAIR_MATERIAL_PREFIX):
				tint = appearance.hair_tint
			if tint == Color.WHITE:
				continue
			mesh.set_surface_override_material(surface, _tinted(base, tint))


## The tinted twin of [param base], made once and reused. Keyed on the material's own
## instance: the mesh resource is shared between every instantiation of a glb, so two
## characters in the same coat arrive here with the same object.
static func _tinted(base: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var key := "%d|%s" % [base.get_instance_id(), tint.to_html(false)]
	if _tinted_materials.has(key):
		return _tinted_materials[key]
	var tinted := base.duplicate() as StandardMaterial3D
	tinted.albedo_color = base.albedo_color * tint
	_tinted_materials[key] = tinted
	return tinted


func _build_animation() -> void:
	var library: AnimationLibrary = load(animation_library_path)
	animation_player = AnimationPlayer.new()
	_rig.add_child(animation_player)
	animation_player.root_node = animation_player.get_path_to(_rig)
	animation_player.add_animation_library(animation_library_name, library)

	var gait := AnimationNodeBlendSpace2D.new()
	gait.min_space = Vector2(-1.0, -1.0)
	gait.max_space = Vector2(1.0, 1.0)
	gait.sync = true
	gait.add_blend_point(_clip(IDLE_CLIP), Vector2.ZERO)
	gait.add_blend_point(_clip(WALK_FORWARD_CLIP), Vector2(0.0, 1.0))
	gait.add_blend_point(_clip(WALK_BACKWARD_CLIP), Vector2(0.0, -1.0))
	gait.add_blend_point(_clip(WALK_LEFT_CLIP), Vector2(-1.0, 0.0))
	gait.add_blend_point(_clip(WALK_RIGHT_CLIP), Vector2(1.0, 0.0))
	gait.add_blend_point(_clip(WALK_FORWARD_LEFT_CLIP), Vector2(-1.0, 1.0))
	gait.add_blend_point(_clip(WALK_FORWARD_RIGHT_CLIP), Vector2(1.0, 1.0))
	gait.add_blend_point(_clip(WALK_BACKWARD_LEFT_CLIP), Vector2(-1.0, -1.0))
	gait.add_blend_point(_clip(WALK_BACKWARD_RIGHT_CLIP), Vector2(1.0, -1.0))

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
	var qualified := "%s/%s" % [animation_library_name, clip_name]
	if not animation_player.has_animation(qualified):
		push_error("CharacterRig: no animation %s" % qualified)
		return null
	var node := AnimationNodeAnimation.new()
	node.animation = qualified
	return node


## Where in the blend space to stand and how fast to play it. Both are decided by
## [SCharacterAnimation]; this only puts them on the tree.
func set_gait(blend_position: Vector2, time_scale: float) -> void:
	if animation_tree == null:
		return
	animation_tree.set(BLEND_POSITION_PARAMETER, blend_position)
	animation_tree.set(TIME_SCALE_PARAMETER, time_scale)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
