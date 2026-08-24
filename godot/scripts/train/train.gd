extends Node3D
class_name Train

## Train : Node3D
## &real -> actual carriage geometry, 32k tris, one 2048 atlas. no baked light,
##          so time of day is runtime state and the camera goes anywhere.
## &cut  -> SIDE mode clips the near wall with the camera near plane, same trick
##          the blender bake used. no geometry is hidden or duplicated.
## &loop -> three levels (Aisle, Orbit, Side) run inside this one carriage. A
##          level swap is a camera + framing swap, never a scene swap, so the
##          wasm instance and the loaded carriage are paid for exactly once.

enum Shot { SIDE, AISLE, ORBIT }

## &order -> Aisle, Orbit, Side; the run wraps back to Aisle after Side so the
##           loop never dead-ends while there is no post-run content
const LEVELS: Array[Shot] = [Shot.AISLE, Shot.ORBIT, Shot.SIDE]
const LEVEL_NAMES: Array[String] = ["Aisle", "Orbit", "Side"]

# &reset -> a level always starts from its own framing, win or lose
const SIDE_HOME := Vector2(0.0, 12.0)
const AISLE_HOME := Vector2(-7.0, 0.0)
const ORBIT_HOME := Vector2(0.6, 16.0)

const SWAY_HZ := 0.7



const CAR_HALF_LEN := 10.44
const NEAR_WALL_Z := 1.70
## &eye -> measured. At 3.02 the camera sat ABOVE the side windows, so every
##         sightline out of them hit ground and the forest was never visible.
const AISLE_EYE := 2.60
const CUT_Z := 1.4
const NO_CLIP := 1000000.0

@onready var _rig: Node3D = $Rig
@onready var _cam: Camera3D = $Rig/Camera3D
@onready var _consist: Consist = $Consist
@onready var _forest: ParallaxBackdrop = $Backdrop/Forest
@onready var _hud: Label = $Debug/Label
@onready var _buttons: Node3D = $Rig/Camera3D/Buttons

var _t := 0.0
## &seed -> re-seeding on every _ready() would restart the evening on re-entry.
var _seed_phase := INF
var _seed_running := true
var _shot: Shot = Shot.AISLE
var _yaw_override := INF
var _eye_override := INF
var _viewer: CViewer
var _occupant: COccupant
var _here: CLocation
var _time_of_day: CTimeOfDay
var _run: CRun
## &scope -> torn down with the scene. The clock is not here; it lives on [Session].
var _scope := ECSScope.new()

# per-shot free parameters, kept so switching back restores the framing
var _side := SIDE_HOME   # x pan, z distance
var _aisle := AISLE_HOME  # x along the carriage, yaw offset
var _orbit := ORBIT_HOME  # angle, radius

func _ready() -> void:
	var start := 0
	# &shot -> `-- --shot=aisle` starts the run on that level, for captures
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			var idx := LEVELS.find(Shot.keys().find(a.split("=")[1].to_upper()))
			if idx >= 0:
				start = idx
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--yaw="):
			# &capture -> aim the aisle camera at a window without driving input.
			#             applied AFTER _start_level, which resets _aisle to home
			_yaw_override = clampf(float(a.split("=")[1]), -1.4, 1.4)
		if a.begins_with("--eye="):
			_eye_override = float(a.split("=")[1])
		if a.begins_with("--phase="):
			# &capture -> 0.0 noon, 0.5 midnight
			_seed_phase = fposmod(float(a.split("=")[1]), 1.0)
			_seed_running = false
		if a.begins_with("--detail="):
			var v := a.split("=")[1].split(",")
			_tune_detail(float(v[0]), float(v[1]), float(v[2]))
	_time_of_day = Session.time_of_day
	_run = Session.run

	# &rooms -> one mesh repeated, so the rooms are authored, not modelled. The
	#          order is shared/data/locations, which React reads as the same list.
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
	# &rig -> NOT the camera: in ORBIT it swings out to 40m and would report the
	#         player walking the train while they have not moved.
	_scope.spawn().add(_viewer).add(_occupant).add(_here).add(ECSViewComponent.new(_rig))
	_scope.add_system(&"viewer", SViewer.new())
	var occupancy := SOccupancy.new()
	occupancy.carriage_pitch = _consist.pitch
	occupancy.carriage_count = _consist.carriage_count
	_scope.add_system(&"occupancy", occupancy)
	_scope.spawn().add(CParallax.new()).add(ECSViewComponent.new(_forest))
	_scope.add_system(&"parallax", SParallax.new())
	_scope.spawn().add(CWorldLighting.new()).add(ECSViewComponent.new($Lighting))
	_scope.add_system(&"world_lighting", SWorldLighting.new())
	var lamps := SCarriageLamps.new()
	lamps.lamp_glass = _consist.glow_material()
	_scope.add_system(&"carriage_lamps", lamps)

	# &pick -> off by default in 3D; without it the buttons never see a click
	get_viewport().physics_object_picking = true
	for b: LevelButton in _buttons.get_children():
		b.pressed.connect(_on_button)

	# &restart -> React's ui:restart and an in-world loss take the same path
	Ecs.world.add_callable(GameEvents.UI_RESTART, _on_ui_restart)

	_time_of_day.running = _seed_running
	if is_finite(_seed_phase):
		_time_of_day.phase = fposmod(_seed_phase, 1.0)
	_start_level(start)
	if is_finite(_yaw_override):
		_aisle.y = _yaw_override
		_apply_shot()

