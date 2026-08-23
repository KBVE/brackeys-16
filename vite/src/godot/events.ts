/**
 * The bridge contract. Both sides must agree on these names and shapes.
 *
 * Keep payloads coarse: gameplay runs at 60/120fps inside WASM, but these
 * cross the JS boundary only on real changes, or a handful of times a second
 * for state snapshots. Never per-frame.
 */

/** Godot -> React. */
export interface GodotToJs {
  'godot:ready': Record<string, never>;
  'player:state': { health: number; max_health: number };
  'scene:changed': { scene: string };
}

/** React -> Godot. */
export interface JsToGodot {
  'ui:pause': { paused: boolean };
  'ui:restart': Record<string, never>;
}

export type GodotEvent = keyof GodotToJs;
export type GodotCommand = keyof JsToGodot;
