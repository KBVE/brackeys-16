extends Node

## GameBridge : Maaack <-> ECS <-> React, one wiring point
##
## &bus -> everything crosses the ECS bus; scene + pause fold into one packed
##         [constant GameEvents.STATE_CHANGED]
## &why -> gameplay never imports [JsBridge], menus never import the ECS


## &map -> scene path substring -> RunState ; first hit wins
const SCENE_STATES: Array[Array] = [
	["/game/", StateBits.RunState.PLAYING],
	["/end_credits/", StateBits.RunState.ENDED],
	["/menus/", StateBits.RunState.MENU],
]

var _last_scene_path: String = ""
var _run_state: int = StateBits.RunState.BOOTING
var _player_flags: int = 0

func _ready() -> void:
	Ecs.add_observer(JsBridgeObserver.new())
	JsBridge.command_received.connect(_on_js_command)
	Ecs.world.add_callable(GameEvents.UI_PAUSE, _on_ui_pause)
	process_priority = 100
	# &always -> unpause is a React command; Ecs pauses with the tree, this cannot
	process_mode = Node.PROCESS_MODE_ALWAYS

## &why -> scene_loaded fires BEFORE the swap, and for loads that never swap
##      -> current_scene reports what happened, incl. changes without SceneLoader
func _process(_delta: float) -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var path := current.scene_file_path
	if path == _last_scene_path:
		return
	_last_scene_path = path
	Ecs.notify(GameEvents.SCENE_CHANGED, {"scene": path})
	# &sync -> leaving the game scene drops the pause
	if get_tree().paused:
		get_tree().paused = false
	_set_run_state(_state_for_scene(path))

func _on_js_command(cmd: String, payload: Dictionary) -> void:
	if not GameEvents.INBOUND_BUS.has(cmd):
		push_warning("GameBridge: unmapped JS command '%s'." % cmd)
		return
	Ecs.notify(GameEvents.INBOUND_BUS[cmd], payload)

## &why -> pause is engine state; a system may not run while paused
func _on_ui_pause(event: GameEvent) -> void:
	var payload: Variant = event.data
	var paused: bool = payload.get("paused", true) if payload is Dictionary else true
	# &guard -> a paused menu is a soft lock
	var scene_state := _state_for_scene(_last_scene_path)
	if scene_state != StateBits.RunState.PLAYING:
		return
	get_tree().paused = paused
	_set_run_state(StateBits.RunState.PAUSED if paused else StateBits.RunState.PLAYING)

## &flags -> gameplay owns these bits, the bridge only forwards
func set_player_flags(flags: int) -> void:
	if flags == _player_flags:
		return
	_player_flags = flags
	_publish()

func _state_for_scene(path: String) -> int:
	for entry: Array in SCENE_STATES:
		if path.contains(entry[0]):
			return entry[1]
	return StateBits.RunState.BOOTING

func _set_run_state(state: int) -> void:
	if state == _run_state:
		return
	_run_state = state
	_publish()

func _publish() -> void:
	Ecs.notify(GameEvents.STATE_CHANGED, {"run": _run_state, "flags": _player_flags})
