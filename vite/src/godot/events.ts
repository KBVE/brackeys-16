/**
 * GENERATED FILE - DO NOT EDIT.
 *
 * Source: shared/state.json + shared/events.json
 * Regenerate: npm run gen (from vite/). Runs automatically on dev and build.
 *
 * The bridge contract. Both sides are generated from the same file, so a wire
 * name cannot drift between Godot and React.
 *
 * Keep payloads coarse: gameplay runs at 60/120fps inside WASM, but these cross
 * the JS boundary only on real changes, or a few times a second for snapshots.
 */

/** Godot -> React. */
export interface GodotToJs {
  // The bridge is live and draining anything React queued before wasm boot. Emitted
  // directly by JsBridge itself rather than the ECS bus, so it has no bus name, (this
  // is like a race condition type situation resolver).
  'godot:ready': Record<string, never>;
  // The scene tree finished swapping scenes; `scene` is the res:// path of the new
  // scene.
  'scene:changed': { scene: string };
  // Coarse HUD snapshot that emit at 5 / 10 / 15 / 20Hz, not per frame!!! Every emit
  // crosses the JS boundary and serialises to JSON or packed ints.
  'player:state': { health: number; max_health: number };
  // Coarse run state; both fields are packed ints from shared/state.json : Json ->
  // `run` is a RunState, `flags` is a PlayerFlags bitfield; decode with the generated
  // helpers, never with constants.
  'game:state': { run: number; flags: number };
  // Score changed, probably hook this into a clue based system later on.
  'game:score': { score: number };
  // The run or murder train ended. Shape is currently game defined, so give it real
  // fields once the game has them.
  'game:run_over': Record<string, unknown>;
}

/** React -> Godot. */
export interface JsToGodot {
  // React or devtools asked to pause or resume. It is ignored outside RunState.PLAYING,
  // with the paused menu acting like a soft lock.
  'ui:pause': { paused: boolean };
  // React , jest or playwright requested to restart the current run or murder or clue
  // scene.
  'ui:restart': Record<string, never>;
  // React asked to leave the game scene for the main menu, think of it as a quick
  // escape hatch.
  'ui:main_menu': Record<string, never>;
}

/** Wire name -> ordered payload fields, matching the positional args Godot sends. */
export const WIRE_FIELDS: Record<string, readonly string[]> = {
  'godot:ready': [],
  'scene:changed': ['scene'],
  'player:state': ['health', 'max_health'],
  'game:state': ['run', 'flags'],
  'game:score': ['score'],
};

export type GodotEvent = keyof GodotToJs;
export type GodotCommand = keyof JsToGodot;