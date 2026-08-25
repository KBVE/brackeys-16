extends Control
class_name Crosshair

## Crosshair marks where picking actually happens once the pointer is captured.
##
## A sibling of the world's [SubViewportContainer], never a child of it: the
## [RenderBudget] divides everything inside that container, and a crosshair is two
## pixels wide before it is divided by anything.
##
## Only drawn while a look is underway. The rest of the time the cursor is the aim
## point and a second one would only argue with it. Which device raised the look is
## [CInput]'s problem, not this one's, so a drag on a touchscreen brings it up too.

const ARM_PIXELS := 7.0
const GAP_PIXELS := 3.0
const THICKNESS := 2.0
const INK := Color(1.0, 1.0, 1.0, 0.75)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.35)

## Read rather than polled from [Input] directly, because [SPlayerControl] is the only
## thing that reads devices and a second reader would disagree with it on touch.
var aiming: CInput

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(_delta: float) -> void:
	var wanted := aiming != null and aiming.holding_look
	if wanted != visible:
		visible = wanted
	if visible:
		queue_redraw()

func _draw() -> void:
	var centre := size * 0.5
	for arm: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from := centre + arm * GAP_PIXELS
		var to := centre + arm * (GAP_PIXELS + ARM_PIXELS)
		draw_line(from, to, OUTLINE, THICKNESS + 2.0)
		draw_line(from, to, INK, THICKNESS)
