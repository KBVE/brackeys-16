extends Node
## 08/23/2026 - This bridge is from a couple older jams, it still needs some work for 4.7.2.
## Bridge between GDScript and the React app (window.__godotBridge).
##
##   Godot -> JS : emit_event(event, payload) -> __godotBridge.emit(event, json)
##   JS -> Godot : __godotBridge.send(cmd, obj) -> command_received(cmd, payload)
##
## Every call is a no-op off the web platform, so the project still runs in the
## editor and in desktop exports without the JS layer present.

## Emitted when the JS side sends a command. Connect from anywhere.
signal command_received(cmd: String, payload: Dictionary)

var _js_bridge = null   # JavaScriptObject wrapping window.__godotBridge
var _callback = null    # must stay referenced for the app's lifetime or it is freed
var _is_web := false


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return

	# React installs window.__godotBridge before starting the engine.
	_js_bridge = JavaScriptBridge.get_interface("__godotBridge")
	if _js_bridge == null:
		push_warning("JsBridge: window.__godotBridge not found")
		return

	_callback = JavaScriptBridge.create_callback(_on_js)
	_js_bridge.setHandler(_callback)

	# Tells the JS side to drain anything it queued before we were listening.
	emit_event("godot:ready", {})


func is_connected_to_js() -> bool:
	return _js_bridge != null


func emit_event(event: String, payload: Dictionary = {}) -> void:
	if _js_bridge == null:
		return
	_js_bridge.emit(event, JSON.stringify(payload))


## Godot delivers the JS arguments as a single Array: [cmd, payload_json].
func _on_js(args: Array) -> void:
	if args.is_empty():
		return
	var cmd := str(args[0])
	var payload := {}
	if args.size() >= 2 and args[1] != null:
		var parsed = JSON.parse_string(str(args[1]))
		if typeof(parsed) == TYPE_DICTIONARY:
			payload = parsed
	command_received.emit(cmd, payload)