## &tune -> `-- --detail=tiling,strength,albedo` to sweep without rebuilding
func _tune_detail(tiling: float, strength: float, albedo: float) -> void:
	_consist.tune_detail(tiling, strength, albedo)

func _process(delta: float) -> void:
	_t += delta
	_rig.position.y = sin(_t * TAU * SWAY_HZ) * 0.012
	_rig.rotation.z = sin(_t * TAU * SWAY_HZ * 0.37) * 0.0016

	# &stream -> only the cars near the viewer draw; cost is O(1) in train length
	_consist.cull_around(_viewer.world_x)

	_read_input(delta)
	_hud.text = _describe()

func _exit_tree() -> void:
	_scope.dispose()

func _apply_shot() -> void:
	match _shot:
		Shot.SIDE:
			# &clip -> push the near plane past the camera-side wall to cut away
			_rig.position = Vector3(_side.x, 2.4, 0.0)
			_cam.position = Vector3(0.0, 0.0, _side.y)
			_cam.rotation = Vector3.ZERO
			_cam.near = 0.05
			_consist.set_clip_z(CUT_Z)
			GameBridge.set_world_mode(StateBits.WorldMode.MODE_2D)
		Shot.AISLE:
			_rig.position = Vector3(_aisle.x, _eye_override if is_finite(_eye_override) else AISLE_EYE, 0.0)
			_cam.position = Vector3.ZERO
			_cam.rotation = Vector3(0.0, deg_to_rad(-90.0) + _aisle.y, 0.0)
			_cam.near = 0.05
			_consist.set_clip_z(NO_CLIP)
			GameBridge.set_world_mode(StateBits.WorldMode.MODE_3D)
		Shot.ORBIT:
			_rig.position = Vector3.ZERO
			_cam.position = Vector3(sin(_orbit.x) * _orbit.y, 4.0, cos(_orbit.x) * _orbit.y)
			_cam.look_at_from_position(_cam.position, Vector3(0.0, 2.4, 0.0), Vector3.UP)
			_cam.near = 0.05
			_consist.set_clip_z(NO_CLIP)
			GameBridge.set_world_mode(StateBits.WorldMode.MODE_3D)
	_place_buttons()

## &clip -> SIDE pushes the near plane past 10m to cut the near wall away, so a
##          fixed offset would leave the buttons inside it. They ride the plane
##          and scale with the distance -> same size on screen in every level.
func _place_buttons() -> void:
	# &gap -> a far near plane means SIDE already cut the wall away; sit just past
	#         the cut, otherwise the plates land inside the carriage and the seats
	#         chew their top edge
	var dist := _cam.near + (0.45 if _cam.near > 1.0 else 1.2)
	var k := dist / 3.4
	_buttons.position = Vector3(0.0, -0.62 * k, -dist)
	_buttons.scale = Vector3.ONE * k

# ==============================================================================
# Levels
# ==============================================================================

