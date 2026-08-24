extends Node3D
class_name Train

## Train : Node3D
##
## Actual carriage geometry, 32k tris, one 2048 atlas. No baked light, so time of
## day is runtime state and the camera goes anywhere.
##
## One scene, one camera, walked from inside the aisle. Everything else the run
## needs is a component on the ECS, not another scene to swap to.

const LEVEL_NAME := "Aisle"

## The framing a run starts from: x along the carriage, yaw offset.
const AISLE_HOME := Vector2(-7.0, 0.0)

## Radians turned per unit of input, so one full swipe is most of a turn.
const TURN_RADIANS_PER_UNIT := 2.4

const SWAY_HZ := 0.7



const CAR_HALF_LEN := 10.44
## Measured. At 3.02 the camera sat above the side windows, so every sightline
## out of them hit ground and the forest was never visible.
const AISLE_EYE := 2.60

## Screen heights a finger travels for one unit of movement, so a swipe covers
## the same arc on any display.
const DRAG_SCREENS_PER_UNIT := 2.6

@onready var _world: SubViewport = $Screen/Frame/World
@onready var _rig: Node3D = $Screen/Frame/World/Rig
@onready var _cam: Camera3D = $Screen/Frame/World/Rig/Camera3D
@onready var _consist: Consist = $Screen/Frame/World/Consist
@onready var _forest: ParallaxBackdrop = $Screen/Frame/World/Backdrop/Forest

var _t := 0.0
## INF, or re-seeding on every _ready() restarts the evening on re-entry.
var _seed_phase := INF
var _seed_running := true
var _yaw_override := INF
var _eye_override := INF
var _viewer: CViewer
var _occupant: COccupant
var _here: CLocation
var _time_of_day: CTimeOfDay
var _run: CRun
## Drag distance accumulated since the last frame, in movement units.
var _drag := Vector2.ZERO

## Torn down with the scene. The clock is not here; it lives on [Session].
var _scope := ECSScope.new()

var _aisle := AISLE_HOME

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--yaw="):
			# applied after _start_level, which resets _aisle to home
			_yaw_override = clampf(float(a.split("=")[1]), -1.4, 1.4)
		if a.begins_with("--eye="):
			_eye_override = float(a.split("=")[1])
		if a.begins_with("--phase="):
			# 0.0 noon, 0.5 midnight
			_seed_phase = fposmod(float(a.split("=")[1]), 1.0)
			_seed_running = false
		if a.begins_with("--detail="):
			var v := a.split("=")[1].split(",")
			_tune_detail(float(v[0]), float(v[1]), float(v[2]))
	_time_of_day = Session.time_of_day
	_run = Session.run

	# one mesh repeated, so rooms are authored not modelled; order is
	# shared/data/locations, which React reads as the same list
	var rooms := GameContent.carriage_locations()
	if rooms.size() != _consist.carriage_count:
		push_error("Consist has %d carriages but shared/data/locations authors %d. Rebuild the scene."
			% [_consist.carriage_count, rooms.size()])
	for i in range(mini(rooms.size(), _consist.carriage_count)):
		var room := CLocation.new()
		room.location_id = rooms[i]
		var carriage := CCarriage.new()
		carriage.index = i
		_scope.spawn().add(carriage).add(room).add(CLamp.new()) \
			.add(ECSViewComponent.new(_consist.lamps_for(i)))

	_viewer = CViewer.new()
	_occupant = COccupant.new()
	_here = CLocation.new()
	# the rig, not the camera: in ORBIT the camera swings out to 40m and would
	# report the player walking the train
	_scope.spawn().add(_viewer).add(_occupant).add(_here).add(ECSViewComponent.new(_rig))
	_scope.add_system(&"viewer", SViewer.new())
	var occupancy := SOccupancy.new()
	occupancy.carriage_pitch = _consist.pitch
	occupancy.carriage_count = _consist.carriage_count
	_scope.add_system(&"occupancy", occupancy)
	_scope.spawn().add(CParallax.new()).add(ECSViewComponent.new(_forest))
	_scope.add_system(&"parallax", SParallax.new())
	_scope.spawn().add(CWorldLighting.new()).add(ECSViewComponent.new($Screen/Frame/World/Lighting))
	_scope.add_system(&"world_lighting", SWorldLighting.new())
	var lamps := SCarriageLamps.new()
	lamps.lamp_glass = _consist.glow_material()
	_scope.add_system(&"carriage_lamps", lamps)

	# the world owns the camera now, so picking is its viewport's job, not the
	# window's
	_world.physics_object_picking = true
	# React's ui:restart and an in-world loss take the same path
	Ecs.world.add_callable(GameEvents.UI_RESTART, _on_ui_restart)

	_time_of_day.running = _seed_running
	if is_finite(_seed_phase):
		_time_of_day.phase = fposmod(_seed_phase, 1.0)
	_begin()
	if is_finite(_yaw_override):
		_aisle.y = _yaw_override
		_apply_shot()

