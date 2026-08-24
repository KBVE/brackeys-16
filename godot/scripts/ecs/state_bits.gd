class_name StateBits

## GENERATED FILE - DO NOT EDIT.
##
## Source: shared/state.json + shared/events.json
## Regenerate: npm run gen (from vite/). Runs automatically on dev and build.

## Where the game as a whole is; replaces sniffing scene paths on the React side.
enum RunState {
	BOOTING = 0,
	MENU = 1,
	PLAYING = 2,
	PAUSED = 3,
	ENDED = 4,
}

## Per frame player state! Packed because systems test these thousands of times a
## second; a bit test is a single AND against a register but overkill for now, damn
## safari.
const PLAYER_ALIVE := 1 << 0
const PLAYER_MOVING := 1 << 1
const PLAYER_ATTACKING := 1 << 2
const PLAYER_INVULNERABLE := 1 << 3

## True when every bit in [param flags] is set in [param value].
static func has_all(value: int, flags: int) -> bool:
	return (value & flags) == flags

## True when any bit in [param flags] is set in [param value].
static func has_any(value: int, flags: int) -> bool:
	return (value & flags) != 0

# Debug decoders. A packed int is unreadable in a log or a breakpoint, which is
# the one real cost of packing state - so the names travel with the layout and
# are generated from the same source rather than retyped.

const _RUN_STATE_NAMES := {0: "BOOTING", 1: "MENU", 2: "PLAYING", 3: "PAUSED", 4: "ENDED"}
## Human-readable name for a [enum RunState] value.
static func run_state_name(value: int) -> String:
	return _RUN_STATE_NAMES.get(value, "UNKNOWN(%d)" % value)

const _PLAYER_FLAGS_NAMES := {1: "ALIVE", 2: "MOVING", 4: "ATTACKING", 8: "INVULNERABLE"}
## Renders a packed [code]PlayerFlags[/code] value as "ALIVE|MOVING", or "NONE".
static func describe_player_flags(value: int) -> String:
	var parts: PackedStringArray = []
	for bit: int in _PLAYER_FLAGS_NAMES:
		if value & bit:
			parts.append(_PLAYER_FLAGS_NAMES[bit])
	var known: int = 0
	for bit: int in _PLAYER_FLAGS_NAMES:
		known |= bit
	if value & ~known:
		parts.append("UNKNOWN(0x%x)" % (value & ~known))
	return "|".join(parts) if not parts.is_empty() else "NONE"