## Levels never swap the scene; they swap the camera, the framing and the rules.
func _start_level(index: int) -> void:
	_run.level_index = posmod(index, LEVELS.size())
	_shot = LEVELS[_run.level_index]
	_side = SIDE_HOME
	_aisle = AISLE_HOME
	_orbit = ORBIT_HOME
	_apply_shot()
	GameBridge.set_player_flags(StateBits.PLAYER_ALIVE)
	# &record -> the journal is the run's memory; a level entered is a fact
	Journal.record(StateBits.JournalKind.ENTERED, "player", "", LEVEL_NAMES[_run.level_index].to_lower())
	_notify_level("start")

func _on_button(won: bool) -> void:
	if won:
		_win()
	else:
		_lose()

func _win() -> void:
	_run.score += 1
	Ecs.notify(GameEvents.SCORE_CHANGED, {"score": _run.score})
	_notify_level("won")
	# &loop -> the run reports itself over, then rolls back to Aisle. Nothing to
	#          cut to yet, and a dead screen would strand the player in wasm
	if _run.level_index == LEVELS.size() - 1:
		Ecs.notify(GameEvents.RUN_OVER, {"score": _run.score, "levels": LEVELS.size()})
	_start_level(_run.level_index + 1)

func _lose() -> void:
	_notify_level("lost")
	_start_level(_run.level_index)

func _on_ui_restart(_event: GameEvent) -> void:
	# &fresh -> a restart is a new run, and a new run remembers nothing
	Session.begin()
	Journal.clear()
	_start_level(0)

func _notify_level(outcome: String) -> void:
	_run.outcome = outcome
	Ecs.notify(GameEvents.LEVEL_CHANGED, {
		"level": LEVEL_NAMES[_run.level_index],
		"index": _run.level_index,
		"total": LEVELS.size(),
		"outcome": outcome,
	})

func _read_input(delta: float) -> void:
	var h := Input.get_axis(&"move_left", &"move_right")
	var v := Input.get_axis(&"move_down", &"move_up")
	match _shot:
		Shot.SIDE:
			_side.x = clampf(_side.x + h * delta * 7.0, -CAR_HALF_LEN, CAR_HALF_LEN)
			_side.y = clampf(_side.y - v * delta * 7.0, 3.0, 26.0)
		Shot.AISLE:
			_aisle.x = clampf(_aisle.x + v * delta * 4.0, -CAR_HALF_LEN + 1.5, CAR_HALF_LEN - 1.5)
			_aisle.y = clampf(_aisle.y - h * delta * 1.2, -1.4, 1.4)
		Shot.ORBIT:
			_orbit.x += h * delta * 0.8
			_orbit.y = clampf(_orbit.y - v * delta * 8.0, 5.0, 40.0)
	_apply_shot()

	# &dev -> keyboard mirror of the WIN plate, so a capture needs no mouse
	if Input.is_action_just_pressed(&"interact"):
		_win()
	if Input.is_action_just_pressed(&"ui_accept"):
		_time_of_day.running = not _time_of_day.running
	if Input.is_action_just_pressed(&"ui_page_up"):
		_time_of_day.phase = fposmod(_time_of_day.phase + 0.08, 1.0)
	if Input.is_action_just_pressed(&"ui_page_down"):
		_time_of_day.phase = fposmod(_time_of_day.phase - 0.08, 1.0)

func _describe() -> String:
	var clock := _time_of_day.minutes_past_midnight / 60
	return "\n".join([
		"level   %d/%d %s   score %d   last %s" % [
			_run.level_index + 1, LEVELS.size(), LEVEL_NAMES[_run.level_index], _run.score, _run.outcome],
		"shot    %s        world %s" % [Shot.keys()[_shot], StateBits.world_mode_name(
			StateBits.WorldMode.MODE_2D if _shot == Shot.SIDE else StateBits.WorldMode.MODE_3D)],
		"time    %02d:%02d   phase %.2f   %s   carriage %d %s" % [
			clock, _time_of_day.minutes_past_midnight % 60, _time_of_day.phase,
			"running" if _time_of_day.running else "held",
			_occupant.carriage_index, _here.location_id],
		"cam     %.2f, %.2f, %.2f   near %.2f" % [
			_rig.position.x + _cam.position.x, _rig.position.y + _cam.position.y,
			_rig.position.z + _cam.position.z, _cam.near],
		"fps     %d" % Engine.get_frames_per_second(),
		"",
		"click WIN / LOSE   E wins   WASD move   SPACE hold day/night   PGUP/PGDN scrub",
	])