## Driven by `-- --detail=tiling,strength,albedo`, to sweep without rebuilding.
func _tune_detail(tiling: float, strength: float, albedo: float) -> void:
	_consist.tune_detail(tiling, strength, albedo)

func _process(delta: float) -> void:
	_t += delta
	_read_input(delta)
	# after _apply_shot, which writes the rig's resting height and would
	# otherwise wipe the sway back out every frame
	_rig.position.y += sin(_t * TAU * SWAY_HZ) * 0.012
	_rig.rotation.z = sin(_t * TAU * SWAY_HZ * 0.37) * 0.0016

	# only the cars near the viewer draw; cost is O(1) in train length
	_consist.cull_around(_viewer.world_x)

func _exit_tree() -> void:
	_scope.dispose()

## Yaw rides the rig, not the camera, so the rig transform is the whole answer to
## "which way is the player facing" and [SViewer] can just read it.
func _apply_shot() -> void:
	_rig.position.x = _aisle.x
	_rig.position.y = _eye_override if is_finite(_eye_override) else AISLE_EYE
	_rig.position.z = 0.0
	_rig.rotation.y = _aisle.y
	_cam.position = Vector3.ZERO
	_cam.rotation = Vector3(0.0, deg_to_rad(-90.0), 0.0)
	_cam.near = 0.05
	GameBridge.set_world_mode(StateBits.WorldMode.MODE_3D)


## Starts the run. There is one scene and one camera, so this sets the framing
## and announces it; it never swaps anything.
func _begin() -> void:
	_run.level_index = 0
	_aisle = AISLE_HOME
	_apply_shot()
	GameBridge.set_player_flags(StateBits.PLAYER_ALIVE)
	Journal.record(StateBits.JournalKind.ENTERED, "player", "", LEVEL_NAME.to_lower())
	_notify_level("start")


func _on_ui_restart(_event: GameEvent) -> void:
	Session.begin()
	Journal.clear()
	_begin()


func _notify_level(outcome: String) -> void:
	_run.outcome = outcome
	Ecs.notify(GameEvents.LEVEL_CHANGED, {
		"level": LEVEL_NAME,
		"index": 0,
		"total": 1,
		"outcome": outcome,
	})


## Drag pans the camera. A tap produces no drag event, so the WIN and LOSE plates
## keep their picking and no on-screen stick is needed.
##
## _input, not _unhandled_input: the SubViewportContainer consumes pointer events
## to forward them inward, so nothing reaches the unhandled pass. Sizes come from
## the window rather than the world, so lowering RENDER_SHRINK cannot change how
## far a swipe travels.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var height := float(get_window().size.y)
		if height > 0.0:
			_drag += (event as InputEventScreenDrag).relative / height * DRAG_SCREENS_PER_UNIT


func _read_input(delta: float) -> void:
	# a held key is a rate, so it scales with frame time; a drag is already a
	# distance, so it must not. Swap either sign to invert that axis.
	var h := Input.get_axis(&"move_left", &"move_right") * delta - _drag.x
	var v := Input.get_axis(&"move_down", &"move_up") * delta + _drag.y
	_drag = Vector2.ZERO
	_aisle.x = clampf(_aisle.x + v * 4.0, -CAR_HALF_LEN + 1.5, CAR_HALF_LEN - 1.5)
	# wraps rather than clamps: the player can turn all the way round and look
	# back down the train
	_aisle.y = wrapf(_aisle.y - h * TURN_RADIANS_PER_UNIT, -PI, PI)
	_apply_shot()

	if Input.is_action_just_pressed(&"ui_accept"):
		_time_of_day.running = not _time_of_day.running
	if Input.is_action_just_pressed(&"ui_page_up"):
		_time_of_day.phase = fposmod(_time_of_day.phase + 0.08, 1.0)
	if Input.is_action_just_pressed(&"ui_page_down"):
		_time_of_day.phase = fposmod(_time_of_day.phase - 0.08, 1.0)
