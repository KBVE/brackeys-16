extends RefCounted
class_name RenderBudget

## RenderBudget : RefCounted
##
## Chooses how far to divide the world's render resolution, from measured frame
## time rather than from a device name. An iPad reports itself as a Mac and every
## Android GPU shares one user-agent, so the name is not evidence; the frame clock
## is. This also means hardware neither of us has ever run still gets a sane
## answer.
##
## Only the 3D world scales. The HUD is React, drawn by the browser outside the
## canvas, so nothing here can make text soft.

## Bounds on the divisor. 4 is a quarter resolution per axis, a sixteenth of the
## fragments, and past that the aisle stops reading as a corridor.
const FASTEST_SHRINK := 1
const SLOWEST_SHRINK := 4

## Below this we are dropping frames and must give pixels back.
const DEGRADE_BELOW_FPS := 50.0
## Above this there is headroom to spend, if it holds long enough to trust.
const UPGRADE_ABOVE_FPS := 58.0

## Frame rate is noisy per-frame, so decisions run on a smoothed value sampled on
## this cadence.
const SAMPLE_SECONDS := 0.5
const SMOOTHING := 0.15

## Giving up pixels must be quick, because the player is watching it stutter now.
## Taking them back must be slow, or the scale oscillates every time a carriage
## comes into view.
const SECONDS_SLOW_BEFORE_DEGRADE := 1.5
const SECONDS_FAST_BEFORE_UPGRADE := 6.0

## Each degrade doubles the wait before that level may be tried again, so a device
## that genuinely cannot hold a level stops re-testing it every few seconds.
const UPGRADE_PENALTY_SECONDS := 20.0

var shrink := FASTEST_SHRINK

var _smoothed_fps := 60.0
var _seconds_since_sample := 0.0
var _seconds_slow := 0.0
var _seconds_fast := 0.0
var _upgrade_locked_for := 0.0
var _upgrade_penalty := UPGRADE_PENALTY_SECONDS


## Starts where the device is likely to cope, so the first seconds of a run are
## not the worst ones. A touchscreen at two or more device pixels per CSS pixel
## is a phone rendering several million fragments for a screen you hold at arm's
## length, and it almost never holds 60 at full resolution.
func begin(has_touchscreen: bool, pixel_ratio: float) -> void:
	if has_touchscreen and pixel_ratio >= 2.0:
		shrink = 3
	elif has_touchscreen:
		shrink = 2
	else:
		shrink = FASTEST_SHRINK


## Feeds one frame in and returns the divisor to use now. The return is the whole
## answer, so the caller never has to ask twice or track state of its own.
func sample(frames_per_second: float, delta: float) -> int:
	_smoothed_fps = lerpf(_smoothed_fps, frames_per_second, SMOOTHING)
	_upgrade_locked_for = maxf(_upgrade_locked_for - delta, 0.0)
	_seconds_since_sample += delta
	if _seconds_since_sample < SAMPLE_SECONDS:
		return shrink
	_seconds_since_sample = 0.0

	if _smoothed_fps < DEGRADE_BELOW_FPS:
		_seconds_fast = 0.0
		_seconds_slow += SAMPLE_SECONDS
	elif _smoothed_fps > UPGRADE_ABOVE_FPS:
		_seconds_slow = 0.0
		_seconds_fast += SAMPLE_SECONDS
	else:
		# the band between the two is where we want to sit, so neither timer runs
		_seconds_slow = 0.0
		_seconds_fast = 0.0

	if _seconds_slow >= SECONDS_SLOW_BEFORE_DEGRADE and shrink < SLOWEST_SHRINK:
		shrink += 1
		_seconds_slow = 0.0
		_upgrade_locked_for = _upgrade_penalty
		_upgrade_penalty *= 2.0
	elif _seconds_fast >= SECONDS_FAST_BEFORE_UPGRADE and shrink > FASTEST_SHRINK \
			and is_zero_approx(_upgrade_locked_for):
		shrink -= 1
		_seconds_fast = 0.0
	return shrink


## Antialiasing costs a multiple of whatever the resolution already costs, so it
## is the first thing to go and the last to come back. At a divided resolution
## there is little left for it to fix anyway.
func msaa() -> Viewport.MSAA:
	if shrink >= 3:
		return Viewport.MSAA_DISABLED
	if shrink == 2:
		return Viewport.MSAA_2X
	return Viewport.MSAA_4X


## What the panel shows, so a slow phone can say why it looks soft.
func describe() -> String:
	var names := {
		Viewport.MSAA_DISABLED: "off",
		Viewport.MSAA_2X: "2x",
		Viewport.MSAA_4X: "4x",
	}
	return "1/%d, msaa %s" % [shrink, names.get(msaa(), "?")]
