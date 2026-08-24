/**
 * GENERATED FILE - DO NOT EDIT.
 *
 * Source: shared/state.json + shared/events.json
 * Regenerate: npm run gen (from vite/). Runs automatically on dev and build.
 */

/**
 * Where the game as a whole is; replaces sniffing scene paths on the React side.
 */
export const RunState = {
  BOOTING: 0,
  MENU: 1,
  PLAYING: 2,
  PAUSED: 3,
  ENDED: 4,
} as const;
export type RunState = (typeof RunState)[keyof typeof RunState];

/**
 * Per frame player state! Packed because systems test these thousands of times a
 * second; a bit test is a single AND against a register but overkill for now, damn
 * safari.
 */
export const PlayerFlags = {
  ALIVE: 1 << 0,
  MOVING: 1 << 1,
  ATTACKING: 1 << 2,
  INVULNERABLE: 1 << 3,
} as const;
export type PlayerFlags = (typeof PlayerFlags)[keyof typeof PlayerFlags];

/** True when every bit in `flags` is set in `value`. */
export const hasAll = (value: number, flags: number): boolean => (value & flags) === flags;

/** True when any bit in `flags` is set in `value`. */
export const hasAny = (value: number, flags: number): boolean => (value & flags) !== 0;

/*
 * Debug decoders. A packed int is unreadable in devtools, 
 * thus the names travel with the layout and are generated
 * from the same source (as the GDScript side rather than retyped like a monkey press.)
 */

const runStateNames: Record<number, string> = { 0: 'BOOTING', 1: 'MENU', 2: 'PLAYING', 3: 'PAUSED', 4: 'ENDED' };
/**
 * Human-readable name for a `RunState` value.
 */
export const runStateName = (value: number): string =>
  runStateNames[value] ?? `UNKNOWN(${value})`;

const playerFlagsNames: Record<number, string> = { 1: 'ALIVE', 2: 'MOVING', 4: 'ATTACKING', 8: 'INVULNERABLE' };
/**
 * Renders a packed `PlayerFlags` value as "ALIVE|MOVING", or "NONE".
 */
export const describePlayerFlags = (value: number): string => {
  const parts = Object.entries(playerFlagsNames)
    .filter(([bit]) => value & Number(bit))
    .map(([, label]) => label);
  const known = Object.keys(playerFlagsNames).reduce((a, b) => a | Number(b), 0);
  const rest = value & ~known;
  if (rest) parts.push(`UNKNOWN(0x${rest.toString(16)})`);
  return parts.length ? parts.join('|') : 'NONE';
};
