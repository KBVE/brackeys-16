class_name GameEvents

## GENERATED FILE - DO NOT EDIT.
##
## Source: shared/state.json + shared/events.json
## Regenerate: npm run gen (from vite/). Runs automatically on dev and build.
##
## The event vocabulary shared by the ECS world, the Maaack menus, and the
## React shell. Gameplay emits these names and nothing else - the mapping onto
## JS wire names lives in [constant OUTBOUND_WIRE], so producers stay unaware
## that a browser exists.

# ==============================================================================
# Outbound - Godot to React
# ==============================================================================

## The scene tree finished swapping scenes; `scene` is the res:// path of the new scene.
##
## Deliberately not driven by SceneLoader.scene_loaded, because it fires before the swap
## and also for background loads that never swap at all. Currently, our gameBridge
## watches the tree's current scene instead, so this reports what actually happened and
## catches changes made without SceneLoader.
##
## Payload: {"scene": string}. Reaches JS as "scene:changed".
const SCENE_CHANGED := &"scene_changed"

## Coarse HUD snapshot that emit at 5 / 10 / 15 / 20Hz, not per frame!!! Every emit
## crosses the JS boundary and serialises to JSON or packed ints.
##
## Payload: {"health": number, "max_health": number}. Reaches JS as "player:state".
const PLAYER_STATE := &"player_state"

## Coarse run state; both fields are packed ints from shared/state.json : Json -> `run`
## is a RunState, `flags` is a PlayerFlags bitfield; decode with the generated helpers,
## never with constants.
##
## Payload: {"run": number, "flags": number}. Reaches JS as "game:state".
const STATE_CHANGED := &"state_changed"

## Score changed, probably hook this into a clue based system later on.
##
## Payload: {"score": number}. Reaches JS as "game:score".
const SCORE_CHANGED := &"score_changed"

## The run or murder train ended. Shape is currently game defined, so give it real
## fields once the game has them.
##
## Payload: game-defined. Reaches JS as "game:run_over".
const RUN_OVER := &"run_over"

# ==============================================================================
# Inbound - React to Godot
# ==============================================================================

## React or devtools asked to pause or resume. It is ignored outside RunState.PLAYING,
## with the paused menu acting like a soft lock.
##
## Payload: {"paused": boolean}. Reaches JS as "ui:pause".
const UI_PAUSE := &"ui_pause"

## React , jest or playwright requested to restart the current run or murder or clue
## scene.
##
## Payload: none. Reaches JS as "ui:restart".
const UI_RESTART := &"ui_restart"

## React asked to leave the game scene for the main menu, think of it as a quick escape
## hatch.
##
## Payload: none. Reaches JS as "ui:main_menu".
const UI_MAIN_MENU := &"ui_main_menu"

# ==============================================================================
# Wire mapping
# ==============================================================================

## Bus name to JS wire name. [JsBridgeObserver] forwards every entry, so adding
## an outbound event is a shared/events.json edit and nothing more.
const OUTBOUND_WIRE: Dictionary[StringName, String] = {
	SCENE_CHANGED: "scene:changed",
	PLAYER_STATE: "player:state",
	STATE_CHANGED: "game:state",
	SCORE_CHANGED: "game:score",
	RUN_OVER: "game:run_over",
}

## JS wire name to bus name. [GameBridge] republishes every entry, so a command
## from React is indistinguishable from in-game intent downstream.
const INBOUND_BUS: Dictionary[String, StringName] = {
	"ui:pause": UI_PAUSE,
	"ui:restart": UI_RESTART,
	"ui:main_menu": UI_MAIN_MENU,
}