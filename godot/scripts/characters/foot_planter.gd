extends SkeletonModifier3D
class_name FootPlanter

## FootPlanter keeps the feet on the deck the clips were not authored for.
##
## The walk clips were animated for a character of a fixed height on a floor at zero.
## This rig is scaled to a stature and stands on a deck a metre and a quarter up, and
## the two disagree by a few centimetres that read as sinking or skating. Worse, they
## disagree by a different amount in every clip, so the error changes as the gait
## blends and a foot slides while it should be planted.
##
## Two bone IK per leg, and the hips drop when neither leg can reach. Nothing here
## decides when it applies: [member weight] is written by [SFootPlanting], which turns
## it off in the air where there is no floor to plant against.

## Metres. Where the deck is, in this rig's own space. A flat plane rather than a
## raycast because the carriage interior carries no collision: the seats, the bulkheads
## and the floorboards are all mesh. When they get colliders this becomes a ray and
## nothing above it has to change.
@export var floor_height_metres: float = 0.0

## How much of the correction to apply. Zero leaves the clips exactly as authored.
@export_range(0.0, 1.0) var weight: float = 1.0

## How far the ankle sits above the sole, so the foot rests on the deck rather than
## through it. Measured from the rig, and scaled with it.
@export var ankle_height_metres: float = 0.075

## The most the hips will drop to let a foot reach. Past this the leg is allowed to
## fall short, because a character folding in half is worse than a foot in the air.
@export var deepest_hip_drop_metres: float = 0.35

const LEGS := [
	{"upper": &"LeftUpperLeg", "lower": &"LeftLowerLeg", "foot": &"LeftFoot"},
	{"upper": &"RightUpperLeg", "lower": &"RightLowerLeg", "foot": &"RightFoot"},
]

const HIPS_BONE := &"Hips"


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_zero_approx(weight):
		return

	var wanted: Array[float] = []
	for leg: Dictionary in LEGS:
		var foot := skeleton.find_bone(leg["foot"])
		if foot < 0:
			return
		var at := skeleton.get_bone_global_pose(foot).origin
		wanted.append(floor_height_metres + ankle_height_metres - at.y)

	# the hips follow the foot that has furthest to reach down, so the legs keep their
	# authored bend instead of snapping straight to make up the difference
	var drop: float = minf(minf(wanted[0], wanted[1]), 0.0)
	drop = maxf(drop, -deepest_hip_drop_metres) * weight
	var hips := skeleton.find_bone(HIPS_BONE)
	if hips >= 0 and not is_zero_approx(drop):
		var pose := skeleton.get_bone_global_pose(hips)
		pose.origin.y += drop
		skeleton.set_bone_global_pose(hips, pose)

	for i in LEGS.size():
		_plant(skeleton, LEGS[i], wanted[i] * weight)


## Puts one foot [param rise] metres from where the clip left it, and bends the knee to
## suit. The bend plane is the one the animation was already using, so a leg that was
## authored bowed stays bowed rather than snapping to face front.
func _plant(skeleton: Skeleton3D, leg: Dictionary, rise: float) -> void:
	var upper := skeleton.find_bone(leg["upper"])
	var lower := skeleton.find_bone(leg["lower"])
	var foot := skeleton.find_bone(leg["foot"])
	if upper < 0 or lower < 0 or foot < 0:
		return

	var hip_pose := skeleton.get_bone_global_pose(upper)
	var knee_pose := skeleton.get_bone_global_pose(lower)
	var foot_pose := skeleton.get_bone_global_pose(foot)
	var hip := hip_pose.origin
	var knee := knee_pose.origin
	var target := foot_pose.origin + Vector3(0.0, rise, 0.0)

	var thigh := hip.distance_to(knee)
	var shin := knee.distance_to(foot_pose.origin)
	if thigh <= 0.0 or shin <= 0.0:
		return

	var to_target := target - hip
	var reach := to_target.length()
	# never fully straight: a leg at exactly thigh + shin has no plane to bend in, and
	# the knee direction becomes whatever the arithmetic rounds to
	reach = clampf(reach, absf(thigh - shin) + 0.001, thigh + shin - 0.001)
	var along := to_target.normalized()

	var bend_plane := (knee - hip).slide(along)
	if bend_plane.length_squared() < 0.000001:
		bend_plane = Vector3.FORWARD.slide(along)
	bend_plane = bend_plane.normalized()

	# cosine rule: how far off the straight line to the target the knee sits
	var cos_hip := clampf((thigh * thigh + reach * reach - shin * shin)
		/ (2.0 * thigh * reach), -1.0, 1.0)
	var placed_knee := hip + (along * cos_hip + bend_plane * sin(acos(cos_hip))) * thigh

	_aim(skeleton, upper, hip_pose, knee, placed_knee)
	var moved_knee := skeleton.get_bone_global_pose(lower)
	moved_knee.origin = placed_knee
	skeleton.set_bone_global_pose(lower, moved_knee)
	_aim(skeleton, lower, moved_knee, foot_pose.origin, target)


## Rotates [param bone] so the point it was aiming at ends up where it should be. The
## whole basis is turned rather than rebuilt, so the bone keeps its roll and the foot
## does not spin on the ankle.
func _aim(skeleton: Skeleton3D, bone: int, pose: Transform3D,
		was_at: Vector3, goes_to: Vector3) -> void:
	var was := (was_at - pose.origin).normalized()
	var goes := (goes_to - pose.origin).normalized()
	if was.length_squared() < 0.5 or goes.length_squared() < 0.5:
		return
	if was.dot(goes) > 0.99999:
		return
	pose.basis = Basis(Quaternion(was, goes)) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
